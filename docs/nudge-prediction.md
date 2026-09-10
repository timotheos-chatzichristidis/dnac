# The nudge: pre-registered prediction

**Written 2026-09-10, before one line of the nudge was coded.** Committed on its
own so the git timestamp shows the prediction came before the data. The result
goes in `docs/nudge.md`. This file is never edited after that, only linked.

## Where the idea came from

Timotheos, from a DJ beatmatching diagram (`Desktop\how-to-mix.png`). When the
second deck slips a beat, a DJ does not keep playing and hope, and does not lift
the needle and drop it somewhere else. The DJ **nudges**: pushes the platter one
beat forward or back and listens for whether it has locked.

`bitshape/docs/exp-005` used the diagram only as a way of *reading* the map, and
wrote it off as a way of *changing* anything: "the controller is dnac's, and dnac
is closed". This file takes it as a lever.

## What dnac does today when the target slips

`match_after()` (`dnac.c:676`). On a miss the match model assumes a
**substitution**: it advances one position, halves its confidence and carries on
at the same phase. After an insertion or deletion that phase is wrong, so almost
every following base misses. Confidence collapses, and the model re-anchors
through the hash, which needs about 13 clean bases after the event. `CLAUDE.md`
records it as a known limit: "reference mode handles indels only through match
tolerance, not alignment."

Prior art, checked 2026-09-10 before writing this: GeCo's STCM tolerates
substitutions only. JARVIS3's repeat models stop when performance drops and
restart from a hash hit, with no realignment. No compressor in this
context-mixing family was found to nudge phase. Alignment-style reference
compressors (GDC2, iDoComp and similar) do handle indels natively, as edit
operations. So **handling indels is not new. Nudging a context-mixing match model
is, as far as this search went.**

## The change (compile-time `-DDNAC_NUDGE`, default build byte-identical)

On a miss, after the usual substitution step, a forward match model that was in
an established match (confidence ≥ 16 at the first miss) tries shifting its
pointer by δ = −1, +1, −2, +2, … ±`NUDGE_D`. It takes the first δ for which the
last `NUDGE_L` coded bases agree exactly with the reference at the shifted phase.
Confidence goes back to half its pre-miss value. It uses only bases both sides
already know, so encoder and decoder stay in lockstep.

**Parameters fixed now: `NUDGE_L = 5`, `NUDGE_D = 12`.** A sweep of other values
may be reported afterwards, labelled as a sweep. The headline stays these two.

## Premises (measured on the unmodified build before writing this)

E. coli MG1655 as reference (`ref.state`). Targets built by
`bitshape/scripts/make_tumour.py` with exactly 2,000 events, 3 seeds each. Cost
per event = (target − zero-event control) × 8 / 2000.

| premise | value | command that produced it |
|---|---|---|
| zero-event control | 41,139 B | `measure.sh dnac_base.exe base` |
| substitution | **14.64 bits** (14.71 / 14.60 / 14.62) | same |
| random single-base indel | **48.25 bits** (48.16 / 48.03 / 48.56) | same |
| homopolymer slip | **31.43 bits** (31.42 / 31.52 / 31.34) | same |
| W3110 vs MG1655 (real, FASTA) | 1,931 B | `measure_real.sh dnac_base.exe base` |
| O157:H7 vs MG1655 (real, diverged) | 362,666 B | same |
| `ecoli_ind` (dnac `mut`: SNPs + 1–10 b indels at 1/10) | 12,580 B | same |
| `chr21_ind` vs chr21 (same simulator) | 113,925 B | same |

## Predictions

**P1, the one that matters.** A random single-base indel falls from 48.25 bits
to **≤ 25 bits** (mean of 3 seeds). *Confidence 55%.*

**P2, no harm.** Substitution cost stays within ±3% of 14.64, in **[14.20, 15.08]**.
A false nudge after a substitution would show here. *Confidence 75%.*

**P3.** A homopolymer slip falls from 31.43 to **≤ 22 bits**. Inside a run the old
phase keeps matching, so there is less to save than in P1. *Confidence 50%.*

**P4.** Every file round-trips byte-identically. The zero-event control moves by
less than 0.1%.

**P5, the realistic pairs.** `chr21_ind` and `ecoli_ind` are **≥ 5% smaller**.
*Confidence 50%.* O157 gains at least 0.3% (*confidence 40%*). W3110 is not worse
by more than 1%.

## When to stop

If P1 lands at **40 bits or more** (under 17% of the gap closed), the nudge as
designed does not work. That is reported as a negative result and the idea gets
one parameter sweep, not a redesign.

## Honest scope

This measures whether the nudge makes dnac's match model better. It does **not**
claim dnac is the best way to store a personal genome. A variant list (VCF) or an
alignment-style reference compressor is the trivial competitor for that, and it
has not been run here.
