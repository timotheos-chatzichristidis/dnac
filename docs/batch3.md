# Batch 3: the sweep and the add-back — result

**Run 2026-09-13/14.** Pre-registered in `docs/batch3-prediction.md` (commit
`5700d4e`) before the first run: the grid, the staging rule, P1–P14 and the
decision rules D1–D4. Every size below comes from a file that was decoded and
`cmp`-ed first (`sh scripts/cue/batch3.sh`), at k=22, in the mode and level its
row names. The baseline the session opened on was green: 203/203 round-trips,
`verify-claims.ps1 -Tier fast` 21/21.

## What was adopted, in one line

**`CUE_MINLEN` 16 → 4, and nothing else.** It is −0.898% on the real human pair
at level 1 in reference mode, −0.839% on the held-out chromosome, a gain in
plain mode at both levels, and it costs **+0.1% time**. **No add-back survived**:
not one part of level 3 earns its time back on top of level 1 + cue.

## 1. The screen (E. coli, level 1, reference mode)

Cost per event in bits ((target − zero-event control) × 8 / 2000, mean of three
seeds) and two whole files. The centre is `cue`, the parameters every published
figure on this branch was measured with.

| build | subst. | random indel | slip | `ecoli_ind` | `o157` |
|---|---:|---:|---:|---:|---:|
| v0.8.0 | 14.75 | 48.85 | 31.97 | +2.51% | +0.13% |
| **`cue` (centre)** | **14.65** | **31.99** | **14.70** | — | — |
| `cue_L2` | 14.79 | 29.95 | 14.23 | +0.55% | +0.03% |
| `cue_L4` | 14.71 | 35.46 | 14.48 | +0.10% | −0.01% |
| `cue_D6` | 14.70 | 31.08 | 14.62 | +1.16% | +0.01% |
| `cue_D20` | 14.71 | 32.66 | 14.75 | +0.06% | +0.00% |
| `cue_S8` | 14.71 | 30.63 | 13.28 | **−1.99%** | −0.11% |
| `cue_S16` | 14.70 | 31.86 | 13.35 | +1.07% | +0.06% |
| `cue_M8` | 14.74 | 30.43 | 14.61 | −0.44% | −0.05% |
| `cue_M24` | 14.70 | 35.74 | 14.88 | +0.40% | +0.03% |
| `noroom` | 14.69 | 31.13 | 13.74 | −0.14% | −0.01% |
| `mf` | 14.68 | 28.83 | 11.56 | −0.93% | −0.01% |
| `mf_noroom` | 14.70 | **28.31** | **10.80** | −1.04% | −0.01% |

Substitutions move by at most 0.14 bits in any corner of the grid, which is the
property the cue was built to have: it only speaks when the master has lost the
beat. `o157`, the diverged pair, moves by at most 0.11% anywhere — the negative
control holds under every setting.

**P2 and P5 failed here, in the same way.** Both predicted a parameter would be
inert on single-base events, and both are wrong: `CUE_MINLEN` moves the indel
cost by 18% across {8, 16, 24} and `CUE_D` by 5% across {6, 12, 20}. The
mechanism explains it after the fact — `CUE_D` decides how far the search looks
before it gives up, so a wider window buys more *wrong* candidates once the true
shift's backward agreement is not there yet — but the prediction was that
neither would matter, and it was made for a stated reason that turned out not to
govern.

**P7 held.** `mf_noroom` is the cheapest per event, as it was at level 3, and
by a wider margin than there (28.31 against 31.99 bits).

## 2. The screen does not predict the human pair

| build | E. coli indel bits | `ecoli_ind` | CHM13 chr21 | `chr21_ind` |
|---|---:|---:|---:|---:|
| `cue_S8` | 30.63 (−4.3%) | **−1.99%** | −0.057% | −0.200% |
| `mf_noroom` | **28.31 (−11.5%)** | −1.04% | −0.070% | −0.069% |
| `mf` | 28.83 (−9.9%) | −0.93% | −0.077% | −0.195% |
| `cue_L2` | 29.95 (−6.4%) | +0.55% | **+0.264%** | +0.377% |
| `cue_D6` | 31.08 (−2.8%) | +1.16% | **+0.375%** | +3.341% |
| `cue_M8` | 30.43 (−4.9%) | −0.44% | **−0.586%** | −1.732% |

**The ranking on the controlled targets is not the ranking on real sequence.**
`cue_S8` is the clear winner of the screen and a tie on the real pair.
`cue_L2` and `cue_D6` are cheaper per event and *worse* on both human files.
`cue_M8` is fourth on the screen and first where it counts.

This is a fact about the instrument, and it cost the registration a rule. The
staging rule fixed in advance — Stage B gets the builds within 2% of the best
indel cost — selects `mf_noroom` and `mf` **only**, and would have thrown away
the one parameter that matters. **Deviation, disclosed:** Stage B was widened to
the better direction of every axis (`cue_L2`, `cue_D6`, `cue_S8`, `cue_M8`) plus
both corners. It cannot flatter the centre: D1 was not touched, and a widened
candidate set can only make the centre easier to beat.

The lesson for the next batch is the one `docs/model-ablation.md` already
records in another form: **a per-event readout on synthetic events measures the
mechanism, not the deliverable.** Nothing gets adopted on it again.

## 3. The winner: `CUE_MINLEN`, and how far down it goes

`CUE_MINLEN` is how established a match must have been for its miss to load the
cue at all. 16 was registered before the mechanism existed. The screen said 8
beat 16 and 24 was worse, so the winning direction was extended past the grid —
**post-hoc, and marked as such**:

| `CUE_MINLEN` | CHM13 chr21 | vs centre | `chr21_ind` | vs centre |
|---:|---:|---:|---:|---:|
| 24 | — | — | — | (E. coli only: +0.40%) |
| **16 (centre)** | **568,133** | — | **104,784** | — |
| 8 | 564,805 | −0.586% | 102,969 | −1.732% |
| **4** | **563,031** | **−0.898%** | 101,517 | −3.118% |
| 2 | 563,188 | −0.870% | **99,594** | **−4.953%** |

**4 is the choice.** It is the best of the five on the real pair; 2 is 157 bytes
behind there and clearly ahead on the simulated individual, whose indels are
dense single-base events. The real pair is the regime the release claims, and
`chr21_ind` is a `dnac mut` file — so the tuning evidence picks 4, and 2's edge
on the simulated file is recorded rather than acted on. 2 was **not** run on
chr22: choosing between two candidates on the held-out set is exactly what D3
forbids.

Per event on the controlled targets, the post-hoc values behave like the rest of
the axis, and the property the cue was built to have survives at the bottom of
it — **substitutions do not get more expensive**:

| build | subst. | random indel | slip | `ecoli_ind` | `o157` |
|---|---:|---:|---:|---:|---:|
| `cue` (centre, MINLEN 16) | 14.65 | 31.99 | 14.70 | — | — |
| `cue_M4` | **14.58** | 30.02 | 14.46 | −0.78% | −0.06% |
| `cue_M2` | 14.68 | 29.87 | 14.42 | −1.89% | −0.07% |

Why it works is the same story the cue is: the cue costs almost nothing when it
is wrong, because it only speaks through the mixer. `CUE_MINLEN` was a guard
against loading it after a match that had not earned anything — and the guard
was priced as if a wrong cue were expensive. It is not. Lowering it four-fold
buys more chances to be right at +0.1% time.

## 4. Confirmation on the held-out chromosome

CHM13 chr22 against GRCh38 chr22, level 1, reference mode — used once, for the
candidate Stage B proposed, and for nothing else.

| | CHM13 chr21 | CHM13 chr22 |
|---|---:|---:|
| v0.8.0 level 1 | 602,170 | 813,961 |
| `cue` (centre) | 568,133 (−5.65%) | 768,104 (−5.63%) |
| `cue_M8` | −0.586% vs centre | −0.579% vs centre |
| **`cue_M4`** | **−0.898% vs centre** | **−0.839% vs centre** |

**D1 is satisfied with room to spare**: ≥ 0.20% on chr21 (0.898%), a *gain* not
a cost in plain mode (below), and chr22 reproducing the effect to within 0.06
percentage points — for both grid points, in the right order. Against v0.8.0's
level 1 the adopted build is −6.50% on chr21 and −6.43% on chr22.

## 4b. The negative control, and a correction for Batch 4

Pass 2 of the routine lists a negative control: *target = reference must leave
the cue silent*. Measured (E. coli against itself, level 1, everything
round-tripped):

| build | bytes |
|---|---:|
| v0.8.0 | 1,456 |
| `cue` | 1,454 |
| `cue_M4` | **1,446** |

**The expectation is wrong as written.** The cue is not silent on an identical
copy: the archives are not byte-identical, and the cue makes the file 0.7%
smaller. The reason is that a master match still misses occasionally even when
the two files are the same — a bucket holds one position, so the anchor can be
pointing at an earlier self-similar place — and every miss after an established
match is an invitation the cue accepts, four times more often at `CUE_MINLEN=4`.

So the invariant Batch 4 should test is **"costs nothing and stays lossless"**,
not "produces the same bytes". A round-trip case asserting byte-identity there
would fail for a legitimate reason, which is exactly the kind of check that gets
disabled instead of understood.

## 5. Plain mode: the winner is a gain where the mechanism is quiet

D1's second gate. Percentages are against the same level's build.

| level | build | E. coli | chr21 |
|---:|---|---:|---:|
| 3 | v0.8.0 | 1,092,692 | 7,506,264 |
| 3 | `cue` | −0.0079% | −0.0450% |
| 3 | **`cue_M4`** | −0.0052% | **−0.1056%** |
| 3 | `cue_M8` | −0.0081% | −0.0745% |
| 1 | v0.8.0 | 1,093,749 | 7,549,315 |
| 1 | `cue` | +0.0144% | −0.0408% |
| 1 | **`cue_M4`** | +0.0096% | **−0.1131%** |

Reference-free, `CUE_MINLEN=4` **more than doubles the cue's gain** at level 3
on chr21 (0.045% → 0.106%) and shrinks the small E. coli loss at level 1. The
one place it costs anything is E. coli at level 3: 29 bytes, 0.0027%, against
the centre — and still a gain against v0.8.0. The gate asked for ≤ 0.05% cost;
the answer is a gain on the dataset the headline lives on.

It does not change Batch 2's decision. Level 1 + cue at `CUE_MINLEN=4` is still
+0.460% against level 3 reference-free on chr21 (the centre was +0.532%), so
**the default stays per mode**: level 3 without a reference, level 1 with one.

## 6. The add-back: nothing earns its time

Paired encode timings of CHM13 chr21 at level 1 with a FASTA reference (priming
inside the time, as in `docs/speed.md`), labels alternating inside each of three
rounds, minimum quoted. v0.8.0 level 3 was timed in the **same** rounds, because
a ratio across two invocations is not a ratio on a machine with 24% noise.

| build | time | size | size vs centre | time vs centre | D2 |
|---|---:|---:|---:|---:|---|
| v0.8.0 level 3 | 202.07 s | 586,615 | — | — | — |
| **`cue` level 1 (centre)** | **95.26 s** | 568,133 | — | — | — |
| `cue_M4` | 95.39 s | 563,031 | **−0.898%** | **+0.1%** | adopted (a parameter, not an add-back) |
| `cue_ir` (other-strand training) | 108.51 s | 564,985 | −0.554% | +13.9% | **no** |
| `cue_ord` (master order set) | 110.34 s | 565,530 | −0.458% | +15.8% | **no** |
| `cue_x4` (four mixer experts) | 115.32 s | 565,162 | −0.523% | +21.1% | **no** |
| `cue_stcm` (tolerant models) | 122.87 s | 561,172 | −1.225% | +29.0% | **no** |

D2 asked for ≥ 1.0% at ≤ 20% time, or ≥ 0.5% at ≤ 10%. The tolerant models are
the only part that clears a whole point, and they cost 29%. Nothing else clears
half a point for its price. **The answer to the add-back question is no across
the board: with the cue in place, level 1 is the right set of models, and the
parts level 3 adds are worth less than the time they take.**

Two sizes in that table are the same bytes as `docs/speed.md` published on
2026-09-10 from a scratch directory: v0.8.0 level 3 **586,615 B** and cue level
1 **568,133 B**. They now come from the repository, by recipe.

The speed ratio, measured paired, is **2.12x** (202.07 / 95.39), not the 2.4x in
`docs/speed.md` — that figure came from two single runs in different minutes.
Both are above the 2x the decision rule required. No timing figure gets a claim
row (24% noise), but Batch 5 should quote the paired number.

## 7. P13: the mixer-context hypothesis is retired

Batch 2 found the cue's gain *shrinks* at level 1 reference-free, the opposite of
what it does with a reference, and left a hypothesis: level 1 has two mixer
experts against level 3's four, so the weight deciding how far to trust the cue
is learned on a coarser context. The test is a level-1 build with four experts,
with its own no-cue control.

| plain, level 1 | the cue's gain, 2 experts | the cue's gain, 4 experts |
|---|---:|---:|
| chr21 | −0.0408% | −0.0404% |
| E. coli | **+0.0144%** (a loss) | **−0.0048%** (a gain) |

**Falsified on chr21, where the shrinkage was measured.** Four experts leave the
cue's gain unchanged to four decimal places. They do flip E. coli's small loss
into a small gain, so the hypothesis survives only on the one dataset where the
cue was a loss at level 1 — it does not explain the shrinkage it was invented
for. The second half of P13 held: four experts close 0.024 of the 0.532
percentage-point gap to level 3 reference-free, well under half.

Incidentally, four experts alone (no cue) gain 0.025% on chr21 plain at level 1
— a real but tiny effect, for +21% time.

## 8. Scoreline

| | prediction | outcome |
|---|---|---|
| **P1** | `cue_L2` better by 0–6%, `cue_L4` worse by 0–10% (indel bits) | **direction held, both bands exceeded**: −6.4% and +10.8%. And on human sequence `cue_L2` is *worse*, which the prediction did not consider |
| **P2** | `CUE_D` inert on the controlled targets (< 3%) | **failed**: 5.1% spread, and `cue_D6` is the worst build of all on `chr21_ind` (+3.34%) |
| **P3** | `cue_D20` within [−0.30%, +0.10%] on CHM13 chr21 | **not measured**: `cue_D20` lost the screen and the staging rule kept it out of Stage B. Recorded as unanswered, not as held |
| **P4** | `cue_S8` better by 0–8%, `cue_S16` worse by 0–8% | **half held**: `cue_S8` −4.3% as predicted; `cue_S16` is −0.4%, a tie, not a loss. On `ecoli_ind` the ordering is as predicted (−1.99% / +1.07%) |
| **P5** | `CUE_MINLEN` within 3% on the controlled targets; `cue_M8` the better side on CHM13 by 0–0.5% | **failed on the first half** (18% spread), **held and then exceeded on the second** (−0.586%, and −0.898% at 4) |
| **P6** | the whole sweep finds < 1.0% on CHM13 chr21 | **held, at the edge**: 0.898% for the adopted point, 0.870% for `CUE_MINLEN=2` |
| **P7** | `mf_noroom` cheapest per event; all four corners within 0.30% on CHM13 chr21 | **held**: cheapest per event (28.31 bits), and the four corners span 0.077% on the real pair — `cue` 568,133, `mf` −0.077%, `mf_noroom` −0.070%, `noroom` −0.007% |
| **P8** | four experts ≥ 0.20% for ≤ 10% time | **failed on time**: −0.523% for **+21.1%** |
| **P9** | other-strand 0.10–0.50% for +10–20% time | **time held** (+13.9%), **size just over the band** (−0.554%) |
| **P10** | tolerant models ≥ 0.50% for +20–35% time | **held on both**: −1.225% for +29.0% |
| **P11** | master orders ≥ 0.50% for +30–50% time | **failed on both, in the good direction on time**: −0.458% for +15.8% |
| **P12** | ranking `stcm` ≥ `ord` > `x4` > `ir`; none over 1.45% | **ranking failed** (`stcm` > `ir` > `x4` > `ord`), **the cap held** (1.225%) |
| **P13** | the cue's gain is larger with four experts, reference-free at level 1 | **failed on chr21** (unchanged), **held on E. coli** (a loss becomes a gain). The hypothesis is retired |
| **P14** | every build round-trips 203/203, every size `cmp`-ed | **held**: 203/203 on ten builds (`cue_M8`, `cue_M4`, `cue_M2`, `cue_x4`, `cue_ir`, `cue_stcm`, `cue_ord`, `base_x4`, `cue_S8`, `mf_noroom`), and every size in this document was compared before it was recorded |

Five held, four failed, three part-held, one unanswered. The two clean failures
that matter are P2 and P5 — both said "this parameter is inert" — and they are
why the batch found anything at all.

## 9. What this batch changes, and what Batch 4 inherits

**Adopted:** `CUE_MINLEN` 16 → 4.
**Rejected:** every add-back (D2), and every other parameter move (D1/D4 — ties
go to the centre, and `CUE_L`, `CUE_D`, `CUE_SWITCH` all either tie or lose on
real sequence).
**Retired:** the mixer-context hypothesis for Batch 2's P5.
**Unchanged:** the default is still per mode, `CUE_ROOM=1`, `CUE_MIXFREE=0`.

The consequence Batch 4 has to plan around: **every published figure on this
branch was measured at `CUE_MINLEN=16`.** `docs/cue.md`, `docs/real-human.md`,
`docs/remaining.md`, `docs/speed.md` and `docs/competitors.md` are the record of
the centre and stay as they are, but the moment the default moves to 4, the
claims a v0.9.0 README makes have to be re-measured at 4 — the per-event costs,
the −5.97% / −18.27% window splits, the chr22 replication and the competitor
table. `verify-claims.ps1` will go red on them if the default changes without
that re-measurement, which is the registry working as designed. **The default
flip and the re-measurement are one change, or the release ships a stale
number.**

One more thing Batch 4 inherits, from §4b: the negative control in the plan is
phrased as "target = reference must leave the cue silent", and that is not what
happens. Test that it costs nothing, not that it produces identical bytes.

An instrument note, in the same family as the eight wrong figures this project
has found: the round-trip loop in the first run of this batch was written as
`roundtrip.sh ... | tail -1` under `set -e`. The pipe discards the script's exit
status, so a suite that had failed would have looked exactly like one that
passed — ten blank lines and no error. It printed nothing, which is what caught
it. **A check behind a pipe is not a check.**
