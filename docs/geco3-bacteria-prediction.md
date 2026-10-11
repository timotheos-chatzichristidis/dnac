# GeCo3 on the bacteria, with the codon tracker -- pre-registration

Written 2026-10-11, before any run. Item 3 of the post-v0.11.0 list (step 4 of
docs/codon-gate.md, never done). Ordered by Timotheos the same day, after the codon-dual
candidate was left unadopted.

## Why

README.md's head-to-head against GeCo3 has one bacterium, E. coli, measured at dnac level 3
before the codon tracker existed (1.8832 vs GeCo3 `-l 9` 1.8903: a 0.38% margin). Since
v0.11.0 the default for a bacterium is level 1 with the tracker, which gains 1.7-3.9% on
the four bacteria. The README does not say how that default compares with GeCo3.

## What is run

Inputs: the plain ACGT `.seq` of the four bacteria (`scripts/mkseq.sh`; E. coli's already
exists in bench-external/seq, the other three are made from data/bsub.fa, paer.fa,
saur.fa), the format the README's GeCo3 table uses.

- dnac release (main, v0.12.0): level 1 default (tracker on: all four open the gate),
  level 1 `-nocodon`, level 3 default, level 3 `-codon`. Every archive decoded, `cmp`.
- GeCo3 (bench-external/geco3-master, as built for the README): `-l 9`, `-l 14`, `-l 16`,
  run exactly as verify-claims.ps1's `Geco` does. GeCo3's size is its `.co` file; its
  decoder is NOT run (README: it fails on every input here), so its sizes are unverified,
  as everywhere else in the README.
- Time: compress wall time, one session, one process at a time, single run (the README's
  convention for this table; noise here is 24%, so times are reported, never claimed).

Measured: bits/base (bytes x 8 / bases), compress time.

## What is decided by it

Nothing in dnac.c. If the numbers hold, they become README rows with verify-claims rows
(tier `extern`), in a separate change that goes through a PR. The README sentence "on all
three datasets dnac has a setting that is at once faster and smaller than every GeCo3
setting tested" is checked for the four bacteria and rewritten to what is measured.

## Predictions (mine)

B1  dnac level 1 (tracker) beats GeCo3's best level on all four by 2-4.5%: the 0.4% of the
    old margin plus the tracker's 1.7-3.9%.
B2  dnac level 1 is also faster than every GeCo3 level on all four.
B3  GeCo3 `-l 16` is not better than `-l 9`/`-l 14` on any bacterium (on E. coli it was
    worse than `-l 9`).
B4  level 3 `-codon` is the smallest dnac setting on every bacterium, but by under 0.3% over
    level 1, at 2x the time.

Timotheos's prediction: none given.
