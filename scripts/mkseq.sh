#!/bin/sh
# Turn a FASTA into the plain ACGT stream that DNA-compression papers benchmark
# on: no header, no newlines, no N, uppercase only. POSIX port of mkseq.ps1.
#   sh scripts/mkseq.sh data/ecoli.fa data/ecoli.seq
set -eu
[ $# -eq 2 ] || { echo "usage: mkseq.sh <in.fa> <out.seq>" >&2; exit 1; }
mkdir -p "$(dirname "$2")"
tr -d '\r' < "$1" | grep -v '^[>;]' | tr 'acgt' 'ACGT' | tr -cd 'ACGT' > "$2"
n=$(wc -c < "$2" | tr -d ' ')
printf '%s' "$n" > "$2.acgt"
echo "$(basename "$1") -> $(basename "$2")  ($n bases)"
