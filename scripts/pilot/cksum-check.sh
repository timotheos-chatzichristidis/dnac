#!/bin/bash
# docs/checksum-prediction.md C1/C2. NEW=<this build> OLD=<v0.11.0 build>.
# C1: for every stream, NEW's archive == OLD's archive with byte 2 'C'->'H' and 8 bytes
#     appended (so nothing but the envelope moved).
# C2: small streams with single bytes changed (every byte of the first 64, 40 random
#     body positions, every trailer byte; XOR 0x01 and XOR 0xFF): each must be refused
#     (exit 1, no output) or decode to exactly the right bytes. Any other exit code is a
#     crash. With DEC=<build> the flips are decoded by that build (negative control:
#     DEC=v0.11.0 on OLD's streams must let wrong bytes through at exit 0).
set -u
O=${OUT:-bench-external/pilot/cksum}; mkdir -p "$O"
c1=0; c1f=0
env1() {  # env1 <label> <input> <args...>   (C1)
  lb=$1; in=$2; shift 2; c1=$((c1+1))
  "$NEW" c "$in" "$O/n.dnac" "$@" >/dev/null 2>&1 || { c1f=$((c1f+1)); echo "C1 FAIL (new encode): $lb"; return; }
  "$OLD" c "$in" "$O/o.dnac" "$@" >/dev/null 2>&1 || { c1f=$((c1f+1)); echo "C1 FAIL (old encode): $lb"; return; }
  { head -c 2 "$O/o.dnac"; printf 'H'; tail -c +4 "$O/o.dnac"; } > "$O/o2.dnac"
  sn=$(wc -c < "$O/n.dnac"); so=$(wc -c < "$O/o.dnac")
  if [ "$(head -c 3 "$O/o.dnac" | tail -c 1)" = C ] && [ $sn -eq $((so+8)) ] && cmp -s "$O/o2.dnac" <(head -c $so "$O/n.dnac"); then :
  else c1f=$((c1f+1)); echo "C1 FAIL (envelope): $lb  old=$so new=$sn"; return; fi
  rm -f "$O/n.out"; "$NEW" d "$O/n.dnac" "$O/n.out" >/dev/null 2>&1 && cmp -s "$O/n.out" "$in" || { c1f=$((c1f+1)); echo "C1 FAIL (round trip): $lb"; }
}
envr() {  # envr <label> <target> <ref> <level>   (C1, reference mode)
  lb=$1; c1=$((c1+1))
  "$NEW" cr "$2" "$O/n.dnac" "$3" 22 $4 >/dev/null 2>&1; "$OLD" cr "$2" "$O/o.dnac" "$3" 22 $4 >/dev/null 2>&1
  { head -c 2 "$O/o.dnac"; printf 'H'; tail -c +4 "$O/o.dnac"; } > "$O/o2.dnac"
  sn=$(wc -c < "$O/n.dnac"); so=$(wc -c < "$O/o.dnac")
  if [ $sn -eq $((so+8)) ] && cmp -s "$O/o2.dnac" <(head -c $so "$O/n.dnac"); then :
  else c1f=$((c1f+1)); echo "C1 FAIL (envelope): $lb  old=$so new=$sn"; return; fi
  rm -f "$O/n.out"; "$NEW" dr "$O/n.dnac" "$O/n.out" "$3" >/dev/null 2>&1 && cmp -s "$O/n.out" "$2" || { c1f=$((c1f+1)); echo "C1 FAIL (round trip): $lb"; }
}
if [ "${SKIP_C1:-0}" != 1 ]; then
  for l in 1 2 3 4; do env1 "ecoli L$l" ecoli.fa 22 $l; done
  env1 "ecoli L3 -codon" ecoli.fa 22 3 -codon
  env1 "ecoli L1 -nocodon" ecoli.fa 22 1 -nocodon
  env1 "ecoli L3 -j 8" ecoli.fa 22 3 -j 8
  env1 "ecoli L1 -j 4 (codon blocks)" ecoli.fa 22 1 -j 4
  env1 "chr21_slice L1" chr21_slice.fa 22 1
  env1 "chr21_slice L3" chr21_slice.fa 22 3
  env1 "chr21_slice L3 k=16" chr21_slice.fa 16 3
  env1 "soft-masked 5 MB L1 (case list)" bench-external/pilot/codon/impl/sm5.fa 22 1
  env1 "soft-masked 5 MB L3 -j 3 (case blocks)" bench-external/pilot/codon/impl/sm5.fa 22 3 -j 3
  env1 "soft-masked E. coli L1 (case + codon)" bench-external/pilot/codon/impl/ecoli_lc.fa 22 1
  printf '>x\r\nACGTNNacgtRYKM\r\n' > "$O/messy.fa"; env1 "messy tiny" "$O/messy.fa" 22 1
  : > "$O/empty.fa"; env1 "empty file" "$O/empty.fa" 22 3
  printf 'A' > "$O/one.fa"; env1 "one byte" "$O/one.fa" 22 3
  envr "reference ecoli_ind/ecoli L1" ecoli_ind.fa ecoli.fa 1
  envr "reference ecoli_ind/ecoli L3" ecoli_ind.fa ecoli.fa 3
  echo "C1: $((c1-c1f))/$c1 streams differ from v0.11.0 only by the envelope"
fi

# ---- C2: flips on small streams ----
ENC=${ENC:-$NEW}; DEC=${DEC:-$NEW}
head -c 200000 ecoli.fa > "$O/e200.fa"
{ head -c 150000 chr21_slice.fa; } > "$O/h150.fa"
awk 'NR==1{print; next} NR%3==0{print tolower($0); next} {print}' "$O/h150.fa" > "$O/h150c.fa"
head -c 60000 ecoli_ind.fa > "$O/ti.fa"; head -c 60000 ecoli.fa > "$O/tr.fa"
mk() { lb=$1; in=$2; shift 2; "$ENC" c "$in" "$O/f_$lb.dnac" "$@" >/dev/null 2>&1 && echo "$lb $in -"; }
{
  mk e_L1 "$O/e200.fa" 22 1
  mk e_L3 "$O/e200.fa" 22 3
  mk e_codon "$O/e200.fa" 22 3 -codon
  mk e_j3 "$O/e200.fa" 22 2 -j 3
  mk h_L4 "$O/h150.fa" 22 4
  mk h_case "$O/h150c.fa" 22 3
  mk h_casej "$O/h150c.fa" 22 1 -j 2
  "$ENC" cr "$O/ti.fa" "$O/f_ref.dnac" "$O/tr.fa" 22 1 >/dev/null 2>&1 && echo "ref $O/ti.fa $O/tr.fa"
} > "$O/set.txt"
: > "$O/jobs.txt"
while read lb in ref; do
  n=$(wc -c < "$O/f_$lb.dnac")
  pos=$( { seq 0 $(( (n<64?n:64) - 1 )); awk -v n=$n -v s=$RANDOM 'BEGIN{srand(s); for(i=0;i<40;i++) print int(64+rand()*(n-72))}'; seq $((n-8)) $((n-1)); } | awk -v n=$n '$1>=0 && $1<n' | sort -un)
  for p in $pos; do for x in 1 255; do echo "$lb $in $ref $p $x" >> "$O/jobs.txt"; done; done
done < "$O/set.txt"
flip() {  # one job line -> one result line
  lb=$1; in=$2; ref=$3; p=$4; x=$5; t="$O/j_${lb}_${p}_$x"
  cp "$O/f_$lb.dnac" "$t.dnac"
  b=$(od -An -tu1 -j$p -N1 "$t.dnac" | tr -d ' '); nb=$(( b ^ x ))
  printf "$(printf '\\%03o' $nb)" | dd of="$t.dnac" bs=1 seek=$p count=1 conv=notrunc 2>/dev/null
  rm -f "$t.out"
  if [ "$ref" = - ]; then timeout 120 "$DEC" d "$t.dnac" "$t.out" >/dev/null 2>&1; else timeout 120 "$DEC" dr "$t.dnac" "$t.out" "$ref" >/dev/null 2>&1; fi
  rc=$?
  if [ $rc -eq 0 ]; then
    if cmp -s "$t.out" "$in"; then r=harmless; else r=WRONG; fi
  elif [ $rc -eq 1 ]; then
    if [ -e "$t.out" ]; then r=LEFT_OUTPUT; else r=refused; fi
  else r="CRASH($rc)"; fi
  echo "$r $lb pos=$p xor=$x"; rm -f "$t.dnac" "$t.out"
}
export -f flip; export O DEC
tr '\n' '\0' < "$O/jobs.txt" | xargs -0 -P 8 -I{} bash -c 'flip {}' > "$O/c2.txt"
echo "C2 ($(wc -l < "$O/jobs.txt") flips, decoded by $(basename $DEC)):"
awk '{print $1}' "$O/c2.txt" | sort | uniq -c
grep -v "^refused\|^harmless" "$O/c2.txt" | head -20
