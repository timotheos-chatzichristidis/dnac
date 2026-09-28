#!/bin/sh
# docs/cue-source-prediction.md. SRC=<build with cue-source.patch> REL=<branch build>
set -u
H=bench-external/cue/human; O=${OUT:-bench-external/pilot/src}; mkdir -p "$O"
one() {  # one <chr>
  c=$1
  DNAC_LOADLOG="$O/$c.tsv" "$SRC" cr "$H/chm13_$c.fa" "$O/s.$c.dnac" "$H/grch38_$c.fa" 22 1 >/dev/null 2>&1 || { echo "FAIL enc src $c"; return; }
  "$REL" cr "$H/chm13_$c.fa" "$O/r.$c.dnac" "$H/grch38_$c.fa" 22 1 >/dev/null 2>&1 || { echo "FAIL enc rel $c"; return; }
  cmp -s "$O/s.$c.dnac" "$O/r.$c.dnac" || { echo "FAIL: the log changed the archive ($c)"; return; }
  "$REL" dr "$O/s.$c.dnac" "$O/b.$c" "$H/grch38_$c.fa" >/dev/null 2>&1 && cmp -s "$O/b.$c" "$H/chm13_$c.fa" || { echo "FAIL lossless $c"; return; }
  echo "$c: $(( $(wc -l < "$O/$c.tsv") - 1 )) loads logged, archive byte-identical to rel, round-trip OK"
  rm -f "$O/b.$c" "$O/r.$c.dnac"
}
one chr21 & one chr22 & wait
echo SRC_DONE
