#!/bin/sh
# Batch 5: the -j table's encode/decode wall-clock on the full chr21. Extracted
# from batch5-headtohead.sh, whose blocks section died on an awk quoting bug the
# first time; the sizes it also records are the ones batch5-readme.sh measured,
# so this only adds the timings.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"
B=$WORK/b5h; mkdir -p "$B"
SEQ=${SEQ:-$ROOT/bench-external/seq}
REL=$(build rel $(defines_for rel))
now() { ${PYTHON:-python} -c 'import time; print("%.3f" % time.time())'; }
el()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.1f", b-a}'; }
echo "== blocks on the full chr21, encode and decode"
for j in 1 2 4 8 16; do
  t0=$(now)
  "$REL" c "$SEQ/chr21.seq" "$B/j.dnac" 22 3 -j "$j" >/dev/null 2>&1 || { echo "FAIL -j $j" >&2; exit 1; }
  t1=$(now)
  "$REL" d "$B/j.dnac" "$B/j.out" >/dev/null 2>&1 || { echo "FAIL decode -j $j" >&2; exit 1; }
  t2=$(now)
  cmp -s "$SEQ/chr21.seq" "$B/j.out" || { echo "FAIL lossless -j $j" >&2; exit 1; }
  echo "  chr21 -j $j  $(wc -c < "$B/j.dnac") B  enc $(el "$t0" "$t1") s  dec $(el "$t1" "$t2") s"
  rm -f "$B/j.dnac" "$B/j.out"
done
echo "BLOCKS_DONE"
