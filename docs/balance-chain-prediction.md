# The balancing wave without our codec -- pre-registration

Written 2026-09-26 after docs/balance-wave.md, before any data below was fetched.

## Why
Our cue logs show consecutive slip signs alternating (unique sequence -1.45/-1.60 pp,
local). That is still OUR search's reading. An alignment made by someone else
decides whether the balancing is in the genome pair: the UCSC liftOver chain
hg38 -> hs1 (CHM13v2), whose gap lines give each indel directly (dt > 0, dq = 0:
bases of GRCh38 absent in CHM13; dq > 0, dt = 0: the opposite).

## What is measured (chr21 and chr22, chr22 is the replication)
Only simple indels (one side 0) of 1..50 bp in the best chain per chromosome.
Sign s = +1 insertion in CHM13, -1 deletion.
A. Sign alternation: excess of P(consecutive same sign) over the baseline from
   the marginal, split by the distance between the two (near < 100, far >= 1000).
B. Restoring force. X(x) = cumulative (ins - del) bp along GRCh38. For lags
   L in {100, 1k, 10k, 100k, 1M} compute D(L) = mean over events-pairs of
   [X(x+L) - X(x)]^2, sampled on a grid, and divide it by the same quantity
   with the signs randomly permuted (positions and sizes kept; mean of 20
   permutations). R(L) < 1 = balancing (a displacement tends to be undone),
   R(L) = 1 = random walk, R(L) > 1 = momentum.

## Predictions
C1  A, near: excess <= -1 pp on both chromosomes (the alternation is the genome's).
C2  A, far: within +-1 pp on both.
C3  B: R(100) < 0.95 on both (local balancing).
C4  B: R(100k) and R(1M) within 0.8..1.2 on both (no long-range restoring force).

## Decision rule (fixed now)
- C1 fails on either chromosome -> the alternation in our logs is our search's,
  not the genome pair's. The balancing-wave claim gets no support from these data.
- C1 and C3 hold, C4 holds -> balancing exists in the genome pair but only locally
  (tens of bases): a displacement is often undone right away. Reported as a local
  fact; it does not generalise to a law of opposites.
- R(100k) or R(1M) < 0.8 on BOTH chromosomes -> a long-range restoring force.
  That would be the one result that supports the thesis beyond local effects,
  and it would need a third pair before being written anywhere outside docs/.
- For compression, whichever way this goes: the sign excess is worth ~15 B on
  chr21 (1 - H(0.4855) per load), so nothing here is a compression lever.
