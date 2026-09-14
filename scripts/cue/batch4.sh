#!/bin/sh
# Batch 4's identity checks (docs/batch4-prediction.md P0, P1, P2, P7): does the
# run-time cue reproduce the compiled one byte for byte, and does the cue
# switched off reproduce v0.8.0?
#
#   sh scripts/cue/batch4.sh [section...]     # sections: p0 p1 p2 p7 p5 p6 (default: all)
#
# Builds from three sources -- the v0.8.0 tag, 4932ffe (the last source that
# measured anything on the branch) and the working tree -- so it needs git and a
# compiler ($CC). Prints one PASS/FAIL line per check, appends every size to
# $WORK/batch4.tsv, and exits non-zero if anything failed. Nothing here sits
# behind a pipe: a check behind a pipe cannot go red (docs/batch3.md).
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

need "$REF" "sh scripts/get-data.sh"
need "$ROOT/ecoli_ind.fa" "sh scripts/get-data.sh"
SEQ=$ROOT/bench-external/seq/ecoli.seq
need "$SEQ" "bench-external/seq/ecoli.seq"

B=$WORK/b4
mkdir -p "$B"
fails=0
SECTIONS=${*:-p0 p1 p2 p7 p5 p6}
has() { case " $SECTIONS " in *" $1 "*) return 0 ;; esac; return 1; }
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; fails=$((fails+1)); }

# srcbuild <label> <git rev or 'tree'> [defines...]
srcbuild() {
  lbl=$1; rev=$2; shift 2
  if [ "$rev" = tree ]; then src=$ROOT/dnac.c
  else src=$B/src_$rev.c; git -C "$ROOT" show "$rev:dnac.c" > "$src"; fi
  $CC -O3 -o "$B/$lbl.exe" "$src" -lm -pthread "$@" || { echo "build failed: $lbl" >&2; exit 1; }
}
srcbuild v080     v0.8.0
srcbuild old_base 4932ffe
srcbuild old_cue  4932ffe -DDNAC_CUE
srcbuild old_m4   4932ffe -DDNAC_CUE -DCUE_MINLEN=4
srcbuild rel      tree
srcbuild v08      tree -DCUE_DEFAULT=0 -DREF_LEVEL_DEFAULT=3
srcbuild m16      tree -DCUE_MINLEN=16

# enc <label> <case> -> writes $B/<case>.<label>.dnac, round-trips it, logs size
enc() {
  lbl=$1; cs=$2; exe=$B/$lbl.exe; out=$B/$cs.$lbl.dnac
  case $cs in
    ref1) "$exe" cr "$ROOT/ecoli_ind.fa" "$out" "$REF" 22 1 >/dev/null 2>&1; in=$ROOT/ecoli_ind.fa; r=$REF ;;
    ref3) "$exe" cr "$ROOT/ecoli_ind.fa" "$out" "$REF" 22 3 >/dev/null 2>&1; in=$ROOT/ecoli_ind.fa; r=$REF ;;
    self1) "$exe" cr "$REF" "$out" "$REF" 22 1 >/dev/null 2>&1; in=$REF; r=$REF ;;
    pl1) "$exe" c "$SEQ" "$out" 22 1 >/dev/null 2>&1; in=$SEQ; r= ;;
    pl2) "$exe" c "$SEQ" "$out" 22 2 >/dev/null 2>&1; in=$SEQ; r= ;;
    pl3) "$exe" c "$SEQ" "$out" 22 3 >/dev/null 2>&1; in=$SEQ; r= ;;
    pl4) "$exe" c "$SEQ" "$out" 22 4 >/dev/null 2>&1; in=$SEQ; r= ;;
    j4)  "$exe" c "$SEQ" "$out" 22 3 -j 4 >/dev/null 2>&1; in=$SEQ; r= ;;
    *) echo "unknown case $cs" >&2; exit 1 ;;
  esac
  if [ -n "$r" ]; then "$exe" dr "$out" "$B/back" "$r" >/dev/null 2>&1
  else "$exe" d "$out" "$B/back" >/dev/null 2>&1; fi
  cmp -s "$in" "$B/back" || { fail "lossless $cs $lbl"; return 0; }
  rm -f "$B/back"
  printf '%s\t%s\t%s\n' "$lbl" "$cs" "$(wc -c < "$out")" >> "$WORK/batch4.tsv"
}

# identical <case> <a> <b>: the whole archive
identical() {
  if cmp -s "$B/$1.$2.dnac" "$B/$1.$3.dnac"; then pass "identical $1 $2 = $3"
  else fail "identical $1 $2 != $3"; fi
}
# butmagic <case> <old> <new> <old letter> <new letter>: equal after byte 4,
# and byte 4 really is the two letters (so the comparison is not vacuous)
butmagic() {
  a=$B/$1.$2.dnac; b=$B/$1.$3.dnac
  la=$(dd if="$a" bs=1 skip=3 count=1 2>/dev/null); lb=$(dd if="$b" bs=1 skip=3 count=1 2>/dev/null)
  if [ "$(wc -c < "$a")" != "$(wc -c < "$b")" ]; then fail "butmagic $1 $2/$3: sizes differ"; return 0; fi
  if [ "$la" != "$4" ] || [ "$lb" != "$5" ]; then fail "butmagic $1 $2/$3: letters '$la'/'$lb', expected '$4'/'$5'"; return 0; fi
  cmp -s "$a" "$b" && { fail "butmagic $1 $2/$3: identical, so the letter did not move"; return 0; }
  ndiff=$(cmp -l "$a" "$b" | awk '$1 != 4' | wc -l)
  if [ "$ndiff" -eq 0 ]; then pass "identical but the magic $1 $2 = $3"
  else fail "butmagic $1 $2/$3: $ndiff bytes differ past the magic"; fi
}

: > "$WORK/batch4.tsv"

if has p0; then
echo "== P0: an old -DDNAC_CUE archive read by the old unflagged build"
enc old_cue ref1
set +e
"$B/old_base.exe" dr "$B/ref1.old_cue.dnac" "$B/p0.back" "$REF" >/dev/null 2>&1
p0exit=$?
set -e
if [ -s "$B/p0.back" ] && cmp -s "$ROOT/ecoli_ind.fa" "$B/p0.back"; then p0out=same
elif [ -s "$B/p0.back" ]; then p0out=wrong
else p0out=none; fi
echo "P0 decoder exit=$p0exit output=$p0out   (prediction: exit=0 output=wrong)"
[ "$p0exit" -eq 0 ] && [ "$p0out" = wrong ] && pass "P0 held" || fail "P0 did not hold as predicted"
rm -f "$B/p0.back"
fi

if has p1; then
echo "== P1: the run-time cue is the compiled cue"
for cs in ref1 ref3 pl1 pl3 j4; do
  enc old_cue "$cs"; enc m16 "$cs"; enc old_m4 "$cs"; enc rel "$cs"
  case $cs in ref*) lo=U; ln=V ;; j4) lo=P; ln=Q ;; *) lo=C; ln=E ;; esac
  # m16 is experimental, so its letters are lower case
  lm=$(printf '%s' "$ln" | tr 'A-Z' 'a-z')
  butmagic "$cs" old_cue m16 "$lo" "$lm"
  butmagic "$cs" old_m4  rel "$lo" "$ln"
done
fi

if has p2; then
echo "== P2: the cue switched off is v0.8.0"
for cs in ref1 ref3 pl1 pl2 pl3 pl4 j4; do
  enc v080 "$cs"; enc v08 "$cs"
  identical "$cs" v080 v08
done
fi

if has p7; then
echo "== P7: target = reference costs nothing"
enc v080 self1; enc rel self1
s_old=$(wc -c < "$B/self1.v080.dnac"); s_new=$(wc -c < "$B/self1.rel.dnac")
echo "P7 v0.8.0 $s_old B, release $s_new B   (prediction: 1456 and 1446)"
[ "$s_new" -le "$s_old" ] && pass "P7 costs nothing" || fail "P7 the cue costs $((s_new - s_old)) B on an identical copy"
fi

# P5 and P6 need only small files: they are about which decoder accepts which
# stream, not about sizes. The inputs are generated, so this runs in seconds.
if has p5 || has p6; then
  "$B/rel.exe" gen "$B/s.fa" 60000 21 >/dev/null
  "$B/rel.exe" mut "$B/s.fa" "$B/t.fa" 20 22 >/dev/null
fi

# refused <label> <what>: the last command must have failed AND written nothing
refused() { if [ "$1" -ne 0 ] && [ ! -e "$B/x.out" ]; then pass "refused: $2"; else fail "accepted: $2"; fi; rm -f "$B/x.out"; }

if has p5; then
echo "== P5: the families never mix"
rm -f "$B/x.out"
"$B/rel.exe" c  "$B/s.fa" "$B/n_plain.dnac" 22 3 >/dev/null
"$B/rel.exe" c  "$B/s.fa" "$B/n_blk.dnac" 22 3 -j 3 >/dev/null
"$B/rel.exe" cr "$B/t.fa" "$B/n_ref.dnac" "$B/s.fa" 22 1 >/dev/null
"$B/m16.exe" cr "$B/t.fa" "$B/x_ref.dnac" "$B/s.fa" 22 1 >/dev/null
"$B/m16.exe" c  "$B/s.fa" "$B/x_plain.dnac" 22 3 >/dev/null
for f in n_plain n_blk; do
  set +e; "$B/v080.exe" d "$B/$f.dnac" "$B/x.out" >/dev/null 2>&1; rc=$?; set -e
  refused "$rc" "v0.8.0 decoder, release $f stream"
done
set +e; "$B/v080.exe" dr "$B/n_ref.dnac" "$B/x.out" "$B/s.fa" >/dev/null 2>&1; rc=$?; set -e
refused "$rc" "v0.8.0 decoder, release reference stream"
set +e; "$B/rel.exe" dr "$B/x_ref.dnac" "$B/x.out" "$B/s.fa" >/dev/null 2>&1; rc=$?; set -e
refused "$rc" "release decoder, experimental reference stream"
set +e; "$B/rel.exe" d "$B/x_plain.dnac" "$B/x.out" >/dev/null 2>&1; rc=$?; set -e
refused "$rc" "release decoder, experimental plain stream"
set +e; "$B/m16.exe" dr "$B/n_ref.dnac" "$B/x.out" "$B/s.fa" >/dev/null 2>&1; rc=$?; set -e
refused "$rc" "experimental decoder, release reference stream"
fi

if has p6; then
echo "== P6: a state primed by v0.8.0 itself"
rm -f "$B/x.out"
"$B/v080.exe" prime "$B/s.fa" "$B/v080.state" 22 3 >/dev/null
"$B/v080.exe" cr "$B/t.fa" "$B/o_ref.dnac" "$B/s.fa" 22 3 >/dev/null
"$B/rel.exe"  cr "$B/t.fa" "$B/n_ref3.dnac" "$B/s.fa" 22 3 >/dev/null
set +e; "$B/rel.exe" dr "$B/o_ref.dnac" "$B/x.out" "$B/v080.state" >/dev/null 2>&1; rc=$?; set -e
if [ "$rc" -eq 0 ] && cmp -s "$B/t.fa" "$B/x.out"; then pass "P6 release + v0.8.0 state reads a v0.8.0 stream"
else fail "P6 release + v0.8.0 state could not read a v0.8.0 stream (exit $rc)"; fi
rm -f "$B/x.out"
set +e; "$B/rel.exe" dr "$B/n_ref3.dnac" "$B/x.out" "$B/v080.state" >/dev/null 2>&1; rc=$?; set -e
refused "$rc" "a v0.8.0 state against a release cue stream"
fi

echo "sizes -> $WORK/batch4.tsv"
if [ "$fails" -ne 0 ]; then echo "$fails check(s) FAILED"; exit 1; fi
echo "all checks passed"
