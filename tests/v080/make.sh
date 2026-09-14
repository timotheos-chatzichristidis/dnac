#!/bin/sh
# Stored v0.8.0 streams. v0.9.0 must decode every archive v0.8.0 wrote, byte for
# byte, and a round-trip suite running one build cannot show that on its own --
# it would only ever read streams its own build wrote. So these were written
# once by the v0.8.0 tag build and are committed; scripts/roundtrip.sh
# regenerates their inputs with `dnac gen` / `dnac mut` (unchanged since v0.8.0,
# pinned by inputs.sha256) and decodes them with the build under test.
#
#   git show v0.8.0:dnac.c > v080.c && gcc -O3 -o dnac_v080 v080.c -lm -pthread
#   sh tests/v080/make.sh ./dnac_v080
set -eu
OLD=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d)
trap 'cd / && rm -rf "$T"' EXIT
cd "$T"

"$OLD" gen g.fa 40000 3 >/dev/null
"$OLD" mut g.fa m.fa 20 4 >/dev/null
for l in 1 2 3 4; do "$OLD" c g.fa "$HERE/plain_l$l.dnac" 22 "$l" >/dev/null; done
"$OLD" c  g.fa "$HERE/blocks_j3.dnac" 22 3 -j 3 >/dev/null
"$OLD" cr m.fa "$HERE/ref_l1.dnac" g.fa 22 1 >/dev/null
"$OLD" cr m.fa "$HERE/ref_l3.dnac" g.fa 22 3 >/dev/null
sha256sum g.fa m.fa > "$HERE/inputs.sha256"
# every stream must decode with the build that wrote it, or it is not a fixture
for f in plain_l1 plain_l2 plain_l3 plain_l4 blocks_j3; do
  "$OLD" d "$HERE/$f.dnac" back >/dev/null; cmp g.fa back
done
for f in ref_l1 ref_l3; do
  "$OLD" dr "$HERE/$f.dnac" back g.fa >/dev/null; cmp m.fa back
done
ls -l "$HERE"
