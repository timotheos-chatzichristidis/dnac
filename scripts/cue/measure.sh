#!/bin/sh
# usage: measure.sh <exe> <label>  -> appends rows to sizes.tsv; round-trips every file
EXE=$1; LBL=$2
for t in ctl sub_1 sub_2 sub_3 ind_1 ind_2 ind_3 hp_1 hp_2 hp_3; do
  $EXE cr $t.fa $t.$LBL.dnac ${STATE:-ref.state} >/dev/null 2>&1 || { echo "FAIL encode $t"; exit 1; }
  $EXE dr $t.$LBL.dnac $t.$LBL.back ${STATE:-ref.state} >/dev/null 2>&1 || { echo "FAIL decode $t"; exit 1; }
  cmp -s $t.fa $t.$LBL.back || { echo "FAIL lossless $t"; exit 1; }
  rm -f $t.$LBL.back
  printf '%s\t%s\t%s\n' "$LBL" "$t" "$(wc -c < $t.$LBL.dnac)" >> sizes.tsv
done
echo done $LBL
