# The cue that alternates decks: pre-registered prediction

**Written 2026-09-10. Not fully blind, and said so up front:** the build's
byte-identity check printed one size before this was written. On `ind_1` it
gave 48,309 B against the single-deck cue's 48,295 (+0.03%). Nothing else has
been measured. The result goes in `docs/cue-back.md`.

## What Timotheos added

His description of the method, after reading `docs/cue.md`:

> While A plays and B is to come in, the cue is on B. Once B's channel is up and
> heard on the speakers, so also in the other (outer) ear, the cue closes
> completely and the mix continues through the outer ear alone. *That* is the
> osmosis: judging with one ear and letting it acclimatise, instead of taking
> the headphones off and listening with both. Then, as A fades out, you turn
> the cue to A if you sense something is wrong, or wait for the mix to finish.
> The sources alternate at every change of track.

Most of this is already what `-DDNAC_CUE` does. The cue is on the candidate
(B). It closes at the mix-in. After that only the master, the outer ear,
carries the phase, and the cue's table is learned conditioned on the master's
state. **What was missing is the alternation:**

1. at the mix-in, the headphones go to **A**, the phase the master just left,
   while it fades;
2. if it is B that goes wrong and A keeps agreeing, A comes back by the same
   mix-in rule;
3. the ear knows which deck it is on: incoming or outgoing is part of the cue's
   table index.

A "fades out" by missing `MISS_MAX` times, and then the headphones are free for
the next candidate. `-DCUE_BACK=1` switches this on. `CUE_BACK=0` is
byte-identical to the cue measured in `docs/cue.md` (checked on `ind_1`).

## Why the prediction is small

The mix-in already requires `CUE_SWITCH = 12` agreeing bases, so mixing in the
wrong deck should be rare in `dnac mut` and `make_tumour` targets, where events
are isolated. Where the alternation could matter is real sequence, where
indels cluster in short tandem repeats, one slip after another, and the
"wrong" deck may be right a few bases later.

## Predictions

**B1.** On the controlled E. coli targets (substitution, random indel,
homopolymer slip) the per-event cost changes by **less than ±2%** from the
single-deck cue. *70%.*

**B2.** `chr21_ind` changes by **less than ±0.5%**. *65%.*

**B3, the one that could show something.** On the real pair (CHM13 chr21
against GRCh38 chr21, FASTA), the fixed shared windows of
`docs/real-human-prediction.md` improve by **≥ 0.5% more** than the single-deck
cue's −18.27%. *30%.*

**B4.** Lossless everywhere, and FASTA and state references are identical
(already seen on `ind_1`).

If B3 fails, the alternation is written down as not measurable on these data,
and the single-deck cue stays as the version to keep.
