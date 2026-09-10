# Taking the headphones off: pre-registered prediction

**Written 2026-09-10, blind:** the ablation build (`-DDNAC_CUE -DCUE_ROOM=0`) has
been compiled and has not been run on anything. The only check run was that
`CUE_ROOM=1` stays byte-identical to the cue in `docs/cue.md` (on `ind_1`).
The result goes in `docs/cue-room.md`.

## The claim under test, in Timotheos's words

> Only with the one ear can you understand, if you let it acclimatise, and do
> not take the easy way of removing the headphones and listening with both ears.
> That spoils the osmosis.

## The translation

In `-DDNAC_CUE` the headphone ear's probabilities are indexed by what the room
ear hears: is master 0 in a miss right now. That is the cue heard *through* the
room. `CUE_ROOM=0` removes that index. The cue is then heard on its own, the
same way whatever the room is doing: both ears listening to everything, nothing
integrated. Everything else is identical, including loading, following, mixing
in and the mixer input.

## Premises (single-deck cue, `docs/cue.md`, `docs/real-human.md`)

| | value |
|---|---|
| substitution / random indel / slip | 14.65 / 28.75 / 11.78 bits |
| slip cost 2nd ÷ 1st half (osmosis) | 0.576 (v0.8.0: 0.913) |
| random indel 2nd ÷ 1st half | 0.835 (v0.8.0: 0.968) |
| `chr21_ind` | 104,013 B (−8.70% on v0.8.0) |
| CHM13 chr21, fixed shared windows | −18.27% on v0.8.0 |

## A reason it might not show

The mixer's own weights are already chosen by a context that includes the match
models' state (`mix_ctx`). The mixer may learn part of the room-conditioning
there, and hide the loss. If so, the ablation costs little. That would say the
integration is happening, only one layer up. It would not say the osmosis is
false.

## Predictions, in the direction Timotheos claims

**H1.** Random indel and slip each cost **≥ 5% more** than with the room ear.
*45%.*

**H2, the osmosis itself.** The learning along the file weakens: slip
2nd ÷ 1st half **above 0.70** (with the room ear: 0.576). *45%.*

**H3.** Substitutions within ±1% (14.65). The room flag only matters when the
master misses. *70%.*

**H4.** `chr21_ind` loses **≥ 1 point** of its −8.70% (≥ 104,013 × 1.01 ≈
105,150 B). *40%.*

**H5.** CHM13 shared windows lose **≥ 1 point** of their −18.27%. *40%.*

Reading: if H1, H2, H4 and H5 hold, taking the headphones off spoils the osmosis,
as claimed. If all of them fail, the room-conditioning in the cue's own table is
not what carries the gain (possibly because the mixer does it one layer up), and
that goes down as a failed prediction of the claim.
