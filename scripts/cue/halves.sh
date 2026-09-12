#!/bin/sh
# The osmosis measurement: per-event cost in the first and second half of each
# target, from the coder's own bit-cost map.
#
#   sh scripts/cue/halves.sh <label> [exe]
#
# -map reads probabilities the coder computed anyway and changes no model state,
# so these runs produce byte-identical archives to measure.sh's. Appends to
# $WORK/halves.tsv.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

LBL=${1:?usage: halves.sh <label> [exe]}
EXE=${2:-$(build "$LBL" $(defines_for "$LBL"))}
need "$TGT/ctl.fa" "sh scripts/cue/make-targets.sh"

ST=$WORK/ref_$LBL.state
"$EXE" prime "$REF" "$ST" 22 >/dev/null 2>&1 || { echo "FAIL prime $LBL" >&2; exit 1; }
for t in ctl hp_1 hp_2 hp_3 ind_1 ind_2 ind_3 sub_1 sub_2 sub_3; do
  "$EXE" cr "$TGT/$t.fa" "$WORK/m.dnac" "$ST" -map "$WORK/$t.$LBL.map.tsv" -mapw 1000 >/dev/null 2>&1 \
    || { echo "FAIL map $t" >&2; exit 1; }
done
rm -f "$ST" "$WORK/m.dnac"
REF="$REF" TGT="$TGT" ${PYTHON:-python} "$CUE_DIR/halves.py" "$LBL" "$WORK" | tee -a "$WORK/halves.tsv"
