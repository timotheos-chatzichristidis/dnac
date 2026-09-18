# M1, riding: the cue corrects itself instead of dying — result

**Run 2026-09-19**, on branch `after-0.9.0`. Pre-registered in
`docs/riding-prediction.md` (commit `4d86862`) before any code was written.
The mechanism: on a cue miss, try `g_cmp ± 1 … ± RIDE_D` and, if `CUE_L` bases
agree at the corrected position, move the cue there and **keep its accumulated
confidence**, instead of halving the confidence and decaying towards a fresh
search. `RIDE_D=0` is v0.9.0's behaviour and is the release value; `ride` is the
release source with `-DRIDE_D=2`, which marks its archives experimental.

`sh scripts/cue/after090-ride.sh`. Every archive was decoded and `cmp`-ed before
its size was recorded.

## The instrument first

Before the experiment is read, the control: `rel` in this run reproduces the
release figures of `docs/batch4.md` **to the byte** — 14.75 / 26.90 / 11.60 bits
per event, CHM13 chr21 547,019 B, chr22 742,177 B. The same four numbers from a
different script on a different day. And the code change is inert where it has
to be: `RIDE_D=0` is byte-identical to `HEAD` on plain and reference mode at
levels 3 and 1, and the riding build passes **229/229** adversarial round-trips.

## The result

Level 3 throughout, against a primed MG1655 for the per-event figures and
GRCh38 for the human pairs.

| | release | riding (`RIDE_D=2`) | change |
|---|---:|---:|---:|
| substitution | 14.75 | **15.18** | **+0.43 bits** |
| random indel | 26.90 | 26.85 | −0.05 bits |
| homopolymer slip | 11.60 | **11.22** | **−3.3%** |
| CHM13 chr21 | 547,019 B | 547,623 B | **+0.110%** |
| CHM13 chr22 (held out) | 742,177 B | 742,244 B | +0.009% |

| | prediction | outcome |
|---|---|---|
| **M1a** | indel below 26.90, in 24.0–26.5 | **failed** — 26.85, a twentieth of a bit |
| **M1b** | chr21 smaller by 0.3–1.5% | **failed, inverted** — 0.110% *larger* |
| **M1c** | substitution within ±0.25 of 14.75 | **failed** — +0.43 |
| **M1d** | time cost under +5% | see below |

**D-M condition 1 requires a gain of ≥ 0.3% on the real human pair. The measured
figure is a loss. The rule says no, and it says no on its first condition**, so
nothing downstream of it has to be argued.

## What failed is not what was being tested

The pre-registration named M1c as the prediction most likely to be wrong, for
this reason: *"a cue that corrects itself instead of dying will stay alive
through stretches where it should have died, and a confidently wrong second deck
is worse than no second deck."* That is exactly what the numbers say, and the
three event classes separate it cleanly:

- a **homopolymer slip is literally a ±1 phase error** — the event riding was
  designed for — and riding gains 3.3% on it, the largest per-event movement in
  the table;
- a **substitution has no phase to correct**. The cue misses, riding looks at
  `±1` and `±2`, and on 4-letter sequence a 3-base agreement turns up often
  enough that the cue is moved for no reason — and moved *with its confidence
  intact*, so the mixer keeps trusting it and the mix-in rule can hand a master
  the wrong phase immediately;
- the **random indel**, which mixes both, barely moves.

So the mechanism works and the test that gates it does not. **The gain is real
and it is smaller than the damage**, on sequence where substitutions vastly
outnumber slips — which is what a real human pair is.

## The post-hoc probe, registered before it was run

This is **post-hoc** and is labelled as such, in the same way `docs/batch3.md`
disclosed extending a sweep past its registered grid. The diagnosis above names
one parameter: `CUE_L = 3` is the test for *picking up* a phase after the master
has already failed, and it is being reused as the test for *overriding a cue
that is currently trusted*. Those are not the same decision and there is no
reason they should share a threshold.

`RIDE_L` (default `CUE_L`, so the measurement above is unchanged) is how many
bases must agree before the cue is moved. The probe is `RIDE_D=2, RIDE_L=8`.

**Predictions, fixed now:**

| | prediction |
|---|---|
| **N1** | the substitution returns to within ±0.15 bits of 14.75 — an 8-base agreement is 65,536 to one against by chance, so riding should essentially stop firing where there is no phase error |
| **N2** | the homopolymer slip keeps most of its gain: between 11.20 and 11.45 (riding fired on a real slip, and a real slip still agrees 8 bases back) |
| **N3** | CHM13 chr21 lands between −0.10% and +0.05% of 547,019 — that is, the loss is removed but a gain is **not** expected, because the slip events riding fixes are a small share of a real human pair's cost |

**N3 is the one that decides anything.** If it comes out a gain, D-M's conditions
apply to it unchanged and the replication on chr22 is what is asked next. If it
comes out at break-even, riding is a mechanism that is right about what it does
and does not matter at this scale, and it is written up beside `cue-back.md` and
`cue-room.md` as the third of Timotheos's refinements to be measured and closed.
