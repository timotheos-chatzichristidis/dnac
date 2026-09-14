#!/bin/sh
# Batch 4's release figures (docs/batch4-prediction.md R1-R6): the claims of the
# cue documents, re-measured at the release settings -- `rel` (CUE_MINLEN 4, the
# run-time cue) against `v08` (the same source, cue off, byte-identical to
# v0.8.0) -- at level 3, where the records were measured, and at level 1, the
# default in reference mode since v0.9.0.
#
#   sh scripts/cue/batch4-release.sh [section...]     # sections: targets real ind human seq
#
# Every archive is decoded and cmp-ed before its size is recorded. Sizes go to
# $WORK/rel/sizes.tsv as <label> <case> <level> <bytes>; the summary at the end
# prints what docs/batch4.md reports. About 1.6 hours for everything. No timing
# here: sizes do not care what else the machine is doing, timings do
# (scripts/cue/batch4-time.sh, run alone).
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/rel
mkdir -p "$B"
need "$REF" "sh scripts/get-data.sh"
need "$TGT/ctl.fa" "sh scripts/cue/make-targets.sh"
REL=$(build rel $(defines_for rel))
V08=$(build v08 $(defines_for v08))
SECTIONS=${*:-targets real ind human seq}
has() { case " $SECTIONS " in *" $1 "*) return 0 ;; esac; return 1; }

# rt <label> <case> <level> <target> <ref> [map]: encode, decode, cmp, record
rt() {
  lb=$1; cs=$2; lv=$3; tg=$4; rf=$5; mp=${6:-}
  eval exe=\$$(echo "$lb" | tr a-z A-Z)
  out=$B/$cs.$lb.l$lv.dnac
  if [ -n "$mp" ]; then "$exe" cr "$tg" "$out" "$rf" 22 "$lv" -map "$mp" -mapw 1000 >/dev/null 2>&1
  else "$exe" cr "$tg" "$out" "$rf" 22 "$lv" >/dev/null 2>&1; fi \
    || { echo "FAIL encode $cs $lb l$lv" >&2; exit 1; }
  "$exe" dr "$out" "$B/back" "$rf" >/dev/null 2>&1 || { echo "FAIL decode $cs $lb l$lv" >&2; exit 1; }
  cmp -s "$tg" "$B/back" || { echo "FAIL lossless $cs $lb l$lv" >&2; exit 1; }
  rm -f "$B/back"
  n=$(wc -c < "$out"); rm -f "$out"
  printf '%s\t%s\t%s\t%s\n' "$lb" "$cs" "$lv" "$n" >> "$B/sizes.tsv"
  echo "  $lb $cs l$lv $n"
}

if has targets; then
  echo "== the ten controlled targets and the three E. coli pairs, against a primed MG1655"
  for lv in 3 1; do
    for lb in v08 rel; do
      eval exe=\$$(echo "$lb" | tr a-z A-Z)
      st=$B/ref.$lb.l$lv.state
      "$exe" prime "$REF" "$st" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL prime $lb l$lv" >&2; exit 1; }
      for t in ctl sub_1 sub_2 sub_3 ind_1 ind_2 ind_3 hp_1 hp_2 hp_3; do
        # level 3 also writes the map halves.py reads; -map leaves the archive unchanged
        if [ "$lv" = 3 ]; then rt "$lb" "$t" "$lv" "$TGT/$t.fa" "$st" "$B/$t.${lb}_l3.map.tsv"
        else rt "$lb" "$t" "$lv" "$TGT/$t.fa" "$st"; fi
      done
      if has real; then
        for p in w3110 o157 ecoli_ind; do rt "$lb" "$p" "$lv" "$ROOT/$p.fa" "$st"; done
      fi
      rm -f "$st"
    done
  done
  for lb in v08 rel; do
    echo "  halves ${lb} level 3:"
    REF="$REF" TGT="$TGT" ${PYTHON:-python} "$CUE_DIR/halves.py" "${lb}_l3" "$B" | tee -a "$B/halves.tsv"
  done
fi

if has ind; then
  echo "== the simulated chr21 individual, against chr21"
  need "$ROOT/chr21_ind.fa" "sh scripts/get-data.sh --human"
  for lv in 3 1; do for lb in v08 rel; do
    rt "$lb" chr21_ind "$lv" "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
  done; done
fi

if has human; then
  echo "== CHM13 against GRCh38, chr21 and chr22, FASTA, with bit-cost maps"
  for c in 21 22; do
    need "$HUM/chm13_chr$c.fa" "sh scripts/get-data.sh --cue"
    rf=$HUM/grch38_chr$c.fa
    need "$rf" "sh scripts/get-data.sh --cue"
    for lv in 3 1; do for lb in v08 rel; do
      rt "$lb" "chm13_chr$c" "$lv" "$HUM/chm13_chr$c.fa" "$rf" "$B/chm13_chr$c.${lb}_l$lv.map.tsv"
    done; done
  done
fi

if has seq; then
  echo "== CHM13 chr21 against GRCh38 chr21, plain ACGT (the competitor table's second half)"
  need "$HUM/chm13_chr21.seq" "sh scripts/get-data.sh --cue"
  for lv in 3 1; do for lb in v08 rel; do
    rt "$lb" chm13_chr21_seq "$lv" "$HUM/chm13_chr21.seq" "$HUM/grch38_chr21.seq"
  done; done
fi

# ------------------------------------------------------------------ summary
echo
echo "== summary (bytes: rel against v08 at the same level, and against v08 level 3)"
awk -F'\t' '{ S[$1 FS $2 FS $3] = $4; C[$2] = 1 }
  END {
    for (c in C) for (lv = 3; lv >= 1; lv -= 2) {
      v = S["v08" FS c FS lv]; r = S["rel" FS c FS lv]; v3 = S["v08" FS c FS 3]
      if (v == "" || r == "") continue
      printf "%-18s l%d  v08 %10d  rel %10d  %+7.3f%%   vs v08 l3 %+7.3f%%\n", c, lv, v, r, 100*(r/v-1), 100*(r/v3-1)
    }
  }' "$B/sizes.tsv" | sort

echo
echo "== per event, bits: (target - control) x 8 / 2000, mean of three seeds"
awk -F'\t' '{ S[$1 FS $2 FS $3] = $4 }
  END {
    for (lv = 3; lv >= 1; lv -= 2) for (i = 1; i <= 2; i++) {
      lb = (i == 1) ? "v08" : "rel"; c = S[lb FS "ctl" FS lv]
      if (c == "") continue
      split("sub ind hp", K, " "); line = sprintf("%s l%d:", lb, lv)
      for (k = 1; k <= 3; k++) {
        t = 0; for (s = 1; s <= 3; s++) t += (S[lb FS K[k] "_" s FS lv] - c) * 8 / 2000
        line = line sprintf("  %s %.2f", K[k], t / 3)
      }
      print line
    }
  }' "$B/sizes.tsv"

echo
echo "== windows, classed ONCE by what v0.8.0 at level 3 paid (shared < 0.2, diverged 0.2-1.0, novel >= 1.0)"
for c in 21 22; do
  base=$B/chm13_chr$c.v08_l3.map.tsv
  [ -s "$base" ] || continue
  for lv in 3 1; do
    [ -s "$B/chm13_chr$c.rel_l$lv.map.tsv" ] || continue
    paste "$base" "$B/chm13_chr$c.v08_l$lv.map.tsv" "$B/chm13_chr$c.rel_l$lv.map.tsv" | awk -F'\t' -v c="$c" -v lv="$lv" '
      NR == 1 { next }
      { k = ($5 < 0.2) ? "shared" : ($5 < 1.0) ? "diverged" : "novel"
        n[k]++; v[k] += $9; r[k] += $14; n["all"]++; v["all"] += $9; r["all"] += $14 }
      END { split("shared diverged novel all", K, " ")
            for (i = 1; i <= 4; i++) printf "chr%s l%d %-8s %6d windows  v08 %12.1f  rel %12.1f  %+7.2f%%\n",
                c, lv, K[i], n[K[i]], v[K[i]], r[K[i]], 100*(r[K[i]]/v[K[i]]-1) }'
  done
done
echo "ALL_DONE  ->  $B/sizes.tsv"
