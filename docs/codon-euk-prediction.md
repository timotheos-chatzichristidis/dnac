# Codon tracker on eukaryotes -- pre-registration

Written 2026-10-11, before any eukaryotic genome was fetched. Item 4 of the post-v0.11.0
list ("eukaryotes: do gene-dense ones with introns (yeast) open the gate, and do they
gain?"), ordered by Timotheos after the reference-mode test.

## The question

The codon tracker (v0.11.0) is used only when the per-file gate finds the codon period:
G = mean MI at lags 3,6,9,12 over mean MI at lags 4,5,7,8,10,11, ON if G >= 2.0. The gate
was set on four bacteria (G 3.26-5.09, gains 1.70-3.94%) and one human slice (G 1.17).
Nothing between those two has ever been measured. Eukaryotes span the gap: gene density
from ~70% coding (budding yeast) down to ~25% (worm), introns from rare to everywhere.

Two ways the gate can be wrong, and only a FORCED run can see either:
- **false negative**: G < 2.0, but the tracker would have gained;
- **false positive**: G >= 2.0, but the tracker loses.

## Genomes (fetched by accession after this commit; sha256 recorded in the result)

| genome | accessions | size | coding, introns |
|---|---|---:|---|
| S. cerevisiae S288C, 16 nuclear chromosomes | NC_001133 .. NC_001148 | 12.1 Mb | ~70%, ~5% of genes |
| S. pombe 972h-, 3 chromosomes | NC_003424, NC_003423, NC_003421 | 12.6 Mb | ~57%, ~43% of genes |
| A. thaliana chromosome 1 | NC_003070 | 30.4 Mb | ~33% |
| C. elegans chromosome I | NC_003279 | 15.1 Mb | ~25% |
| D. melanogaster arm 2L | NT_033779 | 23.5 Mb | ~20% |

Multi-chromosome genomes are one multi-FASTA in accession order. Mitochondria are left
out (a different genetic code is a different question).

## Arms (level 1, the level where the tracker is on by default)

- **E0** `-nocodon`: no tracker.
- **E1** release default: the gate decides (the archive's family letter says which).
- **E2** forced: tracker on whatever G is. Needs a scratch switch (`DNAC_CODON_FORCE=1`,
  research build on branch `codon-euk`, never merged); with it unset the build must be
  byte-identical to main (negative control on ecoli.fa and chr21_slice.fa at level 1).

G is read with `DNAC_CODON_DEBUG=1`. Every archive decoded and compared with `cmp`.
Forced gain = (E0 - E2) / E0. No timing (the tracker's time cost is already measured:
docs/codon-speed.md).

## Decision rule (fixed now)

Per genome, the gate is RIGHT if (G >= 2.0 and forced gain >= +0.50%) or (G < 2.0 and
forced gain < +0.50%); otherwise WRONG (false positive or false negative).

- Gate right on all five -> recorded; nothing changes.
- **Any false negative with forced gain >= 1.0%**, or **any false positive with a loss**
  (forced gain < 0) -> the gate is a candidate for change, with its own pre-registration
  (a lower threshold, or a trial gate that codes a sample both ways). Changing the gate
  is an ENCODER decision -- the family letter already tells the decoder -- so it moves no
  format, but it moves every published number of a file whose decision flips.
- A false negative between +0.50% and +1.0%: recorded as a small miss, no follow-up.

## Predictions (mine)

| genome | G | gate | forced gain |
|---|---|---|---|
| S. cerevisiae | 2.2 - 3.2 | ON | +1.0 .. +2.0% |
| S. pombe | 1.8 - 2.6 | borderline | +0.6 .. +1.5% |
| A. thaliana chr1 | 1.3 - 1.8 | OFF | +0.2 .. +0.6% |
| C. elegans chr I | 1.2 - 1.6 | OFF | +0.1 .. +0.4% |
| D. melanogaster 2L | 1.2 - 1.6 | OFF | +0.1 .. +0.4% |

Q1  G orders the genomes by coding fraction (yeast highest, fly/worm lowest).
Q2  Forced gain orders the same way, and is never negative by more than 0.05%: the
    tracker falls back to the non-coding label where it hears no period, so where it has
    nothing to say it costs little.
Q3  The gate is right on at least four of five; if one is wrong it is S. pombe, a false
    negative under +1.0% (no follow-up).

Timotheos's prediction: none given ("patience, we will see"), as for the two before.
