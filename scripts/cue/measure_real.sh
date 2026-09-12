#!/bin/sh
# The real and simulated pairs, round-tripped, for one labelled build:
# W3110 and O157 against MG1655, and the two simulated individuals.
#
#   sh scripts/cue/measure_real.sh <label> [exe]
#
# Appends to $WORK/real.tsv. chr21_ind needs chr21.fa (sh scripts/get-data.sh
# --human) and takes about three minutes per build; it is skipped if absent.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

LBL=${1:?usage: measure_real.sh <label> [exe]}
EXE=${2:-$(build "$LBL" $(defines_for "$LBL"))}
need "$REF" "sh scripts/get-data.sh"

run() { # run <name> <target> <reference>
  "$EXE" cr "$2" "$WORK/r_$1.$LBL.dnac" "$3" >/dev/null 2>&1 || { echo "FAIL encode $1" >&2; exit 1; }
  "$EXE" dr "$WORK/r_$1.$LBL.dnac" "$WORK/r_$1.$LBL.back" "$3" >/dev/null 2>&1 || { echo "FAIL decode $1" >&2; exit 1; }
  cmp -s "$2" "$WORK/r_$1.$LBL.back" || { echo "FAIL lossless $1" >&2; exit 1; }
  rm -f "$WORK/r_$1.$LBL.back"
  printf '%s\t%s\t%s\n' "$LBL" "$1" "$(wc -c < "$WORK/r_$1.$LBL.dnac")" >> "$WORK/real.tsv"
}

run w3110     "$ROOT/w3110.fa"     "$REF"
run o157      "$ROOT/o157.fa"      "$REF"
run ecoli_ind "$ROOT/ecoli_ind.fa" "$REF"
if [ -s "$ROOT/chr21.fa" ] && [ -s "$ROOT/chr21_ind.fa" ]; then
  run chr21_ind "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
else
  echo "  (no chr21.fa / chr21_ind.fa: skipping chr21_ind)"
fi
echo "done $LBL  ->  $WORK/real.tsv"
