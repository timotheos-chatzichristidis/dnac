#!/bin/sh
# Paired encode timings for Batch 3's add-back (docs/batch3-prediction.md).
#
#   sh scripts/cue/batch3-time.sh <level> <rounds> <label>...
#
# A label may carry its own level as `label@level` (e.g. `base@3`), so the
# v0.8.0 default can be timed in the SAME rounds as the level-1 candidates it
# is compared with -- the 2x claim is a ratio, and a ratio across two
# invocations minutes apart is not one on a machine with 24% noise.
#
# The labels alternate INSIDE each round, back to back, and the minimum of the
# rounds is what gets quoted: run-to-run noise on this machine is 24%, so two
# numbers from different minutes are not comparable. The measurement is the one
# docs/speed.md used -- `cr` of CHM13 chr21 against the GRCh38 chr21 FASTA, so
# the priming pass is inside the time, as it is for a user with one target.
#
# Appends to $WORK/batch3-time.tsv:  <label> <level> <round> <seconds> <bytes>
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

LVL0=${1:?usage: batch3-time.sh <level> <rounds> <label>...}
LVL=$LVL0
R=${2:?usage: batch3-time.sh <level> <rounds> <label>...}
shift 2
[ $# -gt 0 ] || { echo "no labels given" >&2; exit 1; }

TGT_F=$HUM/chm13_chr21.fa
REF_F=$HUM/grch38_chr21.fa
need "$TGT_F" "sh scripts/get-data.sh --cue"
need "$REF_F" "sh scripts/get-data.sh --cue"

# Build everything first: a compile inside a round would land in one label's time.
for SPEC in "$@"; do LBL=${SPEC%@*}; build "$LBL" $(defines_for "$LBL") >/dev/null; done

i=1
while [ "$i" -le "$R" ]; do
  for SPEC in "$@"; do
    LBL=${SPEC%@*}
    case $SPEC in *@*) LVL=${SPEC##*@} ;; *) LVL=$LVL0 ;; esac
    EXE=$WORK/dnac_$LBL.exe
    out=$WORK/t_$LBL.l$LVL.dnac
    t0=$(date +%s.%N)
    "$EXE" cr "$TGT_F" "$out" "$REF_F" 22 "$LVL" >/dev/null 2>&1 || { echo "FAIL encode $LBL" >&2; exit 1; }
    t1=$(date +%s.%N)
    printf '%s\t%s\t%s\t%s\t%s\n' "$LBL" "$LVL" "$i" \
      "$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')" \
      "$(wc -c < "$out")" >> "$WORK/batch3-time.tsv"
    echo "  round $i  $LBL l$LVL: $(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}') s, $(wc -c < "$out") B"
    rm -f "$out"
  done
  i=$((i + 1))
done
echo "BATCH3_TIME_COMPLETE -> $WORK/batch3-time.tsv"
