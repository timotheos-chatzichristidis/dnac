#!/bin/sh
# Bits/base + round-trip verification on every genome in ./data.
# POSIX port of bench.ps1.   sh scripts/bench.sh ./dnac [k]
set -eu
export LC_ALL=C
cd "$(dirname "$0")/.."
EXE=${1:-./dnac}; K=${2:-22}
# Windows toolchains produce dnac.exe; accept either name.
if [ ! -x "$EXE" ] && [ -x "$EXE.exe" ]; then EXE="$EXE.exe"; fi
[ -x "$EXE" ] || { echo "no such executable: $EXE" >&2; exit 1; }
[ -d data ] || { echo "no ./data — run: sh scripts/get-data.sh --human" >&2; exit 1; }

if command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"; else SHA="shasum -a 256"; fi
hash_of() { $SHA "$1" | cut -d' ' -f1; }

printf '%-22s %12s %12s %9s %9s %9s\n' file bytes compressed bits/base "comp(s)" lossless
for f in data/*.fa; do
  [ -e "$f" ] || continue
  bases=$(tr -d '\r' < "$f" | grep -v '^[>;]' | tr 'acgt' 'ACGT' | tr -cd 'ACGT' | wc -c | tr -d ' ')
  [ "$bases" -gt 0 ] || continue
  t0=$(date +%s)
  "$EXE" c "$f" bench.dnac "$K" >/dev/null
  t1=$(date +%s)
  "$EXE" d bench.dnac bench.out >/dev/null
  csize=$(wc -c < bench.dnac | tr -d ' ')
  if [ "$(hash_of "$f")" = "$(hash_of bench.out)" ]; then ok=yes; else ok=NO; fi
  bpb=$(awk -v c="$csize" -v b="$bases" 'BEGIN{printf "%.4f", c*8/b}')
  printf '%-22s %12s %12s %9s %9s %9s\n' \
    "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')" "$csize" "$bpb" "$((t1-t0))" "$ok"
  rm -f bench.dnac bench.out
done

cat <<'EOF'

bits/base divides the whole compressed file by the number of ACGT bases; headers,
newlines and N runs are stored losslessly but excluded from the denominator.
EOF
