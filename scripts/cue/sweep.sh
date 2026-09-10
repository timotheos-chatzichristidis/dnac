#!/bin/sh
# labelled sweep (docs/nudge-prediction.md allows one): L x D on the E. coli set + o157 + ecoli_ind
D=/c/Users/Timotheos/Desktop/dnac
for cfg in "6 12" "8 12" "5 4" "6 4" "8 4"; do
  set -- $cfg; L=$1; DD=$2; LBL="L${L}D${DD}"
  gcc -O3 -DDNAC_NUDGE -DNUDGE_L=$L -DNUDGE_D=$DD -o $D/dnac_$LBL.exe $D/dnac.c -lm || exit 1
  $D/dnac_$LBL.exe prime ref.fa ref_$LBL.state 22 >/dev/null 2>&1
  STATE=ref_$LBL.state ./measure.sh $D/dnac_$LBL.exe $LBL || exit 1
  for r in o157 ecoli_ind; do
    f=$D/$r.fa
    $D/dnac_$LBL.exe cr $f r_$r.$LBL.dnac ref_$LBL.state >/dev/null 2>&1
    $D/dnac_$LBL.exe dr r_$r.$LBL.dnac r_$r.$LBL.back ref_$LBL.state >/dev/null 2>&1
    cmp -s $f r_$r.$LBL.back || { echo "FAIL lossless $r $LBL"; exit 1; }
    rm -f r_$r.$LBL.back
    printf '%s\t%s\t%s\n' "$LBL" "$r" "$(wc -c < r_$r.$LBL.dnac)" >> real.tsv
  done
  rm -f ref_$LBL.state
  echo "sweep done $LBL"
done
echo SWEEP_COMPLETE
