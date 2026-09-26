# Long-range restoring force: the third pair -- pre-registration

Written 2026-09-26 after docs/balance-chain.md, before chr20 was read. chr20 was
chosen because it is the autosome closest in size to chr21/chr22 that was not
looked at; no other chromosome has been run.

Same recipe, plus the spread of the null: 200 sign permutations at L = 1M and
100k; report where the observed D falls (percentile). chr21 and chr22 get the same
percentile computed, post hoc, for reference only -- it decides nothing for them.

## Predictions (mine)
E1  chr20 R(1M) >= 0.8 (I expect the chr21/chr22 figure to be the spread of a
    40-window statistic, not a force).
E2  chr20 observed D(1M) above the 5th percentile of its 200 permutations.

## Decision rule
- Long-range restoring force is supported only if chr20 R(1M) < 0.8 AND its
  observed D(1M) is below the 5th percentile of the permutations. Then it goes to
  a fourth, larger check (all autosomes) before any sentence outside docs/.
- Otherwise the 1M figure on chr21/chr22 is recorded as not replicated, and the
  balancing-wave thesis has no support from the hg38/CHM13 pair.
