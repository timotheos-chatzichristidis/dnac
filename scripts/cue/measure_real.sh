#!/bin/sh
# usage: measure_real.sh <exe> <label>  -> real/sim pairs, round-tripped, appended to real.tsv
EXE=$1; LBL=$2; D=/c/Users/Timotheos/Desktop/dnac
run() { # name target refstate
  $EXE cr $2 r_$1.$LBL.dnac $3 >/dev/null 2>&1 || { echo "FAIL encode $1"; exit 1; }
  $EXE dr r_$1.$LBL.dnac r_$1.$LBL.back $3 >/dev/null 2>&1 || { echo "FAIL decode $1"; exit 1; }
  cmp -s $2 r_$1.$LBL.back || { echo "FAIL lossless $1"; exit 1; }
  rm -f r_$1.$LBL.back
  printf '%s\t%s\t%s\n' "$LBL" "$1" "$(wc -c < r_$1.$LBL.dnac)" >> real.tsv
}
run w3110 $D/w3110.fa ${STATE:-ref.state}
run o157 $D/o157.fa ${STATE:-ref.state}
run ecoli_ind $D/ecoli_ind.fa ${STATE:-ref.state}
run chr21_ind $D/chr21_ind.fa ${CSTATE:-chr21.state}
echo done $LBL
