#!/bin/sh
# Stored v0.9.0 streams of a file WITH lowercase bases. v0.9.0 coded lowercase as
# literals; v0.10.0 codes it as a case list (docs/case-list.md), so the decoder
# now has two ways into the same bytes and a suite running one build would only
# ever test the new one. These were written once by the v0.9.0 tag build and are
# committed; scripts/roundtrip.sh regenerates case_mix.fa the same way (dnac gen
# and the casify transform, pinned by inputs.sha256) and decodes them.
#
#   git show v0.9.0:dnac.c > v090.c && gcc -O3 -o dnac_v090 v090.c -lm -pthread
#   sh tests/v090/make.sh ./dnac_v090
set -eu
OLD=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d)
trap 'cd / && rm -rf "$T"' EXIT
cd "$T"
"$OLD" gen cg.fa 40000 3 >/dev/null
awk 'NR==1{print $0 " soft-masked test"; next}
  NR%4==2{print tolower($0); next}
  NR%4==3{s=""; for(i=1;i<=length($0);i++){c=substr($0,i,1); s=s ((i%9)<4?tolower(c):c)} print s; next}
  {print}' cg.fa > case_mix.fa
"$OLD" c case_mix.fa "$HERE/case_l3.dnac" 22 3 >/dev/null
"$OLD" c case_mix.fa "$HERE/case_j3.dnac" 22 3 -j 3 >/dev/null
sha256sum case_mix.fa > "$HERE/inputs.sha256"
for f in case_l3 case_j3; do "$OLD" d "$HERE/$f.dnac" back >/dev/null; cmp case_mix.fa back; done
ls -l "$HERE"
