#!/bin/sh
# The nudge's labelled L x D sweep (docs/nudge.md). One registration allowed
# exactly one sweep, and this is it -- kept because the table is published.
#
#   sh scripts/cue/sweep.sh [labels...]      # default: the five in the doc
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

[ $# -gt 0 ] || set -- L6D12 L8D12 L5D4 L6D4 L8D4

for LBL in "$@"; do
  EXE=$(build "$LBL" $(defines_for "$LBL"))
  sh "$CUE_DIR/measure.sh" "$LBL" "$EXE"
  sh "$CUE_DIR/measure_real.sh" "$LBL" "$EXE"
  echo "sweep done $LBL"
done
echo SWEEP_COMPLETE
