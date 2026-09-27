# The cue's phase choice: what would a perfect search buy? -- pre-registration

Written 2026-09-27, before any run. docs/cue-source.md found that only ~10% of cue loads
pick the shift that the next 30 bases favour. Today the cue takes the FIRST shift whose
last 3 bases agree (smallest |a|, negative first). Two builds test whether choosing
better matters. Both are scratch patches of this branch's dnac.c
(`scripts/pilot/cue-phase.patch`); with no variable set the patched build must write
archives byte-identical to rel, and that is checked.

## Variants (the load TRIGGER is unchanged: they only choose among the same candidates
## the release search would have found, all shifts +-1..12 whose last 3 bases agree)
- rel        release choice: the first candidate.
- ph-oracle  the candidate that agrees best with the NEXT 30 bases (ties: release order).
             The encoder reads the future from a side file; the shifts it chose are
             written to a second side file, which the decoder replays in order. This is a
             ceiling, not a codec. Target loads only; priming is unchanged.
- ph-back    a real rule, no side information: the candidate whose context agrees
             furthest BACK (back_agree up to 32; ties: release order). It applies
             everywhere, priming included, as a codec would.
Reference mode, level 3, k 22, CHM13 chr21 (decides) and chr22 (replication) against
GRCh38. Every archive is decoded and compared with cmp.

## Predictions
P0  instrument: rel 547,019 / 742,177 B; patched build without variables byte-identical.
P1  ph-oracle smaller than rel on chr21 by 0.5-2%.
P2  ph-back smaller than rel on chr21 by 0-0.3%.

## Decision rule (fixed now)
- ph-oracle gains < 0.6% on chr21 or < 0.3% on chr22 -> the phase-choice lever is closed,
  whatever ph-back shows (a real rule cannot be trusted to beat a ceiling below the bar).
- Otherwise the lever is open. ph-back is then judged on the standing adoption bar:
  >= 0.3% on chr21 and the same sign on chr22 at more than half the magnitude. If it
  passes, it is a candidate for a format change and goes to the full re-measurement
  before any tag. If it fails, the lever is open and a better real rule needs its own
  pre-registration.
