# The cue: result

**Run 2026-09-10.** Pre-registered in `docs/cue-prediction.md` (commit
`f80fc68`, 18:35:57 +0300) before any line of the cue was written. Build:
`gcc -O3 -DDNAC_CUE`, `CUE_L = 3`, `CUE_D = 12`, `CUE_SWITCH = 12` as registered,
no sweep. Without the flag the build is byte-identical to v0.8.0, and the nudge
build is byte-identical to what `docs/nudge.md` measured (both checked on
`ind_1`). FASTA and state references give byte-identical archives.

**Parameter set, added 2026-09-14 (Batch 4):** every figure here was measured
with `CUE_MINLEN = 16`, the value registered before the cue existed. v0.9.0
ships 4 (`docs/batch3.md`) and makes the cue a run-time feature, so this
document is the record of that build, not of the release. Its rows re-derive
from `4932ffe`'s source, which `verify-claims.ps1` pins; the release figures
are in `docs/batch4.md`.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **P1** | homopolymer slip ≤ 10 bits | **failed**: 11.78, over the whole file. **8.63 in its second half** |
| **P2** | substitution in [14.49, 14.79] | **held**: 14.65 (v0.8.0: 14.64) |
| **P3** | random indel ≤ 37.6 bits | **held**: **28.75** (−40% on v0.8.0, better than every nudge) |
| **P4** | lossless, control < 0.1%, FASTA = state | **held**: all round-trip, control −1 B, identical |
| **P5** | O157 ≤ +0.1% | **held**: −0.13% |
| | `chr21_ind` ≤ −3.0% | **held**: **−8.70%** (113,925 → 104,013 B) |
| **P6** | osmosis: slip 2nd ÷ 1st half ≤ 0.86, indel ≤ 0.93 | **held**: **0.576** and **0.835** (v0.8.0: 0.913, 0.968) |

Five of six held. P1 failed on the whole-file average, and P6 explains why: the
cue's cost is still falling when the file ends.

## Against everything measured before

| | substitution | random indel | homopolymer slip | O157 | `ecoli_ind` | `chr21_ind` |
|---|---:|---:|---:|---:|---:|---:|
| v0.8.0 | 14.64 | 48.25 | 31.43 | — | — | — |
| nudge, registered (L5 D12) | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% | −1.50% |
| nudge, best of sweep (L6 D12) | 14.94 | 37.63 | 6.78 | +0.55% | −2.38% | −3.00% |
| **cue** | **14.65** | **28.75** | 11.78 | **−0.13%** | **−3.19%** | **−8.70%** |

W3110 against MG1655: 1,927 B against 1,931 (−0.21%).

**−8.70% on the simulated chr21 individual is eleven times the largest single
improvement in dnac's history (0.8%).**

## The osmosis, measured

Cost per event in the first and second half of each target (bits, `-map`
against the zero-event control, mean of 3 seeds):

| | v0.8.0 1st → 2nd | ratio | cue 1st → 2nd | ratio |
|---|---|---:|---|---:|
| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |
| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |
| substitution | 15.27 → 15.48 | 1.014 | 15.27 → 15.48 | 1.014 |

v0.8.0 already learns a little along the file. With the cue in one ear, the slip
cost falls **42%** from the first half to the second, against 9%. That is the
microclimate: the table that says how far to trust the headphone ear, *given
what the room ear hears*, keeps improving with every slip it sees. Substitutions
are untouched, as they should be, because the cue only speaks when the room has
lost the beat.

The nudge does not have this property (0.916). It jumps, so it has nothing to
learn from. The cue listens, so it does.

## Why the headphones beat the nudge

- **No false jumps.** A cue loaded after a plain substitution only speaks, and
  the mixer learns to discount it. The substitution cost is the v0.8.0 cost to
  two decimal places.
- **It can listen on less evidence.** The cue loads after 3 agreeing bases
  where the nudge needed 5–6, because a wrong candidate costs almost nothing.
  So it starts helping sooner after a random indel: 28.75 bits against 33–38.
- **Where the nudge is still better:** a slip inside a run of identical
  letters, over the whole file (6.8 against 11.8). There the shifted phase is
  certain at once, so jumping is right. By the second half the cue is at 8.6
  and still falling.

## Not measured

- **Time.** Not claimed. The cue adds a follow step per base and a short search
  per miss. Run-to-run noise on this machine is 24%, and no paired timing was run.
- **Real people.** `chr21_ind` comes from `dnac mut`. The real-genome test is
  next, pre-registered separately.
