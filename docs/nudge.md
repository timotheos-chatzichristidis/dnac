# The nudge: result

**Run 2026-09-10.** Pre-registered in `docs/nudge-prediction.md` (commit
`be168be`, 17:34:01 +0300) before any line of the nudge was written. Build:
`gcc -O3 -DDNAC_NUDGE`, with `NUDGE_L = 5` and `NUDGE_D = 12` as registered. The
default build is untouched: without the flag it produces archives
byte-identical to v0.8.0 (checked on `ind_1`).

## Scoreline

| | prediction | outcome |
|---|---|---|
| **P1** | random single-base indel 48.25 → ≤ 25 bits | **failed**: 33.27 bits (−31%) |
| **P2** | substitution stays in [14.20, 15.08] | **failed**: 15.65 (+6.9%) |
| **P3** | homopolymer slip 31.43 → ≤ 22 bits | **held, far past the line**: **6.76 bits** (−78%) |
| **P4** | lossless everywhere, control moves < 0.1% | **held**: every file round-trips, control +11 B (+0.027%) |
| **P5** | `chr21_ind`, `ecoli_ind` ≥ 5% smaller | **failed**: −1.50%, −1.89% |
| | O157 at least 0.3% smaller | **failed, inverted**: +2.07% |
| | W3110 not worse than +1% | **held**: −0.73% |

Stop rule: P1 needed to land at 40 bits or more to stop the idea. It landed at
33.27, so it continues, with the single labelled sweep the registration allows.

## Per-event cost, bits (mean of 3 seeds, 2,000 events each)

| event | before | with the nudge | |
|---|---:|---:|---:|
| substitution | 14.64 | 15.65 | +6.9% |
| random single-base indel | 48.25 | 33.27 | −31.0% |
| homopolymer slip | 31.43 | **6.76** | **−78.5%** |

**A homopolymer slip now costs less than half a substitution.** Before the
nudge, the match model kept playing at the old phase through the run, missed at
its end and then paid for about thirteen bases of re-anchoring. Now it shifts one
base the moment the run ends, and the last five bases agree immediately at the
new phase.

## Why P2 and O157 went the wrong way

A substitution produces a miss too, and the nudge cannot tell it from an indel
at the moment of the miss. When a shifted phase happens to agree on the last five
bases, the model jumps to it and has to find its way back. That is the +1 bit per
substitution. O157 is a diverged strain, dense with substitutions inside
diverged repeats, so it pays that price most often and gains least.

The lever is how hard the model listens before it nudges: `NUDGE_L`, the number
of bases that must agree. The sweep below is the registered one.

## The sweep (labelled as such, not the headline)

Same targets, every file round-tripped. Cost per event in bits. Real pairs as a
change against the unmodified build.

| `L` | `D` | substitution | random indel | homopolymer slip | O157 | `ecoli_ind` |
|---:|---:|---:|---:|---:|---:|---:|
| — | — | 14.64 | 48.25 | 31.43 | — | — |
| **5** | **12** | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% |
| 6 | 12 | 14.94 | 37.63 | 6.78 | +0.55% | **−2.38%** |
| 8 | 12 | 14.72 | 43.80 | 12.69 | −0.12% | −1.51% |
| 5 | 4 | 15.01 | 33.09 | 6.82 | +0.50% | −0.95% |
| 6 | 4 | 14.72 | 37.56 | 6.80 | +0.02% | −0.99% |
| 8 | 4 | 14.71 | 43.77 | 12.66 | −0.15% | −0.50% |

(first row: the unmodified build; bold: the registered setting)

What the sweep says:

1. **The slip result holds at every setting.** At `L ≤ 6` a homopolymer slip
   costs about 6.8 bits. Even the most cautious setting (`L = 8`) cuts it by 60%.
2. **Every other gain is bought with false nudges.** Listening longer (`L`)
   removes the damage to substitutions and to O157, and removes most of the
   random-indel gain with it. No setting has both.
3. **`L = 6, D = 12` is the best balance measured.** Substitutions +2.0%, so P2
   would have held there. Random indels −22%, slips −78%, `ecoli_ind` −2.38%,
   O157 +0.55%. `D` matters only where indels are longer than 4 bases, which is
   why `ecoli_ind` (1–10 base indels) wants 12. On the full simulated chr21
   individual this setting gives **110,508 B against 113,925 B, −3.00%**
   (round-tripped), twice the registered setting's −1.50%.

## What this is, plainly

- **It works where the idea says it should:** a slip in a run of identical
  letters (the MSI mechanism) now costs less than half a substitution.
- **On the simulated personal genomes the total gain is 1.5–3.0%, not the 5%
  predicted.** For scale: dnac's past single improvements were worth 0.05–0.8%
  each. In `dnac mut` indels are a tenth of the events, and their inserted
  bases are random and cost 2 bits each whatever the match model does.
- **The simple nudge jumps before it is sure,** and pays for that on
  substitution-dense, diverged genomes.

## Next, not yet registered

1. **A real human pair**, not `dnac mut`. Most real small indels sit in
   homopolymers and short tandem repeats, which is exactly where the nudge
   gained 78%. That statement comes from the literature, not from this repo, so
   it is a premise to measure first.
2. **Listen before switching: the DJ's headphone cue.** Instead of jumping to the
   shifted phase, run it in parallel as a second candidate and switch only after
   it keeps agreeing. That should keep the slip gain and remove the false-nudge
   cost. It is a redesign, so it gets its own registration.
