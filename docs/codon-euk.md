# Codon tracker on eukaryotes -- result: the gate has TWO false positives

Pre-registration: docs/codon-euk-prediction.md (commit 5467747, before any genome was
fetched). Run 2026-10-11 on branch `codon-euk`. Build: main + the scratch env switch
`DNAC_CODON_FORCE` (commit after 5467747); with it unset the build wrote archives
sha256-identical to main on `ecoli.fa` and `chr21_slice.fa` at level 1 (negative
control). Every archive decoded and compared with `cmp`. Level 1, k = 22.

Genomes as fetched from NCBI efetch (unversioned accessions resolved to the versions in
the deflines), sha256 prefix:

| file | records | bytes | sha256 |
|---|---:|---:|---|
| scer.fa (S. cerevisiae S288C, NC_001133.9 .. NC_001148.4) | 16 | 12,245,035 | 0ecec27e75088f90 |
| spom.fa (S. pombe 972h-, NC_003424.3, NC_003423.3, NC_003421.2) | 3 | 12,751,674 | 7ad3d2aaef17a93e |
| atha1.fa (A. thaliana chr 1, NC_003070.9) | 1 | 30,862,410 | 1ff654d386b5f96b |
| cele1.fa (C. elegans chr I, NC_003279.8) | 1 | 15,287,805 | bfff603b771c1ab8 |
| dmel2L.fa (D. melanogaster 2L, NT_033779.5) | 1 | 23,849,675 | 2c9a023880323887 |

## Result

E0 = `-nocodon`, E1 = release default (the gate decides; `DNHI` = tracker on, `DNHE` =
off), E2 = tracker forced on. Gain = (E0 - size) / E0.

| genome | G | gate | E0 | E1 | E2 | forced gain | verdict |
|---|---:|---|---:|---:|---:|---:|---|
| S. cerevisiae | 9.3036 | ON | 2,753,963 | 2,728,186 | 2,728,186 | **+0.9360%** | right |
| S. pombe | 7.4125 | ON | 2,917,621 | 2,900,741 | 2,900,741 | **+0.5786%** | right |
| A. thaliana chr 1 | 2.8121 | ON | 6,556,231 | 6,561,555 | 6,561,555 | **-0.0812%** | **false positive, a loss** |
| D. melanogaster 2L | 2.4594 | ON | 5,307,611 | 5,312,525 | 5,312,525 | **-0.0926%** | **false positive, a loss** |
| C. elegans chr I | 1.9032 | OFF | 3,212,322 | 3,212,322 | 3,225,651 | -0.4149% | right |

**By the rule fixed in advance, the gate is a candidate for change**: two false positives,
each a loss. Both losses are small (under 0.1%), but the release build ships them today
to anyone who compresses a plant or fly chromosome at the default level.

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| table, G | yeast 2.2-3.2, pombe 1.8-2.6, others 1.2-1.8 | **miss, every one low**: 9.30, 7.41, 2.81, 1.90, 2.46. Two yeasts sit far ABOVE the bacteria (3.26-5.09) |
| table, gate | ON, borderline, OFF, OFF, OFF | 2 of 5: plant and fly open the gate |
| table, gain | +1.0..2.0, +0.6..1.5, +0.2..0.6, +0.1..0.4, +0.1..0.4 | **miss**: +0.94, +0.58, -0.08, -0.41 (forced), -0.09; yeast just under, pombe in range, the other three negative |
| Q1 | G orders by coding fraction | mostly: yeast > pombe > plant > fly > worm; fly (~20% coding) above worm (~25%) is the one inversion |
| Q2 | forced gain never below -0.05% | **failed**: -0.08, -0.09, and -0.41% on the worm |
| Q3 | gate right on >= 4 of 5 | **failed**: 3 of 5 |

## What it says

1. **G measures the strength of the period, not whether the tracker can follow it.**
   Yeast genes are long, intron-poor and densely packed: G is twice a bacterium's, and the
   tracker gains about 0.9%, less than on any bacterium (1.70-3.94%). The period is there,
   but a bacterial genome is almost all coding, while yeast's ~30% of non-coding sequence
   sits between genes the tracker has to re-lock onto.
2. **Where genes are split by introns, the tracker loses.** Plant (~33% coding), fly and
   worm all lose when it runs. Every intron is a frame break the tracker learns only after
   the fact, and the phase labels split the order models' statistics into seven while it
   is wrong. G still clears 2.0 on the plant and the fly because exons carry a strong
   period-3 signal even when they are a minority of the sequence.
3. **No published number is affected by a change of the gate.** Every file in README.md
   has G >= 3.26 (the bacteria) or G <= 1.17 (human), so any new rule that keeps G >= 3.26
   ON and closes the gate between 2.0 and 2.81 flips no figure in the docs, only files of
   the kind measured here. The decision moves no format either: the family letter tells
   the decoder.

## Next step (to be pre-registered, not done here)

Two candidate rules, to be tested on genomes NOT used here (other plants, insects,
protists, fungi with introns, and the four bacteria + human as a regression check):
- **raise the threshold** -- 3.0 closes both false positives and keeps every bacterium
  open, but 3.26 vs 3.0 is a thin margin, and it is fitted to these five genomes;
- **trial gate** -- code a sample (say 1 Mbase from the middle) both ways and keep the
  tracker only if it wins. It measures the thing that matters, the gain, instead of a
  proxy, and costs one extra pass over the sample.
