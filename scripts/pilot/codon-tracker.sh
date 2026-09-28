#!/bin/sh
# docs/codon-tracker-prediction.md. TRK=<build with codon-tracker.patch> REL=<branch build>
set -u
C=bench-external/pilot/codon; O=${OUT:-$C/trk}; mkdir -p "$O"
run() {  # run <label> <name> <fasta> <exe> <track|none>
  lb=$1; g=$2; fa=$3; exe=$4; md=$5; a="$O/$lb.$g.dnac"; b="$O/$lb.$g.back"
  if [ "$md" = none ]; then unset DNAC_CODON DNAC_CODON_LOG; else export DNAC_CODON=track DNAC_CODON_LOG="$O/$g.labels"; fi
  "$exe" c "$fa" "$a" 22 3 >/dev/null 2>"$O/$lb.$g.err" || { echo "FAIL enc $lb $g"; return; }
  unset DNAC_CODON_LOG
  "$exe" d "$a" "$b" >/dev/null 2>>"$O/$lb.$g.err" || { echo "FAIL dec $lb $g"; return; }
  cmp -s "$b" "$fa" || { echo "FAIL lossless $lb $g"; return; }
  echo "$lb $g $(wc -c < "$a") bytes (round-trip OK)"; rm -f "$b"
}
run rel ecoli ecoli.fa "$REL" none & run track ecoli ecoli.fa "$TRK" track & run none ecoli ecoli.fa "$TRK" none & wait
cmp -s "$O/none.ecoli.dnac" "$O/rel.ecoli.dnac" && echo "none ecoli: byte-identical to rel" || echo "FAIL none differs"
run rel bsub "$C/bsub.fa" "$REL" none & run track bsub "$C/bsub.fa" "$TRK" track & wait
run rel chr21s chr21_slice.fa "$REL" none & run track chr21s chr21_slice.fa "$TRK" track & wait
echo TRK_DONE
