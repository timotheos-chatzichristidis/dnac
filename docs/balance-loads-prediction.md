# Which cue loads alternate: the ones at real indels, or the rest? -- pre-registration

Written 2026-09-27, before the run. docs/balance-chain.md concluded that the slip
alternation belongs to our search, and guessed, untested, that most cue loads on unique
sequence are triggered by substitutions and land on a spurious 3-base agreement. Test:
map every chain indel (1-50 bp, best chr21/chr22 chain) to CHM13 coordinates. Call a cue
load "at an indel" if a real indel lies within 20 bases of it. Compute the same-sign
excess (the momentum.py statistic, non-tied loads) for consecutive pairs where both are
at an indel and where neither is.

Predictions:
L1  fewer than 30% of loads are at a real indel, on both chromosomes.
L2  neither-neither pairs: excess <= -1 pp on both (the alternation is there).
L3  indel-indel pairs: excess >= 0 on both (like the chain itself).
Rule: L2 and L3 hold -> the guess is supported: the alternation comes from loads with no
indel behind them. Otherwise the guess is withdrawn and the source stays unexplained.
