# The cue against the competitors, on a real human pair: result

**Run 2026-09-10.** Pre-registered in `docs/competitors-prediction.md` (commit
`4701a50`, 19:23:02 +0300) before any competitor ran on this pair. Target:
CHM13 chr21. Reference: GRCh38 chr21. One run per tool.

## The two tables

**FASTA** (`chm13_chr21.fa` against `dnac/chr21.fa`):

| tool | bytes | vs dnac + cue | round-trip |
|---|---:|---:|---|
| zstd -19 --long=27 --patch-from | 3,143,939 | 5.70x larger | yes |
| HRCM | 1,438,137 | 2.61x larger | sequence, header and line layout yes; drops the file's final empty line |
| dnac v0.8.0 | 586,615 | 1.06x | yes |
| **dnac + cue** | **551,594** | — | yes |

**Plain ACGT** (`chm13_chr21.seq` against `grch38_chr21.seq`):

| tool | bytes | vs dnac + cue | round-trip |
|---|---:|---:|---|
| GeCo3, reference template (`$PARAMR`) | 1,243,961 | 2.28x larger | **unverified** (GeDe3 broken on this machine) |
| zstd -19 --long=27 --patch-from | 882,586 | 1.62x larger | yes |
| GeCo3, hybrid template (`$PARAMH`) | 877,373 | 1.61x larger | **unverified** |
| dnac v0.8.0 | 581,022 | 1.06x | yes |
| **dnac + cue** | **545,982** | — | yes |

## Scoreline

| | prediction | outcome |
|---|---|---|
| **C1** | cue ≥ 2x smaller than zstd, both tables | **failed on plain**: 1.62x. Held on FASTA (5.70x) |
| **C2** | cue ≥ 3% smaller than the best GeCo3 template | **held**: 37.8% smaller (545,982 vs 877,373) |
| **C3** | cue ≥ 10% smaller than HRCM | **held**: 61.6% smaller (551,594 vs 1,438,137) |
| **C4** | (no prediction) does v0.8.0 already lead? | **yes, on every competitor.** The cue widened a lead. It did not change the ranking. |

## What to take from it

- **dnac with the cue is the smallest of everything tried on this pair, in
  both formats.** It is 1.6x smaller than the best competitor in each table.
- **The trivial diff was closer than predicted.** On bare ACGT, zstd's
  `--patch-from` is only 1.62x behind, and C1 failed there. On FASTA it falls to
  5.7x behind, because the two files wrap lines at different widths (60 against
  70) and every line break breaks an LZ match. That is a property of the file
  layout, not of the method, and the plain table is the fair one for zstd.
- **The margin over GeCo3 (38%) is far larger than on the E. coli pairs (1–20%).**
  These are the authors' own reference-mode templates, which were not built for
  a diverged human pair, and they are unverified because the decoder fails
  here. A better-tuned GeCo3 may well close some of this. It is not a claim that
  GeCo3 cannot do better.
- **HRCM is one specialist, built for versions of the same assembly** (its own
  example, hg17 → hg18 chr22, costs 73 KB). Stronger alignment-style
  specialists exist (GDC2, SCCG, HiRGC) and were not run.

## Time (one run each, not a claim)

| tool | compress |
|---|---:|
| HRCM | 5.6 s |
| zstd -19 | 84 – 97 s |
| GeCo3 | 105 – 156 s |
| dnac v0.8.0 / + cue | 190 – 204 s |

HRCM is about 35x faster than dnac. The cue did not change dnac's time outside
this machine's noise. dnac also decodes as slowly as it encodes (`README.md`):
the size lead is bought with time.
