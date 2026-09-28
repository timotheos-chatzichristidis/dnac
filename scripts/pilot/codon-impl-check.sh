#!/bin/sh
# docs/codon-impl-prediction.md I2: the implementation's codon archives equal the scratch
# tracker archives (docs/codon-speed.md: S1 at L1, S123 at L2-4) in every byte after the
# magic letter. NEW=<implementation build>. Also round-trips each archive.
set -u
C=bench-external/pilot/codon; O=${OUT:-$C/impl}; mkdir -p "$O"
job() { g=$1; l=$2; fa=$C/$g.fa; [ "$g" = ecoli ] && fa=ecoli.fa
  v=S123; [ "$l" = 1 ] && v=S1
  flag=""; [ "$l" != 1 ] && flag="-codon"
  a="$O/$g.l$l.dnac"
  "$NEW" c "$fa" "$a" 22 "$l" $flag >/dev/null 2>&1 || { echo "FAIL enc $g l$l"; return; }
  "$NEW" d "$a" "$a.back" >/dev/null 2>&1 && cmp -s "$a.back" "$fa" || { echo "FAIL roundtrip $g l$l"; return; }
  rm -f "$a.back"
  letter=$(head -c 4 "$a" | tail -c 1)
  if cmp -s <(tail -c +5 "$a") <(tail -c +5 "$C/spd/$v.$g.l$l.dnac"); then same=IDENTICAL; else same=DIFFERENT; fi
  echo "$g l$l letter=$letter $(wc -c < "$a") B vs scratch $v $(wc -c < "$C/spd/$v.$g.l$l.dnac") B: $same after the letter"
}
if [ $# -eq 2 ]; then job "$1" "$2"; exit 0; fi
for g in ecoli bsub paer saur; do for l in 1 2 3 4; do echo "$g $l"; done; done | xargs -P 4 -L 1 bash "$0" | sort
