# The cue that alternates decks: result

**Run 2026-09-10.** Pre-registered in `docs/cue-back-prediction.md` (commit
`c86c22b`), with one size seen before writing, disclosed there. Build:
`-DDNAC_CUE -DCUE_BACK=1`, other parameters as in `docs/cue.md`.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **B1** | controlled targets within ±2% of the single-deck cue | **held**: substitution 14.71 (+0.4%), random indel 28.85 (+0.3%), slip 11.82 (+0.3%) |
| **B2** | `chr21_ind` within ±0.5% | **held**: 104,140 B against 104,013 (+0.12%) |
| **B3** | real pair, shared windows ≥ 0.5% better than the single deck | **failed**: −18.38% against −18.27%, an extra 0.1% |
| **B4** | lossless, FASTA = state | **held** |

Real pair, whole file: 551,539 B against 551,594 (−0.01%).

## Verdict

**The alternation is not measurable on these data.** The single-deck cue
(`CUE_BACK=0`) stays as the version to keep. The code stays behind its flag, so
it can be re-tested on data where it might matter.

## Why, plainly

In a DJ mix, A is still music during its fade-out, and there are real moments
when bringing it back is right. In a DNA match after a slip, the old phase A is
simply wrong. By the time the cue has agreed for 12 letters and been mixed in,
it is almost never the one that is mistaken, so the headphones on A have
nothing to catch. The part of the method that carries the gain is the other
part: the headphone ear heard *through* what the room ear hears, and a cue that
never leaves the mix (`docs/cue.md`).

**Corrected 2026-09-12.** That last sentence was half wrong when it was
written, and the branch's own next experiment is what shows it. The 2x2 in
`docs/remaining.md` (T3) removed the room from the cue's table and from the
mixer's context, and the result did not get worse: **the gain comes from the
cue existing and staying, not from hearing it through the room.** So the part
of the method that carries the gain is the permanence alone. Left in place
rather than rewritten, because a document that quietly becomes right is a
document nobody can check.

## The test this points to (not yet run)

Timotheos's sharper claim is that taking the headphones off and listening with
both ears **destroys** the osmosis. In the model that is a cue whose table is
*not* indexed by the master's state: heard on its own, not through the room.
It is a one-line ablation (`room = 0`), and it tests his claim directly.
