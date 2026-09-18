# M1, riding: the cue corrects itself instead of dying — result

**Run 2026-09-19**, on branch `after-0.9.0`. Pre-registered in
`docs/riding-prediction.md` (commit `4d86862`) before any code was written.
The mechanism: on a cue miss, try `g_cmp ± 1 … ± RIDE_D` and, if `RIDE_L` bases
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

## The result, as registered

Level 3 throughout, against a primed MG1655 for the per-event figures and
GRCh38 for the human pairs.

| | release | riding (`RIDE_D=2`) | change |
|---|---:|---:|---:|
| substitution | 14.75 | **15.18** | **+0.43 bits** |
| random indel | 26.90 | 26.85 | −0.05 bits |
| homopolymer slip | 11.60 | **11.22** | **−3.3%** |
| CHM13 chr21 | 547,019 B | 547,623 B | **+0.1104%** |
| CHM13 chr22 (held out) | 742,177 B | 742,244 B | +0.0090% |
| encode, chr21 (min of 3) | 177.07 s | 178.42 s | +0.76% |

| | prediction | outcome |
|---|---|---|
| **M1a** | indel below 26.90, in 24.0–26.5 | **failed** — 26.85, a twentieth of a bit |
| **M1b** | chr21 smaller by 0.3–1.5% | **failed, inverted** — 0.11% *larger* |
| **M1c** | substitution within ±0.25 of 14.75 | **failed** — +0.43 |
| **M1d** | time cost under +5% | **held** — +0.76% |

**D-M condition 1 requires a gain of ≥ 0.3% on the real human pair. The measured
figure is a loss**, so the rule says no on its first condition. The only
prediction that held is the one that cost nothing to hold.

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
disclosed extending a sweep past its registered grid. Its three predictions were
committed in `9fe5c17`, before the probe was built or run. The diagnosis above
names one parameter: `CUE_L = 3` is the test for *picking up* a phase after the
master has already failed, and it was being reused as the test for *overriding a
cue that is currently trusted*. Those are not the same decision and there is no
reason they should share a threshold. `RIDE_L` separates them; the probe is
`RIDE_D=2, RIDE_L=8`.

| | release | riding, `RIDE_L=3` | **probe, `RIDE_L=8`** |
|---|---:|---:|---:|
| substitution | 14.75 | 15.18 | **14.61** |
| random indel | 26.90 | 26.85 | **26.73** |
| homopolymer slip | 11.60 | **11.22** | 11.46 |
| CHM13 chr21 | 547,019 B | +0.1104% | **545,634 B — −0.2532%** |
| CHM13 chr22 (held out) | 742,177 B | +0.0090% | **741,319 B — −0.1156%** |
| encode, chr21 (min of 3) | 177.51 s | +0.76% *(its own run, `rel` 177.07 s)* | **−0.12%** |

| | prediction | outcome |
|---|---|---|
| **N1** | substitution within ±0.15 of 14.75 | **held** — 14.61, and *better* than the release |
| **N2** | slip keeps most of its gain: 11.20–11.45 | **failed**, by a hundredth — 11.46, a third of the gain kept, not most |
| **N3** | chr21 between −0.10% and +0.05% | **failed, in the favourable direction** — −0.2532% |

**The diagnosis is confirmed: the gate was the problem, not the mechanism.**
Raising the test from 3 bases to 8 removes the substitution damage entirely
(14.61 is below the release's 14.75), keeps a third of the slip gain, improves
the random indel, turns a loss on a real human pair into a gain, and costs no
time. The −0.12% is not a speed-up and is not read as one: this machine's
run-to-run noise is 24%, so the only claim the timing supports is that riding is
free. Each table quotes its OWN run's `rel` (177.07 s and 177.51 s), because a
ratio taken across separate invocations is not a ratio here.

## D-M: the answer is still no, and it is no twice

| condition | requirement | measured | verdict |
|---|---|---:|---|
| 1 | gain ≥ 0.3% on the real human pair | **0.2532%** | **fails** |
| 2 | substitution moves ≤ 0.25 bits | −0.14 | passes |
| 3 | time cost ≤ 10% | −0.12% | passes |
| 4 | replicates on chr22, same sign, ≥ half the magnitude | **0.1156% against 0.1266% needed** | **fails** |

Two independent near-misses, both by a whisker: 0.2532% against a bar of 0.3%,
and a replication that reaches 45.7% of the tuning figure where 50% was
required. **That is a better answer than one borderline call**, because the two
failures are not the same fact restated — one says the gain is small, the other
says it is smaller on a chromosome that was not looked at while the parameter
was chosen.

And the second one is the substantive finding. `RIDE_L=8` was chosen *after*
seeing chr21's numbers; chr22 is where that choice is paid for, and it gives
back 46% instead of 100%. **That shrinkage is what a post-hoc parameter looks
like when it is honestly held out.**

## What is deliberately not done

`RIDE_L` is **not swept**. 8 was one guess at a threshold, it landed 0.047
percentage points short of the adoption bar, and the obvious next move — try 6,
try 12, take the best — is precisely the error this project has named three
times now (`docs/after-090.md`: *"choosing an estimator after seeing three
numbers is the same error as choosing a reading of a rule after seeing nine
bytes"*). Anyone who wants that sweep must pre-register it, with the held-out
chromosome named in advance and the adoption bar left where it is.

The same applies to the bar itself. D-M's 0.3% was written before any of this
was built, and this is the second mechanism on this branch to die just short of
a pre-registered threshold — four experts at 1.6957x against 1.7x, and now
riding missing two bars at once, 0.2532% against 0.3% and 45.7% against 50%. If that pattern
means the bars are set too high, **that is an argument to have openly, before the
next measurement, and not one to settle by moving a bar onto a number already
seen.**

## Where this leaves the console, and M2

Of the three controls on Timotheos's CDJ, the jog became the nudge (measured,
superseded), the headphones became the cue (adopted, v0.9.0's whole gain), and
the pitch fader now has both of its readings measured and closed: the
**directional** search (`docs/after-090.md` B — slips alternate, they do not
persist) and **riding** (here — right about what it does, too small where it
matters). The lower panel of `docs/how-to-mix.png` is now implemented and
measured; it is not adopted.

**M2, rotation** (`docs/riding-prediction.md`) is untouched and stays as
registered: let either forward match call for the cue, not only the 13-base one.
Its predicted effect was 0.0 to −0.3% on chr21, which is the same size as what
riding just failed to clear — so it is registered against the same bar and
should be expected to have the same trouble. It is the last of the pre-registered
mechanisms on this branch.
