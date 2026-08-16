#!/bin/sh
# Download the exact sequences the benchmarks in README.md were measured on.
# Nothing here is committed to the repository — genomes are public data, fetched
# by accession so the numbers can be reproduced against identical bytes.
#
#   sh scripts/get-data.sh          # bacteria only (~15 MB, seconds)
#   sh scripts/get-data.sh --human  # also human chr21 (~12 MB gz -> 47 MB)
set -eu
cd "$(dirname "$0")/.."
mkdir -p data
cd data

fetch_ncbi() {   # fetch_ncbi <accession> <outfile> <description>
  acc=$1; out=$2; desc=$3
  if [ -s "$out" ]; then echo "  have $out"; return; fi
  echo "  fetching $desc ($acc)"
  curl -fsSL -o "$out" \
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=$acc&rettype=fasta&retmode=text"
}

echo "E. coli (NCBI, by accession):"
fetch_ncbi NC_000913.3 ecoli.fa  "K-12 MG1655   — reference-free benchmark, and the reference for cr/dr"
fetch_ncbi NC_007779.1 w3110.fa  "K-12 W3110    — near-identical strain (reference-based test)"
fetch_ncbi NC_002695.2 o157.fa   "O157:H7 Sakai — diverged strain (reference-based test)"

if [ "${1:-}" = "--human" ]; then
  echo "Human chr21 (Ensembl GRCh38):"
  if [ -s chr21.fa ]; then
    echo "  have chr21.fa"
  else
    curl -fsSL -o chr21.fa.gz \
      "https://ftp.ensembl.org/pub/current_fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.21.fa.gz"
    gzip -dc chr21.fa.gz > chr21.fa && rm -f chr21.fa.gz
  fi
  # The 10 MB slice used for fast parameter sweeps.
  [ -s chr21_slice.fa ] || head -c 10000000 chr21.fa > chr21_slice.fa
fi

echo
echo "Downloaded into ./data:"
ls -la *.fa 2>/dev/null || true
cat <<'EOF'

Note on assemblies: chr21 is Ensembl GRCh38 (46,709,983 bp incl. N gaps). The
README's bits/base figures divide by ACGT bases only; N runs and line breaks are
stored losslessly but excluded from the denominator. Papers benchmark on the
stripped ACGT stream instead — produce those with scripts/mkseq.sh.
EOF
