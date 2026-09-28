#!/bin/sh
# docs/cue-oracle-prediction.md. Needs: ORC (patched build), REL (branch build).
#   ORC=... REL=... sh scripts/pilot/cue-oracle.sh
set -u
H=bench-external/cue/human; P=bench-external/pilot; O=${OUT:-$P/orc}; mkdir -p "$O"
one() {  # one <label> <chr> <exe> <mode|none>
  lb=$1; c=$2; exe=$3; md=$4; a="$O/$lb.$c.dnac"; b="$O/$lb.$c.back"
  if [ "$md" = none ]; then unset DNAC_ORACLE DNAC_ORACLE_MODE
  else export DNAC_ORACLE="$P/indels_$c.txt" DNAC_ORACLE_MODE=$md; fi
  "$exe" cr "$H/chm13_$c.fa" "$a" "$H/grch38_$c.fa" 22 3 >/dev/null 2>"$O/$lb.$c.err" || { echo "FAIL enc $lb $c"; return; }
  "$exe" dr "$a" "$b" "$H/grch38_$c.fa" >/dev/null 2>>"$O/$lb.$c.err" || { echo "FAIL dec $lb $c"; return; }
  cmp -s "$b" "$H/chm13_$c.fa" || { echo "FAIL lossless $lb $c"; return; }
  echo "$lb $c $(wc -c < "$a") bytes (round-trip OK)"; rm -f "$b"
}
one rel chr21 "$REL" none & one orc-at chr21 "$ORC" at & one orc-not chr21 "$ORC" not & wait
one noenv chr21 "$ORC" none
cmp -s "$O/noenv.chr21.dnac" "$O/rel.chr21.dnac" && echo "noenv chr21: byte-identical to rel (the patch is inert without the oracle)" || echo "FAIL noenv differs from rel"
one rel chr22 "$REL" none & one orc-at chr22 "$ORC" at & one orc-not chr22 "$ORC" not & wait
echo ORACLE_DONE
