# A real codon-phase tracker -- pre-registration

Written 2026-09-27, before any code for it existed. The ceiling (docs/codon-oracle.md):
true phase = 3.7504% (E. coli) / 3.0721% (B. subtilis). Unaligned phase (the randrot
control, roughly what a fixed mod-3 cycle can give) = 1.1309% / 0.8760%.

## The tracker (no side information; the decoder runs the same code)
Seven hypotheses, each a fixed label sequence over the genome: + strand with offset
k (label (t+k) mod 3), - strand with offset k (label 3 + (k-t) mod 3), and non-coding
(label 6). Within one gene exactly one hypothesis is right, and it stays right, so
tracking means detecting which hypothesis holds and when it changes. That is
beatmatching on period 3.
- One shared table P(base | previous 5 bases, label): 7 x 4^5 contexts, counts with a
  +1/2 prior, halved at 65535.
- After each base, every hypothesis scores log2 P(base | context, its label), with an
  exponential decay of 1 - 1/128 (a memory of about 128 bases).
- The label used for the next base is that of the best-scoring hypothesis. The current
  one is replaced only when another leads it by more than 4 bits (hysteresis). Ties go to
  the lower index.
- The table is trained with the label the codec actually used (hard, self-training).
- The codec consumes the label exactly as the oracle did (order-model contexts, expert-4
  weights, inverted-repeat training with the strand swapped), using the label stored for
  each past base.
Parameters are fixed here: ONE run per genome, no sweep. If it misses, any tuned second
round must tune on E. coli only and hold B. subtilis out.

## Runs
Plain mode, level 3, k 22: E. coli, B. subtilis, and chr21_slice.fa (human, few genes)
as the no-regression check. Every archive decoded and compared with cmp. With the variable
unset the build must stay byte-identical to rel. Encode time is measured, min of 3 on E. coli
(release vs tracker, alternating), and reported but not judged. Tracker labels are logged
and compared with the annotation afterwards; that is a diagnostic, not a criterion.

## Predictions
T1  E. coli gain between 1.0% and 2.5%.
T2  label agreement with the annotation (coding bases, exact label) between 50% and 80%.
T3  chr21_slice within +-0.1% of rel.

## Bar (fixed now)
The tracker "works" if it gains >= 1.5% on E. coli AND >= 1.0% on B. subtilis AND
chr21_slice costs no more than +0.1%. 1.5% sits above the unaligned control (1.13%),
so passing means the tracker finds ALIGNED phase, not merely period 3. If it passes, it
becomes a format candidate: the time cost, a new level or flag decision, and the full
re-measurement come after, each pre-registered. If it fails, the result is recorded and a
second round needs its own pre-registration.
