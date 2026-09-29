#!/bin/sh
# Stored v0.11.0 streams: the last 'DNC' generation, before the CRC-64 trailer
# (docs/checksum-prediction.md, C3). From the checksum release on, every build
# writes 'DNH' streams, so a suite running one build would never again decode a
# 'DNC' codon, case or codon+case stream. These were written once by the v0.11.0
# tag build and are committed; scripts/roundtrip.sh regenerates the inputs the
# same way (dnac gen, dnac mut, scripts/genes.awk and the casify transform, pinned
# by inputs.sha256) and decodes them.
#
#   git show v0.11.0:dnac.c > v0110.c && gcc -O3 -o dnac_v0110 v0110.c -lm -pthread
#   sh tests/v0110/make.sh ./dnac_v0110
set -eu
OLD=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
HERE=$(cd "$(dirname "$0")" && pwd)
GA=$HERE/../../scripts/genes.awk
T=$(mktemp -d)
trap 'cd / && rm -rf "$T"' EXIT
cd "$T"
casify() { awk 'NR==1{print $0 " soft-masked test"; next}
  NR%4==2{print tolower($0); next}
  NR%4==3{s=""; for(i=1;i<=length($0);i++){c=substr($0,i,1); s=s ((i%9)<4?tolower(c):c)} print s; next}
  {print}' "$1"; }
"$OLD" gen g.fa 40000 3 >/dev/null
"$OLD" mut g.fa m.fa 20 4 >/dev/null
awk -v seed=1 -v genes=300 -v bias=97 -v junk=0 -f "$GA" > g_on.fa
casify g_on.fa > g_case.fa
"$OLD" c g.fa      "$HERE/plain_l1.dnac" 22 1 >/dev/null
"$OLD" c g.fa      "$HERE/plain_l3.dnac" 22 3 >/dev/null
"$OLD" c g_on.fa   "$HERE/codon_l1.dnac" 22 1 >/dev/null
"$OLD" c g_on.fa   "$HERE/codon_j3.dnac" 16 1 -j 3 >/dev/null
"$OLD" c g_case.fa "$HERE/codon_case_l1.dnac" 22 1 >/dev/null
"$OLD" cr m.fa     "$HERE/ref_l1.dnac" g.fa 22 1 >/dev/null
sha256sum g.fa g_on.fa g_case.fa m.fa > "$HERE/inputs.sha256"
for f in plain_l1 plain_l3; do "$OLD" d "$HERE/$f.dnac" back >/dev/null; cmp g.fa back; done
for f in codon_l1 codon_j3; do "$OLD" d "$HERE/$f.dnac" back >/dev/null; cmp g_on.fa back; done
"$OLD" d "$HERE/codon_case_l1.dnac" back >/dev/null; cmp g_case.fa back
"$OLD" dr "$HERE/ref_l1.dnac" back g.fa >/dev/null; cmp m.fa back
for f in "$HERE"/*.dnac; do printf '%s %s\n' "$(basename "$f")" "$(dd if="$f" bs=1 count=4 2>/dev/null)"; done
ls -l "$HERE"
