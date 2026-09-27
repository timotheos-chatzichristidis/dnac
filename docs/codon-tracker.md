# A real codon-phase tracker -- result

Run 2026-09-27, pre-registered in `docs/codon-tracker-prediction.md` (commit 3e7dd06).
Recipe: `TRK=<build with scripts/pilot/codon-tracker.patch> REL=<branch build> sh scripts/pilot/codon-tracker.sh`;
diagnostic `python scripts/pilot/codon-track-diag.py <true.lab> <tracker.labels>`.
Every archive decoded and compared with cmp. With the variable unset the build is
byte-identical to rel (E. coli). No side information: the decoder runs the tracker itself.

| | rel | tracker | gain | bar |
|---|---:|---:|---:|---|
| E. coli | 1,093,425 B | 1,076,176 B | **1.5775%** | >= 1.5% -- met |
| B. subtilis | 1,002,525 B | 993,594 B | **0.8909%** | >= 1.0% -- **missed** |
| chr21_slice | 2,104,484 B | 2,107,028 B | **+0.1209% (cost)** | <= +0.1% -- **missed** |

Encode time on E. coli, three alternating rounds: rel 10.15 / 10.19 / 10.57 s, tracker
13.41 / 13.49 / 14.14 s, so min against min is +32%. Reported, not judged.

| | prediction | outcome |
|---|---|---|
| T1 | E. coli 1.0-2.5% | held (1.5775%) |
| T2 | label agreement 50-80% | failed: 46.5% on coding bases after the best renaming (43.4% B. subtilis) |
| T3 | chr21_slice within +-0.1% | failed (+0.1209%) |

**The bar fails, on two of its three conditions.** Recorded as is.

## What the tracker actually did (the diagnostic, read up to a renaming)
The tracker is unsupervised, so its label names are arbitrary. The comparison takes the
best one-to-one renaming over all 7! permutations. A first reading without that renaming
gave "2.9% correct", which was the renaming error of docs/codon-oracle-control-prediction.md
again, caught before it was reported.
- **It found the phase and lost the strand.** It uses only three of its seven labels, and
  each maps cleanly onto ONE codon position of a + gene AND one of a - gene (E. coli: 12.7%
  and 13.3% of all bases per label, about 0.6% elsewhere). In effect it runs a single mod-3
  clock that stays locked to gene frames. The strand split, and the non-coding label, never
  formed. Self-training from a symmetric start never broke the strand symmetry.
- On human sequence, which has few genes, the same three-way split of the statistics costs
  0.12%. There is no "non-coding" fallback, because that label is never chosen.
- For scale: this beats the unaligned control on E. coli (1.58 against 1.13) but not on
  B. subtilis (0.89 against 0.88). The strandless clock is worth little more than a fixed
  cycle there.

## What a second round would have to change (not decided here)
1. **Strand:** break the symmetry by construction, not by luck. The - hypotheses could
   share the + statistics through the reverse complement, since that is what a - gene is.
2. **Non-coding / human:** a default that wins when no phase earns its keep, so a
   gene-poor genome pays nothing.
Tuning, if any, is done on E. coli only, with B. subtilis held out. It needs its own
pre-registration and bar, and the bar above does not move.
