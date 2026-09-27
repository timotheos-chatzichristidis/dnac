# Codon oracle: the control was void, and the replacement controls -- pre-registration

Written 2026-09-27 after the first codon-oracle run, before the controls below were run.

## What happened
The oracle gained 3.7504% (E. coli) and 3.0721% (B. subtilis). The "shifted" control
gained 3.7506% and 3.0734%: the same, to 2 and 13 bytes. **The control was void by
construction, not failed.** Moving every codon position by one (c -> c+1 mod 3) in every
gene is a consistent RENAMING of the three phases. The model never sees the names, only
which bases share a label. So the control carried exactly the oracle's information. This
is the "cosmetic relabelling" that CLAUDE.md's first principle names. The design error is
mine, and it is recorded here rather than removed.

Consequence for the rule of docs/codon-oracle-prediction.md: C2 cannot be judged from a
void control, so the decision is **pending**, not "closed" and not "open". C1 (1-4%) and
C3 (B. subtilis >= half) held. The oracle thresholds (1.0% / 0.5%) are met, but the rule
also needs C2.

## Replacement controls (thresholds unchanged)
Same build and recipe, other label files (`scripts/pilot/codon-labels.py --control`):
- nophase: every coding label collapsed to its strand (0-2 -> 0, 3-5 -> 3). Coding vs
  non-coding and strand are kept; the phase is removed.
- randrot: each gene's phase rotated by its own random offset (seed 20260927). Phase is
  consistent within a gene but no longer aligned ACROSS genes, so shared codon statistics
  cannot form.
C2' holds only if EACH control gains less than a third of the oracle's gain, on both
genomes. Then the full rule decides (build a real phase tracker, after a prior-art search).
If either control gains a third or more, the lever is closed as specified.

## Predictions
N1  nophase gains < 0.5% on both genomes.
N2  randrot gains < 1.0% on both genomes.
