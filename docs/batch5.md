# Batch 5: claims and release — result

**Run 2026-09-17.** Pre-registered in `docs/batch5-prediction.md` (commits
`3339074` and `5ee9f33`) before the runs: the design F1–F8, the figures P1–P10,
the W3110 experiment W1–W5 and the decision rule D1. The session opened green on
`ba4c86e`: `make` clean, `sh scripts/roundtrip.sh ./dnac.exe` 229/229,
`./verify-claims.ps1 -Tier fast` 21/21.

## W: the one decision Batch 4 handed over

**The question.** Since v0.9.0, `dnac cr` defaults to level 1, and on the
tightest real bacterial pair that default is 9.84% larger than v0.8.0's. Is that
a property of near-identical pairs — in which case the default is wrong — or an
artefact of a 2 kB output, or content that level 3's dropped models earn on?

### The gradient (`sh scripts/cue/batch5-w3110.sh`)

`dnac mut` on MG1655 at four rates, seed 42 (SNPs at the rate, short indels at a
tenth of it), each coded against MG1655 by the release build at levels 3 and 1,
every archive round-tripped. The real pairs are in the same run at the same
settings.

| target | level 3 | level 1 | penalty | | SNPs | indels |
|---|---:|---:|---:|---:|---:|---:|
| `mut` 0.05 ‰ | 2,220 | 2,224 | 4 B | **+0.18%** | 232 | 23 |
| `mut` 0.2 ‰ | 3,989 | 3,993 | 4 B | **+0.10%** | 928 | 92 |
| `mut` 1.0 ‰ | 12,112 | 12,281 | 169 B | +1.40% | 4,641 | 464 |
| `mut` 5.0 ‰ | 43,149 | 43,937 | 788 B | +1.83% | 23,208 | 2,320 |
| `ecoli_ind` | 12,051 | 12,204 | 153 B | +1.27% | | |
| **W3110** | 1,916 | 2,121 | **205 B** | **+10.70%** | | |
| O157:H7 | 362,006 | 362,862 | 856 B | +0.24% | | |

**W1 held**: the whole simulated gradient stays under 2%, nowhere near 9.84%.
**W2 held**: the penalty is not a fixed overhead — it runs from 4 B to 788 B,
a factor of 197, against the "at least 3x" predicted. **W3 held, decisively**:
the 0.2 ‰ point produces 3,989 B, twice W3110's output, and pays **4 bytes**
where W3110 pays 205. At a matched output size the simulated penalty is fifty
times smaller, so **the loss is content, not size**.

**W4 part held**, 3 of 4. The per-event arithmetic (level 1 pays +3.12 bits per
indel and saves 0.17 bits per substitution, Batch 4 R1) predicts 4.2, 16.7, 83.5
and 417.7 B against measured 4, 4, 169 and 788 — ratios 0.96, 0.24, 2.02, 1.89.
Three are inside the factor of 2.5 the prediction allowed; the 0.2 ‰ point is
four times outside it, in the direction of costing *less* than the events say it
should. Two of the four are also nearly twice the predicted value, so the
arithmetic is the right order and not the right number: at these rates the model
recovers more from an indel than the isolated per-event screen suggests.

### W5: which content, then

Added after W1–W4 were run and disclosed as such in the pre-registration. W3110
against MG1655 at level 1, release build, with one of level 3's parts switched
back on at a time (the `L1_*` diagnostics Batch 4 kept for exactly this):

| level 1 plus… | bytes | of the 205 B gap |
|---|---:|---:|
| nothing (the default) | 2,121 | — |
| the master order set (`L1_ORDERS`) | 2,131 | **−4.9%** (worse) |
| other-strand training (`L1_IR`) | 2,131 | −4.9% (worse) |
| the tolerant models (`L1_STCM`) | 2,126 | −2.4% (worse) |
| **four mixer experts (`L1_NMIX=4`)** | **1,907** | **104%** |

**W5a held** (one part dominates, and by more than the 40% predicted).
**W5b failed**: it is not the order set — that is a small *loss*, as are the
other two model add-backs. **W5c failed** with it, for the same reason: it
compared two things that both turn out to be inert here.

**The answer is the mixer's context, not the model set.** Level 1 has two
expert mixers where level 3 has four; giving level 1 four recovers the entire
gap on W3110 and overshoots it, landing below level 3 (1,907 against 1,916) and
below v0.8.0 (1,931). Checked on the other two pairs at the same settings, to
see how far it generalises:

| pair | level 1 | level 1, four experts | level 3 |
|---|---:|---:|---:|
| W3110 (near-identical) | 2,121 | **1,907** | 1,916 |
| `ecoli_ind` (simulated individual) | 12,204 | **12,051** | 12,051 |
| O157:H7 (diverged) | 362,862 | 362,675 | 362,006 |

On the simulated individual four experts recover the gap **exactly** — 12,051 is
level 3's own size, to the byte. On the diverged pair they recover a fifth. So
the finding is scoped: **where the reference is very close, what level 1 gives
up is the mixer's context, and almost nothing else.**

### D1: the default stays level 1, and the loss is stated

W1 held, and both real pairs whose output exceeds 100 kB stay under 3% (O157
+0.24%, CHM13 chr21 +2.93%). By the rule fixed before the runs, **the
reference-mode default stays level 1** and the README states the W3110 case in
both units — +9.84% and +190 bytes — with `-l 3` named as the remedy, which at
level 3 is also smaller than v0.8.0 on both bacterial pairs.

**What is not done here, and why.** Four experts at level 1 would remove this
loss outright and gain on every reference-mode pair measured. It was priced on
the human pair in Batch 3 — **+21.1% time for −0.523% size** — against a rule
fixed in advance (≥ 1.0% at ≤ 20%, or ≥ 0.5% at ≤ 10%), and it failed. Changing
the default now, on the strength of a result found after that rule was written,
is exactly the move the routine exists to prevent. It is recorded instead as the
first candidate for the next release, with its price attached, and it is in the
README where a reader will see it rather than in a drawer.
