# The balancing wave: in the genome, or in our search? -- pre-registration

Written 2026-09-26, before the analysis below was run. Data already exist (logged
2026-09-18 for docs/after-090.md experiment B): every cue load on CHM13 chr21/chr22
against GRCh38, as (position, signed shift, tied). No codec run is needed; the
statistic is the one in scripts/cue/after090-momentum.py (non-tied loads, excess of
P(consecutive same sign) over the independence baseline from the run's own marginal).

## The claim under test
Timotheos: between two opposites stands a balancing wave. In our data the only
measured candidate is the alternation of consecutive slip signs, -1.12 pp (chr21)
and -1.10 pp (chr22) below chance. docs/after-090.md left one confound open: it may
be our search overshooting and coming back (mechanism), not the two genomes (nature).

## Split
Each load is classified by the TARGET sequence around it: "tandem" if some period
p in 1..6 repeats (seq[i] == seq[i+p]) over a run of >= 12 bases that overlaps the
window [t-20, t+20]; otherwise "unique". The shift ambiguity that could make the
search overshoot lives in tandem repeats, where many shifts agree on 3 bases.
Consecutive pairs are also split by gap: near (< 100 bases apart) vs far (>= 1000).

## Predictions
T0  instrument: the unsplit statistic reproduces -1.12 / -1.10 pp to 0.01.
T1  unique-unique pairs: excess within +-0.5 pp on both chromosomes.
T2  tandem-tandem pairs: excess <= -2 pp on both chromosomes.
T3  far pairs (gap >= 1000): excess within +-0.5 pp on both chromosomes.

## Decision rule (fixed now)
- T1 and T3 hold -> the alternation is local correction inside repeats, i.e. our
  search's own ambiguity plus the repeat's geometry; it is not a property of the
  genome pair at large, and gives the "balancing wave" no support here.
- Unique-unique excess <= -1 pp on BOTH chromosomes -> alternation survives outside
  repeats; that earns a codec-free follow-up (signs of indels in a real alignment)
  before anything is claimed about genomes.
- Anything between: inconclusive, said so, no claim.
