# Batch 5: claims and release — pre-registration

**Written 2026-09-17**, before any measurement, as `docs/v0.9.0-plan.md` requires.
Batch 5 is the last batch of v0.9.0: the README is rewritten to describe the
shipping build, every number in it gets a row that re-derives it, `CITATION.cff`
moves to 0.9.0, and the one open decision Batch 4 handed over — the level-1
default's loss on W3110 — is settled by measurement rather than by argument.

The session opened green on `ba4c86e`: `make` clean, `sh scripts/roundtrip.sh
./dnac.exe` 229/229, `./verify-claims.ps1 -Tier fast` 21/21.

## What Batch 4 handed over (not re-derived here)

1. Three record claims do **not** carry to the release: "exactly 0 on sequence
   one person lacks" (now a gain of 0.23–0.34%), "1.6x ahead" (1.62x at level 3,
   **1.57x** at the level-1 default), "3% smaller than v0.8.0" (now **−4.02%**).
2. **The level-1 default is +9.84% on W3110 against v0.8.0's default** (2,121 B
   against 1,931 B), +0.05% on O157. Batch 5 states it or re-opens the default.
3. Two CI checks have never run (macOS arm64 on the stored v0.8.0 streams; the
   families step), because nothing is pushed.
4. The records are pinned to `4932ffe`; only `rel`, `v08`, `exp` compile the tree.
5. The README still describes v0.8.0 on purpose, and its rows run the `v08`
   build for that reason.

## F — the design of the rewrite, fixed before the numbers arrive

- **F1. The README describes the shipping build.** Every dnac figure in it is
  re-measured with `rel` (the unflagged working tree). The `v08` build survives
  only in rows that defend an explicit *comparison* with v0.8.0 ("−4.02% against
  v0.8.0's default"). Concretely, `verify-claims.ps1`'s `$dnac` becomes the
  release build and a separate `$v08` is kept for those rows.
- **F2. Nothing in a record document is edited.** `cue.md`, `cue-room.md`,
  `cue-back.md`, `real-human.md`, `remaining.md`, `speed.md`, `competitors.md`,
  `reference-free.md`, `batch1/3/4.md` keep their figures and their parameter
  note. The README quotes the *release* figures, which are Batch 4's R1–R7.
- **F3. Reference-mode tables lead with the default and print `-l 3` beside it.**
  The default changed to level 1 with a reference; a README that quotes a number
  the default does not produce is exactly how figures went stale here before.
- **F4. "Where this loses" gains three entries**, each with its row: the W3110
  loss under the level-1 default (D1 below decides how it is phrased), the
  competitor lead being 1.57x at the default rather than 1.62x at level 3, and
  the cue's cost in time.
- **F5. The cue gets its own section**: the mechanism in plain words, its origin
  (`docs/origin.md`), what it is worth on real pairs, and what it is *not* worth
  (reference-free, 0.1% at level 3).
- **F6. The format section states the families**: `DNCC`/`DNCU`/`DNCP` are
  v0.8.0's and still decode, `DNCE`/`DNCV`/`DNCQ` carry the cue, lower case is an
  experimental build and both sides refuse it.
- **F7. The ablation table stays labelled as v0.8.0's model set.** With the cue
  there are 16 mixer inputs at level 3, not 15; `docs/model-ablation.md` measured
  15 and is not re-run here. The README says which set it describes.
- **F8. `CITATION.cff` → 0.9.0**, with the date of the tag, not of this session.

## P — the figures, predicted before they are measured

Plain mode at the release is Batch 3's `cue_M4` (Batch 4's P1 proved `rel` is
that build to the byte), so these follow from `docs/batch3.md` §5 and are stated
to the byte. A miss here means P1 does not hold as widely as Batch 4 claimed.

| | claim | prediction |
|---|---|---|
| **P1** | E. coli `.seq`, plain, level 3 | 1,092,635 B ± 6 (v0.8.0: 1,092,692) |
| **P2** | chr21 `.seq`, plain, level 3 | 7,498,337 B ± 8 → **1.4963 bpb** (v0.8.0: 1.4979) |
| **P3** | chr21 `.seq`, plain, level 1 | 7,540,777 B ± 8 |
| **P4** | chr21 slice `.seq`, level 3 | between 2,103,300 and 2,104,100 B (never measured at `CUE_MINLEN=4`) |
| **P5** | metagenome, level 3 | between 17,310,000 and 17,319,000 B; still 1.44–1.47x zstd |
| **P6** | E. coli `-j 8`, level 3 | within ±0.05% of v0.8.0's 1,116,080 B |
| **P7** | E. coli state file | larger than 616 MB, by less than 40 MB (the cue adds a deck and a mixer input to the model memory) |
| **P8** | W3110 `.fa` vs MG1655, release level 3 / level 1 | 1,916 B / 2,121 B, to the byte (Batch 4 R2, measured against a primed state; a FASTA reference must give the same bytes) |
| **P9** | `ecoli_ind` and O157 `.fa`, release level 3 / level 1 | 12,051 / 12,204 and 362,006 / 362,862, to the byte |
| **P10** | level 4 with the cue, E. coli and the slice | a gain against v0.8.0's level 4, smaller than 0.05% |

## W — the W3110 question, and the experiment that settles it

**The question.** Under the new default (level 1 with a reference) the tightest
real bacterial pair is 9.84% larger than under v0.8.0's default. Is that a
property of near-identical pairs in general — in which case the default is
wrong — or an artefact of a 2 kB output, or content that level 3's dropped
models earn on and level 1 cannot?

**What is already known, and this pre-registration is not blind to it** (Batch 4
R2, release build, level 1 against level 3): `ecoli_ind` +1.27% (12 kB output),
`chr21_ind` +0.71% (101 kB), O157 +0.24% (362 kB), CHM13 chr21 +2.93% (547 kB),
W3110 **+10.7%** (2 kB). Output size alone does not order these — O157's 362 kB
costs 0.24% and CHM13's 547 kB costs 2.93% — so "the percentage is big because
the file is small" is a hypothesis, not a reading of the table.

**The experiment** (`scripts/cue/batch5-w3110.sh`, E. coli scale, minutes):
`dnac mut ecoli.fa` at 0.05, 0.2, 1.0 and 5.0 per-mille (seed 42 — SNPs at the
rate, indels at a tenth of it), each compressed against MG1655 with the release
build at levels 1 and 3, every archive round-tripped. W3110 and O157 are
measured in the same run at the same settings. The 0.2 per-mille point is chosen
because its output should land near W3110's 2 kB, which makes the comparison a
matched one rather than an extrapolation.

| | prediction |
|---|---|
| **W1** | the level-1 penalty stays **below 3%** at every rate on the simulated gradient, and never approaches 9.84% |
| **W2** | the penalty is **not a fixed overhead**: in bytes it grows with the rate, by at least 3x from 0.05 to 5.0 per-mille |
| **W3** | at a matched output size (~2 kB, the 0.2 per-mille point) the simulated penalty is **far below W3110's 205 B** — so the loss is content, not size |
| **W4** | the per-event arithmetic predicts the gradient's penalty within a factor of 2.5: level 1 pays +3.12 bits per indel and saves 0.17 bits per substitution (Batch 4 R1), i.e. about 0.39 B per indel minus 0.021 B per SNP |

### W5, added after W1–W4 were run, and disclosed as such

W1–W4 were measured before this paragraph was written, and W3 came back
decisive: at a matched output size the simulated pair's level-1 penalty is 4 B
against W3110's 205 B. That answers "size or content" and immediately raises
"**which** content", which the four `L1_*` diagnostics can answer in minutes.
Adding a prediction after seeing a result is exactly the move Batch 3 had to
disclose, so it is disclosed here: **W5 was written after W1–W4 and before the
`L1_*` runs**, and it is a diagnosis of a loss, not a re-opening of Batch 3's
add-back decision (that rule was about time on the human pair, and nothing here
re-prices it).

The experiment: W3110 against MG1655 at level 1, release build, with one of
`L1_ORDERS`, `L1_IR`, `L1_STCM`, `L1_NMIX=4` switched on at a time, against
level 1 (2,121 B) and level 3 (1,916 B).

| | prediction |
|---|---|
| **W5a** | one part dominates: the largest single add-back recovers **at least 40%** of the 205 B |
| **W5b** | that part is **`L1_ORDERS`** (the master order set) — re-establishing context after a slip is what a near-identical pair spends its bytes on, and per-event level 1 is *better* on substitutions and worse only on indels |
| **W5c** | `L1_STCM` (the tolerant models) recovers less than `L1_ORDERS`, because W3110's differences are structural rather than substitutions |

**D1, the decision rule, fixed now.** If W1 holds *and* every real pair whose
output exceeds 100 kB stays under 3%, the reference-mode default **stays level
1**, and the README states the W3110 case in both units (+9.84%, +190 bytes)
with `-l 3` named as the remedy. If the penalty exceeds 3% across the simulated
gradient as well, the default is **re-opened**: Batch 5 stops the rewrite and
measures a size-dependent default instead. Anything in between is reported as
in between, and the default stays with the loss stated.

**D2.** Whatever D1 decides, the README's reference-mode tables print both
levels (F3), so no reader has to know this document exists to find the smaller
number.

## R — what "green" means at the end of this batch

- `sh scripts/roundtrip.sh ./dnac.exe` 229/229 and `./adversarial.ps1` 155/155
  on the release build (unchanged code is expected; the rewrite touches docs,
  the registry and `CITATION.cff`, not `dnac.c` — unless D1 re-opens the default).
- `verify-claims.ps1 -SelfTest` red on every detector, including any added here.
- Every tier green, one at a time: `fast`, `slow`, `extern`, `meta`, `cue`,
  `cue3`, `b4`. The pinned tiers (`cue`, `cue3`, `b4`) must not move: they
  compile `4932ffe`, and this batch does not touch it.
- Every number in the rewritten README has a row. A number without a row is
  either deleted or measured; there is no third option.

## What this batch does not do

Tag or push. `docs/v0.9.0-plan.md`: "Tag and release only after Timotheos says
so." The release candidate is prepared, committed on `nudge`, and left there.
