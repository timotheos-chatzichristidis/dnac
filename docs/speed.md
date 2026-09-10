# Why dnac is slow, and level 1 + cue: result

**Run 2026-09-10.** Pre-registered in `docs/speed-prediction.md` (commit
`b46f830`, 22:10:18 +0300). Every file below round-trips.

## Where the time goes

See the premises in `speed-prediction.md`. In one line: **about 5,000 CPU cycles
of thinking per letter.** Mostly the mixer's arithmetic, then the other-strand
training, then SSE. Memory stalls are a 15–20% share (measured by shrinking the
tables 1,024x). Disk is nothing. The hardware is a 4-core laptop CPU. A desktop
core would be faster, but no hardware turns 5,000 cycles into 50.

## Level 1 + cue, E. coli targets (paired, 3 rounds, minimum)

| target | v0.8.0 level 3 | cue level 3 | v0.8.0 level 1 | **cue level 1** |
|---|---|---|---|---|
| `ecoli_ind` | 12,580 B, 8.86 s | −3.19%, 8.96 s | +0.23%, 4.06 s | **−2.23%, 4.12 s** |
| `ind_1` | 53,178 B, 8.80 s | −9.18%, 8.96 s | +0.27%, 4.01 s | **−7.66%, 4.07 s** |
| `hp_1` | 48,994 B, 8.82 s | −10.00%, 8.98 s | +0.26%, 4.08 s | **−8.54%, 4.14 s** |

| | prediction | outcome |
|---|---|---|
| **S1** | level 1 + cue ≥ 1.5x faster than v0.8.0 level 3 | **held**: 2.13 – 2.15x |
| **S2** | smaller than v0.8.0 level 3 on all three | **held**: −2.23%, −7.66%, −8.54% |
| **S3** | the cue keeps ≥ 80% of its gain at level 1, per target | **failed on one**: 0.77 (`ecoli_ind`); 0.86, 0.88 on the others |

## The real human pair (measured after, not registered)

CHM13 chr21 against GRCh38 chr21, FASTA reference (priming included), one run
each:

| | size | time |
|---|---:|---:|
| v0.8.0 level 3 (today's default) | 586,615 B | 206.9 s |
| cue level 3 | 551,594 B (−5.97%) | ~193 s |
| **cue level 1** | **568,133 B (−3.15%)** | **85.8 s (2.4x faster)** |

## What this means for a v0.9.0

**With the cue, the fast level is better than the old default on both axes at
once.** The cue carries some of the work the heavy models were doing. That
gives a real choice of default, which is Timotheos's to make:

- **cue level 3**: smallest (−6% on real pairs), same speed as today;
- **cue level 1**: 2.4x faster than today and still 3% smaller.

## Speed levers beyond this, ranked by expected size (none measured yet)

1. **Use the other cores in reference mode.** Blocks (`-j N`) already give 5.1x
   on 8 cores in plain mode, and a reference-mode boundary costs only ~245 B
   (`negative-results.md` #3). What blocks reference mode is memory: every
   thread needs its own copy of the primed model (1.25 GB for chr21). The fix
   written down there and never tried is to share one frozen copy of what the
   reference taught, with a small private layer per thread for what the target
   teaches. On this 4-core CPU the ceiling is about 3–4x. This is the
   rethink-from-the-root lever.
2. **Cheaper arithmetic in the mixer** (27% of the time): single precision and
   vector instructions for the 16 × 4 weighted sums, and a table instead of
   `exp()`. Estimate 15–25% overall. It has to stay bit-exact across compilers,
   which the 14-bit quantisation before the coder has protected so far
   (`README.md`).
3. **Cache-sized tables**: 15–20% for +0.4% size (measured above). Worth
   offering as a level, not as a default.
