# Which cue loads alternate -- result

Run 2026-09-27, pre-registered in `docs/balance-loads-prediction.md` (commit 41d51b0).
Recipe: `python scripts/pilot/balance-loads.py <chain.gz> chr21 <chm13_chr21.tsv> 40088619`
(chr22: 39159777). Chain file SHA-256 926d4583eda8f90c88434293859b06906573f2469630e898b8b475ac8751327a.

| | chr21 | chr22 | prediction | verdict |
|---|---:|---:|---|---|
| loads within 20 b of a real indel | 7.4% | 5.2% | < 30% | **L1 held** |
| neither-neither pairs, same-sign excess | **-1.65 pp** (n 167,175) | **-1.49 pp** (n 243,473) | <= -1 | **L2 held** |
| indel-indel pairs | **+5.39 pp** (n 8,022) | **+6.62 pp** (n 7,780) | >= 0 | **L3 held** |

**The guess is supported.** More than nine loads in ten have no real indel behind them.
Those are the ones that alternate. Where a real indel is present, the cue's signs keep
their direction, as the independent alignment does (+13-15 pp). The "balancing wave"
seen in our logs is the cue correcting its own false loads, not the genomes balancing.

A side finding for the codec, not a lever yet: 93-95% of cue loads are not at an indel.
That fits the rotation/riding results, where the cue earns about a quarter of a percent.
Whether filtering false loads is worth anything needs its own pre-registration.
