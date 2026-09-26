# ECG: tempo-following copy -- result

Run 2026-09-26, pre-registered in `docs/ecg-ride-prediction.md` (commit ad2ff05).
Recipe: `python scripts/pilot/ecg_ride.py bench-external/pilot/mitbih 100 101 119 208`
(the .dat SHA-256s are in the commit message of this file's commit). **Every predictor
was decoded back from its residuals and matched the input sample for sample.**

Zeroth-order entropy of the residual, bits/sample:

| rec | LIN | FIX | RIDE | RIDE vs FIX | RIDE vs LIN |
|---|---:|---:|---:|---:|---:|
| 100 | 3.8385 | 3.9603 | 3.8378 | **-3.09%** | -0.02% |
| 101 | 3.9674 | 3.9667 | 3.8653 | **-2.56%** | -2.57% |
| 119 | 4.2570 | 4.2269 | 4.1484 | -1.86% | -2.55% |
| 208 | 4.3179 | 4.3425 | 4.2915 | -1.17% | -0.61% |

| | prediction | outcome |
|---|---|---|
| R1 | RIDE beats FIX by >= 3% on 100 and 101 | **failed**: 101 is -2.56% |
| R2 | RIDE beats LIN by >= 3% on 100 and 101 | **failed**: -0.02% / -2.57% |
| R3 | RIDE never worse than LIN by > 0.5% | held |

**The bar fails: tempo following does not fit ECG in this form.** The number that
stands: riding beats the fixed-tempo copy on **all four records** (-1.17 to -3.09%),
so following the tempo is always worth something. It is never worth the 3% that was
asked for, and the 3% stays where it was set.

## Post hoc, labelled as such, decides nothing
The registered selector falls back to 2x[t-1]-x[t-2]. On 100 and 101 the plain
x[t-1] is much the better linear predictor (3.84 against 4.00), so the copy was paired
with the worse partner there. Swapping the fallback to x[t-1] (same code, one line):

| rec | FIX | RIDE | RIDE vs FIX | RIDE vs LIN |
|---|---:|---:|---:|---:|
| 100 | 3.7859 | 3.6826 | -2.73% | -4.06% |
| 101 | 3.7907 | 3.7129 | -2.05% | -6.41% |
| 119 | 4.3608 | 4.2879 | -1.67% | +0.73% |
| 208 | 4.6713 | 4.6141 | -1.23% | +6.86% |

Two readings survive both versions. **Riding over fixed tempo is a steady 1.2-3.1%,
eight out of eight.** How much copying the beat is worth at all depends on the fallback
it is paired with. That second part is the long-term prediction of the prior art, not
our mechanism. A selector over {x[t-1], 2x[t-1]-x[t-2], copy} on held-out MIT-BIH
records would settle it, and it needs its own pre-registration. That test measures the
prior art's lever, though. Ours, riding, is 1-3%.
