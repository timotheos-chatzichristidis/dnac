#!/bin/sh
# Download the exact sequences the benchmarks in README.md were measured on.
# Nothing here is committed to the repository — genomes are public data, fetched
# by accession so the numbers can be reproduced against identical bytes.
#
#   sh scripts/get-data.sh          # bacteria only (~15 MB, seconds)
#   sh scripts/get-data.sh --human  # also human chr21 (~12 MB gz -> 47 MB)
#   sh scripts/get-data.sh --meta   # the metagenome for "Where this loses" (~300 MB)
#   sh scripts/get-data.sh --cue    # the real human pairs the cue was measured on
#                                   # (~190 MB) -- CHM13 chr21/chr22 + GRCh38 chr22
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

if [ "${1:-}" = "--meta" ]; then
  # The metagenome the "Where this loses" table was measured on. No reference
  # genome exists for a metagenomic sample, which is what makes it the fair
  # fight against gzip/zstd/xz. A 300 MB prefix of the run is plenty for the
  # 200 Mbase stream; the range request keeps it honest (identical bytes) and
  # small (the full run is 1.56 GB).
  echo "Human gut metagenome (ENA DRR003618, 300 MB prefix):"
  if [ -s meta.seq ]; then
    echo "  have meta.seq"
  else
    [ -s gut.part.gz ] || curl -fsSL -r 0-314572799 -o gut.part.gz       "https://ftp.sra.ebi.ac.uk/vol1/fastq/DRR003/DRR003618/DRR003618.fastq.gz"
    # every 4th line from the 2nd is the sequence; stop at exactly 200 Mbases so
    # the file is byte-identical to the one the README table was measured on
    gzip -dc gut.part.gz 2>/dev/null       | awk 'NR%4==2 { print; b+=length($0); if (b>=200000000) exit }' > meta.seq
    rm -f gut.part.gz
  fi
  echo "  meta.seq: $(wc -c < meta.seq) bytes"
fi

if [ "${1:-}" = "--cue" ]; then
  # The real human pairs behind docs/real-human.md, docs/competitors.md and
  # docs/remaining.md: a second person's chromosome against the reference one.
  # These land in bench-external/cue/human/ rather than data/, because that is
  # where verify-claims.ps1 reads them -- the same arrangement as meta.seq.
  #
  # CHM13 comes from NCBI by accession, GRCh38 chr22 from Ensembl release 110
  # (pinned: "current" moves, and a different assembly release is a different
  # measurement). Run --human first: chr21's reference side is the repository's
  # own chr21.fa, so that pair is the one the README already benchmarks.
  H=../bench-external/cue/human
  mkdir -p "$H"
  echo "Real human pair (CHM13 vs GRCh38):"
  fetch_ncbi CP068257.2 "$H/chm13_chr21.fa" "T2T-CHM13v2.0 chr21 — the target of docs/real-human.md"
  fetch_ncbi CP068256.2 "$H/chm13_chr22.fa" "T2T-CHM13v2.0 chr22 — the held-out replication"
  if [ -s "$H/grch38_chr22.fa" ]; then echo "  have grch38_chr22.fa"; else
    echo "  fetching GRCh38 chr22 (Ensembl release 110)"
    curl -fsSL -o "$H/grch38_chr22.fa.gz"       "https://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.22.fa.gz"
    gzip -dc "$H/grch38_chr22.fa.gz" > "$H/grch38_chr22.fa" && rm -f "$H/grch38_chr22.fa.gz"
  fi
  # chr21's reference side is the repository's own chr21.fa, under the name the
  # cue documents and scripts use for it. A copy, not a symlink: this has to work
  # on a Windows checkout too.
  if [ ! -s "$H/grch38_chr21.fa" ]; then
    if   [ -s ../chr21.fa ]; then cp ../chr21.fa "$H/grch38_chr21.fa"
    elif [ -s chr21.fa ];    then cp chr21.fa    "$H/grch38_chr21.fa"
    else echo "  (chr21.fa missing: run --human first for grch38_chr21.fa)"; fi
  fi
  # the plain-ACGT side of the same pair (the fair table for zstd and GeCo3)
  [ -s "$H/chm13_chr21.seq" ] || sh ../scripts/mkseq.sh "$H/chm13_chr21.fa" "$H/chm13_chr21.seq"
  if [ ! -s "$H/grch38_chr21.seq" ]; then
    if   [ -s ../chr21.fa ]; then sh ../scripts/mkseq.sh ../chr21.fa "$H/grch38_chr21.seq"
    elif [ -s chr21.fa ];    then sh ../scripts/mkseq.sh chr21.fa    "$H/grch38_chr21.seq"
    else echo "  (chr21.fa missing: run --human first for grch38_chr21.seq)"; fi
  fi
  # Identical bytes or the figures do not apply. A defline or a release that
  # moved is a different measurement, not a worse download.
  if [ -s ../scripts/cue/data.sha256 ]; then
    echo "  checking against scripts/cue/data.sha256"
    ( cd "$H" && sha256sum -c ../../../scripts/cue/data.sha256 ) || {
      echo "  FETCHED DATA DIFFERS from what docs/real-human.md was measured on." >&2
      echo "  The figures do not apply to these bytes until that is understood." >&2
      exit 1; }
  fi
  # The ten controlled E. coli targets are built, not downloaded (6 s). The
  # script finds its own reference, and checks what it rebuilt against
  # scripts/cue/targets.sha256.
  sh ../scripts/cue/make-targets.sh
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
