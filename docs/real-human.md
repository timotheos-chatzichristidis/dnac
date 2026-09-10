# The cue on a real human pair: result

**Run 2026-09-10.** Pre-registered in `docs/real-human-prediction.md` (commit
`49ba66c`, 18:55:19 +0300) after the v0.8.0 run and before the cue build touched
the pair. Target: T2T-CHM13 chr21 (`CP068257.2`). Reference: GRCh38 chr21. The
cue build is `-DDNAC_CUE` with the parameters of `docs/cue.md`, unchanged. Both
archives round-trip byte-identically.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **R1** | whole chromosome ≥ 1.0% smaller | **held**: 586,615 → **551,594 B, −5.97%** |
| **R2** | shared windows ≥ 5% fewer bits | **held**: **−18.27%** |
| **R3** | novel windows within ±1% | **held**: −0.00% (1,082,312 → 1,082,291 bits) |
| **R4** | gain larger in the second half of the shared set | **held**: −13.26% first half, **−23.21%** second |
| **R5** | lossless | **held** |

**Replicated on chromosome 22** (`docs/remaining.md`): −5.83% file, −16.24% on
shared sequence, −0.01% on novel.

## Where the gain comes from

Windows are fixed from the v0.8.0 map (1 kb each, same target, so paired):

| windows (v0.8.0 bits/base) | windows | v0.8.0 bits | cue bits | change |
|---|---:|---:|---:|---:|
| shared (< 0.2) | 39,888 | 1,189,954 | 972,579 | **−18.27%** |
| diverged (0.2 – 1.0) | 4,512 | 2,351,053 | 2,288,286 | −2.67% |
| novel (≥ 1.0) | 691 | 1,082,312 | 1,082,291 | −0.00% |
| all | 45,091 | 4,623,320 | 4,343,157 | −6.06% |

(Map totals are the coder's own bit sums and differ slightly from file bytes,
which include the header and the non-ACGT stream. The file figure in R1 is the
real one.)

The pattern is the one the mechanism predicts: the gain is large where the two
people's chromosomes line up, and exactly zero on sequence one of them does not
have. **The real pair gains more than the simulator predicted** (−18% on shared
sequence against −8.7% on `dnac mut`'s whole chromosome), which fits real small
indels sitting mostly in runs and short repeats. That was the cue's best case
in `docs/cue.md`.

## About R4

The two halves of a chromosome are not the same material, so R4 cannot separate
learning from content. It is consistent with the osmosis seen on the controlled
targets in `docs/cue.md`, where the material was uniform. It is not
independent proof of it.

## What this does not claim

- **Not "best way to store a human genome".** The established competitors on a
  human pair — GeCo3's reference mode, alignment-style reference compressors,
  and a variant list — were not run here. The claim is only that the cue makes
  dnac 6% better on a real human pair.
- **Novelty beyond the context-mixing DNA family.** GeCo and JARVIS were checked
  (`docs/nudge-prediction.md`). The PAQ family (paq8px's match-model recovery,
  its sparse match model) has not been checked yet, and has to be before the
  idea is called new.
- **Time.** Not measured.
