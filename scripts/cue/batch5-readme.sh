#!/bin/sh
# Batch 5: every dnac figure in README.md, re-measured with the RELEASE build.
#
#   sh scripts/cue/batch5-readme.sh [section...]   # fast slow meta ram
#
# The README described v0.8.0 until this batch, and its rows ran a build of
# dnac.c configured as v0.8.0 for that reason (verify-claims.ps1). v0.9.0 ships
# the cue on by default and level 1 with a reference, so every one of those
# figures moves, most by a hair and some by a lot. This produces the new ones.
#
# `rel` is the unflagged working tree; `v08` is the same source with the cue off
# and v0.8.0's default level, which is byte-identical to the v0.8.0 tag
# (docs/batch4.md P2). Both are measured for every figure the README states as a
# comparison. Every archive is decoded and cmp-ed before its size is recorded.
#
# Sections and rough cost on this machine: fast ~25 min (E. coli, the slice),
# slow ~3 h (chr21), meta ~40 min (200 Mbase metagenome), ram ~15 min (peak RSS,
# so run it with nothing else going).
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

# TAG keeps concurrent sections out of each other's scratch and tsv; the
# summary at the end reads every b5r-* file, so it sees all of them.
TAG=${TAG:-all}
B=$WORK/b5r-$TAG
mkdir -p "$B"
SEQ=${SEQ:-$ROOT/bench-external/seq}
REL=$(build rel $(defines_for rel))
V08=$(build v08 $(defines_for v08))
SECTIONS=${*:-fast slow meta}
has() { case " $SECTIONS " in *" $1 "*) return 0 ;; esac; return 1; }
[ -f "$B/sizes.tsv" ] || : > "$B/sizes.tsv"

# rt <label> <case> <level> <target> [ref] [-j N]: encode, decode, cmp, record.
# Skips a case already in sizes.tsv, so an interrupted run resumes.
rt() {
  lb=$1; cs=$2; lv=$3; tg=$4; rf=${5:-}; jn=${6:-}
  key="$lb	$cs	$lv"
  if grep -q "^$key	" "$B/sizes.tsv" 2>/dev/null; then
    echo "  $lb $cs l$lv $(grep "^$key	" "$B/sizes.tsv" | cut -f4)  (cached)"; return 0
  fi
  eval exe=\$$(echo "$lb" | tr a-z A-Z)
  [ -s "$tg" ] || { echo "missing target: $tg" >&2; exit 1; }
  out=$B/out.dnac
  set -- 22 "$lv"
  [ -n "$jn" ] && set -- "$@" -j "$jn"
  if [ -n "$rf" ]; then "$exe" cr "$tg" "$out" "$rf" "$@" >/dev/null 2>&1 || { echo "FAIL encode $cs $lb l$lv" >&2; exit 1; }
  else "$exe" c "$tg" "$out" "$@" >/dev/null 2>&1 || { echo "FAIL encode $cs $lb l$lv" >&2; exit 1; }; fi
  if [ -n "$rf" ]; then "$exe" dr "$out" "$B/back" "$rf" >/dev/null 2>&1 || { echo "FAIL decode $cs $lb l$lv" >&2; exit 1; }
  else "$exe" d "$out" "$B/back" >/dev/null 2>&1 || { echo "FAIL decode $cs $lb l$lv" >&2; exit 1; }; fi
  cmp -s "$tg" "$B/back" || { echo "FAIL lossless $cs $lb l$lv" >&2; exit 1; }
  rm -f "$B/back"
  n=$(wc -c < "$out"); rm -f "$out"
  printf '%s\t%s\t%s\t%s\n' "$lb" "$cs" "$lv" "$n" >> "$B/sizes.tsv"
  echo "  $lb $cs l$lv $n"
}

if has fast; then
  echo "== E. coli and the chr21 slice, plain"
  for lb in v08 rel; do
    rt $lb ecoli_seq 3 "$SEQ/ecoli.seq"
    rt $lb ecoli_seq 1 "$SEQ/ecoli.seq"
    rt $lb ecoli_fa  3 "$ROOT/ecoli.fa"
    rt $lb w3110_fa_alone 3 "$ROOT/w3110.fa"
    rt $lb slice_seq 3 "$SEQ/chr21slice.seq"
    rt $lb slice_seq 1 "$SEQ/chr21slice.seq"
    for lv in 1 2 3 4; do rt $lb slice_fa $lv "$ROOT/chr21_slice.fa"; done
    rt $lb ecoli_fa 4 "$ROOT/ecoli.fa"
    for j in 2 4 8; do rt $lb "ecoli_seq_j$j" 3 "$SEQ/ecoli.seq" "" $j; done
  done
  echo "== E. coli pairs, reference mode, both levels"
  for lb in v08 rel; do
    for lv in 3 1; do
      rt $lb w3110_seq   $lv "$SEQ/w3110.seq"   "$SEQ/ecoli.seq"
      rt $lb o157_seq    $lv "$SEQ/o157.seq"    "$SEQ/ecoli.seq"
      rt $lb w3110_fa    $lv "$ROOT/w3110.fa"   "$ROOT/ecoli.fa"
      rt $lb o157_fa     $lv "$ROOT/o157.fa"    "$ROOT/ecoli.fa"
      rt $lb ecoli_ind_fa $lv "$ROOT/ecoli_ind.fa" "$ROOT/ecoli.fa"
    done
  done
fi

if has slow; then
  echo "== chr21, plain"
  for lb in v08 rel; do
    for lv in 1 2 3 4; do rt $lb chr21_seq $lv "$SEQ/chr21.seq"; done
    rt $lb chr21_fa 3 "$ROOT/chr21.fa"
    for j in 2 4 8 16; do rt $lb "chr21_seq_j$j" 3 "$SEQ/chr21.seq" "" $j; done
    rt $lb chr21_ind_alone 3 "$ROOT/chr21_ind.fa"
  done
  echo "== chr21, reference mode, both levels"
  for lb in v08 rel; do
    for lv in 3 1; do
      rt $lb chr21_ind_ref $lv "$ROOT/chr21_ind.fa" "$ROOT/chr21.fa"
      rt $lb unrelated     $lv "$ROOT/ecoli.fa"     "$ROOT/chr21.fa"
    done
  done
fi

if has meta; then
  echo "== the metagenome (200,000,000 bases)"
  need "$SEQ/meta.seq" "sh scripts/get-data.sh --meta"
  for lb in v08 rel; do rt $lb meta 3 "$SEQ/meta.seq"; rt $lb meta 1 "$SEQ/meta.seq"; done
fi

if has ram; then
  echo "== state files and peak memory (run this alone)"
  for lb in v08 rel; do
    eval exe=\$$(echo "$lb" | tr a-z A-Z)
    for r in ecoli chr21; do
      [ -s "$ROOT/$r.fa" ] || continue
      # the default level is part of the figure: `dnac prime` picks level 1
      # since v0.9.0, so the README's state size is a level-1 state now.
      for lv in "" 3; do
        st=$B/$r.$lb.state
        "$exe" prime "$ROOT/$r.fa" "$st" 22 $lv >/dev/null 2>&1 || { echo "FAIL prime $r $lb ${lv:-default}" >&2; exit 1; }
        echo "  state $lb $r level ${lv:-default}: $(( $(wc -c < "$st") / 1048576 )) MB"
        rm -f "$st"
      done
    done
  done
fi

# ------------------------------------------------------------------ summary
echo
echo "== summary: rel against v08, same case and level"
awk -F'\t' '{ S[$1 FS $2 FS $3] = $4; C[$2 FS $3] = 1 }
  END { for (k in C) { split(k, a, FS); v = S["v08" FS k]; r = S["rel" FS k]
          if (v == "" || r == "") continue
          printf "%-18s l%s  v08 %11d  rel %11d  %+8.4f%%\n", a[1], a[2], v, r, 100*(r/v-1) } }' \
  "$WORK"/b5r-*/sizes.tsv | sort
echo "ALL_DONE  ->  $B/sizes.tsv"
