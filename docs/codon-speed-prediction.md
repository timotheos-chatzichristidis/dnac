# Codon tracker: speed, at every level -- pre-registration

Written 2026-09-27, before any variant below existed. The round-2 tracker behind the
round-3 gate (docs/codon-gate.md) costs +33% encode on E. coli at level 3 (min of 3:
10.48 -> 13.89 s). A same-session split: labels alone (the oracle build, no tracker) cost
+21%, the tracker itself the remaining +12%. The labels' cost is memory: the direct tables
grow 8x, so order 8 goes from about 0.4 MB to 3 MB, and the hashed tables hold 7x the
contexts.

## Variants (run-time switches in one scratch build, round-2 tracker otherwise unchanged)
- S0  round 2 as measured (reference for speed)
- S1  tracker log2 from a precomputed table; tracker counts halve at 8191 instead of 65535
- S2  phase fed only to order models of order <= 11 (higher orders stay unphased)
- S3  direct tables interleaved: the 8 phase slots of one context sit side by side
      (one cache line) instead of 4^order apart
- S123  all three together

## Measurements
- SIZE: every variant at levels 1, 2, 3, 4 on E. coli, B. subtilis, P. aeruginosa and
  S. aureus, gated by round 3's rule (G >= 2.0, so ON for all four; human unaffected, the
  gate is OFF). Every archive decoded and compared with cmp. Release at the same level is
  the reference.
- TIME: E. coli, encode AND decode, min of 3 alternating rounds, at every level: release,
  S0, and every variant that passes the size condition below.

## Predictions
W1  S3 is size-identical in effect (within 0.01%) and removes most of the label cost.
W2  S2 keeps >= 80% of S0's gain at level 3.
W3  S123 encode overhead at level 3 <= 15%.
W4  At level 1 (6 orders, 2 experts, no IR) the tracker gains less than at level 3.

## Decision rule (fixed now)
A variant is ELIGIBLE at a level if its gated gain there is >= 1.5% on E. coli and >= 1.0% on
each of the other three bacteria (round 3's bar, unchanged). Among eligible variants the
fastest encode is the CANDIDATE for that level. Recommendation to Timotheos, whose decision
it is:
- candidate's encode AND decode overhead <= 10% at a level -> into that level's default;
- 10-25% -> a new level or an opt-in flag;
- > 25% or no eligible variant -> opt-in flag only, or not shipped at that level.
Nothing is adopted by this step; implementation in dnac.c and the full re-measurement
follow separately.
