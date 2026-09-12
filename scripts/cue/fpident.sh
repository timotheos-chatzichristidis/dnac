#!/bin/sh
# Floating-point identity of the cue build (docs/reference-free-prediction.md P7).
#
#   sh scripts/cue/fpident.sh
#
# The codec is deterministic because the encoder and decoder run identical float
# code in the same order -- inside one binary. Across binaries it is only
# deterministic if the compiler's float arithmetic agrees, which is why the
# 14-bit quantisation before the coder exists. The cue adds another table of
# probabilities and another mixer input, so that has to be re-checked with it.
#
# Same source, six ways of doing the arithmetic: two optimisation levels, x87
# against SSE2, and fused multiply-add contracted or not. Every archive must be
# byte-identical, and each build must decode every other build's file.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

D=$(defines_for cue)
VARIANTS="O2:-O2 O3:-O3 x87:-O2_-mfpmath=387 sse2:-O2_-mfpmath=sse_-msse2 fma:-O2_-ffp-contract=fast nofma:-O2_-ffp-contract=off"

need "$ROOT/ecoli.fa" "sh scripts/get-data.sh"
"$ROOT/dnac.exe" gen "$WORK/fp_gen.fa" 400000 7 >/dev/null 2>&1 || \
  { echo "could not generate the synthetic input" >&2; exit 1; }

names=
for v in $VARIANTS; do
  n=${v%%:*}; flags=$(echo "${v#*:}" | tr '_' ' ')
  exe=$WORK/dnac_cue_$n.exe
  # shellcheck disable=SC2086
  $CC $flags -o "$exe" "$ROOT/dnac.c" -lm $D 2>/dev/null || { echo "  (build $n failed: $flags -- skipped)"; continue; }
  names="$names $n"
  for input in fp_gen ecoli; do
    src=$WORK/fp_gen.fa; [ "$input" = ecoli ] && src=$ROOT/ecoli.fa
    "$exe" c "$src" "$WORK/fp_$input.$n.dnac" 22 3 >/dev/null 2>&1 || { echo "FAIL encode $n $input" >&2; exit 1; }
  done
  echo "  built $n ($flags)"
done

fail=0
for input in fp_gen ecoli; do
  ref=; for n in $names; do [ -z "$ref" ] && ref=$n; done
  for n in $names; do
    if cmp -s "$WORK/fp_$input.$ref.dnac" "$WORK/fp_$input.$n.dnac"; then
      echo "  $input: $n identical to $ref"
    else
      echo "  $input: $n DIFFERS from $ref" >&2; fail=1
    fi
  done
  # and every build must read every other build's archive
  for n in $names; do
    for m in $names; do
      src=$WORK/fp_gen.fa; [ "$input" = ecoli ] && src=$ROOT/ecoli.fa
      "$WORK/dnac_cue_$n.exe" d "$WORK/fp_$input.$m.dnac" "$WORK/fp_x.back" >/dev/null 2>&1 \
        && cmp -s "$src" "$WORK/fp_x.back" || { echo "  $input: $n cannot decode $m's archive" >&2; fail=1; }
    done
  done
done
rm -f "$WORK/fp_x.back"
[ $fail -eq 0 ] && echo "float identity holds across$names" || { echo "FLOAT IDENTITY BROKEN" >&2; exit 1; }
