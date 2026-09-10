# Why dnac is slow, and one lever the cue opens: pre-registered

**Written 2026-09-10.** The profile below was measured first. The level test
below it has not been run.

## Premises: where the time goes (measured)

Machine: Intel Core i5-1135G7 (4 cores / 8 threads, 2.4 GHz base, 8 MB L3),
16 GB DDR4-3200, NVMe SSD.

`-DDNAC_PROF` (added on this branch, output byte-identical) counts CPU cycles
per stage of coding one base. `ind_1.fa` against the E. coli state, cue build:

| stage | cycles / base | share |
|---|---:|---:|
| mixer: 16 voices × 4 experts, 2 decisions per base (double precision, exp/log) | 1,440 | 27% |
| of which: fetching the order models' counters from their tables | 236 | 4.5% |
| other-strand training (`ir_train`) | 771 | 15% |
| SSE apply + update | 430 | 8% |
| mixer update | 290 | 6% |
| match models + cue | 144 | 3% |
| range coder | 35 | 0.7% |
| whole base (includes the counters' own overhead) | 5,260 | 100% |

**Memory is not the main cost.** Shrinking the hash tables 1,024x
(`HASHBITS_MAX` 26 → 16, so they nearly fit in cache) on the 10 Mb chr21 slice,
two rounds each:

| `HASHBITS_MAX` | time | size |
|---:|---:|---:|
| 26 (default) | 24.9 – 27.5 s | 2,105,437 B |
| 20 | 22.3 – 22.5 s | 2,111,506 B |
| 16 | 20.9 – 21.1 s | 2,114,114 B (+0.4%) |

Cache-friendly tables buy 15–20%, not a multiple. **Disk is not a cost at all**:
the input is read once into RAM in milliseconds. A Redis-style cache would
solve a problem this program does not have. What costs is the *thinking per
letter*: about 5,000 cycles, where an LZ compressor spends tens.

## The lever the cue opens

dnac's level 1 (`README.md`: 6 order models, 2 experts, no other-strand
training, no tolerant models) is 2.1x faster than level 3 for +0.375% size on
the chr21 slice. The cue saves 6% on real human pairs. If the cue does the job
some of level 3's expensive models were doing (following diverged repeats
through small differences), then **level 1 + cue** could be faster *and*
smaller than v0.8.0's default.

## Predictions

Targets: `ecoli_ind.fa`, `ind_1.fa`, `hp_1.fa` against E. coli states primed at
the matching level. Time is paired: back to back, 3 rounds, minimum.

**S1.** Level 1 + cue is **≥ 1.5x faster** than v0.8.0 level 3. *75%.*

**S2.** Level 1 + cue is **smaller** than v0.8.0 level 3 on all three targets.
*60%.*

**S3.** The cue's gain at level 1 is at least **80%** of its gain at level 3
(in bytes saved, per target). *50%.*

If S2 holds, the default for a v0.9.0 is up for re-decision: the fastest level
may become the recommended one.
