#!/bin/sh
# The ten controlled E. coli targets, round-tripped, for one labelled build.
#
#   sh scripts/cue/measure.sh <label>        # builds it, measures it
#   sh scripts/cue/measure.sh <label> <exe>  # measure an existing binary
#
# Labels are the ones the docs use: base, cue, noroom, mf, mf_noroom, cue2,
# nudge, L6D12 ... (see defines_for in common.sh). Sizes are appended to
# $WORK/sizes.tsv; scripts/cue/score.py turns them into bits per event.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

LBL=${1:?usage: measure.sh <label> [exe]}
EXE=${2:-$(build "$LBL" $(defines_for "$LBL"))}
need "$REF" "sh scripts/get-data.sh"
need "$TGT/ctl.fa" "sh scripts/cue/make-targets.sh"

# One priming pass per build, reused by all ten targets: the reference is the
# same file every time, and priming it ten times measures the same thing ten
# times. A state and its FASTA give byte-identical archives (README).
ST=$WORK/ref_$LBL.state
"$EXE" prime "$REF" "$ST" 22 >/dev/null 2>&1 || { echo "FAIL prime $LBL" >&2; exit 1; }

for t in ctl sub_1 sub_2 sub_3 ind_1 ind_2 ind_3 hp_1 hp_2 hp_3; do
  "$EXE" cr "$TGT/$t.fa" "$WORK/$t.$LBL.dnac" "$ST" >/dev/null 2>&1 || { echo "FAIL encode $t" >&2; exit 1; }
  "$EXE" dr "$WORK/$t.$LBL.dnac" "$WORK/$t.$LBL.back" "$ST" >/dev/null 2>&1 || { echo "FAIL decode $t" >&2; exit 1; }
  cmp -s "$TGT/$t.fa" "$WORK/$t.$LBL.back" || { echo "FAIL lossless $t" >&2; exit 1; }
  rm -f "$WORK/$t.$LBL.back"
  printf '%s\t%s\t%s\n' "$LBL" "$t" "$(wc -c < "$WORK/$t.$LBL.dnac")" >> "$WORK/sizes.tsv"
done
rm -f "$ST"
echo "done $LBL  ->  $WORK/sizes.tsv"
