# Codon phase as a context: the oracle ceiling -- pre-registration

Written 2026-09-27, before any run. Agreed 2026-09-23 as Timotheos's "missing fundamental"
(period 3 in bacteria), oracle first. Motivation measured the same day: in E. coli the
base-to-base mutual information at distances 3, 6, 9, 12... is 4-7x that of the
neighbouring distances (the codon period). No such peak exists at 10-11 (the helix turn).

## The oracle
Each base gets a label from the NCBI RefSeq annotation (CDS features, joins followed):
0-2 = codon position in a + strand gene, 3-5 = codon position in a - strand gene (in the
gene's own direction), 6 = not coding. Where genes overlap, the first annotated wins.
Header bases (dnac codes upper-case A/C/G/T in the '>' line as bases) are labelled 6.
The build asserts that its history matches the label file's sequence at every base.
A scratch patch (`scripts/pilot/codon-oracle.patch`) gives the label to the model in
two places:
- every non-tolerant ORDER MODEL context carries the label (direct tables 8x larger,
  hashed ones hash it in), so each phase has its own statistics;
- the fourth mixer expert (today one global weight set) selects its weights by label.
Inverted-repeat training gets the label of the base it trains on, with the strand
swapped (0-2 <-> 3-5), because the other strand reads a + gene as a - gene.
The decoder reads the same label file, so this is a ceiling, not a codec.

## Runs
Plain mode, level 3, k 22. E. coli MG1655 (NC_000913.3, ecoli.fa) decides; B. subtilis
168 (NC_000964.3) replicates. Every archive decoded and compared with cmp.
- rel         the branch build
- none        patched build, no variables: must be byte-identical to rel
- oracle      the true labels
- shifted     control: every coding label moved one codon position (c -> c+1 mod 3),
              same strand and same coding/non-coding map

## Predictions
C0  none byte-identical to rel on both genomes.
C1  oracle smaller than rel on E. coli by 1-4%.
C2  shifted gains less than a third of what oracle gains (the gain is PHASE, not merely
    "coding vs non-coding" or more table).
C3  B. subtilis oracle gain at least half of E. coli's.

## Decision rule (fixed now)
Build a REAL phase tracker (one that infers the phase from the sequence, which is the
beatmatching idea again: lock onto period 3) only if the oracle gains >= 1.0% on E. coli
AND >= 0.5% on B. subtilis AND C2 holds on both. Otherwise the codon-phase lever is closed.
A prior-art search for phase-aware DNA compressors has not been done. It is done before
any real tracker is built, not before this ceiling.
