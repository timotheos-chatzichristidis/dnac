# Codon tracker: speed, at every level -- result

Run 2026-09-27, pre-registered in `docs/codon-speed-prediction.md` (commit ce6e4e9). Build:
`scripts/pilot/codon-speed.patch` (run-time switches). Recipes:
`SPD=... REL=... sh scripts/pilot/codon-speed-size.sh` (sizes, 96 jobs) and
`sh scripts/pilot/codon-speed-time.sh` (time). **All 96 size archives and every timed run
round-tripped, with 0 failures.** S0 reproduces round 2 to the byte (E. coli L3 1,066,573).

## Size: gated gain (tracker archive + 1 byte against release at the same level)

| level | variant | E. coli | B. subtilis | P. aeruginosa | S. aureus |
|---|---|---:|---:|---:|---:|
| 1 | S0 / S1 / S3 | 2.2854 | 1.6083 | 3.8834 | 2.4731 |
| 1 | S2 / S123 | 2.3016 | 1.6170 | 3.886 | 2.4864 |
| 2 | S0 / S3 | 2.3821 | 1.6585 | 3.9478 | 2.5108 |
| 2 | S2 / S123 | 2.4021 | 1.6683 | 3.95 | 2.5311 |
| 3 | S0 / S3 | 2.4557 | 1.6981 | 3.9384 | 2.5590 |
| 3 | S2 / S123 | 2.4984 | 1.7189 | 3.951 | 2.5998 |
| 4 | S0 / S3 | 2.4567 | 1.6938 | 3.9487 | 2.5673 |
| 4 | S2 / S123 | 2.4894 | 1.7115 | 3.960 | 2.5937 |

(S1 differs from S0 by at most 0.002 points. The exact figures are in `bench-external/pilot/codon/spd/sizes.txt`.)
**Every variant is eligible at every level.** Phasing only orders <= 11 (S2) gains slightly
MORE than phasing all of them.

## Time: E. coli, min of 3 alternating rounds, one process at a time

| level | release enc / dec | S0 | S1 | S2 | S3 | S123 |
|---|---|---|---|---|---|---|
| 1 | 5.75 / 5.80 s | +26.4 / +25.1% | **+7.8 / +9.0%** | +25.5 / +25.3% | +30.3 / +26.2% | +11.2 / +15.9% |
| 2 | 8.62 / 8.74 s | +17.7 / +16.4% | **+6.3 / +10.1%** | +19.9 / +17.6% | +18.6 / +15.7% | +8.1 / +7.8% |
| 3 | 12.42 / 12.27 s | +32.3 / +44.6% | +30.6 / +29.8% | +26.7 / +26.8% | +39.7 / +42.3% | **+16.3 / +19.9%** |
| 4 | 8.66 / 8.82 s | +39.8 / +37.0% | +28.6 / +27.7% | +31.5 / +29.1% | +40.2 / +38.7% | **+13.5 / +12.1%** |

Bold marks the CANDIDATE: the fastest eligible encode, by the rule. The release L3 time here
(12.42 s) is slower than earlier in the day (10.48 s) for the same work. Machine state
differs between sessions, which is why only same-session ratios are quoted. Spread between
rounds reaches about 25% on single runs (S0 L3 encode 16.4-21.1 s). Minimums are used as
registered.

| | prediction | outcome |
|---|---|---|
| W1 | S3 alone removes most of the label cost | **failed**: S3 alone is no faster, sometimes slower |
| W2 | S2 keeps >= 80% of S0's gain at L3 | held (it gains more: 2.4984 against 2.4557) |
| W3 | S123 encode overhead at L3 <= 15% | **failed** (+16.3%) |
| W4 | level 1 gains less than level 3 | held (2.2854 against 2.4557) |

## Recommendation by the pre-set rule (the decision is Timotheos's)
- **Level 1:** S1, +7.8% encode / +9.0% decode, both <= 10% -> **into the level's default**.
- **Level 2:** S1, +6.3% / +10.1%. Decode is over 10% by 0.1 point, so **new level or opt-in
  flag** by the rule. Stated, not rounded: S123 at level 2 is +8.1 / +7.8%, inside 10% on
  both. The rule names the fastest ENCODE, so S1, and it is not re-read after the fact.
- **Level 3 and 4:** S123, +16.3 / +19.9% and +13.5 / +12.1% -> **new level or opt-in flag**.

Two readings of the table, offered as description:
- **The tracker's log2 was the main cost at the fast levels.** S1 alone cuts L1 from +26%
  to +8%.
- **At L3/L4 the phased tables are the main cost,** and only all three changes together get
  under +20%. The interleaved layout helps only in combination.
