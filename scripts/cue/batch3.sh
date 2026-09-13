#!/bin/sh
# Batch 3 (docs/v0.9.0-plan.md): the pre-registered sweep and add-back, at the
# level the mechanism is loud in -- level 1, reference mode.
#
#   sh scripts/cue/batch3.sh <stage> <level> <label>...
#
#   stage   screen   the ten controlled E. coli targets + ecoli_ind + o157
#           human    chr21_ind (simulated) and CHM13 chr21 vs GRCh38 chr21
#           heldout  CHM13 chr22 vs GRCh38 chr22   -- confirmation only
#           plain    ecoli.seq and chr21.seq, no reference
#   level   1..4, passed to cr / c
#   label   any label defines_for knows (base, cue, cue_L2, cue_x4, ...)
#
# Every file is decoded and compared with cmp before its size is recorded: a
# size from a run whose losslessness was not checked is not a measurement.
# Rows are appended to $WORK/batch3.tsv as
#
#   <label>  <stage>  <dataset>  <level>  <bytes>
#
# and turned into tables by scripts/cue/batch3-score.py.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

STAGE=${1:?usage: batch3.sh <stage> <level> <label>...}
LVL=${2:?usage: batch3.sh <stage> <level> <label>...}
shift 2
[ $# -gt 0 ] || { echo "no labels given" >&2; exit 1; }
OUT=$WORK/batch3.tsv

rt() { # rt <label> <dataset> <target> <ref|-> ; '-' means plain mode
  lbl=$1; name=$2; tgt=$3; ref=$4
  out=$WORK/b3_$name.$lbl.l$LVL.dnac
  back=$out.back
  if [ "$ref" = "-" ]; then
    "$EXE" c "$tgt" "$out" 22 "$LVL" >/dev/null 2>&1 || { echo "FAIL encode $name $lbl" >&2; exit 1; }
    "$EXE" d "$out" "$back"          >/dev/null 2>&1 || { echo "FAIL decode $name $lbl" >&2; exit 1; }
  else
    "$EXE" cr "$tgt" "$out" "$ref" 22 "$LVL" >/dev/null 2>&1 || { echo "FAIL encode $name $lbl" >&2; exit 1; }
    "$EXE" dr "$out" "$back" "$ref"          >/dev/null 2>&1 || { echo "FAIL decode $name $lbl" >&2; exit 1; }
  fi
  cmp -s "$tgt" "$back" || { echo "FAIL lossless $name $lbl l$LVL" >&2; exit 1; }
  rm -f "$back"
  printf '%s\t%s\t%s\t%s\t%s\n' "$lbl" "$STAGE" "$name" "$LVL" "$(wc -c < "$out")" >> "$OUT"
  echo "  $lbl l$LVL $name: $(wc -c < "$out") B"
  rm -f "$out"
}

for LBL in "$@"; do
  EXE=$(build "$LBL" $(defines_for "$LBL"))
  case $STAGE in
    screen)
      need "$REF" "sh scripts/get-data.sh"
      need "$TGT/ctl.fa" "sh scripts/cue/make-targets.sh"
      # one priming pass of MG1655 per build and level, reused by the ten targets
      ST=$WORK/b3ref_$LBL.l$LVL.state
      "$EXE" prime "$REF" "$ST" 22 "$LVL" >/dev/null 2>&1 || { echo "FAIL prime $LBL" >&2; exit 1; }
      for t in ctl sub_1 sub_2 sub_3 ind_1 ind_2 ind_3 hp_1 hp_2 hp_3; do
        rt "$LBL" "$t" "$TGT/$t.fa" "$ST"
      done
      rm -f "$ST"
      rt "$LBL" ecoli_ind "$ROOT/ecoli_ind.fa" "$REF"
      rt "$LBL" o157      "$ROOT/o157.fa"      "$REF"
      ;;
    human)
      if [ -s "$ROOT/chr21.fa" ] && [ -s "$ROOT/chr21_ind.fa" ]; then
        rt "$LBL" chr21_ind "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
      else echo "  (no chr21.fa / chr21_ind.fa: skipping chr21_ind)"; fi
      need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
      rt "$LBL" chm13_chr21 "$HUM/chm13_chr21.fa" "$HUM/grch38_chr21.fa"
      ;;
    heldout)
      need "$HUM/chm13_chr22.fa" "sh scripts/get-data.sh --cue"
      rt "$LBL" chm13_chr22 "$HUM/chm13_chr22.fa" "$HUM/grch38_chr22.fa"
      ;;
    plain)
      rt "$LBL" ecoli_plain "$ROOT/bench-external/seq/ecoli.seq" -
      if [ -s "$ROOT/bench-external/seq/chr21.seq" ]; then
        rt "$LBL" chr21_plain "$ROOT/bench-external/seq/chr21.seq" -
      else echo "  (no chr21.seq: skipping chr21_plain)"; fi
      ;;
    *) echo "unknown stage: $STAGE" >&2; exit 1 ;;
  esac
  echo "batch3 done $STAGE l$LVL $LBL"
done
echo "BATCH3_STAGE_COMPLETE $STAGE l$LVL -> $OUT"
