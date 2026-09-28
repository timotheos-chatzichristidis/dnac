# Codon-phase tracker, round 2 -- result

Run 2026-09-27, pre-registered in `docs/codon-tracker2-prediction.md` (commit 64d2e78).
Recipe: `OUT=bench-external/pilot/codon/trk2 TRK=<build with scripts/pilot/codon-tracker2.patch> REL=<branch build> sh scripts/pilot/codon-tracker.sh`.
Every archive decoded and compared with cmp. The build with the variable unset is
byte-identical to rel. No side information.

| | rel | tracker 2 | gain | bar | round 1 |
|---|---:|---:|---:|---|---:|
| E. coli | 1,093,425 B | 1,066,573 B | **2.4558%** | >= 1.5% -- met | 1.5775% |
| B. subtilis (held out) | 1,002,525 B | 985,500 B | **1.6982%** | >= 1.0% -- met | 0.8909% |
| chr21_slice | 2,104,484 B | 2,111,478 B | **+0.3323% (cost)** | <= +0.1% -- **missed** | +0.1209% |

Encode time on E. coli, three alternating rounds: rel 10.48 / 10.16 / 10.27 s, tracker
13.82 / 13.84 / 13.45 s, so min against min is +32%.

| | prediction | outcome |
|---|---|---|
| U1 | E. coli 2.0-3.0% | held (2.4558%) |
| U2 | B. subtilis >= 1.0% | held (1.6982%) |
| U3 | chr21_slice within +-0.05% | **failed** (+0.3323%) |
| U4 | coding agreement after renaming 60-85% | held (83.3%; B. subtilis 81.1%) |

**The bar fails on the human condition alone.** The bacterial half works: the strand is now
split by construction. The best renaming maps each of the tracker's six phase labels onto
exactly one true label, at 11.5-12.8% of bases each against 0.1-0.5% off the diagonal. That
takes the tracker to 65% of the oracle's ceiling on E. coli (2.46 of 3.75) and 55% on
B. subtilis (1.70 of 3.07), well above the unaligned controls (1.13 / 0.88).

**Why human got worse, not better:** on chr21_slice the tracker holds a phase label on 94%
of bases, and the non-coding default wins only 6% of the time. Six phase hypotheses compete
with one background model, all trained on the same data. On sequence without codons the
BEST of six noisy scores regularly beats the single background score by more than the 4-bit
margin (a winner's curse), so the codec splits its statistics by a phase that does not
exist.

## The pre-set consequence
"If it fails, the codon lever gets a written decision (a third round or a close) before any
more code." That decision belongs to Timotheos. The failure is a GATE: whether to trust the
tracker on a given genome. Phase-finding itself is not what failed.
