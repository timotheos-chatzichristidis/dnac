#!/bin/sh
# docs/codon-speed-prediction.md, SIZE part. SPD=<build with codon-speed.patch> REL=<branch build>
# One job per (variant, genome, level); every archive decoded and compared.
set -u
C=bench-external/pilot/codon; O=${OUT:-$C/spd}; mkdir -p "$O"
job() {  # job <variant> <genome> <level>
  v=$1; g=$2; l=$3; fa=$C/$g.fa; [ "$g" = ecoli ] && fa=ecoli.fa
  a="$O/$v.$g.l$l.dnac"; b="$a.back"
  case $v in
    rel)  exe=$REL; env="" ;;
    S0)   exe=$SPD; env="DNAC_CODON=track" ;;
    S1)   exe=$SPD; env="DNAC_CODON=track DNAC_SV_LOG=1" ;;
    S2)   exe=$SPD; env="DNAC_CODON=track DNAC_SV_MAXORD=11" ;;
    S3)   exe=$SPD; env="DNAC_CODON=track DNAC_SV_INTER=1" ;;
    S123) exe=$SPD; env="DNAC_CODON=track DNAC_SV_LOG=1 DNAC_SV_MAXORD=11 DNAC_SV_INTER=1" ;;
  esac
  if env $env "$exe" c "$fa" "$a" 22 "$l" >/dev/null 2>&1 && env $env "$exe" d "$a" "$b" >/dev/null 2>&1 && cmp -s "$b" "$fa"; then
    echo "$v $g $l $(wc -c < "$a")"
  else echo "$v $g $l FAIL"; fi
  rm -f "$b"
}
if [ $# -eq 3 ]; then job "$1" "$2" "$3"; exit 0; fi
for l in 1 2 3 4; do for g in ecoli bsub paer saur; do for v in rel S0 S1 S2 S3 S123; do echo "$v $g $l"; done; done; done > "$O/jobs"
xargs -P "${JOBS:-4}" -L 1 sh "$0" < "$O/jobs" | sort > "$O/sizes.txt"
echo SIZE_DONE
