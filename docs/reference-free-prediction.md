# The cue without a reference: pre-registration

**Written 2026-09-12, before the first run.** Batch 2 of `docs/v0.9.0-plan.md`.
Nothing below is measured; every number here is a prediction, and the commands
that will decide them are named.

## Why this is the batch that matters

Everything the cue has been shown to do was measured **with a reference**:
−5.97% on a real human pair, −18.27% on the windows where the two people's
chromosomes line up (`docs/real-human.md`). That is exactly the cue's case — a
long established match, then an indel.

dnac's headline claim in `README.md` is the other mode. Reference-free it beats
GeCo3 on chr21 by **0.7%**, and level 1 costs **+0.374%** on the chr21 slice and
**+0.574%** on the full chromosome (rows `slice-l1-bpb`, `chr21-seq-l1-bpb`).
Against margins that size, a reference-free regression of a few tenths of a
percent would undo the project's strongest existing claim to buy a gain in a
mode most users never enter. **The cue has never been run in that mode.**

## Premises, each with how it is known

1. **The cue only loads after an established match misses.** `dnac.c:794`:
   the short match model (MMIN=13) must have had `mlen_pre >= CUE_MINLEN` (16)
   agreeing bases and then missed; a shifted phase within ±`CUE_D` (12) is
   accepted if `CUE_L` (3) bases agree backwards, and it is mixed in after
   `CUE_SWITCH` (12) agreeing bases.
2. **Reference-free, those established matches come from the file's own
   repeats** — Alu and LINE copies, tandem arrays and segmental duplications in
   human; IS elements and rRNA operons in E. coli; overlapping reads of one
   locus, and several strains of one species, in a metagenome. Copies of a
   repeat differ by indels as well as substitutions, so the cue's case exists
   here. It is rarer than an aligned reference's, and it arrives later in the
   file, because the first copy of a repeat has nothing to match.
3. **An extra mixer input is not free.** Every input dilutes the others until
   its weight is learned. The measured scale of that effect: the 2x2 in
   `docs/remaining.md` moved `chr21_ind` by at most 0.12% across four cue
   variants, and `docs/cue.md`'s zero-event control moved by 1 byte in 41,139.
4. **Level 1 has six orders and two experts, no IR training, no tolerant
   models** (`CLAUDE.md`). In reference mode the cue carried enough of that work
   to make level 1 both faster and smaller than v0.8.0's level 3
   (`docs/speed.md`). Reference-free there is no reference for it to carry.

## What will be run

`sh scripts/cue/reffree.sh` — plain mode (`dnac c`), k=22, every file
round-tripped with `cmp`, sizes to `$WORK/reffree.tsv`:

| dataset | bases | why it is in the set |
|---|---:|---|
| `ecoli.seq` | 4,641,652 | the bacterial regime, few long repeats |
| `chr21slice.seq` | 9,836,065 | the tuning-scale human slice |
| `chr21.seq` | 40,088,619 | where the README's headline lives |
| `meta.seq` | 200,000,000 | the regime dnac actually wins (1.47x over zstd) |

× builds {`base`, `cue`} × levels {1, 3} = 16 compressions, each decompressed
and compared. Then the floating-point identity runs of P7.

## Predictions

Sizes are compared as percentages, cue against base, same level, same file.

| | prediction | falsified if |
|---|---|---|
| **P1** | E. coli, level 3: within **[−0.30%, +0.10%]** | outside that band |
| **P2** | chr21 slice, level 3: within **[−0.50%, +0.10%]** | outside |
| **P3** | full chr21, level 3: within **[−0.60%, +0.10%]**, point estimate **−0.20%** | outside |
| **P4** | metagenome, level 3: within **[−2.0%, +0.10%]**, point estimate **−0.50%** | outside |
| **P5** | the cue's gain is **larger at level 1 than at level 3** on at least 3 of the 4 datasets | 2 or fewer |
| **P6** | reference-free, **level 1 + cue is still worse than level 3 base** on full chr21, by more than **0.30%** | 0.30% or less |
| **P7** | every file round-trips, and the cue build compiled `-O2`, `-O3`, `-mfpmath=387`, `-msse2` and `-ffp-contract=fast/off` gives **byte-identical archives** | any difference |

The honest summary of P1–P4: **the cue is expected to be nearly silent without
a reference, with a small gain where repeats are dense.** A large gain would be
a surprise; a large loss would be a problem.

## Decision rules, fixed now

- **D1.** If the cue costs more than **+0.20%** at level 3 on any of the four
  datasets, it cannot be unconditionally on. It becomes mode-dependent: on with
  a reference, off without. (Either way Batch 4 records it in the header, so
  this changes the default, not the format work.)
- **D2.** If the cue stays within **±0.20%** reference-free and keeps its
  reference-mode gain, it ships **always on**.
- **D3.** The default level is chosen **per mode**, by this rule: the smallest
  setting that is not slower than today's default. Reference mode already has
  its answer from `docs/speed.md` (level 1 + cue: −3.15% and 2.4x faster).
  Plain mode takes level 3 unless level 1 + cue lands **within 0.10%** of level
  3 base — in which case the speed is worth the size.
- **Stop rule.** If the cue loses more than **1%** anywhere reference-free,
  Batch 3's parameter sweeps are cancelled and the cue is treated as a
  reference-mode mechanism, because tuning a mechanism that hurts the headline
  regime is tuning the wrong thing.

## What would open a new question (recorded, not chased here)

A gain larger than **1%** on the metagenome would mean the cue is repairing
indel differences *between reads of the same locus* — a read-data effect. That
belongs to the FASTQ work (`Desktop\dnafq`), which this project closed on speed
grounds, and it would be recorded as a finding, not followed in v0.9.0.

## What this batch will not decide

Time. The reference-mode timing (+3.1% encode, `docs/remaining.md`) was paired
and repeated; no timing is claimed here, and none of these runs is quoted as a
speed figure. The level-1 speed argument already has its measurement.
