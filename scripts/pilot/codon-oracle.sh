#!/bin/sh
# docs/codon-oracle-prediction.md. COD=<build with codon-oracle.patch> REL=<branch build>
set -u
C=bench-external/pilot/codon; O=${OUT:-$C/run}; mkdir -p "$O"
run() {  # run <label> <genome-name> <fasta> <exe> <labels|none>
  lb=$1; g=$2; fa=$3; exe=$4; lab=$5; a="$O/$lb.$g.dnac"; b="$O/$lb.$g.back"
  if [ "$lab" = none ]; then unset DNAC_CODON DNAC_CODON_SEQ
  else export DNAC_CODON="$C/$g.$lab" DNAC_CODON_SEQ="$C/$g.seq"; fi
  "$exe" c "$fa" "$a" 22 3 >/dev/null 2>"$O/$lb.$g.err" || { echo "FAIL enc $lb $g: $(cat "$O/$lb.$g.err")"; return; }
  "$exe" d "$a" "$b" >/dev/null 2>>"$O/$lb.$g.err" || { echo "FAIL dec $lb $g"; return; }
  cmp -s "$b" "$fa" || { echo "FAIL lossless $lb $g"; return; }
  echo "$lb $g $(wc -c < "$a") bytes (round-trip OK)"; rm -f "$b"
}
for pair in "ecoli ecoli.fa" "bsub $C/bsub.fa"; do
  set -- $pair; g=$1; fa=$2
  run rel "$g" "$fa" "$REL" none & run none "$g" "$fa" "$COD" none & run oracle "$g" "$fa" "$COD" lab & run shifted "$g" "$fa" "$COD" shf & wait
  cmp -s "$O/none.$g.dnac" "$O/rel.$g.dnac" && echo "none $g: byte-identical to rel" || echo "FAIL none $g differs from rel"
done
echo CODON_DONE
