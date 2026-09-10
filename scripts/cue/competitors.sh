#!/bin/sh
# head-to-head on CHM13 chr21 vs GRCh38 chr21; one row per tool to results.tsv
N=../nudge; D=/c/Users/Timotheos/Desktop/dnac; H=../HRCM
cp $N/chm13_chr21.fa $N/chm13_chr21.seq $N/grch38_chr21.seq . ; cp $D/chr21.fa grch38_chr21.fa
t() { date +%s.%N; }
row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> results.tsv; }
ok() { cmp -s "$1" "$2" && echo yes || echo NO; }
: > results.tsv
for kind in fa seq; do
  T=chm13_chr21.$kind; R=grch38_chr21.$kind
  a=$(t); zstd -q -f -19 --long=27 --patch-from=$R $T -o z.$kind.zst; b=$(t)
  zstd -q -f -d --long=27 --patch-from=$R z.$kind.zst -o z.back
  row $kind zstd-patch-from $(wc -c < z.$kind.zst) $(ok z.back $T) $(echo "$b - $a" | bc)
  for v in base cue; do
    a=$(t); $D/dnac_$v.exe cr $T d.$v.$kind.dnac $R >/dev/null 2>&1; b=$(t)
    $D/dnac_$v.exe dr d.$v.$kind.dnac d.back $R >/dev/null 2>&1
    row $kind dnac-$v $(wc -c < d.$v.$kind.dnac) $(ok d.back $T) $(echo "$b - $a" | bc)
  done
  rm -f z.back d.back
done
# HRCM (FASTA), in its own dir so its outputs are unambiguous
rm -rf h && mkdir h && cp chm13_chr21.fa grch38_chr21.fa h/ && cd h
a=$(t); ../$H/hrcm.exe compress -r grch38_chr21.fa -t chm13_chr21.fa > c.log 2>&1; b=$(t)
mkdir dd && cp chm13_chr21.7z grch38_chr21.fa dd/ && cd dd && ../../$H/hrcm.exe decompress -r grch38_chr21.fa -t chm13_chr21.7z > d.log 2>&1; cd ..
cd ..; row fa HRCM $(wc -c < h/chm13_chr21.7z) $(ok h/dd/chm13_chr21.fasta chm13_chr21.fa) $(echo "$b - $a" | bc)
# GeCo3 (plain), relative names because GeCo3 splits on ':'
PARAMR="-rm 20:500:1:35:0.95/3:100:0.95 -rm 13:200:1:1:0.95/0:0:0 -rm 10:10:0:0:0.95/0:0:0 -lr 0.03 -hs 64"
PARAMH="$PARAMR -tm 4:1:0:1:0.9/0:0:0 -tm 17:100:1:10:0.95/2:20:0.95"
G=$D/bench-external/geco3-master/src/GeCo3.exe
for tpl in R H; do
  eval P=\$PARAM$tpl
  rm -f chm13_chr21.seq.co
  a=$(t); $G -F $P -r grch38_chr21.seq chm13_chr21.seq > geco_$tpl.log 2>&1; b=$(t)
  row seq GeCo3-$tpl $(wc -c < chm13_chr21.seq.co) unverified $(echo "$b - $a" | bc)
  mv chm13_chr21.seq.co geco_$tpl.co
done
echo ALL_DONE
