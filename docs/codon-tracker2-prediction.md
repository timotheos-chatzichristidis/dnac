# Codon-phase tracker, round 2 -- pre-registration

Written 2026-09-27, before any round-2 code existed. Round 1 (docs/codon-tracker.md) locked
the phase but never split the strand and never chose non-coding: E. coli 1.5775%,
B. subtilis 0.8909% (bar 1.0), chr21_slice +0.1209% (bar +0.1).

## Two structural changes, both aimed at a diagnosed failure. No parameter moves.
1. **Strand by construction.** Statistics are kept in GENE orientation. G_fwd[c] predicts a
   base from the 5 before it, and G_bwd[c] predicts it from the 5 after it, where c is the
   codon position. A + hypothesis predicts x_t with G_fwd. A - hypothesis predicts it with
   G_bwd applied to the complemented bases, because read forward a - gene is a + gene read
   backwards on the other strand (the palintropos idea). Every trained base feeds both
   tables: + labelled data trains G_fwd directly and G_bwd with the base 5 back; - labelled
   data does the mirror. So what one strand teaches, the other can use at once.
2. **Non-coding as the default.** A background order-5 model N trains on every base. The
   tracker keeps a leading PHASE hypothesis P* among the six (hysteresis 4 bits). The
   phase tables always train with P*'s labels. The codec receives P*'s label only while
   P* leads N by more than 4 bits, and label 6 otherwise. It starts at label 6.
Unchanged from round 1: order 5, decay 1 - 1/128, margin 4 bits, count prior +1/2, halving
at 65535, and the codec-side plumbing (order contexts, expert-4 weights, IR with strand swap).

## Runs
Same recipe and files as round 1. **B. subtilis is the held-out genome.** It was used in
round 1, but no round-2 design choice was taken from its numbers. That is stated and not
hidden: round 1's diagnosis was read on both genomes and agreed on both. E. coli encode
time is min of 3, alternating. Labels are compared with the annotation after the best
renaming.

## Predictions
U1  E. coli gain 2.0-3.0%.
U2  B. subtilis gain >= 1.0%.
U3  chr21_slice within +-0.05% of rel.
U4  label agreement on coding bases after renaming: 60-85% (E. coli).

## Bar (the same as round 1, unchanged)
>= 1.5% on E. coli AND >= 1.0% on B. subtilis AND chr21_slice <= +0.1%. If it passes, it is
a format candidate: time, level or flag, and the full re-measurement are pre-registered next.
If it fails, the codon lever gets a written decision (a third round or a close) before any
more code.
