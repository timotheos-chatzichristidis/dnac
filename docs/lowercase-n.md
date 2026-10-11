# Lowercase `n` in the case list -- result

Pre-registration: docs/lowercase-n-prediction.md (commit 5bf2341). Run 2026-10-11 on this
machine, one session, one process at a time. The design is exactly as pre-registered. The
scratch implementation is on the local branch `lowercase-n`: `cl_pos`, `CL_NFLAG`, and the
top bit of the run count. v0.12.0 is `main` (ed2a8b7). Both are built `-O3 -Wall -Wextra`,
with no warnings.

**Verdict: NOT ADOPTABLE.** Every requirement holds, and chr21 clears the bar, but chr22 does
not. Lowercase `n` stays on the literal path.

## Result

| file, level | v0.12.0 | n in the list | change | bar (0.05%) |
|---|---:|---:|---:|---|
| chr21_sm L3 | 7,890,488 | 7,883,800 | **−6,688 B (−0.0848%)** | 3,945 B: passes |
| chr21_sm L1 | 7,933,145 | 7,926,343 | −6,802 B (−0.0857%) | |
| chr22_sm L3 | 7,574,763 | 7,572,143 | **−2,620 B (−0.0346%)** | 3,787 B: **fails** |
| chr22_sm L1 | 7,631,423 | 7,628,844 | −2,579 B (−0.0338%) | |

The case list itself barely moves:

| | v0.12.0 runs | n-list runs | v0.12.0 section | n-list section |
|---|---:|---:|---:|---:|
| chr21_sm | 119,986 | 120,002 (+16) | 143,081 B | 143,143 B (+62) |
| chr22_sm | 124,658 | 124,672 (+14) | 147,004 B | 147,052 B (+48) |

The lowercase `n` stretches sit almost entirely inside lowercase runs that were already there,
so they cost the list only 14 to 16 runs. The saving is therefore almost all of what the
literal path spent: 6,688 B on chr21, which is 99% of the 6,745 B ceiling. On chr22 the literal
path spent only about 2.6 KB. Its 948,691 lowercase `n` are cheaper as literals than chr21's
1,261,364, and that cost was never measured before this run.

## Requirements

- **R1, holds.** All 9 files without a lowercase `n`, at levels 1 and 3, give archives
  byte-identical to v0.12.0 (18 of 18). The 5 small hand cases also hold: an `n` inside a
  header and a case file with only uppercase `N` are byte-identical.
- **R2, holds.** Both n-files round-trip (`cmp`) at L1 and L3, plain and `-j 3`. So do the
  hand cases: `n` only, `n` first and last, `n` mixed with `N`.
- **R3, holds.** v0.12.0 refuses every n-archive with "corrupt case list", exit 1, and writes
  no output file. That covers both chromosomes at both levels and 3 hand cases.
- **R4, holds.** At both levels, each n-archive's body is `cmp`-identical to v0.12.0's archive
  of the twin with a/c/g/t/n uppercased. The archive is exactly twin + 16 B + section, on both
  chromosomes.

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| N1 | chr21_sm −5,000 to −6,745 B | hit: −6,688 B |
| N2 | chr22_sm −3,000 to −8,000 B | **miss**: −2,620 B |
| N3 | runs change < 1%, section grows < 1 KB | hit: +16 runs (0.013%), +62 B |
| N4 | times do not move outside noise | hit: chr21 L3 compress 88 s vs 91 s, chr22 93 s vs 100 s (single runs) |

## What this leaves

The mechanism works exactly as designed: zero regret, byte identity everywhere it should hold,
and an old decoder refuses rather than misreads. It does not earn a format change by the rule
fixed in advance. The bar was half of chr21's ceiling, and chr22's whole ceiling lies below it.
The bar is not moved onto a number already seen. The code stays on the local branch
`lowercase-n` as a ready implementation, in case a future format change (a release that breaks
the case section anyway) wants to carry it for free.
