# Long-range restoring force: the third pair -- result

Run 2026-09-26, pre-registered in `docs/balance-chain-chr20-prediction.md` (commit 56eadcb).
Recipe: `python scripts/pilot/balance-chain-pct.py <chain.gz> chr20 chr21 chr22`
(200 sign permutations, seed 20260926).

| | events | R(100k) | pct | R(1M) | pct |
|---|---:|---:|---:|---:|---:|
| **chr20** (decides) | 14,192 | 1.200 | 99.0% | **1.044** | **62.0%** |
| chr21 (post hoc) | 10,934 | 1.002 | 56.0% | 0.660 | 4.5% |
| chr22 (post hoc) | 11,652 | 1.196 | 98.5% | 0.658 | 6.0% |

E1 (chr20 R(1M) >= 0.8) **held**; E2 (above the 5th percentile) **held**. By the rule:
**the 1 Mb restoring force does not replicate**, and the balancing-wave thesis gets no
support from the GRCh38/CHM13 pair. The chr21/chr22 figures sit at the 4.5th and 6th
percentiles of their own null, which is what two borderline draws look like. The
statistic reports the mean over only about 40 one-Mb windows, and the ratio to a mean
had hidden that.

What the data do show, at every scale where they show anything, is the **opposite of
balancing**: nearby indels share their sign (+13-15 pp under 100 bp), and at 100 kb
two of three chromosomes sit at the 98.5-99th percentile of MOMENTUM (regions where one
genome is net longer). A likely reading, not tested: regional differences such as
repeat collapses in GRCh38, not a force.

## Summary of the three checks of 2026-09-26
1. Pilot wave (docs/pilot-wave.md): the mapping holds, and every row that fits is already built.
2. Slip alternation (docs/balance-wave.md): real in our logs, but local and in unique sequence.
3. Codec-free (this and docs/balance-chain.md): the alternation is our search's, not
   the genome's, and the one long-range hint did not survive a third chromosome.
