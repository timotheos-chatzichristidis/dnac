#!/bin/sh
# The cue WITHOUT a reference (docs/reference-free-prediction.md).
#
#   sh scripts/cue/reffree.sh [datasets...]
#
# Plain mode, k=22, levels 1 and 3, base against cue, every file round-tripped
# with cmp before its size is recorded. Appends to $WORK/reffree.tsv:
#
#   <label>  <dataset>  <level>  <bytes>  <bases>
#
# This is the mode dnac's README headline lives in, and the one the cue has
# never been run in. Datasets default to the four in the registration; each is
# skipped, loudly, if it is not there (sh scripts/get-data.sh, then mkseq.sh).
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

SEQ=$ROOT/bench-external/seq
[ $# -gt 0 ] || set -- ecoli chr21slice chr21 meta

BASE=$(build base $(defines_for base))
CUE=$(build cue $(defines_for cue))

for d in "$@"; do
  f=$SEQ/$d.seq
  if [ ! -s "$f" ]; then echo "  (no $d.seq -- skipped)"; continue; fi
  bases=$(wc -c < "$f" | tr -d ' ')
  for lvl in 1 3; do
    for lbl in base cue; do
      eval EXE=\$$(echo $lbl | tr a-z A-Z)
      out=$WORK/rf_$d.$lbl.l$lvl.dnac
      back=$WORK/rf_$d.$lbl.l$lvl.back
      "$EXE" c "$f" "$out" 22 $lvl >/dev/null 2>&1 || { echo "FAIL encode $d $lbl l$lvl" >&2; exit 1; }
      "$EXE" d "$out" "$back"      >/dev/null 2>&1 || { echo "FAIL decode $d $lbl l$lvl" >&2; exit 1; }
      cmp -s "$f" "$back" || { echo "FAIL lossless $d $lbl l$lvl" >&2; exit 1; }
      rm -f "$back"
      printf '%s\t%s\t%s\t%s\t%s\n' "$lbl" "$d" "$lvl" "$(wc -c < "$out")" "$bases" >> "$WORK/reffree.tsv"
      echo "  $d l$lvl $lbl: $(wc -c < "$out") B"
      rm -f "$out"
    done
  done
done
echo "done -> $WORK/reffree.tsv"
