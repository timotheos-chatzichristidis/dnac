#!/bin/sh
# docs/cue-phase-oracle-prediction.md. PH=<build with cue-phase.patch>
set -u
H=bench-external/cue/human; P=bench-external/pilot; O=${OUT:-$P/ph}; mkdir -p "$O"
chk() {  # chk <label> <chr> -- decode (env already set by caller) and compare
  cmp -s "$O/$1.$2.back" "$H/chm13_$2.fa" && echo "$1 $2 $(wc -c < "$O/$1.$2.dnac") bytes (round-trip OK)" || echo "FAIL lossless $1 $2"
  rm -f "$O/$1.$2.back"
}
noenv() { c=$1
  "$PH" cr "$H/chm13_$c.fa" "$O/noenv.$c.dnac" "$H/grch38_$c.fa" 22 3 >/dev/null 2>&1 && "$PH" dr "$O/noenv.$c.dnac" "$O/noenv.$c.back" "$H/grch38_$c.fa" >/dev/null 2>&1; chk noenv $c; }
back() { c=$1
  DNAC_PHASE=back "$PH" cr "$H/chm13_$c.fa" "$O/back.$c.dnac" "$H/grch38_$c.fa" 22 3 >/dev/null 2>&1 && \
  DNAC_PHASE=back "$PH" dr "$O/back.$c.dnac" "$O/back.$c.back" "$H/grch38_$c.fa" >/dev/null 2>&1; chk back $c; }
orc() { c=$1
  DNAC_PHASE=oracle-enc DNAC_PHASE_SEQ="$P/hist_$c.bin" DNAC_PHASE_SIDE="$O/side.$c" "$PH" cr "$H/chm13_$c.fa" "$O/oracle.$c.dnac" "$H/grch38_$c.fa" 22 3 >/dev/null 2>"$O/oracle.$c.err" && \
  DNAC_PHASE=oracle-dec DNAC_PHASE_SIDE="$O/side.$c" "$PH" dr "$O/oracle.$c.dnac" "$O/oracle.$c.back" "$H/grch38_$c.fa" >/dev/null 2>>"$O/oracle.$c.err"; chk oracle $c
  echo "  (oracle $c side file: $(wc -c < "$O/side.$c") choices; $(cat "$O/oracle.$c.err"))"; }
noenv chr21 & back chr21 & orc chr21 & wait
noenv chr22 & back chr22 & orc chr22 & wait
echo PHASE_DONE
