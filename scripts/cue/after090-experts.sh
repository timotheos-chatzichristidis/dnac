#!/bin/sh
# Experiment A (docs/after-090-prediction.md): four mixer experts at level 1 in
# reference mode -- the one lever v0.9.0 leaves on the table.
#
#   sh scripts/cue/after090-experts.sh [sizes|time]
#
# `rel_x4` is the release source with -DL1_NMIX=4, which marks its archives as
# experimental (so it can never be confused with a release file) and is already
# a label in common.sh. Every archive is decoded and cmp-ed before its size is
# recorded. The timing half runs the three labels alternating inside each of
# three rounds, minimum quoted, because a ratio across separate invocations is
# not a ratio on a machine with 24% noise.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/a090
mkdir -p "$B"
SECT=${1:-sizes}
REL=$(build rel $(defines_for rel))
REL_X4=$(build rel_x4 $(defines_for rel_x4))
V08=$(build v08 $(defines_for v08))

now() { ${PYTHON:-python} -c 'import time; print("%.3f" % time.time())'; }
el()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", b-a}'; }

# rt <label> <case> <level> <target> <ref>
rt() {
  lb=$1; cs=$2; lv=$3; tg=$4; rf=$5
  eval exe=\$$(echo "$lb" | tr a-z A-Z)
  out=$B/$cs.$lb.l$lv.dnac
  "$exe" cr "$tg" "$out" "$rf" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL encode $cs $lb l$lv" >&2; exit 1; }
  "$exe" dr "$out" "$B/back" "$rf" >/dev/null 2>&1 || { echo "FAIL decode $cs $lb l$lv" >&2; exit 1; }
  cmp -s "$tg" "$B/back" || { echo "FAIL lossless $cs $lb l$lv" >&2; exit 1; }
  rm -f "$B/back"
  n=$(wc -c < "$out"); rm -f "$out"
  printf '%s\t%s\t%s\t%s\n' "$lb" "$cs" "$lv" "$n" >> "$B/sizes.tsv"
  echo "  $lb $cs l$lv $n"
}

if [ "$SECT" = sizes ]; then
  : > "$B/sizes.tsv"
  echo "== the tuning set: v0.8.0's default, v0.9.0's default, and four experts"
  for p in w3110 o157 ecoli_ind; do
    rt v08    "$p" 3 "$ROOT/$p.fa" "$REF"
    rt rel    "$p" 1 "$ROOT/$p.fa" "$REF"
    rt rel_x4 "$p" 1 "$ROOT/$p.fa" "$REF"
  done
  if [ -s "$ROOT/chr21_ind.fa" ]; then
    rt v08    chr21_ind 3 "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
    rt rel    chr21_ind 1 "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
    rt rel_x4 chr21_ind 1 "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
  fi
  echo "== the real human pair, and the held-out chromosome"
  for c in 21 22; do
    t=$HUM/chm13_chr$c.fa; r=$HUM/grch38_chr$c.fa
    [ -s "$t" ] && [ -s "$r" ] || { echo "  (chr$c data missing -- sh scripts/get-data.sh --cue)"; continue; }
    rt v08    "chm13_chr$c" 3 "$t" "$r"
    rt rel    "chm13_chr$c" 1 "$t" "$r"
    rt rel_x4 "chm13_chr$c" 1 "$t" "$r"
  done

  echo
  echo "== D-A conditions 1 and 2, per pair"
  awk -F'\t' '{ S[$2 FS $1] = $4; C[$2] = 1 }
    END {
      printf "%-14s %10s %10s %10s   %9s %9s\n", "pair", "v08 l3", "rel l1", "x4 l1", "x4/v08", "x4/rel"
      for (c in C) {
        v = S[c FS "v08"]; r = S[c FS "rel"]; x = S[c FS "rel_x4"]
        if (v == "" || r == "" || x == "") continue
        printf "%-14s %10d %10d %10d   %+8.2f%% %+8.2f%%\n", c, v, r, x, 100*(x/v-1), 100*(x/r-1)
      }
    }' "$B/sizes.tsv" | sort
  echo "ALL_DONE  ->  $B/sizes.tsv"
fi

if [ "$SECT" = time ]; then
  need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
  echo "== encode of CHM13 chr21 against the GRCh38 FASTA, priming inside the time"
  : > "$B/time.tsv"
  for r in 1 2 3; do
    for lb in v08 rel rel_x4; do
      eval exe=\$$(echo "$lb" | tr a-z A-Z)
      lv=$([ "$lb" = v08 ] && echo 3 || echo 1)
      t0=$(now)
      "$exe" cr "$HUM/chm13_chr21.fa" "$B/t.dnac" "$HUM/grch38_chr21.fa" 22 "$lv" >/dev/null 2>&1 \
        || { echo "FAIL $lb round $r" >&2; exit 1; }
      t1=$(now)
      printf '%s\t%s\t%s\t%s\n' "$lb" "$r" "$(el "$t0" "$t1")" "$(wc -c < "$B/t.dnac")" >> "$B/time.tsv"
      echo "  round $r  $lb  $(el "$t0" "$t1") s  $(wc -c < "$B/t.dnac") B"
      rm -f "$B/t.dnac"
    done
  done
  echo
  awk -F'\t' '{ if (m[$1] == "" || $3 < m[$1]) m[$1] = $3; b[$1] = $4 }
    END {
      printf "  v0.8.0 default      %7.2f s  %10d B\n", m["v08"], b["v08"]
      printf "  v0.9.0 default      %7.2f s  %10d B   %.2fx faster\n", m["rel"], b["rel"], m["v08"]/m["rel"]
      printf "  + four experts      %7.2f s  %10d B   %.2fx faster   (%+.1f%% time vs v0.9.0)\n",
             m["rel_x4"], b["rel_x4"], m["v08"]/m["rel_x4"], 100*(m["rel_x4"]/m["rel"]-1)
    }' "$B/time.tsv"
  echo "ALL_DONE  ->  $B/time.tsv"
fi
