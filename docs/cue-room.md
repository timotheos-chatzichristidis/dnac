# Taking the headphones off: result

**Run 2026-09-10.** Pre-registered blind in `docs/cue-room-prediction.md`
(commit `54d28d0`, 20:36:47 +0300). Build `-DDNAC_CUE -DCUE_ROOM=0`: the cue's
table is no longer indexed by what the room ear (master 0) hears. Everything
round-trips.

**Parameter set, added 2026-09-14 (Batch 4):** measured with `CUE_MINLEN = 16`.
v0.9.0 ships 4 (`docs/batch3.md`), so this is the record of that build; its
rows re-derive from `4932ffe`'s source, which `verify-claims.ps1` pins.
`CUE_ROOM` survives in v0.9.0 as an experimental knob.

## Scoreline

| | prediction (the claim's direction) | outcome |
|---|---|---|
| **H1** | indel and slip ≥ 5% dearer | **failed, inverted**: indel 28.34 (−1.4%), slip 11.04 (−6.3%) |
| **H2** | slip learning weaker: 2nd ÷ 1st > 0.70 | **failed**: 0.610 (with room: 0.576) |
| **H3** | substitutions within ±1% | **held**: 14.73 (+0.5%) |
| **H4** | `chr21_ind` loses ≥ 1 point | **failed**: 104,125 B against 104,013 (+0.11%) |
| **H5** | CHM13 shared windows lose ≥ 1 point | **failed**: −18.14% against −18.27% |

CHM13 whole file: 551,753 B against 551,594 (+0.03%).

## Verdict

**The claim, as translated here, is not supported.** Removing the room from the
cue's table changes the result by about 0.1% on real sequence. On the
controlled targets it even helps a little, because a table with half the cells
fills faster. That shows as a cheaper first half (slip 13.73 against 14.99
bits), with the second half almost the same (8.38 against 8.63).

## What the three builds together do say about the osmosis

| build | what it is, in the DJ's terms | slip cost 2nd ÷ 1st half |
|---|---|---:|
| v0.8.0 | no second deck at all | 0.913 |
| nudge | no headphones: jump when it sounds wrong | 0.916 |
| cue, room-conditioned | headphones permanently on one ear | **0.576** |
| cue, not room-conditioned | headphones permanently on, heard alone | **0.610** |

- **Supported:** a *permanently present* second ear, whose trust is learned over
  the whole file, is what produces the learning along the file (0.58–0.61
  against 0.91–0.92). Jumping without it (the nudge) learns nothing. That is
  the "never take them off, never put them on and off" half of the method, and
  it holds.
- **Not supported:** that the headphone ear has to be heard *through* the room
  in its own table. Either that integration does not matter here, or, as the
  prediction warned, the mixer already does it one layer up: its weights are
  chosen by a context that includes the match models' state. Telling those two
  apart needs one more ablation, removing the match state from the mixer's
  context. Not run.

## What is kept

The room-conditioned cue (`CUE_ROOM=1`, the default) stays. It is better on
both real-sequence tests, by a margin too small to claim, and it is the version
every other result on this branch was measured with.
