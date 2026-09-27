# ECG riding: tempo, or a bad detector? -- pre-registration

Written 2026-09-27, before the run. docs/ecg-ride.md found RIDE beating FIX on 4/4
records by 1.17-3.09%. Both use a crude causal R detector that was never checked. If it
misses or misplaces beats, FIX copies at a wrong lag for a whole beat and riding may
only be repairing the detector, not following the heart.

Check: (a) detector accuracy against the MIT-BIH reference beat annotations (.atr):
a detection counts as a hit if it lies within 54 samples (150 ms) of an annotated
beat; report sensitivity and positive predictivity. (b) Re-run FIX and RIDE with the
ANNOTATED beats as the detections (an oracle: same beats for both, so the comparison
between them is fair; not a codec, since the decoder would need the beats as side
information). Same selector and fallback as registered (2x[t-1]-x[t-2]).

Decision rule:
- oracle RIDE vs FIX <= -1% on all four records -> riding follows the tempo; the
  8/8 finding stands.
- oracle RIDE vs FIX weaker than -0.5% on 100 or 101 -> the gain was mostly the
  detector being repaired; the 8/8 finding is withdrawn as a tempo claim.
- between: partial, the share is reported, no tempo claim beyond it.
