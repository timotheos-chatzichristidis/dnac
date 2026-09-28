# The cue's false loads: what would a perfect filter buy? -- result

Run 2026-09-27, pre-registered in `docs/cue-oracle-prediction.md` (commit 9488647).
Recipe: `ORC=<build with scripts/pilot/cue-oracle.patch> REL=<branch build> sh scripts/pilot/cue-oracle.sh`.
Every archive was decoded with the same oracle file and compared with `cmp`. The
patched build without the oracle variables writes an archive byte-identical to the
release build (chr21), so the patch is inert.

| | chr21 | vs rel | chr22 | vs rel |
|---|---:|---:|---:|---:|
| rel (v0.10.0 source) | 547,019 B | -- | 742,177 B | -- |
| **orc-at** (loads only at chain indels) | 559,046 B | **+2.20%** | 762,539 B | **+2.74%** |
| orc-not (loads only where the chain has none) | 572,802 B | +4.71% | 770,766 B | +3.85% |
| no cue at all (docs/batch4.md) | 586,615 B | +7.24% | | |

| | prediction | outcome |
|---|---|---|
| I0 | rel reproduces 547,019 / 742,177 | **held**, to the byte |
| O1 | orc-at 0-0.3% smaller | **failed, inverted**: 2.20% / 2.74% LARGER |
| O2 | orc-not >= 3% larger | held: +4.71% (chr22 +3.85%) |

**By the rule: the false-load filter is closed.** A perfect filter does not gain; it
loses 2.2-2.7%.

**The rule's escape clause was aimed at the wrong run, and that is stated rather than
repaired.** It was meant to catch "false loads help". That is shown by orc-at coming out
larger. orc-not coming out smaller would have shown something else. So the finding is
reported as found, and no filter is built on it.

## What it means: "false" was false only relative to the wrong map

The loads that the chain does not explain earn 2.2-2.7%. The loads it does explain earn
3.9-4.7%. Together they are roughly the whole cue (7.24% on chr21). They are not false
alarms. The chain records only the ORTHOLOGOUS alignment, target position against the
same position in GRCh38. Most of the time the match model copies from somewhere else: an
Alu, an L1, another copy in the target itself. A slip against that copy is a real indel
between two repeat copies (paralogs), and no GRCh38/CHM13 alignment contains it.

**This corrects docs/balance-loads.md.** "The cue correcting its own false loads" was too
strong. What stands: 93-95% of loads are not at an ORTHOLOGOUS indel, and those alternate.
Whether that alternation is the search overshooting or real paralog geometry is open
again. Resolving it would need the source each load copies from, which a -DDNAC_CUEPROF
build could log.
