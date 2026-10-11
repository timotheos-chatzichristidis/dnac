# Reference mode without the 16-mer model -- pre-registration

Written 2026-10-11, after docs/match-wire.md and before any run below. Agreed with
Timotheos the same day ("after the reference mode, eukaryotes, then the rest of the
list").

## Where this comes from, and why it needs its own test

docs/match-wire.md rejected "match 16 as wiring" on plain-mode size. Its reference-mode
check, which was only a regression guard (no pair worse than +0.50%), came out the other
way round from my prediction: the wired build (W2, no 16-mer table, "agreement >= 16" as
a context bit) was SMALLER than release on three of four pairs at level 1, the `cr`
default:

| pair | release | W2 | change |
|---|---:|---:|---:|
| w3110 / ecoli | 2,129 | 2,082 | -2.21% |
| ecoli_ind / ecoli | 12,212 | 12,126 | -0.70% |
| chr21_ind / chr21 | 101,525 | 101,074 | -0.44% |
| o157 / ecoli (diverged) | 362,870 | 363,643 | +0.21% |

That is a post-hoc finding on four pairs that were looked at. Those four are now the
DEVELOPMENT set and decide nothing. The held-out set below was chosen before any of it
was run.

## The question

In reference mode only, is the codec better without the 16-mer forward model? Plain
mode is not touched: docs/match-wire.md measured it, the answer there is no.

One candidate explanation, written down so it can fail: in a near-identical pair the
13-mer model, primed on the reference with sticky anchors, already sits on the aligned
position almost everywhere; the 16-mer model then says the same thing a second time, and
on a target whose output is a few kB the mixer pays to learn the redundant input (its
own weights, in every context x expert slot) for longer than the target lasts. If so, the
gain shrinks as the output grows and turns into a loss as divergence grows (o157).

## Arms (the scratch build of docs/match-wire.md, unchanged)

- **R0** release (`MATCH_WIRE=0`), byte-identical to main (already shown).
- **R1** drop (`MATCH_WIRE=1`): no 16-mer model, its two context bits constant 0.
- **R2** wire (`MATCH_WIRE=2`): as W2.

## Protocol

Every archive decoded with `dr` and compared with `cmp`.

1. **Development** (pairs already seen): R1 on the four pairs above at level 1. The
   CANDIDATE is whichever of R1 / R2 has the lower mean change over the four; a tie
   (within 0.01 pp) goes to R1, the simpler one. Nothing else is chosen on these pairs.
2. **Held-out**, the candidate vs R0, at level 1 (the `cr` default) and level 3:
   - real human: `chm13_chr21` / `grch38_chr21`, `chm13_chr22` / `grch38_chr22`
     (bench-external/cue/human, the pairs of docs/real-human.md);
   - real bacteria, strain vs the repository's genome, fetched by accession:
     B. subtilis PY79 `CP006881.1` / bsub (168), S. aureus USA300_FPR3757
     `NC_007793.1` / saur (NCTC 8325), P. aeruginosa UCBPP-PA14 `NC_008463.1` /
     paer (PAO1);
   - simulated: `dnac mut` 2 per mille, seed 11, of bsub and of paer, each against its
     source.
   That is 7 pairs. Fetched files get their sha256 written into the result before the
   first run.
3. Time and memory: not measured. The table that goes is the same 128 MB as in
   docs/match-wire.md, which measured it; the priming pass is the same code path.

## Bar (fixed now)

The candidate becomes a FORMAT CANDIDATE for reference mode if, on the held-out pairs:

- mean change over the 7 pairs at level 1 <= **-0.30%**, and
- mean change at level 3 <= **0.00%** (no average regression at the other level a user
  may pick), and
- no held-out pair at either level worse than **+0.50%**.

Anything else: rejected, recorded in negative-results.md. Exact figures, never a rounded
display. The mean is the plain mean of per-pair percentages: every pair counts once,
whatever its size.

## What adoption would cost (not decided here)

Reference streams would code with one forward model. That is format: new family letters
for reference streams only (the old letters keep decoding through the two-model path),
state files likewise (a state primed with two models must refuse a one-model stream),
then a re-measurement of every reference-mode figure in README.md, both suites,
verify-claims fast + slow. Plain-mode figures would not move by construction, which the
negative control proves byte for byte. Timotheos decides.

## Predictions (mine)

P1  R1 and R2 within 0.1 pp of each other on the development pairs: in reference mode
    the context bit carries little either way. (Plain mode said the same, 15% recovery.)
P2  Near-identical real and simulated bacterial pairs (PY79, the two `mut` pairs) gain
    -0.5..-2%; USA300 smaller; PA14, the most diverged, loses (+0.05..+0.30%).
P3  The human pairs gain little, -0.05..-0.30%: their outputs are MBs, and real human
    divergence (indels, SVs) is where the second anchor earns its keep.
P4  The level-1 mean passes the -0.30% bar narrowly; level 3 gains less than level 1
    (four experts and more inputs dilute one redundant input).

Timotheos's prediction: none given ("patience, we will see"), as for docs/match-wire.md.
