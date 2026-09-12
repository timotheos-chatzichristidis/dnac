# The cue without a reference: result

**Run 2026-09-12.** Pre-registered in `docs/reference-free-prediction.md`
(commit `ddee2c4`) before the first run. Plain mode (`dnac c`), k=22, every file
round-tripped with `cmp` before its size was recorded
(`sh scripts/cue/reffree.sh`). Builds: `base` (no flag, byte-identical to
v0.8.0) and `cue` (`-DDNAC_CUE`, the parameters of `docs/cue.md`).

## The table

| dataset | bases | level | v0.8.0 | + cue | change |
|---|---:|---:|---:|---:|---:|
| E. coli | 4,641,652 | 3 | 1,092,692 | 1,092,606 | **−0.008%** |
| | | 1 | 1,093,749 | 1,093,906 | +0.014% |
| chr21 slice | 9,836,065 | 3 | 2,104,223 | 2,104,040 | −0.009% |
| | | 1 | 2,112,100 | 2,112,092 | −0.000% |
| **chr21** | 40,088,619 | **3** | **7,506,264** | **7,502,884** | **−0.045%** |
| | | 1 | 7,549,315 | 7,546,232 | −0.041% |
| metagenome | 200,000,000 | 3 | 17,323,036 | 17,318,948 | −0.024% |
| | | 1 | 17,653,816 | 17,650,900 | −0.017% |

In bits/base: chr21 1.4979 → 1.4973, E. coli 1.8833 → 1.8831, the metagenome
0.6874 → 0.6873.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **P1** | E. coli l3 within [−0.30%, +0.10%] | **held**: −0.008% |
| **P2** | chr21 slice l3 within [−0.50%, +0.10%] | **held**: −0.009% |
| **P3** | chr21 l3 within [−0.60%, +0.10%], point −0.20% | **held**: −0.045%, four times smaller than the point estimate |
| **P4** | metagenome l3 within [−2.0%, +0.10%], point −0.50% | **held**: −0.024%, twenty times smaller |
| **P5** | the gain is larger at level 1 than at level 3, on ≥ 3 of 4 | **failed, inverted**: 0 of 4. It is *smaller* at level 1 everywhere, and on E. coli it becomes a small loss |
| **P6** | level 1 + cue still worse than level 3 base on chr21, by > 0.30% | **held**: **+0.532%** |
| **P7** | float identity across six builds | see below |

## What this settles

**The risk the plan opened is closed: the cue does not hurt without a
reference.** Every level-3 figure is a gain, none is a loss, and the largest is
0.045%. Decision rule **D1** (mode-dependent if it costs more than +0.20%
anywhere) is not triggered; **D2** applies, so the cue ships **always on**.

These are not noise. Sizes here are deterministic — the same build on the same
bytes gives the same archive — so −0.045% on chr21 is a real 3,380 bytes. It is
just small: against dnac's 0.7% margin over GeCo3 reference-free, the cue adds
about a sixteenth of that margin.

**The mechanism's own story predicts this,** which is the reassuring part. The
cue needs a long established match to miss and a shifted copy of it to exist
(`dnac.c:794`). With a reference that is every indel between two people. Without
one it is only the file's own repeats — later in the file, and rarer.

## P5, the failure, and what it costs

With a reference the cue *carried* level 1: it kept 77–88% of its gain there,
which is what made "level 1 + cue, 2.4x faster and 3% smaller" possible
(`docs/speed.md`). Reference-free the opposite happens — the gain shrinks at
level 1, and on E. coli it turns into a 0.014% loss.

A hypothesis, not a measurement: level 1 has two mixer experts against level 3's
four, so the weight that decides how far to trust the cue is learned on a
coarser context, and a rare input needs the finer context most. Testing that
means a level-1 build with four experts, which is a Batch 3 question
(`add-back`), not this one.

The cost is the decision below. "Level 1 for everything" is off the table.

## The decision: the default level, per mode

Rule **D3**, fixed before the run: the smallest setting that is not slower than
today's default; plain mode takes level 3 unless level 1 + cue lands within
0.10% of level 3 base. Measured, level 1 + cue against level 3 base:

| dataset | level 1 + cue vs level 3 |
|---|---:|
| E. coli | +0.111% |
| chr21 slice | +0.374% |
| chr21 | +0.532% |
| metagenome | +1.893% |

All four are outside the 0.10% band, the metagenome by nineteen times. So:

- **Reference-free (`dnac c`): level 3 stays the default, with the cue on.**
  This is where the README's headline lives and the margin is 0.7%; giving up
  0.53% of it for speed would be trading the strongest claim for the least
  used one.
- **Reference mode (`dnac cr`): level 1 + cue becomes the default** — 2.4x
  faster than today and 3% smaller on the real human pair (`docs/speed.md`).
  Level 3 remains available and is still the smallest (−5.97%), for anyone
  who wants it.

That is the answer to the question `docs/v0.9.0-plan.md` refused to let the
default be chosen without: **the default is per mode, because the cue's value
is per mode.** Timotheos's direction — the light setting — holds exactly where
he measured it, and not where it was never measured.

One consequence for Batch 4: the level already travels in the header, so a
per-mode default costs nothing in format. It is a change to what the CLI picks
when the user does not say.

## P7: the same source, six ways of doing the arithmetic

`sh scripts/cue/fpident.sh`. The codec is deterministic because encoder and
decoder run identical float code in the same order *inside one binary*; across
binaries it holds only if the compilers' arithmetic agrees, which is what the
14-bit quantisation before the coder protects. The cue adds a probability table
and a mixer input since that was last checked, so it is checked again: `-O2`,
`-O3`, x87 (`-mfpmath=387`), SSE2, and FMA contraction on and off, each
compressing a generated 400 kbase genome and E. coli, with every build then
decoding every other build's archive.

**P7 held.** All six builds produce **byte-identical** archives on both
inputs — one MD5 across the six E. coli files — and all 72 cross-decodes
return the original bytes. Two of them were repeated by hand afterwards, on
the principle that a check which reports nothing when it passes has to be seen
passing once: the SSE2 build decodes the x87 build's archive, and the x87 build
decodes the `-O3` build's, both byte-identical.

That is the property that makes an archive portable at all, and it is not
free: it holds because every probability is quantised to 14 bits before it
reaches the coder (`README.md`). The cue adds a table and an input to that
path without breaking it.

No clang on this machine, so the cross-*compiler* half is CI's: the
`cross-compiler` job now builds the cue with gcc and clang, requires
byte-identical archives, and cross-decodes them in both directions.
