# The balancing wave: in the genome, or in our search? -- result

Run 2026-09-26 on branch `pilot-wave`, pre-registered in
`docs/balance-wave-prediction.md` (commit 4e9cc01, sha256 0f5a79a8...). Data: the cue-load
logs of 2026-09-18 (docs/after-090.md, experiment B). Recipe:
`python scripts/pilot/balance-split.py <label> <tsv> <ref.fa> <target.fa>`.
The log positions were checked against the reduced FASTAs: refn = 40,088,619 / 39,159,777
(chr21 equals grch38_chr21.seq to the byte), 0 loads out of range.

| pairs of consecutive non-tied loads | chr21 n | chr21 excess | chr22 n | chr22 excess |
|---|---:|---:|---:|---:|
| all (T0, instrument) | 186,593 | **-1.12 pp** | 263,179 | **-1.10 pp** |
| unique-unique | 144,857 | **-1.45 pp** | 210,712 | **-1.60 pp** |
| tandem-tandem | 24,258 | +0.46 pp | 30,737 | +1.20 pp |
| mixed | 17,478 | -1.32 pp | 21,730 | -1.27 pp |
| near (< 100 bases) | 149,425 | -1.37 pp | 207,186 | -1.37 pp |
| far (>= 1000 bases) | 8,811 | +0.55 pp | 9,636 | +0.35 pp |

| | prediction | outcome |
|---|---|---|
| T0 | reproduces -1.12 / -1.10 | **held**, exactly |
| T1 | unique-unique within +-0.5 pp | **failed, both**: -1.45 / -1.60 (about 11 SE from zero) |
| T2 | tandem-tandem <= -2 pp | **failed, inverted**: +0.46 / +1.20 (repeats show momentum) |
| T3 | far within +-0.5 pp | chr22 held; **chr21 failed by 0.05** (+0.55; SE ~ 0.53, so no evidence either way) |

**My hypothesis was wrong.** The alternation is not the search getting lost in tandem
repeats. It is strongest in unique sequence, it is local (under 100 bases), and it is
gone at 1 kb. Inside tandem repeats the signs keep their direction instead.

**The decision rule:** unique-unique <= -1 pp on both chromosomes, so the alternation
survives outside repeats. The pre-set consequence is a codec-free follow-up before
anything is said about genomes: `docs/balance-chain-prediction.md`.
