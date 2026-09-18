# After v0.9.0: the two experiments — result

**Run 2026-09-18**, on branch `after-0.9.0`, cut from the v0.9.0 release
candidate so that candidate's history is untouched. Pre-registered in
`docs/after-090-prediction.md` (commit `b4b41e1`) before either was run.

---

## A. Four mixer experts at level 1, in reference mode

`sh scripts/cue/after090-experts.sh sizes`. `rel` is the release build, `rel_x4`
the same source with `-DL1_NMIX=4`, `v08` the same source configured as v0.8.0.
Every archive was decoded and `cmp`-ed before its size was recorded.

| pair | v0.8.0 default (`-l 3`) | v0.9.0 default (`-l 1`) | + four experts | x4 vs v0.8.0 | x4 vs v0.9.0 |
|---|---:|---:|---:|---:|---:|
| **W3110** vs MG1655 | 1,931 | 2,121 | **1,907** | **−1.24%** (−24 B) | −10.09% |
| O157:H7 vs MG1655 | 362,666 | 362,862 | 362,675 | **+0.0025%** (+9 B) | −0.05% |
| `ecoli_ind` | 12,580 | 12,204 | **12,051** | −4.21% | −1.25% |
| `chr21_ind` | 113,925 | 101,517 | **100,829** | −11.50% | −0.68% |
| **CHM13 chr21** | 586,615 | 563,031 | **560,096** | **−4.52%** | −0.52% |
| **CHM13 chr22** (held out) | 794,330 | 761,658 | **758,398** | **−4.52%** | −0.43% |

**A1 held**: 560,096 B, inside the 559,000–562,500 band. **A2 held**: −4.52%,
inside −4.1% to −4.7%. **A5 held**: chr22 is 0.43% below level 1, inside the
0.3–0.8% band, and the held-out chromosome reproduces chr21's whole-file figure
to two decimal places.

**The thing this was built to test is answered: the regression is not merely
reduced, it is reversed.** W3110 under the v0.9.0 default is 190 bytes *worse*
than v0.8.0's; with four experts it is 24 bytes *better*. And the change costs
size nowhere — all six pairs improve against the current default.

### The rule I wrote an hour earlier has an ambiguity that decides the outcome

D-A condition 1 reads: *"On every pair in the tuning set, it is ≤ what v0.8.0's
level-3 default produced."*

O157 comes out at **362,675 against 362,666 — nine bytes over**. The penalty has
fallen by 95% (the current default is +196 B on the same pair) but it has not
reached zero. By the letter of condition 1, **the change fails.**

Except that the plan's formally defined tuning set is *"the E. coli targets,
`ecoli_ind`, `chr21_ind`, CHM13 chr21"* (`docs/v0.9.0-plan.md`). **O157 is not in
it. Neither is W3110** — and W3110 is the pair the whole experiment exists for,
which I named in the same sentence as the rule. So the rule admits two readings:

- **every pair measured** → condition 1 **fails**, by nine bytes on 362 kB;
- **the tuning set as the plan defines it** → O157 is out of scope and condition
  1 **passes**.

**I predicted (A6) that it would pass.** Resolving an ambiguity of my own making
in the direction that confirms my own prediction is precisely the move this
routine exists to prevent, so it is not resolved here. It is put to Timotheos as
what it is: a rule that was written loosely, and a nine-byte result that lands
exactly on the loose part.

What can be said without resolving it: **nine bytes is not a user-visible
regression and one hundred and ninety is.** Whether that makes the rule wrong or
the result acceptable is a decision, not a measurement.

### Conditions 2 and 4

**Condition 2 (never costs size against the current default): passes**, on all
six pairs. **Condition 4 (replicates on the held-out set): passes** — chr22
−0.43% against chr21's −0.52%, same sign, more than half the magnitude.

**Condition 3 (the speed win survives) is measured separately** and is the one
that can still end this regardless of the above.

---

## B. The pitch fader: does a slip have momentum?

`sh scripts/cue/after090-slip.sh`. Every run was checked first: the
`-DDNAC_CUEPROF` build wrote a **byte-identical archive** to the release build on
all four cases, and every archive round-tripped. Every statistic below is on
**non-tied loads only**, against an independence baseline from that run's own
marginal.

| file | loads | tied | P(neg) all | P(neg) non-tied | P(same) | baseline | **excess** |
|---|---:|---:|---:|---:|---:|---:|---:|
| **CHM13 chr21** | 196,227 | 4.9% | 0.537 | 0.513 | 0.489 | 0.500 | **−1.12 pp** |
| **CHM13 chr22** (held out) | 275,495 | 4.5% | 0.532 | 0.510 | 0.489 | 0.500 | **−1.10 pp** |
| `chr21_ind` (control) | 26,482 | 1.0% | 0.483 | 0.478 | 0.504 | 0.501 | +0.27 pp |
| `ecoli_ind` (control) | 2,194 | 1.0% | 0.480 | 0.475 | 0.505 | 0.501 | +0.36 pp |

### The answer is no, and it is no in the opposite direction

**B3 failed, inverted.** The prediction was that consecutive slips would share a
sign at least 2 percentage points above chance. They share a sign **1.12 points
BELOW** chance: on real human pairs, consecutive corrections **alternate** more
often than independence allows.

**B5 held on the replication and therefore confirms the inversion**: chr22 gives
−1.10 pp against chr21's −1.12, on 275,495 loads against 196,227 — two
chromosomes, agreeing to two hundredths of a point.

**B4 held**: the simulated controls, whose indel signs `dnac mut` draws at
random, sit at +0.27 and +0.36 pp — indistinguishable from zero, which is what a
negative control has to look like for the real figure to mean anything.

**B2 held, B1 failed, and the pair of them shows the tie-correction working.**
Over *all* loads the marginal is 0.537 negative — the tie-breaking bias is real,
since the search tries `-a` before `+a`. Drop the 4.9% of loads that were ties
and it falls to 0.513, inside the 0.45–0.55 band B2 named. B1 predicted the raw
bias would exceed 0.55 and it is 0.537, so the bias is smaller than guessed, but
it is there and the correction removes it. **Had the ties been left in, the
measured "momentum" would have been contaminated by exactly the artifact the
pre-registration named** — and note which way: the artifact pushes *toward*
agreement, so the true anti-correlation is if anything slightly stronger than
−1.12.

### D-B: the directional search is closed

By the rule fixed before the run, B3 failing closes it. **Searching the drift
direction first would be searching the wrong way**: after a correction in one
direction, the next one is more likely to go back.

### What the failure points at instead

That is the shape of his own diagram. The lower panel of `docs/how-to-mix.png`
is not a drift in one direction — it is a **continuous alternation around the
steady line**, above, below, above, below. The measurement says real slips
behave like that panel and not like a one-way push.

So this result argues *against* the mechanism it was testing and *for* the one
registered beside it, **M1, riding** (`docs/riding-prediction.md`): the cue
should be nudged back and forth around its position rather than aimed in a
direction — or thrown away and re-acquired, which is what it does today.

**One confound, named and not resolved.** Once the cue is trusted, the master
takes its phase, so the next miss is measured from the *moved* position. If the
search systematically overshoots, a corrective shift in the opposite direction is
partly mechanical rather than biological. Distinguishing "the two genomes
alternate" from "our search overshoots and comes back" needs a second
measurement — the distribution of `|shift|` conditioned on whether the previous
load was adopted by a master — and until that is run, **the anti-correlation is
a property of this codec on this data, not a claim about genomes.**
