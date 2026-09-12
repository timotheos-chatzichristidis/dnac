#!/bin/sh
# Head-to-head on the real human pair: CHM13 chr21 against GRCh38 chr21, in
# both formats. One row per tool to $WORK/competitors.tsv (docs/competitors.md).
#
#   sh scripts/cue/competitors.sh
#
# Needs: sh scripts/get-data.sh --cue --human, zstd on PATH, and -- for the two
# specialists -- HRCM built from scripts/cue/hrcm-windows.patch and GeCo3 in
# bench-external/geco3-master. Each specialist is skipped, loudly, if absent:
# a competitor's number that was not produced here is not reported here.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
need "$HUM/chm13_chr21.seq" "sh scripts/get-data.sh --cue"
need "$HUM/grch38_chr21.seq" "sh scripts/get-data.sh --cue"
need "$ROOT/chr21.fa" "sh scripts/get-data.sh --human"

cd "$WORK"
cp "$HUM/chm13_chr21.fa" "$HUM/chm13_chr21.seq" "$HUM/grch38_chr21.seq" .
cp "$ROOT/chr21.fa" grch38_chr21.fa
t()   { date +%s.%N; }
row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> competitors.tsv; }
ok()  { cmp -s "$1" "$2" && echo yes || echo NO; }
: > competitors.tsv

BASE=$(build base $(defines_for base)); CUE=$(build cue $(defines_for cue))

for kind in fa seq; do
  T=chm13_chr21.$kind; R=grch38_chr21.$kind
  a=$(t); zstd -q -f -19 --long=27 --patch-from=$R $T -o z.$kind.zst; b=$(t)
  zstd -q -f -d --long=27 --patch-from=$R z.$kind.zst -o z.back
  row $kind zstd-patch-from "$(wc -c < z.$kind.zst)" "$(ok z.back $T)" "$(echo "$b - $a" | bc)"
  for v in base cue; do
    eval E=\$$(echo $v | tr a-z A-Z)
    a=$(t); "$E" cr $T d.$v.$kind.dnac $R >/dev/null 2>&1; b=$(t)
    "$E" dr d.$v.$kind.dnac d.back $R >/dev/null 2>&1
    row $kind dnac-$v "$(wc -c < d.$v.$kind.dnac)" "$(ok d.back $T)" "$(echo "$b - $a" | bc)"
  done
  rm -f z.back d.back
done

# HRCM (FASTA), in its own directory so its outputs are unambiguous.
if [ -x "$HRCM" ]; then
  rm -rf h && mkdir h && cp chm13_chr21.fa grch38_chr21.fa h/ && cd h
  a=$(t); "$HRCM" compress -r grch38_chr21.fa -t chm13_chr21.fa > c.log 2>&1; b=$(t)
  mkdir dd && cp chm13_chr21.7z grch38_chr21.fa dd/ \
    && ( cd dd && "$HRCM" decompress -r grch38_chr21.fa -t chm13_chr21.7z > d.log 2>&1 )
  cd ..
  row fa HRCM "$(wc -c < h/chm13_chr21.7z)" "$(ok h/dd/chm13_chr21.fasta chm13_chr21.fa)" "$(echo "$b - $a" | bc)"
else
  echo "  (no HRCM at $HRCM -- skipped)"
fi

# GeCo3 (plain ACGT), relative names because GeCo3 splits its arguments on ':'.
PARAMR="-rm 20:500:1:35:0.95/3:100:0.95 -rm 13:200:1:1:0.95/0:0:0 -rm 10:10:0:0:0.95/0:0:0 -lr 0.03 -hs 64"
PARAMH="$PARAMR -tm 4:1:0:1:0.9/0:0:0 -tm 17:100:1:10:0.95/2:20:0.95"
G=$ROOT/bench-external/geco3-master/src/GeCo3.exe
if [ -x "$G" ]; then
  for tpl in R H; do
    eval P=\$PARAM$tpl
    rm -f chm13_chr21.seq.co
    a=$(t); "$G" -F $P -r grch38_chr21.seq chm13_chr21.seq > geco_$tpl.log 2>&1; b=$(t)
    # "unverified": GeDe3 does not run on this machine, so nothing here has
    # shown these bytes decode back. Reported as such, never as a round-trip.
    row seq GeCo3-$tpl "$(wc -c < chm13_chr21.seq.co)" unverified "$(echo "$b - $a" | bc)"
    mv chm13_chr21.seq.co geco_$tpl.co
  done
else
  echo "  (no GeCo3 at $G -- skipped)"
fi
echo "ALL_DONE  ->  $WORK/competitors.tsv"
