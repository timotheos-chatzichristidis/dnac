# Where does each cue load copy from, and is its alternation search or geometry? -- pre-registration

Written 2026-09-27, before any run. docs/cue-oracle.md showed that loads the orthologous
chain cannot explain earn 2.2-2.7%, so they are probably slips against repeat copies.
That reopened the question of whether the slip alternation (docs/after-090.md, -1.12 /
-1.10 pp) is our search overshooting or the real geometry of those copies.

## Instrument
A scratch patch (`scripts/pilot/cue-source.patch`) logs every target cue load:
position np, signed shift, tie flag, and the master's source position mp. It must write
an archive byte-identical to the branch build, and that is checked. Reference mode,
**level 1** (the level of the 2026-09-18 logs), k 22, CHM13 chr21 and chr22 against GRCh38.

## Analysis (`scripts/pilot/cue-source.py`)
- Source class: `self` if mp is in the target; else `ortholog` if mp lies within 1,000
  bases of the target position lifted to GRCh38 through the UCSC chain; else `paralog`.
- Hindsight truth: over the next 30 bases, which shift d in -12..12 makes source and
  target agree most? A load is CONFIRMED if its shift is one of the argmax shifts and
  that maximum is >= 24/30. Otherwise it is a search error. This uses future bases, so
  it is an analysis, not a codec.
- Statistic: the same-sign excess of consecutive non-tied loads (after090-momentum.py),
  per subset of pairs.

## Predictions
S0  instrument: the unsplit statistic reproduces -1.12 / -1.10 pp and the logs hold the
    same number of loads as on 2026-09-18 (196,227 / 275,495).
S1  ortholog loads are <= 30% of loads on both chromosomes.
S2  confirmed loads are >= 50% of loads on both.
S3  confirmed-confirmed pairs: excess >= -0.5 pp on both (real slips do not alternate).
S4  pairs containing at least one unconfirmed load: excess <= -1.5 pp on both.

## Decision rule (fixed now)
- S3 and S4 hold -> the alternation is the search: a wrong load followed by its
  correction. The mechanism question is closed as "search". The share of unconfirmed
  loads becomes the one number a better phase search could attack, and that gets its own
  pre-registration and bar.
- confirmed-confirmed excess <= -1 pp on both -> real slips between copies alternate:
  geometry. Reported as a property of repeat copies, nothing more.
- Otherwise: mixed, reported with the numbers, no claim.
