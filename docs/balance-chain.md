# The balancing wave without our codec -- result

Run 2026-09-26, pre-registered in `docs/balance-chain-prediction.md` (commit 11fc31e).
Data: UCSC `hg38ToHs1.over.chain.gz` (2,678,042 B, fetched 2026-09-26), best + / + chain
per chromosome. Recipe: `python scripts/pilot/balance-chain.py <chain.gz> chr21 chr22`.

| | chr21 | chr22 |
|---|---:|---:|
| simple indels 1-50 bp (ins / del) | 10,934 (5,778 / 5,156) | 11,652 (5,918 / 5,734) |
| A all: same-sign excess | +2.12 pp | +2.60 pp |
| A near (< 100 bp) | **+14.52 pp** (n 1,423) | **+12.96 pp** (n 1,316) |
| A far (>= 1 kb) | +0.22 pp | +2.07 pp |
| near pairs that exactly undo (opposite sign, equal size) | 13.35% | 11.09% |
| B R(100) | 1.085 | 1.043 |
| B R(1k) | 1.171 | 1.200 |
| B R(10k) | 1.115 | 1.270 |
| B R(100k) | 1.008 | 1.171 |
| B R(1M) | **0.657** | **0.670** |

| | prediction | outcome |
|---|---|---|
| C1 | near excess <= -1 pp, both | **failed, inverted**: +14.5 / +13.0 pp (nearby indels share their sign) |
| C2 | far within +-1 pp, both | chr21 held, chr22 failed (+2.07) |
| C3 | R(100) < 0.95, both | **failed**: 1.085 / 1.043 |
| C4 | R(100k), R(1M) within 0.8..1.2, both | **failed at 1M on both**: 0.657 / 0.670 |

## What the rule says

- **C1 failed, so the local alternation in our cue logs belongs to our search, not to
  the genome pair.** In an independent alignment, nearby indels do not undo each other;
  they cluster with the same sign. A likely reading, not tested here: most cue loads on
  unique sequence are triggered by substitutions, not indels, and the search then finds a
  spurious 3-base agreement. The aligner has its own convention too (one event split into
  two gaps of the same sign), so the +14 pp is not a clean biological figure either.
- **R(1M) < 0.8 on both chromosomes** is the one outcome the rule named as supporting
  the thesis beyond local effects. The rule's own consequence: a third pair before it is
  believed. Between 1 kb and 100 kb the opposite holds (R > 1: momentum). **Not yet
  checked, and it matters:** at 1 Mb a chromosome gives only about 40 independent
  windows, so one observed value against the MEAN of 20 permutations says nothing about
  its spread. The third-pair pre-registration therefore also fixes a percentile test.
  That test is stricter than the original rule, not looser, and is written before chr20
  is looked at: `docs/balance-chain-chr20-prediction.md`.
