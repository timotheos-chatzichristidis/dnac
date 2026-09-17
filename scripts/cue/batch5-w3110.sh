#!/bin/sh
# Batch 5's one experiment (docs/batch5-prediction.md, W1-W4 and D1): is the
# level-1 default's +9.84% on W3110 a property of near-identical pairs, an
# artefact of a 2 kB output, or content that level 3's dropped models earn on?
#
#   sh scripts/cue/batch5-w3110.sh
#
# A controlled divergence gradient -- `dnac mut` at 0.05, 0.2, 1.0 and 5.0
# per-mille of MG1655, seed 42 -- compressed against MG1655 by the RELEASE build
# at levels 3 and 1, with W3110, O157 and ecoli_ind measured in the same run at
# the same settings. Every archive is decoded and cmp-ed before its size is
# recorded. About twenty minutes; sizes, so it does not care what else runs.
#
# The 0.2 per-mille point exists to land near W3110's 2 kB of output: W3 is a
# comparison at a matched output size, not an extrapolation from a curve.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/b5w
mkdir -p "$B"
need "$REF" "sh scripts/get-data.sh"
REL=$(build rel $(defines_for rel))
: > "$B/sizes.tsv"

# The gradient. `dnac mut` puts SNPs at the rate and short indels at a tenth of
# it, so the rate is also the event-count axis W4 predicts from.
# `dnac mut` writes the INPUT'S PATH into the FASTA header, and the header is
# compressed with everything else -- so the same target, from the same seed,
# gives a different archive depending on whether the caller spelled the
# reference with forward or backward slashes (2 bytes at level 3, 7 at level 1).
# Every mut-derived figure here therefore uses a CANONICAL header, written over
# the first line, so the number does not depend on who called the script.
for r in 0.05 0.2 1.0 5.0; do
  t=$B/mut_$r.fa
  if [ ! -s "$t" ]; then
    "$REL" mut "$REF" "$t.raw" "$r" 42 >/dev/null || { echo "FAIL mut $r" >&2; exit 1; }
    { echo ">mut_${r}_seed42"; tail -n +2 "$t.raw"; } > "$t"
    rm -f "$t.raw"
  fi
done

# rt <case> <level> <target> <ref-or-state>: encode, decode, cmp, record
rt() {
  cs=$1; lv=$2; tg=$3; rf=$4
  out=$B/$cs.l$lv.dnac
  "$REL" cr "$tg" "$out" "$rf" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL encode $cs l$lv" >&2; exit 1; }
  "$REL" dr "$out" "$B/back" "$rf" >/dev/null 2>&1 || { echo "FAIL decode $cs l$lv" >&2; exit 1; }
  cmp -s "$tg" "$B/back" || { echo "FAIL lossless $cs l$lv" >&2; exit 1; }
  rm -f "$B/back"
  n=$(wc -c < "$out"); rm -f "$out"
  printf '%s\t%s\t%s\n' "$cs" "$lv" "$n" >> "$B/sizes.tsv"
  echo "  $cs l$lv $n"
}

for lv in 3 1; do
  st=$B/ref.l$lv.state
  "$REL" prime "$REF" "$st" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL prime l$lv" >&2; exit 1; }
  for r in 0.05 0.2 1.0 5.0; do rt "mut_$r" "$lv" "$B/mut_$r.fa" "$st"; done
  for p in w3110 o157 ecoli_ind; do
    [ -s "$ROOT/$p.fa" ] || { echo "missing $ROOT/$p.fa (sh scripts/get-data.sh)" >&2; exit 1; }
    rt "$p" "$lv" "$ROOT/$p.fa" "$st"
  done
  rm -f "$st"
done

# ------------------------------------------------------------------ summary
# Expected event counts come from the rate, not from a diff: `dnac mut` draws a
# SNP with probability r/1000 and an indel with r/10000 at every base of the
# reference (dnac.c, do_mutate), and the reference has 4,641,652 of them.
echo
echo "== the level-1 penalty, against level 3 of the same build"
awk -F'\t' -v n=4641652 '
  { S[$1 FS $2] = $3 }
  END {
    printf "%-12s %10s %10s %9s %8s %10s %9s\n", "case", "level 3", "level 1", "penalty", "pct", "SNPs", "indels"
    split("mut_0.05 mut_0.2 mut_1.0 mut_5.0 ecoli_ind w3110 o157", K, " ")
    for (i = 1; i <= 7; i++) {
      c = K[i]; a = S[c FS 3]; b = S[c FS 1]
      if (a == "" || b == "") continue
      snp = ""; ind = ""
      if (substr(c, 1, 4) == "mut_") { r = substr(c, 5) + 0; snp = sprintf("%d", n*r/1000); ind = sprintf("%d", n*r/10000) }
      printf "%-12s %10d %10d %9d %+7.2f%% %10s %9s\n", c, a, b, b-a, 100*(b/a-1), snp, ind
    }
  }' "$B/sizes.tsv"

echo
echo "== W4: the penalty the per-event costs predict (0.39 B per indel - 0.021 B per SNP)"
awk -F'\t' -v n=4641652 '
  { S[$1 FS $2] = $3 }
  END {
    split("0.05 0.2 1.0 5.0", R, " ")
    for (i = 1; i <= 4; i++) {
      r = R[i] + 0; c = "mut_" R[i]; a = S[c FS 3]; b = S[c FS 1]
      if (a == "" || b == "") continue
      p = n*r/10000 * 0.39 - n*r/1000 * 0.021
      printf "  %-9s predicted %8.1f B   measured %6d B   ratio %5.2f\n", c, p, b-a, (p != 0 ? (b-a)/p : 0)
    }
  }' "$B/sizes.tsv"
echo "ALL_DONE  ->  $B/sizes.tsv"
