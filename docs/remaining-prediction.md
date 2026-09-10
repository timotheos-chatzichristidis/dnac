# The remaining tests: pre-registered

**Written 2026-09-10, blind.** The 2x2 ablation builds are compiled and have not
been run. `CUE_MIXFREE=0` is byte-identical to the measured cue, and the default
build to v0.8.0 (both checked on `ind_1`). No chr22 file has been downloaded.
Results go in `docs/remaining.md`.

## T1. Robustness (running while this is written)

`scripts/roundtrip.sh`, dnac's own losslessness suite (adversarial inputs,
every `k`, every level, reference mode, state files, block mode), on every new
build: base, cue, cue without room, cue alternating, nudge L5D12, nudge L6D12.
**Prediction: all pass.** Anything else blocks every result on this branch
until fixed.

## T2. Time, paired

Base against cue: `cr` of `ind_1.fa` against `ref.state`, and of
`chr21_slice`-sized input. Back to back in one loop, 3 rounds, **minimum**
quoted (METHOD, 24% noise).
**Prediction: the cue costs less than 10% more time.** It adds one follow step
per base and a ≤ 24-candidate search per established miss. *75%.*

## T3. Where the osmosis happens: the 2x2

`docs/cue-room.md` left two readings. Either hearing the cue through the room
does not matter, or the mixer already does it one layer up: two of its four
experts choose their weights by the match state. `CUE_MIXFREE=1` gives the cue
**one context-free weight** in those two experts, so the mixer cannot hear it
through the room either.

| | cue table heard through the room | not |
|---|---|---|
| mixer hears the cue through the match state | cue (measured) | noroom (measured) |
| mixer does not | **mf** | **mf_noroom** |

**If the osmosis lives in the mixer** (the reading that saves Timotheos's claim
in a different place):
- **M1.** `mf_noroom` is worse than `mf` by **≥ 3%** in random-indel or slip
  cost. The room matters once the mixer cannot supply it. *45%.*
- **M2.** `mf_noroom` loses **≥ 1 point** of `chr21_ind`'s −8.70%. *40%.*

**If the integration matters nowhere,** M1 and M2 fail and all four corners sit
within ~1%.

M3. Substitutions within ±1% in every corner. *70%.*

## T4. Replication on a second real pair: chromosome 22

T2T-CHM13 chr22 (NCBI `CP068256.2`) against GRCh38 chr22 (Ensembl, same release
family as `chr21.fa`). Fresh downloads, same method as `docs/real-human.md`:
the shared set is fixed from the v0.8.0 map at < 0.2 bits/base before the cue
runs.
- **R22a.** Whole file **≥ 2% smaller** with the cue. *60%.* (chr21: −5.97%)
- **R22b.** Shared windows **≥ 8% fewer bits.** *60%.* (chr21: −18.27%)
- **R22c.** Novel windows (≥ 1.0 bits/base) within ±1%. *75%.*
- **R22d.** Lossless.

If chr22 misses R22a and R22b both, chr21 was a lucky chromosome, and that goes
into `real-human.md` as a qualification.
