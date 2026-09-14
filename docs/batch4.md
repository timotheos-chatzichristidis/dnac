# Batch 4: integration and format — result

**Run 2026-09-14.** Pre-registered in `docs/batch4-prediction.md` (commit
`30d9fb9`) before the first run: the design F1–F8, P0–P10, R1–R7 and the
decision rules D1–D4. The session opened green on `4932ffe`: 203/203
round-trips, `verify-claims.ps1 -Tier fast` 21/21.

## What changed, in one paragraph

The cue is compiled into every build and switched at run time, and the switch
travels in the fourth letter of the magic: v0.8.0's `DNCC`/`DNCU`/`DNCP` still
mean "no cue" and still decode, `DNCE`/`DNCV`/`DNCQ` are the same streams with
the cue, and lower case marks an **experimental build** — one that moved a cue
parameter or an `L1_*` knob — which release builds refuse, and which refuses
them. Nothing after the letter moved, so no byte count did. `CUE_MINLEN` is 4.
`dnac cr` and `dnac prime` default to level 1; `dnac c` stays at 3. State files
record the cue (`DNACST02` without, `DNACST03` with). `-DDNAC_CUE`, the nudge and
the alternating deck are gone from `dnac.c`, and every record measured with them
re-derives from `4932ffe`'s source instead.

## P0: the hazard was real

`4932ffe`, `-DDNAC_CUE`, `ecoli_ind` against E. coli at level 1, decoded by the
unflagged build of the same source: **the decoder exits 0 and writes wrong
bytes.** Before this batch, a cue archive and a v0.8.0 archive carried the same
magic, so nothing in the file could stop the wrong decoder, and it did not stop.
Nobody would have met it on this branch — the cue never shipped — but it is the
exact shape of the v0.3.0 geometry bug, and it would have shipped with a v0.9.0
that only flipped a compile flag. **P0 held.**

## P1: the run-time cue is the compiled cue

The working tree built with `-DCUE_MINLEN=16` against `4932ffe -DDNAC_CUE`, and the
working tree unflagged against `4932ffe -DDNAC_CUE -DCUE_MINLEN=4`, on five cases
(`ecoli_ind` in reference mode at levels 1 and 3, `ecoli.seq` plain at levels 1
and 3, and plain `-j 4`): **all ten pairs identical but the magic**, and in every
pair the fourth byte really is the two different letters, so the comparison is
not vacuous. **P1 held.** The conversion from `#ifdef` to a run-time switch
changed no probability anywhere.

## P2: the cue switched off is v0.8.0

The working tree built with `-DCUE_DEFAULT=0 -DREF_LEVEL_DEFAULT=3` against the
v0.8.0 tag, on seven cases (reference mode at levels 1 and 3, plain at levels 1
to 4, plain `-j 4`): **all seven archives identical, byte for byte.** **P2
held.** This is what lets every README row keep defending v0.8.0's figures with
a build of the current source.

## P7: target = reference costs nothing

E. coli against itself at level 1: **v0.8.0 1,456 B, release 1,446 B**, both
round-tripped — the prediction to the byte, since the release is Batch 3's
`cue_M4` (P1). **P7 held.**

## P8: every family passes the extended suite

`scripts/roundtrip.sh` grew from 203 cases to 229: indel- and homopolymer-dense
pairs and target = reference at the default level and levels 1 and 3, state
against FASTA on the indel pair, the default levels read out of the header, a
stream and a state of the other family refused, and the seven stored v0.8.0
streams (decoded by a release build, refused by an experimental one, and refused
by a state primed with the cue). Each family asserts its own rules, so it runs
the same count. **229/229 on the release build, 229/229 on the cue switched off,
229/229 on an experimental build (`-DCUE_MINLEN=16`).** `adversarial.ps1` on the
release build: 155/155. **P8 held.**

A first run gave the experimental build 227 and the others 228: the state-family
case only existed for release builds. A check that only one family can fail is
half a check, so both families got a case of their own (a flipped state marker,
and an experimental state against a v0.8.0 stream) before the counts were
recorded.

## P4, P5, P6: old files, other families, old states

**P4 held.** The seven stored v0.8.0 streams in `tests/v080/` — plain at levels 1
to 4, three blocks, reference mode at levels 1 and 3, written once by the v0.8.0
tag and committed — decode byte for byte with the release build. That is part of
P8's 229, so it runs in CI on every build.

**P5 held: all six refusals.** The v0.8.0 decoder refuses the release's plain,
block and reference streams (it cannot know the new letters, and says "not a
dnac file"); the release decoder refuses an experimental build's reference and
plain streams; an experimental decoder refuses a release reference stream. Every
refusal is a non-zero exit **and no output file**.

**P6 held, both halves.** A state primed by v0.8.0 itself (`DNACST02`) decodes a
v0.8.0 reference stream with the release build, byte for byte, and the same
state is refused against a release cue stream. So a user's existing primed
states keep working for their existing archives, and cannot silently be used to
decode new ones.

The last three are `scripts/cue/batch4.sh p5 p6`, on generated inputs, in
seconds.

## P3: the release is Batch 3's `cue_M4`, to the byte

CHM13 chr21 against GRCh38 chr21 at level 1, the release build: **563,031 B**,
round-tripped — exactly the figure `docs/batch3.md` measured for `cue_M4`. **P3
held.** It follows from P1, and it is still worth a row: it is the one release
size the whole of Batch 3's decision rested on.

## The release figures (`scripts/cue/batch4-release.sh`)

`rel` is the release build, `v08` the same source with the cue off (the v0.8.0
tag's bytes, P2). Every archive round-tripped before its size was recorded.

### R1: per event, on the ten controlled targets

Bits per event, (target − control) × 8 / 2000, mean of three seeds, against a
primed MG1655:

| level | build | substitution | random indel | homopolymer slip |
|---:|---|---:|---:|---:|
| 3 | v0.8.0 | 14.64 | **48.25** | 31.43 |
| 3 | release | 14.75 | **26.90** | **11.60** |
| 1 | v0.8.0 | 14.75 | 48.85 | 31.97 |
| 1 | release | 14.58 | 30.02 | 14.46 |

**R1 held**: the random indel falls from 48.25 to **26.90 bits at level 3**
(the record: 28.75), and the substitution moves by +0.11 bits, inside ±0.25. At
level 1 the release reproduces Batch 3's `cue_M4` screen exactly (14.58 /
30.02 / 14.46).

The osmosis, from the same targets' maps (`halves.py`): at level 3 the slip costs
14.76 bits in the first half of a target and 8.44 in the second, **a fall of
43%** (ratio 0.571), against 9% without the cue (ratio 0.913). The record said
42% against 9%.

### R2, R3 and the pairs

| file | level | v0.8.0 | release | change | against v0.8.0 level 3 |
|---|---:|---:|---:|---:|---:|
| `chr21_ind` | 3 | 113,925 | 100,806 | **−11.52%** | −11.52% |
| `chr21_ind` | 1 | 114,124 | 101,517 | −11.05% | −10.89% |
| CHM13 chr21 | 3 | 586,615 | 547,019 | **−6.75%** | −6.75% |
| CHM13 chr21 | 1 | 602,170 | 563,031 | −6.50% | **−4.02%** |
| `ecoli_ind` | 3 | 12,580 | 12,051 | −4.21% | −4.21% |
| `ecoli_ind` | 1 | 12,609 | 12,204 | −3.21% | −2.99% |
| O157 | 3 | 362,666 | 362,006 | −0.18% | −0.18% |
| O157 | 1 | 363,532 | 362,862 | −0.18% | **+0.05%** |
| W3110 | 3 | 1,931 | 1,916 | −0.78% | −0.78% |
| W3110 | 1 | 2,130 | 2,121 | −0.42% | **+9.84%** |

**R2 held** (−11.52% at level 3, band −9.5% to −13%; the record −8.70%). **R3
held** (−6.75% at level 3, band −6.3% to −7.5%; the record −5.97%). The
level-1 CHM13 figure against v0.8.0's level 3 is the **−4.02%** R7 predicted
from P3.

**The loss this table shows, stated where it is.** The cue gains at both levels
on every file. But the reference-mode *default* is now level 1, and on the
near-identical bacterial pair that default is **+9.84% larger than v0.8.0's
default** (W3110: 2,121 B against 1,931 B), and +0.05% on the diverged O157.
Level 1 costs 10% there on its own, and a file of 2 kB has almost no indels for
the cue to win back. Batch 2 chose the per-mode default on human and metagenome
data, and Batch 3 confirmed it on the human pair; neither measured a pair this
close. It does not change this batch (D3: no parameter moves), but a default
that makes the tightest real bacterial pair 10% bigger is a claim Batch 5 has to
make out loud, or revisit.

### R4 and R5: where the gain comes from, on both chromosomes

Windows of 1 kb, classed **once** by what v0.8.0 at level 3 paid for them
(shared < 0.2 bits/base, diverged 0.2–1.0, novel ≥ 1.0), then summed for both
builds at the same level — the method of `docs/real-human.md`:

| chromosome | level | shared | diverged | novel | all windows | file |
|---|---:|---:|---:|---:|---:|---:|
| chr21 | 3 | **−19.36%** | −3.55% | **−0.26%** | −6.85% | −6.75% |
| chr21 | 1 | −18.46% | −3.60% | −0.34% | −6.60% | −6.50% |
| chr22 | 3 | **−16.90%** | −4.51% | **−0.23%** | −6.64% | **−6.57%** |
| chr22 | 1 | −16.32% | −4.54% | −0.29% | −6.50% | −6.43% |

The record, at `CUE_MINLEN=16` and level 3: chr21 −18.27% shared, −0.00% novel;
chr22 −16.24% shared, −0.01% novel.

**R4 and R5 held on the shared windows and on the files, and both failed on the
novel windows** — in the direction of a gain. The prediction was "within
±0.05%", because the record was exactly zero there; the release saves 0.23–0.34%
on sequence one of the two people does not have. The mechanism is the adopted
parameter itself: `CUE_MINLEN=4` lets the cue load after a match of four bases,
and short matches inside novel sequence are exactly the ones 16 used to ignore.
**So "exactly zero on sequence one person lacks" is a claim about the record, not
about the release.** What the release can claim is a small gain there, and never
a cost.

### R6: the competitor table, at the release settings

The competitors' bytes are the ones `docs/competitors.md` measured (their rows
live in the `extern` tier; nothing about them changed). The release, both
formats, both levels, every archive round-tripped:

| format | best competitor | record (`CUE_MINLEN=16`, level 3) | release, level 3 | release, level 1 |
|---|---|---:|---:|---:|
| FASTA | HRCM, 1,438,137 B | 551,594 B, 2.607x | **547,019 B, 2.629x** | **563,031 B, 2.554x** |
| plain ACGT | GeCo3 hybrid template, 877,373 B (unverified) | 545,982 B, 1.607x | **541,353 B, 1.621x** | **557,497 B, 1.574x** |
| plain ACGT | zstd `--patch-from`, 882,586 B (verified) | 1.617x | 1.630x | 1.583x |

**R6 half held.** The release is still the smallest of everything tried, in both
formats and at both levels. At level 3 it is further ahead than the record, as
predicted. At level 1 — the reference-mode default — it is **less** far ahead
than the record: 1.57x the best competitor on plain ACGT instead of 1.61x.
That is the same trade as everywhere else in this batch, seen from the other
side: level 1 is 2x faster and gives up about 3% of size to buy it, and the
cue's new parameter wins back only part of that. "1.6x ahead" stays true at
level 3 and becomes "1.57x" at the default.

## P9 and R7: time

Encode of CHM13 chr21 against the GRCh38 chr21 FASTA (priming inside the time),
three rounds, the three labels alternating inside each round, minimum quoted,
nothing else running on the machine (`scripts/cue/batch3-time.sh`, `OUT=batch4-time.tsv`):

| build | level | round 1 | round 2 | round 3 | minimum | bytes |
|---|---:|---:|---:|---:|---:|---:|
| `4932ffe -DDNAC_CUE -DCUE_MINLEN=4` (compiled cue) | 1 | 84.59 s | 78.68 s | 78.90 s | 78.68 s | 563,031 |
| release (run-time cue) | 1 | 78.78 s | 78.92 s | 78.37 s | **78.37 s** | 563,031 |
| v0.8.0 (the cue switched off) | 3 | 170.45 s | 181.25 s | 170.30 s | **170.30 s** | 586,615 |

**P9 held**: the run-time switch costs nothing measurable — −0.4% against the
compiled cue, well inside the < 3% band and inside this machine's noise.
**R7 held**: the reference-mode default is **2.17x faster than v0.8.0's default**
and 4.02% smaller. Batch 3 measured 2.12x for the same pair of settings in other
rounds; the two agree within noise, and **2.1x** is the figure a README can
carry. No timing gets a row: run-to-run noise here is 24%.

## P10: every record still re-derives

Every tier of the registry, run against this batch's working tree, one tier at a
time:

| tier | rows | result | what it defends |
|---|---:|---|---|
| `fast` | 21 | **21/21** | README (v0.8.0), through the `v08` build of the working tree |
| `cue` | 98 | **98/98** | the cue documents, compiled from `4932ffe` |
| `cue3` | 50 | **50/50** | `docs/batch3.md`, compiled from `4932ffe` |
| `slow` | 84 | **84/84** | README and the cue documents at chromosome scale |
| `extern` | 15 | **15/15** | GeCo3, HRCM, zstd |
| `meta` | 13 | **13/13** | the metagenome bake-off, and Batch 2's metagenome rows |
| `b4` | 33 | **33/33** | this document, after one fix (below) |

**P10 held**, 314 of 314 rows: no historical row changed value,
and none needed an edit beyond F6/F7's plumbing. The `extern` tier was killed
once for low memory — GeCo3 takes 9.2 GB and the machine was also in use — and
its eight unfinished rows were run again alone; nothing in it had gone red.

## Two instrument findings

**A second implementation caught a bug in the first.** The window splits were
computed twice: by `scripts/cue/batch4-release.sh` (awk over the maps) for this
document, and by the registry's `CueWindowSums` for its rows. The first full
`b4` run went red on exactly one row, chr21 shared at level 1: the document said
−18.46%, the registry −18.58%. The registry was wrong. Giving `CueWindowSums` a
level, I left its loop classing each window by the map *at that level* instead
of v0.8.0's level-3 map — the moving goalpost its own comment forbids. At level 3
the two maps are the same file, which is why every level-3 row was green and the
bug could only show at level 1. Fixed, and all 33 rows reproduce. Had the
document been written from the registry's number, both would have agreed and
been wrong together.

**A cache that was safe for records is not safe for the working tree.**
`CueState` and `CueMap` reuse a primed state or a `-map` file from disk when one
with the label's name exists. For the pinned labels that is correct: their source
never changes. For `rel`, `v08` and `exp` it is not — after any edit to `dnac.c`
the next run would measure a new binary against an old binary's state, silently.
It surfaced while setting up the red test for the new self-test detector, which
the cached cue-off state would have kept green. None of this batch's figures is
affected (`dnac.c` did not change after those files were written), and the
working-tree labels now rebuild their states and maps once per run.

**Every new detector was watched red.** The self-test gained one check: the
release build and the cue-off build must write different archives, and the
cue-off build must equal v0.8.0. A scratch copy of `verify-claims.ps1` in which
`v08` compiles without its flags (so it *is* the release build) stopped with
"the release build and the cue-off build wrote the same archive (41128 B)". The
pin needs no new detector: if a record's label ever compiled the working tree,
`base` and `cue` would be the same build and the existing flag check goes red. In
the suite, the family refusals are flipped letters and a flipped state marker,
so each is a case that *must* fail.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **P0** | a `-DDNAC_CUE` archive decoded by the unflagged build of `4932ffe`: exit 0, wrong bytes | **held** — the hazard was real |
| **P1** | the run-time cue writes the compiled cue's bytes but the magic, ten pairs | **held**, 10/10 |
| **P2** | the cue switched off writes the v0.8.0 tag's bytes, seven cases | **held**, 7/7 |
| **P3** | CHM13 chr21 at level 1: 563,031 B | **held**, to the byte |
| **P4** | stored v0.8.0 streams decode with the release build | **held**, 7/7 |
| **P5** | the families refuse each other, non-zero exit, nothing written | **held**, 6/6 |
| **P6** | a v0.8.0-primed state reads a v0.8.0 stream, refuses a cue stream | **held**, both |
| **P7** | E. coli against itself: 1,456 → 1,446 B | **held**, to the byte |
| **P8** | the release and the cue switched off pass the extended suite | **held**, 229/229 on all three families |
| **P9** | the run-time switch costs < 3% time | **held**: −0.4% |
| **P10** | every historical row passes unchanged | see below |
| **R1** | indel 26.0–28.75 bits at level 3; substitution within ±0.25 | **held**: 26.90; +0.11 |
| **R2** | `chr21_ind` −9.5% to −13% at level 3 | **held**: −11.52% |
| **R3** | CHM13 chr21 −6.3% to −7.5% at level 3 | **held**: −6.75% |
| **R4** | chr21 shared −18.5% to −21%, novel within ±0.05% | **shared held** (−19.36%), **novel failed** (−0.26%, a gain) |
| **R5** | chr22 file −6.1% to −7.3%, shared −16.5% to −19%, novel ±0.05% | **file and shared held** (−6.57%, −16.90%), **novel failed** (−0.23%, a gain) |
| **R6** | still smallest, and further ahead than the record at both levels | **half held**: smallest everywhere; further ahead at level 3 (1.62x), **less** at level 1 (1.57x) |
| **R7** | level 1 −4.02% against v0.8.0 level 3; ≥ 2.0x faster | **held**: −4.02%, 2.17x |

Sixteen held, two part-failed on the same sub-claim (novel windows, both in the
direction of a gain), one half held. Not predicted at all, and the finding that
matters most for the release: **the level-1 default loses 9.84% on W3110**.

## What this batch changes, and what Batch 5 inherits

**Changed:** the cue is a run-time feature recorded in the magic; `CUE_MINLEN`
is 4; `cr` and `prime` default to level 1; state files record the cue; the
nudge, the alternating deck and `-DDNAC_CUE` are gone; experimental builds mark
their files; the records re-derive from `4932ffe`'s source; `roundtrip.sh` is
229 cases with stored v0.8.0 streams; CI checks the cue switched off against the
v0.8.0 tag.

**Batch 5 inherits** (also in `docs/v0.9.0-plan.md`): the three record claims that
do not carry to the release (novel windows, 1.6x, "3% smaller"); the W3110 loss
under the level-1 default; two CI checks that have never run because nothing is
pushed (macOS arm64 decoding Windows-written v0.8.0 streams, and the families
step); and a README that still describes v0.8.0 on purpose.
