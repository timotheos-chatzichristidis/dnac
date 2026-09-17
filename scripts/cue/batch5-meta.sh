#!/bin/sh
# Batch 5: the metagenome bake-off in README's "Where this loses", re-run in ONE
# session with the v0.9.0 release build.
#
#   sh scripts/cue/batch5-meta.sh        # ~35 minutes, run it alone
#
# 200,000,000 bases of ENA DRR003618 (sh scripts/get-data.sh --meta). The table
# quotes encode and decode wall-clock for six tools, so the whole row set has to
# come from one session on an otherwise idle machine -- the general-purpose
# tools are there to be compared against, and a comparison across sessions on a
# machine with 24% timing noise is not one.
#
# dnac's archives are round-tripped and byte-compared; the others are checked by
# decompressing to a hash. Single runs, as the table always was: at 200 Mbase a
# minimum of three would be two hours for numbers that carry no claim row.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/b5m
mkdir -p "$B"
SEQ=${SEQ:-$ROOT/bench-external/seq}
M=$SEQ/meta.seq
need "$M" "sh scripts/get-data.sh --meta"
REL=$(build rel $(defines_for rel))
BASES=$(cat "$M.acgt")
H=$(sha256sum < "$M" | cut -d' ' -f1)

now() { ${PYTHON:-python} -c 'import time; print("%.3f" % time.time())'; }
el()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.1f", b-a}'; }

: > "$B/meta.tsv"
row() { # row <tool> <bytes> <encode> <decode>
  awk -v t="$1" -v n="$2" -v e="$3" -v d="$4" -v b="$BASES" \
    'BEGIN{ printf "  %-20s %12d B  %.4f bpb  enc %7.1f s  dec %7.1f s\n", t, n, 8*n/b, e, d }'
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$B/meta.tsv"
}

for lv in 3 1; do
  t0=$(now); "$REL" c "$M" "$B/m.dnac" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL dnac l$lv" >&2; exit 1; }
  t1=$(now); "$REL" d "$B/m.dnac" "$B/m.out" >/dev/null 2>&1 || { echo "FAIL dnac decode l$lv" >&2; exit 1; }
  t2=$(now)
  [ "$(sha256sum < "$B/m.out" | cut -d' ' -f1)" = "$H" ] || { echo "FAIL lossless dnac l$lv" >&2; exit 1; }
  row "dnac -l$lv" "$(wc -c < "$B/m.dnac")" "$(el "$t0" "$t1")" "$(el "$t1" "$t2")"
  rm -f "$B/m.dnac" "$B/m.out"
done

# The general-purpose tools, each at the setting the README quotes.
try() { # try <name> <compress-cmd...> :: <decompress-cmd...>
  name=$1; shift
  command -v "$1" >/dev/null 2>&1 || { echo "  ($name not installed -- skipped)"; return 0; }
  case $name in
    "xz -9e")            c="xz -9e -T1 -c"; d="xz -d -c" ;;
    "zstd -19 --long=27") c="zstd -19 --long=27 -T1 -c"; d="zstd -d --long=27 -c" ;;
    "bzip2 -9")          c="bzip2 -9 -c"; d="bzip2 -d -c" ;;
    "gzip -9")           c="gzip -9 -c"; d="gzip -d -c" ;;
  esac
  t0=$(now); $c < "$M" > "$B/m.x" 2>/dev/null || { echo "  ($name failed)"; return 0; }
  t1=$(now); $d < "$B/m.x" > "$B/m.out" 2>/dev/null || { echo "  ($name decode failed)"; return 0; }
  t2=$(now)
  [ "$(sha256sum < "$B/m.out" | cut -d' ' -f1)" = "$H" ] || { echo "FAIL lossless $name" >&2; exit 1; }
  row "$name" "$(wc -c < "$B/m.x")" "$(el "$t0" "$t1")" "$(el "$t1" "$t2")"
  rm -f "$B/m.x" "$B/m.out"
}

try "xz -9e" xz
try "zstd -19 --long=27" zstd
try "bzip2 -9" bzip2
try "gzip -9" gzip

echo
echo "== dnac -l3 against the best of the rest"
awk -F'\t' '$1 == "dnac -l3" { d = $2 } $1 != "dnac -l3" && $1 != "dnac -l1" && ($2 < m || m == 0) { m = $2; n = $1 }
  END { if (d && m) printf "  %.2fx smaller than %s (%d against %d)\n", m/d, n, d, m }' "$B/meta.tsv"
echo "ALL_DONE  ->  $B/meta.tsv"
