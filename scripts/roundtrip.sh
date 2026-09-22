#!/bin/sh
# Losslessness proof — POSIX port of adversarial.ps1, used by CI.
# Every input x every k must round-trip SHA-256 identical, in plain mode,
# reference mode, and with primed state files. No downloads: all inputs are
# generated here, so this runs anywhere in seconds.
#   sh scripts/roundtrip.sh ./dnac
set -eu
export LC_ALL=C
EXE=${1:-./dnac}
# Windows toolchains produce dnac.exe; accept either name.
if [ ! -x "$EXE" ] && [ -x "$EXE.exe" ]; then EXE="$EXE.exe"; fi
[ -x "$EXE" ] || { echo "no such executable: $EXE" >&2; exit 1; }
# Absolute paths are left alone. The ?:/ and ?:\ cases are Windows drive
# letters -- without them "C:/x/dnac.exe" would be turned into "./C:/x/dnac.exe".
case $EXE in /*|./*|../*|?:/*|?:\\*) ;; *) EXE=./$EXE ;; esac
EXE=$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")
# the checkout, found before this script moves into its scratch directory
SRCROOT=$(cd "$(dirname "$0")/.." && pwd)

if command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"
elif command -v shasum   >/dev/null 2>&1; then SHA="shasum -a 256"
else echo "need sha256sum or shasum" >&2; exit 1; fi
hash_of() { $SHA "$1" | cut -d' ' -f1; }

DIR=$(mktemp -d 2>/dev/null || echo /tmp/dnac_adv.$$)
mkdir -p "$DIR"
trap 'cd / && rm -rf "$DIR"' EXIT   # leave the dir before removing it
cd "$DIR"

# ---------------------------------------------------------------- test inputs
: > empty.bin
printf 'A' > one_base.fa
i=0; while [ $i -lt 256 ]; do printf "\\$(printf '%03o' $i)"; i=$((i+1)); done > all_bytes.bin
awk 'BEGIN{for(i=0;i<5000;i++) printf "\n"}' > newlines.txt
awk 'BEGIN{for(i=0;i<500;i++) printf ">chr test\r\nACGTNNNNacgtACGT\r\nNNNNNNNNNNNN\r\nacgtacgtACGTACGT\r\n"}' > messy.fa
dd if=/dev/urandom of=random.bin bs=1024 count=200 2>/dev/null
awk 'BEGIN{srand(7);b="ACGT";for(i=0;i<200000;i++)printf "%s", substr(b,int(rand()*4)+1,1)}' > random_dna.fa
awk 'BEGIN{for(i=0;i<12500;i++) printf "ACGTTGCAAGGCCTTA"}' > repetitive.fa
# a block followed by its reverse complement (inverted repeat)
awk 'BEGIN{srand(11);b="ACGT";for(i=1;i<=100000;i++){c=substr(b,int(rand()*4)+1,1);s=s c}
     printf "%s",s
     for(i=length(s);i>=1;i--){c=substr(s,i,1)
       printf "%s", (c=="A"?"T":c=="T"?"A":c=="C"?"G":"C")}}' > inverted.fa
# a block plus a 10%-mutated copy (diverged repeat)
awk 'BEGIN{srand(13);b="ACGT";for(i=1;i<=100000;i++){c=substr(b,int(rand()*4)+1,1);s=s c}
     printf "%s",s
     for(i=1;i<=length(s);i++){c=substr(s,i,1)
       if(int(rand()*10)==0) c=substr(b,int(rand()*4)+1,1)
       printf "%s",c}}' > diverged.fa

FILES="empty.bin one_base.fa all_bytes.bin newlines.txt messy.fa random.bin random_dna.fa repetitive.fa inverted.fa diverged.fa"

fail=0; n=0
report() { n=$((n+1)); if [ "$2" != "$3" ]; then fail=$((fail+1)); echo "FAIL $1"; fi; }

# ------------------------------------------------------- plain mode, every k
for f in $FILES; do
  for k in 1 2 8 16 22 28; do
    "$EXE" c "$f" rt.dnac "$k" >/dev/null
    "$EXE" d rt.dnac rt.out  >/dev/null
    report "$f k=$k" "$(hash_of "$f")" "$(hash_of rt.out)"
    rm -f rt.dnac rt.out
  done
done

# -------------------------------------------------- block mode (-j N)
# Each block is coded against a model of its own, so N blocks is N codecs whose
# output must concatenate into one decodable stream. -j 1 must stay byte-for-byte
# what a plain run produces -- that identity is what makes every other measurement
# in the registry still valid.
for f in $FILES; do
  for j in 1 2 3 8; do
    "$EXE" c "$f" rt.dnac 16 -j "$j" >/dev/null
    "$EXE" d rt.dnac rt.out >/dev/null
    report "$f -j=$j" "$(hash_of "$f")" "$(hash_of rt.out)"
    rm -f rt.dnac rt.out
  done
done

# -j 1 is not merely decodable, it is the SAME BYTES as no -j at all.
"$EXE" c diverged.fa rt_plain.dnac 16 >/dev/null
"$EXE" c diverged.fa rt_j1.dnac 16 -j 1 >/dev/null
report "-j 1 is byte-identical to plain" "$(hash_of rt_plain.dnac)" "$(hash_of rt_j1.dnac)"
rm -f rt_plain.dnac rt_j1.dnac

# more blocks than bytes must not crash or lose data
printf 'ACGTACGTAC' > tiny_j.fa
"$EXE" c tiny_j.fa rt.dnac 16 -j 200 >/dev/null
"$EXE" d rt.dnac rt.out >/dev/null
report "tiny input, -j 200" "$(hash_of tiny_j.fa)" "$(hash_of rt.out)"
rm -f tiny_j.fa rt.dnac rt.out

# --------------------------------------------- every compression level

# Levels change which models exist, so each one is a distinct codec and needs
# its own proof. The level travels in the header; the decoder is given no hint.
for f in $FILES; do
  for lvl in 1 2 3 4; do
    "$EXE" c "$f" rt.dnac 22 "$lvl" >/dev/null
    "$EXE" d rt.dnac rt.out         >/dev/null
    report "$f level=$lvl" "$(hash_of "$f")" "$(hash_of rt.out)"
    rm -f rt.dnac rt.out
  done
done

# an out-of-range level must be refused, not silently clamped
n=$((n+1))
if "$EXE" c diverged.fa bad.dnac 22 9 >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL: level 9 was accepted"
fi
rm -f bad.dnac

# ------------------------------------------------------------ reference mode
# unrelated / short / messy references must all work and never corrupt.
awk 'BEGIN{printf ">r\n";for(i=0;i<100;i++)printf "ACGTTGCAAGGCCTTA";printf "\n"}' > ref_small.fa
awk 'BEGIN{for(i=0;i<200;i++)printf ">r desc\nacgtNNNNACGT\r\n"}' > ref_messy.fa
head -c 100000 random_dna.fa > ref_dna.fa

for f in $FILES; do
  for ref in ref_small.fa ref_messy.fa ref_dna.fa; do
    "$EXE" cr "$f" rt.dnac "$ref" 16 >/dev/null
    "$EXE" dr rt.dnac rt.out "$ref"  >/dev/null
    report "ref $f / $ref" "$(hash_of "$f")" "$(hash_of rt.out)"
    rm -f rt.dnac rt.out
  done
done

# ------------------------------------------- reference mode at every level
for lvl in 1 2 3 4; do
  "$EXE" cr diverged.fa rt.dnac ref_dna.fa 16 "$lvl" >/dev/null
  "$EXE" dr rt.dnac rt.out ref_dna.fa                >/dev/null
  report "ref level=$lvl" "$(hash_of diverged.fa)" "$(hash_of rt.out)"
  rm -f rt.dnac rt.out
done

# ------------------------------------------------- primed state interchange
"$EXE" prime ref_dna.fa ref_dna.state 16 >/dev/null
for f in $FILES; do
  "$EXE" cr "$f" rt.dnac ref_dna.fa    16 >/dev/null   # compress with FASTA...
  "$EXE" dr rt.dnac rt.out ref_dna.state  >/dev/null   # ...decompress with state
  report "state(fa->st) $f" "$(hash_of "$f")" "$(hash_of rt.out)"
  rm -f rt.dnac rt.out
  "$EXE" cr "$f" rt.dnac ref_dna.state 16 >/dev/null   # and the other way round
  "$EXE" dr rt.dnac rt.out ref_dna.fa     >/dev/null
  report "state(st->fa) $f" "$(hash_of "$f")" "$(hash_of rt.out)"
  rm -f rt.dnac rt.out
done

# a state and the FASTA it came from must produce byte-identical output
"$EXE" cr diverged.fa eq_fa.dnac ref_dna.fa    16 >/dev/null
"$EXE" cr diverged.fa eq_st.dnac ref_dna.state 16 >/dev/null
report "state-primed stream == FASTA-primed stream" \
       "$(hash_of eq_fa.dnac)" "$(hash_of eq_st.dnac)"
rm -f eq_fa.dnac eq_st.dnac

# the WRONG reference must be refused, never silently decoded
"$EXE" cr diverged.fa wrong.dnac ref_small.fa 16 >/dev/null
n=$((n+1))
if "$EXE" dr wrong.dnac wrong.out ref_messy.fa >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL: wrong reference was accepted"
fi
rm -f wrong.dnac wrong.out

# a state primed at one level must not decode a stream written at another
"$EXE" prime ref_dna.fa lvl1.state 16 1 >/dev/null
"$EXE" cr diverged.fa mix.dnac ref_dna.fa 16 3 >/dev/null
n=$((n+1))
if "$EXE" dr mix.dnac mix.out lvl1.state >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL: a level-1 state decoded a level-3 stream"
fi
rm -f lvl1.state mix.dnac mix.out

# a state file from an older dnac must be REFUSED, not scraped as if it were a
# FASTA. Dispatch matches the "DNACST" prefix precisely so this cannot go quiet.
{ printf 'DNACST01'; head -c 4096 /dev/urandom; } > old.state
n=$((n+1))
if "$EXE" cr diverged.fa old.dnac old.state 16 >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL: a v0.1.x state file was accepted"
fi
rm -f old.state old.dnac

# a v0.2.x stream carried no table geometry, so no build can know how to size
# its models. It must be refused by magic, not decoded into wrong bytes.
{ printf 'DNCB'; head -c 64 /dev/urandom; } > v02.dnac
n=$((n+1))
if "$EXE" d v02.dnac v02.out >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL: a v0.2.x stream was accepted"
fi
rm -f v02.dnac v02.out

# -map is a diagnostic, not part of the format: the same input must compress to
# byte-identical bytes with and without it. Nothing else in this file can catch a
# flag that quietly perturbs the coder, because every other case runs one binary
# with one set of arguments -- the same blind spot that hid three earlier bugs.
"$EXE" c diverged.fa map_off.dnac 16 >/dev/null
"$EXE" c diverged.fa map_on.dnac 16 -map map.tsv >/dev/null 2>&1
n=$((n+1))
if ! cmp -s map_off.dnac map_on.dnac; then
  fail=$((fail+1)); echo "FAIL: -map changed the compressed bytes"
fi
rm -f map_off.dnac map_on.dnac map.tsv

# ------------------------------------------- v0.9.0: the cue and its families
# Which family does this build write? Its own plain stream says: 'E' is a release
# build with the cue, 'C' the cue switched off (a v0.8.0-configured build), and
# lower case the same from an experimental build (non-default cue or level-1
# parameters). Everything below asserts what that family must do.
"$EXE" c diverged.fa fam.dnac >/dev/null
LET=$(dd if=fam.dnac bs=1 skip=3 count=1 2>/dev/null)
rm -f fam.dnac
EXPER=0; CUEON=1
case $LET in
  E) ;;
  C) CUEON=0 ;;
  e) EXPER=1 ;;
  c) EXPER=1; CUEON=0 ;;
  *) n=$((n+1)); fail=$((fail+1)); echo "FAIL: a plain stream carries the letter '$LET'" ;;
esac

# The cases the cue exists for, and the one it must not spoil. Indel-dense: 4
# indels and 40 substitutions per 1,000 bases. Homopolymer-dense: runs of 1-12
# of one base, and a copy in which one run in five slips by a base. Target =
# reference: the cue is not silent there (docs/batch3.md 4b), so this asserts
# losslessness; that it costs nothing is a registry row, since it needs two builds.
"$EXE" gen cue_ref.fa 60000 5 >/dev/null
"$EXE" mut cue_ref.fa cue_ind.fa 40 6 >/dev/null
awk 'BEGIN{srand(17);b="ACGT";o="";p=""
     for(i=0;i<9000;i++){c=substr(b,int(rand()*4)+1,1);L=1+int(rand()*12)
       for(j=0;j<L;j++)o=o c
       M=L; if(int(rand()*5)==0) M=L+(rand()<0.5?-1:1); if(M<1)M=1
       for(j=0;j<M;j++)p=p c}
     print ">hp_ref" > "hp_ref.fa"; print o > "hp_ref.fa"
     print ">hp_tgt" > "hp_tgt.fa"; print p > "hp_tgt.fa"}'
for pair in "cue_ind.fa cue_ref.fa" "hp_tgt.fa hp_ref.fa" "cue_ref.fa cue_ref.fa"; do
  set -- $pair
  for lvl in default 1 3; do
    if [ "$lvl" = default ]; then "$EXE" cr "$1" rt.dnac "$2" >/dev/null
    else "$EXE" cr "$1" rt.dnac "$2" 22 "$lvl" >/dev/null; fi
    "$EXE" dr rt.dnac rt.out "$2" >/dev/null
    report "cue $1 / $2 level=$lvl" "$(hash_of "$1")" "$(hash_of rt.out)"
    rm -f rt.dnac rt.out
  done
done
# the cue is reset when priming ends, so a state must still be interchangeable
# with its FASTA on exactly the file where the cue is busiest
"$EXE" prime cue_ref.fa cue.state >/dev/null
"$EXE" cr cue_ind.fa st.dnac cue.state >/dev/null
"$EXE" cr cue_ind.fa fa.dnac cue_ref.fa >/dev/null
report "cue: state-primed stream == FASTA-primed stream" "$(hash_of st.dnac)" "$(hash_of fa.dnac)"
"$EXE" dr st.dnac rt.out cue_ref.fa >/dev/null
report "cue: state -> FASTA decode" "$(hash_of cue_ind.fa)" "$(hash_of rt.out)"
rm -f st.dnac fa.dnac rt.out

# Default levels, read out of the header (byte 5): plain mode 3, reference mode
# and prime 1 -- and 3 for a build that reproduces v0.8.0.
hdr_level() { od -An -tu1 -j5 -N1 "$1" | tr -d ' '; }
want_ref=1; [ "$CUEON" -eq 1 ] || want_ref=3
"$EXE" c  cue_ind.fa dp.dnac >/dev/null
"$EXE" cr cue_ind.fa dr.dnac cue_ref.fa >/dev/null
"$EXE" cr cue_ind.fa ds.dnac cue.state >/dev/null
report "default level, plain" "3" "$(hdr_level dp.dnac)"
report "default level, reference" "$want_ref" "$(hdr_level dr.dnac)"
report "default level, prime" "$want_ref" "$(hdr_level ds.dnac)"

# A stream of the other family must be refused, and nothing written: flip the
# case of the letter, which is exactly the release/experimental difference.
L=$(dd if=dr.dnac bs=1 skip=3 count=1 2>/dev/null)
F=$(printf '%s' "$L" | tr 'A-Za-z' 'a-zA-Z')
for bad in "$F" Z; do
  cp dr.dnac flip.dnac
  printf 'DNC%s' "$bad" | dd of=flip.dnac bs=1 count=4 conv=notrunc 2>/dev/null
  n=$((n+1))
  if "$EXE" dr flip.dnac flip.out cue_ref.fa >/dev/null 2>&1 || [ -e flip.out ]; then
    fail=$((fail+1)); echo "FAIL: a stream with the letter '$bad' was accepted by a build writing '$L'"
  fi
  rm -f flip.dnac flip.out
done
# ...and the same for a state: flip its release/experimental marker (byte 6,
# '0' or 'x') and it must be refused, whichever family this build is
S6=$(dd if=cue.state bs=1 skip=6 count=1 2>/dev/null)
case $S6 in 0) S6F=x ;; *) S6F=0 ;; esac
cp cue.state flip.state
printf '%s' "$S6F" | dd of=flip.state bs=1 seek=6 count=1 conv=notrunc 2>/dev/null
n=$((n+1))
if "$EXE" cr cue_ind.fa flip.dnac flip.state >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL: a state marked '$S6F' was accepted by a build that writes '$S6'"
fi
rm -f flip.state flip.dnac
rm -f dp.dnac dr.dnac ds.dnac cue.state

# Stored v0.8.0 streams (tests/v080/make.sh wrote them with the v0.8.0 tag). A
# release build must decode every one byte for byte; an experimental build must
# refuse every one. The inputs are regenerated, and must be the ones v0.8.0 used.
FIX=$SRCROOT/tests/v080
if [ ! -s "$FIX/inputs.sha256" ]; then
  n=$((n+1)); fail=$((fail+1)); echo "FAIL: no stored v0.8.0 streams at $FIX"
else
  "$EXE" gen g.fa 40000 3 >/dev/null
  "$EXE" mut g.fa m.fa 20 4 >/dev/null
  n=$((n+1))
  if ! $SHA -c "$FIX/inputs.sha256" >/dev/null 2>&1; then
    fail=$((fail+1)); echo "FAIL: gen/mut no longer reproduce the v0.8.0 fixture inputs"
  fi
  for f in plain_l1 plain_l2 plain_l3 plain_l4 blocks_j3 ref_l1 ref_l3; do
    case $f in ref_*) src=m.fa; "$EXE" dr "$FIX/$f.dnac" v8.out g.fa >/dev/null 2>&1 || true ;;
               *)     src=g.fa; "$EXE" d  "$FIX/$f.dnac" v8.out      >/dev/null 2>&1 || true ;; esac
    if [ "$EXPER" -eq 0 ]; then
      if [ -e v8.out ]; then report "v0.8.0 stream $f" "$(hash_of $src)" "$(hash_of v8.out)"
      else n=$((n+1)); fail=$((fail+1)); echo "FAIL: v0.8.0 stream $f was refused"; fi
    else
      n=$((n+1)); [ -e v8.out ] && { fail=$((fail+1)); echo "FAIL: an experimental build read v0.8.0 stream $f"; }
    fi
    rm -f v8.out
  done
  # a state carries the cue: one primed with it must refuse a v0.8.0 stream, and
  # one primed without it (a v0.8.0-configured build) must read it; one primed
  # by an experimental build must refuse it whatever its cue
  "$EXE" prime g.fa g3.state 22 3 >/dev/null
  n=$((n+1))
  if [ "$EXPER" -eq 1 ]; then
    if "$EXE" dr "$FIX/ref_l3.dnac" v8.out g3.state >/dev/null 2>&1 || [ -e v8.out ]; then
      fail=$((fail+1)); echo "FAIL: an experimental state decoded a v0.8.0 stream"
    fi
    rm -f g3.state v8.out
  else
    if [ "$CUEON" -eq 1 ]; then
      if "$EXE" dr "$FIX/ref_l3.dnac" v8.out g3.state >/dev/null 2>&1 || [ -e v8.out ]; then
        fail=$((fail+1)); echo "FAIL: a state primed with the cue decoded a v0.8.0 stream"
      fi
    else
      "$EXE" dr "$FIX/ref_l3.dnac" v8.out g3.state >/dev/null 2>&1 || true
      [ -e v8.out ] && [ "$(hash_of m.fa)" = "$(hash_of v8.out)" ] || { fail=$((fail+1)); echo "FAIL: a cue-less state could not decode a v0.8.0 stream"; }
    fi
    rm -f g3.state v8.out
  fi
fi

# ------------------------------------------- v0.10.0: the case list
# A lowercase a/c/g/t outside a '>' line makes a file a case-list stream: it is
# coded as its uppercase twin and its case travels beside it as run lengths
# (docs/case-list.md). No rand() here: tests/v090 depends on these inputs, and
# awk implementations disagree about rand().
"$EXE" gen cg.fa 40000 3 >/dev/null
casify() { awk 'NR==1{print $0 " soft-masked test"; next}
  NR%4==2{print tolower($0); next}
  NR%4==3{s=""; for(i=1;i<=length($0);i++){c=substr($0,i,1); s=s ((i%9)<4?tolower(c):c)} print s; next}
  {print}' "$1"; }
casify cg.fa > case_mix.fa
awk 'NR==1{print ">all lower"; next}{print tolower($0)}' cg.fa > case_lower.fa
{ printf '>lowercase header acgt only\n'; awk 'NR>1' cg.fa; } > case_hdr.fa
{ awk 'NR>1' cg.fa | tr -d '\n' | head -c 20000; printf 'a'; } > case_last.fa
{ printf 'c'; awk 'NR>1' cg.fa | tr -d '\n' | head -c 20000; } > case_first.fa
printf '>x\nACGTnnnnNNNNacgtNnNn\nacgtacgtACGT\n' > case_n.fa
for f in case_mix.fa case_lower.fa case_last.fa case_first.fa case_n.fa; do
  for a in "22" "22 1" "22 4" "16 -j 3" "22 -j 8"; do
    "$EXE" c "$f" rt.dnac $a >/dev/null
    "$EXE" d rt.dnac rt.out >/dev/null
    report "case $f $a" "$(hash_of "$f")" "$(hash_of rt.out)"
    rm -f rt.dnac rt.out
  done
done
# The family letter: a case file gets the case letter of this build's family, and
# a file whose only lowercase is in its header is NOT a case file -- it must be
# written exactly as v0.9.0 wrote it, with v0.9.0's letter.
case $LET in E) CL=K ;; C) CL=F ;; e) CL=k ;; c) CL=f ;; *) CL=? ;; esac
"$EXE" c case_mix.fa cm.dnac >/dev/null
"$EXE" c case_hdr.fa ch.dnac >/dev/null
report "case: letter of a case file" "$CL" "$(dd if=cm.dnac bs=1 skip=3 count=1 2>/dev/null)"
report "case: letter of a header-only-lowercase file" "$LET" "$(dd if=ch.dnac bs=1 skip=3 count=1 2>/dev/null)"
rm -f ch.dnac
# The separation: the body of a case stream is byte for byte the stream of its
# uppercase twin (a/c/g/t uppercased outside '>' lines, n untouched), in plain and
# block mode. Header 16 B; then run count and section size, 8 B each, LE.
twin() { awk '/^>/{print; next}{gsub(/a/,"A");gsub(/c/,"C");gsub(/g/,"G");gsub(/t/,"T");print}' "$1"; }
for f in case_mix.fa case_n.fa; do
  twin "$f" > tw.fa
  for a in "22" "16 -j 3"; do
    "$EXE" c "$f" cs.dnac $a >/dev/null
    "$EXE" c tw.fa tw.dnac $a >/dev/null
    SEC=$(od -An -tu8 -j24 -N8 cs.dnac | tr -d ' ')
    # a stream that is not a case stream has no section there: read garbage as
    # "no section", so the comparison fails instead of aborting the suite
    case $SEC in ''|*[!0-9]*) SEC=0 ;; esac
    [ ${#SEC} -le 12 ] && [ "$SEC" -le "$(wc -c < cs.dnac)" ] || SEC=0
    tail -c +17 tw.dnac > b_tw
    tail -c +$((33 + SEC)) cs.dnac > b_cs
    report "case: body == uppercase twin, $f $a" "$(hash_of b_tw)" "$(hash_of b_cs)"
    rm -f cs.dnac tw.dnac b_tw b_cs
  done
  rm -f tw.fa
done
# A truncated case list must be refused, and nothing written.
head -c 40 cm.dnac > cut.dnac
n=$((n+1))
if "$EXE" d cut.dnac cut.out >/dev/null 2>&1 || [ -e cut.out ]; then
  fail=$((fail+1)); echo "FAIL: a truncated case list was accepted"
fi
rm -f cut.dnac cut.out cm.dnac
# Stored v0.9.0 streams of a file WITH lowercase (tests/v090/make.sh, written by
# the v0.9.0 tag build, where lowercase was a literal): a release build must
# still decode them byte for byte, an experimental build must refuse them.
FIX9=$SRCROOT/tests/v090
if [ ! -s "$FIX9/inputs.sha256" ]; then
  n=$((n+1)); fail=$((fail+1)); echo "FAIL: no stored v0.9.0 streams at $FIX9"
else
  n=$((n+1))
  if ! $SHA -c "$FIX9/inputs.sha256" >/dev/null 2>&1; then
    fail=$((fail+1)); echo "FAIL: gen/casify no longer reproduce the v0.9.0 fixture inputs"
  fi
  for f in case_l3 case_j3; do
    "$EXE" d "$FIX9/$f.dnac" v9.out >/dev/null 2>&1 || true
    if [ "$EXPER" -eq 0 ]; then
      if [ -e v9.out ]; then report "v0.9.0 stream $f" "$(hash_of case_mix.fa)" "$(hash_of v9.out)"
      else n=$((n+1)); fail=$((fail+1)); echo "FAIL: v0.9.0 stream $f was refused"; fi
    else
      n=$((n+1)); [ -e v9.out ] && { fail=$((fail+1)); echo "FAIL: an experimental build read v0.9.0 stream $f"; }
    fi
    rm -f v9.out
  done
fi

# ------------------------------------------------------------------- verdict
if [ "$fail" -ne 0 ]; then echo "$fail of $n FAILED"; exit 1; fi
echo "$n/$n adversarial round-trips lossless"
