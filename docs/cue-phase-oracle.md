# The cue's phase choice: what would a perfect search buy? -- result

Run 2026-09-27, pre-registered in `docs/cue-phase-oracle-prediction.md` (commit 94557b6).
Recipe: `PH=<build with scripts/pilot/cue-phase.patch> sh scripts/pilot/cue-phase.sh`
(history files `bench-external/pilot/hist_chrN.bin` built as in scripts/pilot/cue-source.py).
Every archive was decoded and compared with cmp. The oracle decode replays the encoder's
choices from the side file (185,674 / 263,025 choices). The patched build without
variables is **byte-identical** to the release archives on both chromosomes.

| | chr21 | vs rel | chr22 | vs rel |
|---|---:|---:|---:|---:|
| rel | 547,019 B | -- | 742,177 B | -- |
| ph-back (furthest back-agreement, a real rule) | 546,542 B | -0.0872% | 741,689 B | -0.0658% |
| **ph-oracle** (best over the next 30 bases) | 543,869 B | **-0.5758%** | 738,805 B | **-0.4543%** |

| | prediction | outcome |
|---|---|---|
| P0 | rel figures; no-variable build byte-identical | held |
| P1 | ph-oracle 0.5-2% on chr21 | held (0.5758%) |
| P2 | ph-back 0-0.3% on chr21 | held (0.0872%) |

## By the rule: the phase-choice lever is closed

The rule needed the ceiling to reach >= 0.6% on chr21. It reaches **0.5758%**, short by
0.0242 points. The chr22 condition (>= 0.3%) is met, but the rule needs both. **The bar
stays at 0.6%.** It was set as twice the adoption bar, because a real rule recovers only
part of a ceiling, and the only real rule measured here recovers 15% of it (0.0872 of
0.5758). A filter that captured the whole ceiling would sit just under 0.6%; one that
captured a realistic share would sit far below the 0.3% adoption bar.

This is the fourth mechanism to finish within a whisker of a pre-registered threshold,
after the four-expert, riding and rotation experiments. That is the standing question in
CLAUDE.md, and it belongs to Timotheos: it is argued before the next measurement, never
by moving this bar.

## What the ceiling says about the cue
Choosing perfectly among the SAME candidates at the SAME moments is worth about half a
percent. The cue as a whole is worth 7.24%. So the cue's value lies in WHEN it loads and
in having a second deck at all. Which of the 3-base candidates it picks matters little.
