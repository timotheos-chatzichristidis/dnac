#!/bin/sh
# usage: halves.sh <exe> <state> <label> -> maps for ctl, hp_*, ind_*; appends per-half costs to halves.tsv
EXE=$1; ST=$2; LBL=$3
for t in ctl hp_1 hp_2 hp_3 ind_1 ind_2 ind_3 sub_1 sub_2 sub_3; do
  $EXE cr $t.fa m.dnac $ST -map $t.$LBL.map.tsv -mapw 1000 >/dev/null 2>&1 || { echo FAIL $t; exit 1; }
done
python halves.py $LBL >> halves.tsv
echo done $LBL
