#!/bin/sh
# docs/codon-speed-prediction.md, TIME part: E. coli, encode and decode, 3 rounds, variants
# alternating inside each round, one process at a time. SPD=... REL=...
set -u
O=${OUT:-bench-external/pilot/codon/spdt}; mkdir -p "$O"
now() { python -c "import time; print(time.perf_counter())"; }
for l in 1 2 3 4; do for r in 1 2 3; do for v in rel S0 S1 S2 S3 S123; do
  case $v in
    rel)  exe=$REL; env="" ;;
    S0)   exe=$SPD; env="DNAC_CODON=track" ;;
    S1)   exe=$SPD; env="DNAC_CODON=track DNAC_SV_LOG=1" ;;
    S2)   exe=$SPD; env="DNAC_CODON=track DNAC_SV_MAXORD=11" ;;
    S3)   exe=$SPD; env="DNAC_CODON=track DNAC_SV_INTER=1" ;;
    S123) exe=$SPD; env="DNAC_CODON=track DNAC_SV_LOG=1 DNAC_SV_MAXORD=11 DNAC_SV_INTER=1" ;;
  esac
  t0=$(date +%s%N); env $env "$exe" c ecoli.fa "$O/t.dnac" 22 $l >/dev/null 2>&1; t1=$(date +%s%N)
  env $env "$exe" d "$O/t.dnac" "$O/t.back" >/dev/null 2>&1; t2=$(date +%s%N)
  cmp -s "$O/t.back" ecoli.fa || echo "FAIL $v l$l r$r"
  echo "$l $r $v $(( (t1-t0)/1000000 )) $(( (t2-t1)/1000000 ))"
done; done; done
echo TIME_DONE
