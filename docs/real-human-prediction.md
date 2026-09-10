# The cue on a real human pair: pre-registered prediction

**Written 2026-09-10, after the v0.8.0 run below and before the cue build
touched this pair.** Committed alone for the timestamp. The result goes in
`docs/real-human.md`.

## The pair

- **Target:** T2T-CHM13 v2.0 chromosome 21, NCBI `CP068257.2`: 45,090,682
  bases, no `N`.
- **Reference:** GRCh38 chromosome 21 (Ensembl, dnac's `chr21.fa`): 46,709,983
  bases, of which 6,621,364 are `N`.

Two different people, both assembled from real reads. CHM13 also contains the
p-arm and centromere that GRCh38 leaves as gaps. That is sequence no ear can
predict, so the prediction separates **shared** windows from the rest.

## Premises

| premise | value | command |
|---|---|---|
| v0.8.0, CHM13 chr21 against GRCh38 chr21 | **586,615 B**, round-trips | `dnac_base cr chm13_chr21.fa … chr21.state -map … -mapw 1000` |
| windows (1 kb) | 45,091 | map rows |
| windows below 0.2 bits/base under v0.8.0 (**"shared"**) | 39,888 (88.5%) holding **25.7%** of the bits | `python` over `chm13.base.map.tsv` |
| windows at or above 1.0 bits/base (**"novel"**) | 691 (1.5%), 23.4% of the bits | same |
| cue on simulated `chr21_ind` | −8.70% | `docs/cue.md` |

The shared set is fixed now, from the v0.8.0 map: the same window indices are
used for the cue build. The target is the same file, so the windows are paired.

## Predictions

**R1, whole chromosome:** the cue build is **≥ 1.0% smaller** than 586,615 B.
*50%.* Most of the bits sit where the sequences are unrelated, which caps the
whole-file gain.

**R2, shared windows:** bits in the fixed shared set fall **≥ 5%**. *50%.*
This is where real indels live and where the headphone ear can hear anything.

**R3, novel windows (≥ 1.0 bits/base under v0.8.0):** their bits change by less
than **±1%**. *60%.* No ear helps on new sequence, and the cue must not hurt it.

**R4, the osmosis on real data:** inside the shared set, the cue's relative gain
over v0.8.0 is larger in the second half of the chromosome than in the first.
*55%.*

**R5:** lossless.

## When to stop

If R2 fails with a gain under 1%, the simulation (`dnac mut`) misrepresented real
indels, the headline −8.70% is a simulator artefact, and that goes on record.
