#!/bin/sh
# Losslessness proof — POSIX port of adversarial.ps1, used by CI.
# Every input x every k must round-trip SHA-256 identical, in plain mode,
# reference mode, and with primed state files. No downloads: all inputs are
# generated here, so this runs anywhere in seconds.
#   sh scripts/roundtrip.sh ./dnac
set -eu
export LC_ALL=C
EXE=${1:-./dnac}
[ -x "$EXE" ] || { echo "no such executable: $EXE" >&2; exit 1; }
case $EXE in /*|./*|../*) ;; *) EXE=./$EXE ;; esac
EXE=$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")

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

# ------------------------------------------------------------------- verdict
if [ "$fail" -ne 0 ]; then echo "$fail of $n FAILED"; exit 1; fi
echo "$n/$n adversarial round-trips lossless"
