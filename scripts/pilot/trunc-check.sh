#!/bin/bash
# docs/truncation-prediction.md T1/T2. EXE=<build>. For each stream: the whole stream
# decodes (T1); cut to 50%, 90% and one byte short it is refused, exit != 0, no output (T2).
set -u
O=${OUT:-bench-external/pilot/trunc}; mkdir -p "$O"; t1=0; t1f=0; t2=0; t2f=0
dec() {  # dec <stream> <out> [ref]
  if [ -n "${3:-}" ]; then "$EXE" dr "$1" "$2" "$3" >/dev/null 2>&1; else "$EXE" d "$1" "$2" >/dev/null 2>&1; fi; }
one() {  # one <label> <stream> <original or -> [ref]
  lb=$1; s=$2; orig=$3; ref=${4:-}
  rm -f "$O/full.out"; t1=$((t1+1))
  if dec "$s" "$O/full.out" "$ref" && { [ "$orig" = - ] || cmp -s "$O/full.out" "$orig"; }; then :; else t1f=$((t1f+1)); echo "T1 FAIL (valid stream refused or wrong): $lb"; fi
  n=$(wc -c < "$s")
  for cut in $((n/2)) $((n*9/10)) $((n-1)); do
    head -c $cut "$s" > "$O/cut.dnac"; rm -f "$O/cut.out"; t2=$((t2+1))
    if dec "$O/cut.dnac" "$O/cut.out" "$ref" || [ -e "$O/cut.out" ]; then t2f=$((t2f+1)); echo "T2 FAIL (truncated to $cut of $n accepted or left output): $lb"; fi
  done
}
enc() {  # enc <label> <input> <args...>
  lb=$1; in=$2; shift 2; "$EXE" c "$in" "$O/s.dnac" "$@" >/dev/null 2>&1 || { echo "encode failed: $lb"; return; }; one "$lb" "$O/s.dnac" "$in"; }
for l in 1 2 3 4; do enc "ecoli L$l" ecoli.fa 22 $l; done
enc "ecoli L3 -codon" ecoli.fa 22 3 -codon
enc "ecoli L3 -j 8" ecoli.fa 22 3 -j 8
enc "ecoli L1 -j 4 (codon blocks)" ecoli.fa 22 1 -j 4
enc "chr21_slice L1" chr21_slice.fa 22 1
enc "chr21_slice L3" chr21_slice.fa 22 3
enc "soft-masked 5 MB L1 (case list)" bench-external/pilot/codon/impl/sm5.fa 22 1
enc "soft-masked E. coli L1 (case + codon)" bench-external/pilot/codon/impl/ecoli_lc.fa 22 1
printf '>x\r\nACGTNNacgtRYKM\r\n' > "$O/messy.fa"; enc "messy tiny" "$O/messy.fa" 22 1
"$EXE" cr ecoli_ind.fa "$O/r.dnac" ecoli.fa 22 1 >/dev/null 2>&1 && one "reference ecoli_ind/ecoli L1" "$O/r.dnac" ecoli_ind.fa ecoli.fa
"$EXE" cr ecoli_ind.fa "$O/r3.dnac" ecoli.fa 22 3 >/dev/null 2>&1 && one "reference ecoli_ind/ecoli L3" "$O/r3.dnac" ecoli_ind.fa ecoli.fa
# the stored streams. Their reference is g.fa as tests/v080/make.sh derives it (gen is
# deterministic); the decoded target is checked against the hash make.sh recorded,
# because mut writes its input's path into the header and so cannot be re-derived here.
"$EXE" gen "$O/g.fa" 40000 3 >/dev/null
for f in tests/v080/plain_l*.dnac tests/v080/blocks_j3.dnac tests/v090/*.dnac; do one "stored $(basename $(dirname $f))/$(basename $f)" "$f" -; done
MH=$(awk '/ \*m\.fa$/{print $1}' tests/v080/inputs.sha256)
for f in tests/v080/ref_l*.dnac; do
  one "stored v080/$(basename $f)" "$f" - "$O/g.fa"
  "$EXE" dr "$f" "$O/full.out" "$O/g.fa" >/dev/null 2>&1
  [ "$(sha256sum "$O/full.out" | cut -d' ' -f1)" = "$MH" ] || { t1f=$((t1f+1)); echo "T1 FAIL (wrong bytes): $f"; }
done
echo "T1: $((t1-t1f))/$t1 valid streams decoded   T2: $((t2-t2f))/$t2 truncations refused"
