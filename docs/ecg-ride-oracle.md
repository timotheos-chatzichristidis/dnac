# ECG riding: tempo, or a bad detector? -- result

Run 2026-09-27, pre-registered in `docs/ecg-ride-oracle-prediction.md` (commit 0e6a4c3).
Annotations: PhysioNet mitdb 1.0.0 `.atr`, SHA-256 100 8d8a5349, 101 441cdd64,
119 fd919c8e, 208 33878519 (prefixes). Recipes (the script now carries the
fallback flag too, so the post-hoc table of docs/ecg-ride.md is runnable):

    python scripts/pilot/ecg_ride.py bench-external/pilot/mitbih 100 101 119 208               # registered run + detector accuracy
    python scripts/pilot/ecg_ride.py bench-external/pilot/mitbih 100 101 119 208 --fallback=d1 # the post-hoc table
    python scripts/pilot/ecg_ride.py bench-external/pilot/mitbih 100 101 119 208 --oracle      # this check

The extended script reproduces both earlier tables to four decimals. Every run was
decoded back sample for sample.

## (a) The detector

| rec | sensitivity | positive predictivity |
|---|---:|---:|
| 100 | 99.96% | 99.91% |
| 101 | 99.84% | 99.15% |
| 119 | 99.95% | 99.70% |
| 208 | **88.60%** | 97.76% |

The detector is essentially exact on three records. On 208, which has frequent PVCs,
it misses about one beat in nine.

## (b) Oracle beats

| rec | RIDE vs FIX, causal detector | RIDE vs FIX, oracle beats |
|---|---:|---:|
| 100 | -3.09% | **-3.00%** |
| 101 | -2.56% | **-2.57%** |
| 119 | -1.86% | -1.41% |
| 208 | -1.17% | **-0.70%** |

**By the rule: partial.** On 208 the oracle gain is weaker than -1%, so the "all four"
branch fails. On 100 and 101 it stays far below -0.5%, so the withdrawal branch does
not apply either.

**What it means:** on regular rhythm the riding gain is the heart's tempo. It does not
move when the beats are exact (-3.00 / -2.57%). On the arrhythmic records part of it
was riding repairing the detector: on 208 roughly 40% (-1.17 -> -0.70). The 8/8
finding stands as a tempo claim for regular rhythm, and is smaller than first reported
where the rhythm is irregular.
