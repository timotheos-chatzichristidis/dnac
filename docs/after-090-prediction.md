# After v0.9.0: two experiments, pre-registered

**Written 2026-09-18**, before either was run, on branch `after-0.9.0` (cut from
`f54b8b8`, the v0.9.0 release candidate, so that candidate's history stays
exactly as it was). Both come from `docs/v0.9.0-plan.md`'s "After 0.9.0" list.

The standing rules apply: the prediction is written and committed before the
run; every archive round-trips before its size is used; timings are paired, back
to back, minimum of three, on an otherwise idle machine.

---

## A. Four mixer experts at level 1, in reference mode

**What is already known** (Batch 5, `docs/batch5.md` W5, release build, level 1
against level 3):

| pair | level 1 | level 1 + four experts | level 3 | v0.8.0 default (`-l 3`) |
|---|---:|---:|---:|---:|
| W3110 vs MG1655 | 2,121 | **1,907** | 1,916 | 1,931 |
| `ecoli_ind` | 12,204 | **12,051** | 12,051 | 12,580 |
| O157 vs MG1655 | 362,862 | 362,675 | 362,006 | 362,666 |

**What is not known, and is what this experiment measures:** the same build on
the real human pair (CHM13 chr21 against GRCh38 chr21) at the release settings,
its time, and the held-out chromosome 22.

### Why a new rule is needed, stated before the numbers

Batch 3 rejected four experts by a rule that read **≥ 1.0% size at ≤ 20% time,
or ≥ 0.5% at ≤ 10%**. That rule was written to answer *"should level 1 get one
of level 3's parts back?"* — a question about model sets, priced on one pair.
It is the wrong instrument for the question now on the table, which is
*"what should `dnac cr` do when the user says nothing?"* A default is not judged
by a percentage on one file; it is judged by whether it is ever **worse than the
default it replaced**, because that is the only thing a user can be surprised
by. Re-using Batch 3's rule here would be re-using an answer to a different
question, and the fact that it happens to be the rule already on record is not a
reason to keep it.

### D-A, the decision rule, fixed now

Level 1 + four experts becomes the reference-mode default **only if all four
hold**:

1. **No regression against v0.8.0's default.** On every pair in the tuning set,
   it is **≤** what v0.8.0's level-3 default produced. This is the condition
   v0.9.0's default fails (W3110 +9.84%) and the whole reason to look.
2. **No regression against v0.9.0's default.** It is ≤ level 1 on every pair —
   i.e. the experts never cost size.
3. **The speed win survives.** Encode of CHM13 chr21 against the GRCh38 FASTA,
   priming inside the time, stays **≥ 1.7x faster than v0.8.0's default**
   (which measured 170.30 s in Batch 4's rounds; v0.9.0's default was 2.17x).
   1.7x is chosen because the speed claim the README makes is "2.1x"; anything
   that drops the ratio below 1.7 would make that sentence false rather than
   conservative, and a default may not cost a published claim.
4. **It replicates on the held-out set.** chr22 must show the same sign on both
   size conditions. chr22 is used to confirm, never to choose.

If 1–4 hold, the default changes and every affected figure is re-measured in
**one** change, as Batch 4 did for `CUE_MINLEN`. If any fails, the default stays
and this is written up as a negative result.

### Predictions

| | claim | prediction |
|---|---|---|
| **A1** | CHM13 chr21, level 1 + four experts, release build | between 559,000 and 562,500 B (level 1 is 563,031; level 3 is 547,019; Batch 3 saw −0.523% for this change at `CUE_MINLEN=16`) |
| **A2** | the same against v0.8.0's default, 586,615 B | between −4.1% and −4.7% |
| **A3** | encode time against v0.9.0's level 1 | +15% to +25% (Batch 3 measured +21.1%) |
| **A4** | the speed ratio against v0.8.0's default | between 1.75x and 1.95x — so **D-A.3 passes** |
| **A5** | chr22 at level 1 + four experts | smaller than chr22 at level 1, by 0.3% to 0.8% |
| **A6** | D-A overall | **all four conditions hold and the default changes** |

A6 is the prediction most likely to be wrong, and the one worth being wrong
about: conditions 1 and 2 are already met on three of four bacterial cases, so
the risk sits in 3.

---

## B. The pitch fader: does a slip have momentum?

**Where it comes from.** Of the three DJ controls, two are translated: the jog
became the nudge (`docs/nudge.md`, measured and superseded), the headphones
became the cue. The **pitch fader** is not. Timotheos's description of it, asked
for explicitly and recorded in the ideas inbox: the pitch is *ridden
continuously*, never set once — "data of human intervention, not mechanism".

**The translation.** Today the cue searches **symmetrically**: at each distance
`a` from 1 to `CUE_D`, it tries `-a` then `+a` and takes the first place where
the last three bases agree (`dnac.c:789`). If real slips keep a **persistent
sign** locally — an insertion followed by more insertions rather than a
deletion — then searching in the direction of recent drift first would find the
right phase sooner and more often. That is the pitch fader: not a setting, a
direction you keep riding.

**This is a measurement before it is a feature.** No code changes to the codec.
The first question is only whether the signal exists.

### The trap this experiment must not fall into

**The search is not symmetric in its tie-breaking.** `sg = -1` is tried before
`sg = +1` at every distance, so whenever both `-a` and `+a` would agree, the
negative one always wins. That alone makes consecutive signs agree more often
than chance, with no biology involved whatsoever. A naive "how often does the
sign repeat?" would therefore find "momentum" in pure noise.

Two defences, both fixed now:

- The instrument records, for every cue load, **whether the opposite sign at the
  same distance would also have matched** — one extra `back_agree` call, under
  the diagnostic build only. Every statistic below is computed on
  **non-tied loads only**.
- Every figure is reported against an **independence baseline** computed from
  that run's own marginal, `p² + (1−p)²`, not against 50%.

### The instrument

`-DDNAC_CUEPROF` adds a counter block that writes one line per cue load to the
path in `DNAC_CUEPROF_OUT`: the target position, the signed shift, and a tie
flag. It touches no model state and no probability — the archive must be
byte-identical with and without it, and the run asserts that, exactly as `-map`
does.

### Predictions

| | claim | prediction |
|---|---|---|
| **B1** | over ALL loads on CHM13 chr21, the marginal sign is biased negative by the tie-breaking | P(negative) > 0.55 |
| **B2** | over **non-tied** loads, the marginal is near even | P(negative) within 0.45–0.55 |
| **B3** | **the question**: on non-tied loads, P(same sign as the previous non-tied load) exceeds its own independence baseline | **by ≥ 2 percentage points** on CHM13 chr21 |
| **B4** | negative control: the same statistic on `chr21_ind`, whose indels `dnac mut` draws with random signs by construction | excess **≤ 0.5 points** |
| **B5** | replication: chr22 | same sign as chr21, excess ≥ 1 point |

### D-B, the decision rule, fixed now

- **B3 and B4 and B5 all hold** → the signal is real and directional search is
  worth building. Pre-register that separately; it is a format change, since it
  moves which phase the cue loads.
- **B3 fails** (excess < 2 points) → **the pitch fader is closed**, written up as
  a negative result beside `cue-back.md` and `cue-room.md`, and the DJ console is
  fully translated: two controls that worked, one that did not.
- **B3 holds but B4 also does** → the statistic is measuring the instrument, not
  the biology. Stop and fix the instrument before believing anything.

The cheap outcome is the good one: if B3 fails this costs an hour and closes a
question that would otherwise sit open indefinitely.
