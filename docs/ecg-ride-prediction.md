# ECG: does a tempo-following copy earn what a fixed-tempo copy did not? -- pre-registration

Written 2026-09-26, before any run. Follows the signals-as-DNA test of the same day,
which lost its bar: the match/cue part earned 0.06-0.94% on ECG. It was run on
quartile symbols, which throw information away, so it did not test the mechanism on
the signal itself. This one runs on the raw signal, losslessly.

## Data
MIT-BIH Arrhythmia DB, records 100, 101 (mostly regular rhythm), 119 (ventricular
bigeminy/trigeminy), 208 (frequent PVCs); channel 0, 650,000 samples at 360 Hz,
11-bit, format 212 (the same .dat files as the earlier test).

## Three predictors, all causal and integer, so each is exactly decodable
- LIN  (trivial opponent): the better of x[t-1] and 2x[t-1]-x[t-2] per file.
- FIX  (fixed tempo): a causal R-peak detector gives RR = distance between the last two
  detections (clamped 120..700). The copy predicts x[t-1] + (x[t-L]-x[t-L-1]) with
  L = RR, held for the whole beat. Per sample, a selector picks copy or
  2x[t-1]-x[t-2] by the smaller sum of |error| over the last 8 samples.
- RIDE (tempo following, the DJ): identical, except that inside the beat the lag rides.
  Each sample it moves to L-1, L or L+1, whichever had the least slope mismatch over the
  last 8 samples (ties keep L). At each detection the lag reloads to RR (the cue load).
Metric: zeroth-order entropy of the residual, bits/sample. It is the same estimator
for all three, so the comparison is fair. It is an estimate, not a file.
Losslessness: each predictor is run a second time as a DECODER from its residuals;
the reconstruction must equal the input sample for sample, or the run is void.

## Prior art, stated before the run
A copy of the previous period with a tracked lag is long-term prediction: the pitch
predictor / adaptive codebook of speech codecs (CELP, 1980s), applied to ECG as
beat-to-beat prediction (e.g. Nave & Cohen, IEEE TBME 1993). The mechanism class is
occupied. The question is only whether our variant (cue reload + ±1 riding) earns.

## Predictions
R1  RIDE beats FIX by >= 3% on both 100 and 101.
R2  RIDE beats LIN by >= 3% on both 100 and 101.
R3  RIDE is never worse than LIN by more than 0.5% on any record (the selector
    protects).
(My expectation: R2 holds and R1 is doubtful, because the beat-to-beat drift that
riding follows may be smaller than the noise.)

## Bar, fixed now
"Tempo following fits ECG" = R1 AND R2 on both 100 and 101. Anything less and it
does not, whatever 119/208 show.
