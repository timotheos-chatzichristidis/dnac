#!/bin/sh
# Batch 5: the reference-free head-to-head against GeCo3, re-run in ONE session
# with the v0.9.0 release build.
#
#   sh scripts/cue/batch5-headtohead.sh        # ~35 minutes, run it alone
#
# The README's head-to-head table promises that "every row was re-measured in a
# single session on one machine, with one build, so the times are comparable to
# each other". v0.9.0 moves every dnac size in it, so keeping v0.8.0's times
# beside v0.9.0's sizes would break exactly that promise. This re-runs both
# sides together.
#
# dnac is timed three times and the minimum is quoted (24% run-to-run noise on
# this machine); GeCo3 twice, because its heavy levels are minutes each. Sizes
# are deterministic and every dnac archive is round-tripped; GeCo3's decoder
# fails on every input tried here, which is why its sizes are marked unverified
# in the README and in docs/competitors.md.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/b5h
mkdir -p "$B"
SEQ=${SEQ:-$ROOT/bench-external/seq}
GECO=${GECO:-$ROOT/bench-external/GeCo3-master/src/GeCo3.exe}
REL=$(build rel $(defines_for rel))

now() { ${PYTHON:-python} -c 'import time; print("%.3f" % time.time())'; }

# dnac <case> <level> <file>: three rounds, minimum, round-tripped once
dn() {
  cs=$1; lv=$2; f=$3
  best=
  for r in 1 2 3; do
    t0=$(now)
    "$REL" c "$f" "$B/out.dnac" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL $cs l$lv" >&2; exit 1; }
    t1=$(now)
    d=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
    best=$(awk -v x="$d" -v y="${best:-9999}" 'BEGIN{print (x<y)?x:y}')
  done
  "$REL" d "$B/out.dnac" "$B/back" >/dev/null 2>&1 || { echo "FAIL decode $cs l$lv" >&2; exit 1; }
  cmp -s "$f" "$B/back" || { echo "FAIL lossless $cs l$lv" >&2; exit 1; }
  n=$(wc -c < "$B/out.dnac"); bases=$(cat "$f.acgt")
  rm -f "$B/out.dnac" "$B/back"
  awk -v c="$cs" -v l="$lv" -v n="$n" -v b="$bases" -v t="$best" \
    'BEGIN{ printf "  dnac  %-10s l%s  %10d B  %.4f bpb  %7.1f s\n", c, l, n, 8*n/b, t }'
  printf 'dnac\t%s\t%s\t%s\t%s\n' "$cs" "$lv" "$n" "$best" >> "$B/h2h.tsv"
}

# geco <case> <level> <file>: two rounds, minimum
gc() {
  cs=$1; lv=$2; f=$3
  [ -x "$GECO" ] || { echo "  (GeCo3 not built at $GECO -- skipped)"; return 0; }
  # GeCo3 writes <input>.co beside its input, so it runs on a copy in $B
  cp -f "$f" "$B/in.seq"
  best=
  for r in 1 2; do
    rm -f "$B/in.seq.co"
    t0=$(now)
    "$GECO" -F -l "$lv" "$B/in.seq" >/dev/null 2>&1 || { echo "  GeCo3 l$lv failed on $cs" >&2; rm -f "$B/in.seq"; return 0; }
    t1=$(now)
    d=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
    best=$(awk -v x="$d" -v y="${best:-99999}" 'BEGIN{print (x<y)?x:y}')
  done
  n=$(wc -c < "$B/in.seq.co"); bases=$(cat "$f.acgt"); rm -f "$B/in.seq.co" "$B/in.seq"
  awk -v c="$cs" -v l="$lv" -v n="$n" -v b="$bases" -v t="$best" \
    'BEGIN{ printf "  GeCo3 %-10s l%-2s %10d B  %.4f bpb  %7.1f s\n", c, l, n, 8*n/b, t }'
  printf 'geco3\t%s\t%s\t%s\t%s\n' "$cs" "$lv" "$n" "$best" >> "$B/h2h.tsv"
}

: > "$B/h2h.tsv"
echo "== E. coli (4,641,652 bases)"
dn ecoli 3 "$SEQ/ecoli.seq"
gc ecoli 9 "$SEQ/ecoli.seq"
gc ecoli 16 "$SEQ/ecoli.seq"

echo "== chr21 slice (9,836,065 bases)"
dn slice 3 "$SEQ/chr21slice.seq"
dn slice 1 "$SEQ/chr21slice.seq"
gc slice 16 "$SEQ/chr21slice.seq"
gc slice 14 "$SEQ/chr21slice.seq"

echo "== chr21 (40,088,619 bases)"
dn chr21 3 "$SEQ/chr21.seq"
dn chr21 2 "$SEQ/chr21.seq"
dn chr21 1 "$SEQ/chr21.seq"
gc chr21 14 "$SEQ/chr21.seq"
gc chr21 9 "$SEQ/chr21.seq"

# The levels table in the README is timed on the FASTA slice, all four back to
# back in one session, minimum of three -- the same promise as the table above,
# so it is re-run here rather than in a second session.
echo "== the four levels, chr21_slice.fa (the README's level table)"
for lv in 1 2 4 3; do dn slice_fa "$lv" "$ROOT/chr21_slice.fa"; done

echo
echo "ALL_DONE  ->  $B/h2h.tsv"
