# Riding and rotation: the third control, pre-registered

**Written 2026-09-18**, before any code or measurement, on branch `after-0.9.0`.
Both mechanisms below come from an account Timotheos gave after v0.9.0 was
finished — the account of what he was actually doing when the idea formed, which
turns out to describe something the codec does not do.

## What he described, and why it is technical rather than biographical

The idea dates to **2015 and a third deck**. Three-deck mixing means **two tracks
are always playing to the room at once** and the third is prepared in cue: A+B
playing, bring C in while pulling A out, leaving B+C, then prepare A so B can
leave, leaving A+C, and so on — the roles rotate, and whichever is ending is the
one replaced while the other two carry.

Two consequences follow, and both are mechanical:

1. **You cannot put the headphones on and off.** With two tracks live in the room
   that must stay aligned continuously, the ear has to acclimatise to that
   environment permanently and mix the third in when needed. This is the part
   v0.9.0 already implements: the cue is a permanent mixer input, never switched
   in or out (`docs/cue.md`).
2. **On CDJ-100s the pitch has no decimal precision.** You cannot dial the right
   tempo and leave it. Drift is therefore *guaranteed*, not exceptional, and the
   only way to hold alignment is to **ride the pitch continuously** — small
   corrections that never settle.

His own diagram (`docs/how-to-mix.png`, drawn years before this project) shows
exactly that: the upper panel is the coarse correction — too slow at B,
overshooting past the line at C, parked at D — and the lower panel is the
practised version, a continuous small oscillation around the steady deck that
never comes to rest.

## What the codec actually does, checked against the source

**The cue does not ride. It jumps once, and when it drifts it is thrown away and
re-acquired.**

- It is loaded by a single search of ±`CUE_D` positions and then stays at that
  offset (`dnac.c`, the `match_after` miss branch).
- On a cue miss, confidence is halved and a miss counter advances; after
  `MISS_MAX` the cue is **deactivated** (`g_cactive = 0`), and the next master
  miss starts a completely fresh search.

That is "lift the needle and drop it somewhere else" — **the exact move the cue
was invented to stop the master from making**, performed by the cue itself one
level down. Nobody noticed because the cue's own failures are invisible: they
show up only as the master's next miss.

**And the roles do not rotate.** dnac has *two* forward match models — a 13-base
anchor and a 16-base anchor — both permanently live, which is the two-decks-in-
the-room half of the picture. But the cue is loaded only when the **short** one
misses (`mi == 0` guards the load). The long anchor can be handed the cue's phase
once the cue is trusted, but it can never *cause* a cue. One deck is watched; the
other is only ever rescued.

## M1 — riding: correct the cue instead of replacing it

On a cue miss, before the confidence is halved, try `g_cmp ± 1` (then ± 2, up to
`RIDE_D`, default 2): if the last `CUE_L` bases agree at the corrected position,
**move the cue there and keep its accumulated confidence**, rather than decaying
towards a fresh search. A cue that has been right for two hundred bases and slips
by one should be nudged, not discarded.

This is a **format change** — it changes what the cue predicts, so it changes the
bytes. It ships, if it ships at all, behind the existing experimental-build
machinery (`DNAC_EXPERIMENTAL`), exactly as the Batch 3 sweep parameters did.

| | prediction |
|---|---|
| **M1a** | bits per random indel at level 3 falls below the release's **26.90**, into the band **24.0–26.5** |
| **M1b** | CHM13 chr21 at level 3 is smaller than **547,019 B**, by **0.3% to 1.5%** |
| **M1c** | the substitution stays within ±0.25 bits of **14.75** — riding must not start inventing phase where the content is simply different |
| **M1d** | time cost under **+5%**: the extra work is a handful of `back_agree` calls on a path that only runs when the cue is already missing |

**The prediction most likely to be wrong is M1c.** A cue that corrects itself
instead of dying will stay alive through stretches where it should have died, and
a confidently wrong second deck is worse than no second deck — that is precisely
what `docs/cue-back.md` found when the decks alternated.

## M2 — rotation: let either master call for the cue

Remove the `mi == 0` restriction, so a cue is loaded when **either** forward
match loses an established run — in his terms, whichever deck is ending is the
one replaced, while the other carries.

| | prediction |
|---|---|
| **M2a** | CHM13 chr21 at level 3: between **0.0% and −0.3%** — a real but small gain, because the 16-base anchor fires rarely on human sequence and its misses are mostly the same events the 13-base anchor already caught |
| **M2b** | on the **diverged** bacterial pair (O157), where long exact anchors are scarce, the effect is smaller still: within ±0.05% |
| **M2c** | M1 and M2 together are **not additive**: their combined gain is less than the sum, because both act on the same misses |

## D-M, the decision rule, fixed now

A mechanism is adopted only if, at level 3 on the tuning set:

1. it gains **≥ 0.3%** on the real human pair, **and**
2. the substitution cost moves by **≤ 0.25 bits**, **and**
3. time cost is **≤ 10%**, **and**
4. it replicates on the held-out chr22 with the same sign and at least half the
   magnitude.

Anything less is written up beside `cue-back.md` and `cue-room.md` as another
refinement that sounded better than it measured. **Two of his three refinements
have already been measured as failures and published as such; that is the base
rate this is judged against, not against hope.**

## Order, and what is not being done

M1 first: it is the sharper idea, it comes straight from the diagram, and it
tests the thing v0.9.0 left undone. M2 only after M1 is settled, so their effects
are never confounded — `docs/batch3.md` already paid once for measuring two
things whose effects overlap.

Experiment B (`docs/after-090-prediction.md`), the directional search, stays as
registered and is **not** merged into this. It asks whether drift has a
*direction*; M1 asks whether the cue should *correct* rather than restart. They
could both be true, both false, or either alone.
