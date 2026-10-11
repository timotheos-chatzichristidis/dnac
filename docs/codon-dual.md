# Codon tracker: code both ways, keep the smaller -- result: PASSES, a candidate for the level-1 default

Pre-registration: docs/codon-dual-prediction.md (commit 0eef25f, before any code). Run
2026-10-11 on branch `codon-euk`; scratch switch `CODON_DUAL` (commit after 0eef25f).

## Negative control

`CODON_DUAL=0` writes archives sha256-identical to main on `ecoli.fa` and
`chr21_slice.fa` at level 1.

## A bug the identity check caught before any number was taken

The first threaded build wrote an E. coli archive the release decoder refused
("truncated archive"). Job 0 of the two runs on the caller's thread, and it left that
thread's own codon choice at 0; the header letter then named the plain model while the
span written was the tracker's. The `DNAC_NO_THREADS` build, where job 1 runs last, hid
it. Fix: each job hands its thread back the configuration when it ends. Every number below
is from the fixed build. (Refusal, not wrong bytes: the stream length check of v0.11.0 did
its job.)

## Identity and regret, level 1

Unseen genomes (sha256 prefix): vcho NC_002505.1 f5bdfb993f94fb18, cjej NC_002163.1
2461bf573a726afc, bant NC_003997.3 dbf913d80c46be87, lmon NC_003210.1 262da11c4c7ec0ff,
calb1 NC_032089.1 36f5a807e0552700, ggal28 NC_052559.1 0b499977060187e3, zmay10
NC_050105.1 da82cdfb3af42f43. **Leishmania major `NC_007242` was DROPPED**: the accession
now resolves to "Vicia cryptic virus RNA2", and the rule said drop, not replace.

| file | G | `-nocodon` | tracker forced | release | dual | release regret | dual = smaller? |
|---|---:|---:|---:|---:|---:|---:|---|
| V. cholerae chr 1 | 2.0946 | 708,873 | 692,553 | 692,553 | 692,553 | 0 | yes |
| C. jejuni | 2.6611 | 364,600 | 352,715 | 352,715 | 352,715 | 0 | yes |
| B. anthracis | 2.9671 | 1,216,361 | 1,188,919 | 1,188,919 | 1,188,919 | 0 | yes |
| L. monocytogenes | 3.4644 | 695,662 | 680,063 | 680,063 | 680,063 | 0 | yes |
| C. albicans chr 1 | 6.9768 | 744,467 | 734,637 | 734,637 | 734,637 | 0 | yes |
| G. gallus chr 28 | 1.5513 | 1,145,209 | 1,149,184 | 1,145,209 | 1,145,209 | 0 | yes |
| **Z. mays chr 10** | 2.8274 | 13,201,468 | 13,358,118 | 13,358,118 | **13,201,468** | **1.1866%** | yes |
| H. pylori (round 2) | 1.7440 | 375,440 | 365,022 | 375,440 | **365,022** | **2.7749%** | yes |
| O. sativa chr 1 (round 2) | 2.1207 | 8,389,209 | 8,424,707 | 8,424,707 | **8,389,209** | **0.4231%** | yes |
| M. tuberculosis (round 2) | 2.0180 | 1,004,480 | 982,428 | 982,428 | 982,428 | 0 | yes |
| A. thaliana chr 1 (round 1) | 2.8121 | 6,556,231 | 6,561,555 | 6,561,555 | **6,556,231** | **0.0812%** | yes |
| E. coli (README) | 3.8858 | 1,094,640 | 1,069,622 | 1,069,622 | 1,069,622 | 0 | yes |
| chr21_slice (README) | 1.1736 | 2,112,257 | 2,117,312 | 2,112,257 | 2,112,257 | 0 | below 1.5: coded once, = release |

"Yes" means sha256-identical to the smaller release archive (the plain one on a tie), not
merely the same size. Every archive in the table -- release and dual -- was decoded by the
RELEASE build (main) and compared with `cmp`: 52 decodes, 0 failures. **Dual regret is 0 on
all 13 files; release regret is non-zero on 4 of them, worst 2.77%.**

## Cost (run alone, min of 3 alternating rounds, level-1 encode)

| file | wall, release | wall, dual | CPU, release | CPU, dual | peak WS, release | peak WS, dual |
|---|---:|---:|---:|---:|---:|---:|
| E. coli | 5.66 s | 6.58 s (**+16.3%**) | 5.39 s | 12.61 s (+134%) | 479 MB | 938 MB (**1.96x**) |
| H. pylori | 1.91 s | 2.36 s (+23.6%) | 1.89 s | 4.52 s (+139%) | 132 MB | 256 MB (1.94x) |
| chr21 (G 1.17) | 50.04 s | 49.27 s (**-1.5%**) | 49.19 s | 48.58 s | 748 MB | 748 MB (**1.00x**) |

(H. pylori is not a like-for-like time comparison: release codes it without the tracker,
dual also runs the slower tracker arm. Its archive is 2.77% smaller for that.)

## Verdict against the bar

| condition | bar | measured | |
|---|---|---|---|
| identity on every file | all | 13 of 13, sha256 | pass |
| regret 0 on every unseen genome | 0 | 0 on 7 of 7 | pass |
| chr21 wall time | within +5% | -1.5% | pass |
| chr21 peak memory | within 2% | 748 = 748 MB | pass |
| E. coli wall time | <= +25% | +16.3% | pass |
| E. coli peak memory | <= 2.2x | 1.96x | pass |

**Passes on every condition: a candidate for the level-1 default.**

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| D1 | identity holds on every file | hit, after the bug above was fixed (the check is what found it) |
| D2 | release has regret > 0 on at least one unseen genome | hit: maize, 1.19% -- the largest false positive seen in three rounds |
| D3 | E. coli wall +5..+15%, CPU +95..+105%, memory 1.9..2.05x | wall **+16.3%, just over**; CPU **+134%, missed** -- the tracker arm alone costs ~+32% (docs/codon-speed.md), which I left out; memory 1.96x hit |
| D4 | chr21: no measurable difference | hit |

## What adoption would mean (Timotheos's decision)

- **No format change.** Every archive dual writes is one the release encoder can already
  write, under the letter that names it; v0.11.0 and later decoders read them all.
- **Published figures**: a README file changes only if 1.5 <= G and the tracker LOSES on it
  (it would then get smaller). The README's bacteria all gain (dual picks what release
  picks, byte-identical: E. coli above), human files sit at G <= 1.17. Expected: no README
  number moves -- verify-claims fast and slow would have to confirm it.
- **The cost lands only on files that pass the filter**: about 2x memory and +16-24% wall
  time on bacteria-sized files at level 1. A user who wants neither has `-nocodon` and
  `-codon`, which keep their meaning (dual runs only with the default setting).
- **Open edge**: G. gallus chr 28 (1.55) shows a gene-dense vertebrate chromosome can clear
  1.5 and pay the double cost for nothing; it costs no size, only time. Whole-genome or
  large chromosomes of birds/mammals measured so far sit at 1.10-1.17.
- Implementation in the release code means the same change as the scratch switch, minus
  the switch, plus round-trip suite cases (a gate-above-1.5-but-tracker-loses file, and a
  threaded vs `DNAC_NO_THREADS` identity case, which is the one that would have caught the
  bug above).
