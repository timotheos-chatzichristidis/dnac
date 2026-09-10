# The cue: pre-registered prediction

**Written 2026-09-10, before one line of the cue was coded.** Committed alone
for the timestamp. The result goes in `docs/cue.md`.

## Where it comes from: how Timotheos actually mixes

The nudge (`docs/nudge.md`) jumps to a new phase the moment five bases agree,
and pays for the jumps that were wrong. The obvious fix was "listen on
headphones before switching". Timotheos's actual method is more specific:

> One ear **permanently** on the incoming track, the other ear **permanently**
> free, on the room. Never take the headphones off to mix, never put them on both
> ears. That way an "osmosis microclimate" between outside and inside builds up,
> and it helps more the longer it runs.

Translated into the match model, three rules:

1. **The room ear** is the master match model. It carries on exactly as in
   v0.8.0: no jumps.
2. **The headphone ear** is a second, permanently present deck, a *cue*, which
   follows a candidate shifted phase. Its prediction is **always** a mixer input.
   It is never switched in or out of the mix. When nothing is loaded it predicts
   nothing, as an idle match model does.
3. **Osmosis.** The cue's probability table is indexed by what the *room* ear is
   hearing: is the master in a miss or not. The cue is heard *in the context of*
   the room, and that table and the mixer's weight for the cue keep learning
   over the whole file. The track is **mixed in** (the master takes the cue's
   phase) only after the cue has kept agreeing for a while.

## The change (compile-time `-DDNAC_CUE`, default build byte-identical)

- **Loading the cue:** when forward match model 0 misses after an established
  match (confidence ≥ 16 at the first miss), and the cue is idle or failing,
  shifts δ = ±1 … ±`CUE_D` are tried. The first δ whose last `CUE_L` bases agree
  is loaded into the cue with confidence `CUE_L`. Being wrong is cheap here,
  because a loaded cue only speaks. It does not take over.
- **The cue follows** its own phase base by base, with the same
  hit/miss/confidence rule as a match model. It is dropped after `MISS_MAX`
  misses.
- **Mixing in:** when the cue's confidence reaches `CUE_SWITCH` and a forward
  master is in a miss with lower confidence, that master takes the cue's phase
  and confidence, and the cue goes idle.
- **Input count:** the cue is one extra mixer input, which brings level 3 to 16,
  exactly `MAXIN`.
- **Reference paths:** the cue's state and table are reset at the end of priming
  and after loading a state, so FASTA and state references stay identical.

**Parameters fixed now: `CUE_L = 3`, `CUE_D = 12`, `CUE_SWITCH = 12`.** There is
no sweep this time unless the stop rule below fires.

## Premises

Same targets and scripts as `docs/nudge-prediction.md`. Per-half costs come from
`-map` against the zero-event control, with event positions from
`make_tumour.plan` and the homopolymer `#run` rows (`halves.py`).

| premise | value | command |
|---|---|---|
| substitution, v0.8.0 / nudge L6D12 | 14.64 / 14.94 bits | `score.py` |
| random indel, v0.8.0 / nudge L6D12 | 48.25 / 37.63 bits | same |
| homopolymer slip, v0.8.0 / nudge L6D12 | 31.43 / 6.78 bits | same |
| O157, nudge L6D12 | +0.55% | same |
| `chr21_ind`, nudge L6D12 | −3.00% | `docs/nudge.md` |
| slip cost, 2nd half ÷ 1st half, v0.8.0 | **0.913** | `halves.py base` |
| same, nudge L6D12 | 0.916 | `halves.py L6D12` |
| random indel, 2nd ÷ 1st, v0.8.0 / nudge | 0.968 / 0.987 | same |
| substitution, 2nd ÷ 1st, v0.8.0 | 1.014 | same |

The model already learns along the file: v0.8.0's slips are 9% cheaper in the
second half. So the osmosis claim has to beat **0.913**, not 1.0.

## Predictions

**P1.** Homopolymer slip **≤ 10 bits**, keeping most of the nudge's gain. *60%.*

**P2, the reason the cue exists.** Substitution cost in **[14.49, 14.79]**, within
±1% of v0.8.0. No false-jump cost. *55%.*

**P3.** Random single-base indel **≤ 37.6 bits**, at least as good as the best
nudge. *45%.*

**P4.** Lossless on every file. Control moves < 0.1%. FASTA and state references
give byte-identical archives.

**P5.** O157 **no worse than +0.1%**, and `chr21_ind` **≤ −3.0%**. *45%.*

**P6, the osmosis: Timotheos's own claim.** The cue build learns along the file
more than v0.8.0 does. Slip cost, second half ÷ first half, **≤ 0.86** (v0.8.0:
0.913), and random indel **≤ 0.93** (v0.8.0: 0.968). *35%.* Stated low: one
file of 2,000 events may not give the table enough time to show it.

## When to stop

If P1 **and** P2 both fail, the cue does not do what the headphones do. That goes
down as a negative result, next to the nudge's numbers.
