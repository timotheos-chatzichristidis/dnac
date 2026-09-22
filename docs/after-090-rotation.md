# M2, rotation: either deck may call for the cue — result

**Run 2026-09-19**, on branch `after-0.9.0`, immediately after M1
(`docs/after-090-riding.md`). Pre-registered in `docs/riding-prediction.md`
(commit `4d86862`).

The change is one token. v0.9.0 loads a cue only when the **13-base** forward
match loses an established run (`mi == 0` guards the load), so of the two decks
permanently playing to the room, one is watched and the other is only ever
rescued. `CUE_ROTATE=1` lets **either** forward match call for a cue — in
Timotheos's terms, whichever deck is ending is the one replaced while the other
carries. `CUE_ROTATE=0` is the release value and compiles to exactly v0.9.0's
expression.

`LABELS="rel rot" sh scripts/cue/after090-ride.sh`. Every archive was decoded
and `cmp`-ed before its size was recorded. Level 3 throughout.

## The instrument, again

`rel` reproduced `docs/batch4.md`'s release figures to the byte a second time in
this session — O157 362,006 B, chr21 547,019 B, chr22 742,177 B, and 14.75 /
26.90 / 11.60 bits per event. `CUE_ROTATE=0` is byte-identical to `HEAD` in
plain and reference mode, and the rotation build passes **229/229** adversarial
round-trips.

## The result

| | release | rotation | change |
|---|---:|---:|---:|
| substitution | 14.75 | 14.74 | −0.01 bits |
| random indel | 26.90 | 26.91 | +0.01 bits |
| homopolymer slip | 11.60 | 11.62 | +0.02 bits |
| **CHM13 chr21** | 547,019 B | **545,568 B** | **−0.2653%** |
| **CHM13 chr22** (held out) | 742,177 B | **740,525 B** | **−0.2226%** |
| O157:H7 (diverged) | 362,006 B | 361,976 B | −0.008% |
| `ecoli_ind` | 12,051 B | 12,015 B | −0.299% |
| encode, chr21 (min of 3) | 183.41 s | 184.26 s | +0.46% |

| | prediction | outcome |
|---|---|---|
| **M2a** | chr21 between 0.0% and −0.3% | **held** — −0.2653% |
| **M2b** | O157 within ±0.05% | **held** — −0.008% |
| **M2c** | M1 and M2 not additive | **not run** — see below |

**M2c was dropped, and this says so rather than omitting it.** It asks whether
riding and rotation overlap. Riding was rejected in the measurement immediately
before this one, so the combination cannot change any decision; the cost was
about six minutes and the reason for skipping it is economy, not a result.
Anyone who revisits riding must run it.

## The screen said nothing and the real pair gained

The controlled E. coli targets move by a hundredth of a bit in every class —
substitution, indel and slip alike. On that screen rotation **does nothing, to
two decimal places**. On two real human pairs it is worth a quarter of a percent,
and it replicates on a held-out chromosome.

That is `docs/batch3.md`'s instrument finding in its cleanest form yet: **the
per-event E. coli screen does not predict the human pair.** The reason is
visible in the mechanism. Each screened target carries single injected events
against an otherwise identical reference, so the 16-base anchor almost never has
an established run to lose; on real sequence between two people it does, often,
and those are precisely the misses rotation exists to catch. A staged design
that screened on E. coli first would have discarded this change without ever
measuring it — for the second time on this branch.

## D-M: three conditions pass and the first one fails

| condition | requirement | measured | verdict |
|---|---|---:|---|
| 1 | gain ≥ 0.3% on the real human pair | **0.2653%** | **fails** |
| 2 | substitution moves ≤ 0.25 bits | 0.01 | passes |
| 3 | time cost ≤ 10% | +0.46% | passes |
| 4 | replicates on chr22, same sign, ≥ half the magnitude | **83.9%** | passes |

**By the rule fixed before any of this was built, rotation is not adopted.**

## The rule could not have said yes, and that was written down first

D-M was written once, for both mechanisms. **M2's own registered prediction was
0.0 to −0.3%** — a band whose best case only just touches a bar of 0.3%. So the
rule and the prediction, written in the same document on the same day,
**disagreed about what success would look like before a line of code existed.**

This is not a complaint constructed after seeing 0.2653%. It is in
`docs/after-090-riding.md`, committed before rotation was built: *"its predicted
effect was 0.0 to −0.3% on chr21, which is the same size as what riding just
failed to clear — so it is registered against the same bar and should be
expected to have the same trouble."*

So there are two defensible readings and this document resolves neither:

- **the rule as written** — 0.2653% is less than 0.3%, rotation is not adopted,
  and the fact that its prediction was pessimistic is not the rule's problem;
- **the rule as constructed** — a bar that a mechanism's own pre-registered band
  cannot reach is not a test of that mechanism, and applying it produces a
  foregone conclusion rather than a measurement.

**Which reading holds is Timotheos's decision, not a measurement**, and it is
put to him as what it is. What can be said without deciding it: of the three
mechanisms measured after v0.9.0, rotation is the only one that gains on every
file measured, costs nothing anywhere, holds both of its registered predictions,
replicates at 84% on a chromosome nothing was tuned on, and changes one token.

## The pattern this branch now has

| mechanism | best figure | bar | verdict |
|---|---:|---:|---|
| four mixer experts at level 1 | 1.6957x | 1.70x | fails by 0.25% |
| riding (`RIDE_L=8`, post-hoc) | 0.2532% | 0.30% | fails by 0.047 pp, and replicates at 45.7% |
| **rotation** | **0.2653%** | 0.30% | **fails by 0.035 pp, replicates at 83.9%** |

Three mechanisms, three deaths inside a whisker of a pre-registered threshold.
Two readings of that, and again this document picks neither: either the bars are
where they should be and **this codec has run out of quarter-percent levers that
are worth format changes**, or the bars were set by a hand that expected larger
gains than v0.9.0's remaining headroom allows. **That argument belongs before the
next measurement, not after this one** — and moving a bar onto a number already
seen is the one move that is ruled out either way.

## What is left

Nothing pre-registered. The jog (the nudge), the headphones (the cue) and the
pitch fader (directional search, and riding) are all measured and written up; the
three-deck rotation is measured here. The cue is the one that shipped, and it
carried v0.9.0 by itself.

**One unregistered mechanism was named after this was written**, when Timotheos
corrected the account of his own practice (`docs/origin.md`, 2026-09-19). The
cue button is not permanent — it is opened on exactly one deck, closed as that
deck's fader goes up, and then **opened straight away on the deck that is now
leaving**. dnac does the first two: one cue at a time, closed the instant a
master takes its phase. It does not do the third. It waits for the leaving deck
to miss.

What was measured here is the weaker, reactive version of that: either master
may *call* for a cue **when it misses**. The proactive version — re-open the cue
on the other master the moment the mix completes, before it has missed anything
— is a different mechanism and is **unbuilt**. Whether it is worth building
against a bar that three mechanisms have now failed by a whisker is the same
open question as the rest of this document.

## Correction, 2026-09-22: the proactive version was built, and it failed

The paragraph above is wrong. Re-opening the cue on the leaving deck the moment
the mix completes is `CUE_BACK`, measured on 2026-09-10 against the single-deck
cue (`docs/cue-back.md`): **−0.01%** on the real pair's whole file (551,539 B
against 551,594), an extra **0.1%** on its shared windows, and prediction B3
failed. It was removed from `dnac.c` in v0.9.0 and re-derives from `4932ffe`.

It was measured with `CUE_MINLEN = 16` and without rotation, so it has not been
run under v0.9.0's parameters. Running it there would be re-tuning a measured
mechanism, not testing a new one, and the rule on this branch is that a tuning
idea does not re-open a closed question. The bar agreed on 2026-09-22 before
this was found asked for **≥ 0.10%** from the proactive half alone, over the
rotation build; the one measurement that exists is a tenth of that.

**So nothing unbuilt is left on this branch, and the decision agreed for that
case applies: dnac closes at v0.9.0.** Rotation is not adopted on its own, since
it missed its bar. This branch stays public and unmerged as the record of four
post-release mechanisms measured against bars fixed before they ran.
