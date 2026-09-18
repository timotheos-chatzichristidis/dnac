#!/bin/sh
# Experiment B (docs/after-090-prediction.md): collect the cue's shift signs.
#   sh scripts/cue/after090-slip.sh
# Builds the instrumented codec, asserts it writes the SAME archive as the plain
# release build (the instrument must not be part of the format), then logs the
# loads for the real pair, the held-out chromosome and the simulated control.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"
B=$WORK/b090; mkdir -p "$B"
PROF=$B/dnac_prof.exe
REL=$(build rel $(defines_for rel))
$CC -O3 -Wall -o "$PROF" "$ROOT/dnac.c" -lm -pthread -DDNAC_CUEPROF || { echo "build failed" >&2; exit 1; }

run() {  # run <name> <target> <ref>
  nm=$1; tg=$2; rf=$3
  [ -s "$tg" ] && [ -s "$rf" ] || { echo "  ($nm: data missing)"; return 0; }
  DNAC_CUEPROF_OUT="$B/$nm.tsv" "$PROF" cr "$tg" "$B/p.dnac" "$rf" 22 1 >/dev/null 2>&1 \
    || { echo "FAIL prof $nm" >&2; exit 1; }
  "$REL" cr "$tg" "$B/r.dnac" "$rf" 22 1 >/dev/null 2>&1 || { echo "FAIL rel $nm" >&2; exit 1; }
  cmp -s "$B/p.dnac" "$B/r.dnac" || { echo "FAIL: the instrument changed the archive ($nm)" >&2; exit 1; }
  "$PROF" dr "$B/p.dnac" "$B/back" "$rf" >/dev/null 2>&1 || { echo "FAIL decode $nm" >&2; exit 1; }
  cmp -s "$tg" "$B/back" || { echo "FAIL lossless $nm" >&2; exit 1; }
  rm -f "$B/p.dnac" "$B/r.dnac" "$B/back"
  echo "  $nm: $(( $(wc -l < "$B/$nm.tsv") - 1 )) cue loads, archive byte-identical to the release"
}

echo "== collecting cue loads (target only; priming is excluded by g_cueprof_on)"
run chm13_chr21 "$HUM/chm13_chr21.fa" "$HUM/grch38_chr21.fa"
run chm13_chr22 "$HUM/chm13_chr22.fa" "$HUM/grch38_chr22.fa"
run chr21_ind   "$ROOT/chr21_ind.fa"  "$ROOT/chr21.fa"
run ecoli_ind   "$ROOT/ecoli_ind.fa"  "$REF"
echo
${PYTHON:-python} "$CUE_DIR/after090-momentum.py" \
  "chm13_chr21=$B/chm13_chr21.tsv" "chm13_chr22=$B/chm13_chr22.tsv" \
  "chr21_ind=$B/chr21_ind.tsv" "ecoli_ind=$B/ecoli_ind.tsv"
echo "SLIP_DONE"
