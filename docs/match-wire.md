# Match 16 as wiring -- result: REJECTED

Pre-registration: docs/match-wire-prediction.md (commit c7558fb, written before any code).
Run 2026-10-11 on branch `match-wire`, scratch switch `MATCH_WIRE` in dnac.c; main's
dnac.c is unchanged. Every archive below was decoded and compared with `cmp`.

## Negative control

W0 (`MATCH_WIRE=0`) against main, sha256 of the archive: identical on `ecoli.fa` and
`chr21_slice.fa` at levels 1 and 3 (1,069,622 / 1,093,433 / 2,112,257 / 2,104,492 B).

## Size, plain mode

| file | level | W0 (release) | W1 drop | W2 wire |
|---|---:|---:|---:|---:|
| ecoli | 3 | 1,093,433 | +0.0134% | +0.0173% |
| bsub | 3 | 1,002,533 | -0.0007% | +0.0090% |
| paer | 3 | 1,382,307 | +0.0340% | +0.0480% |
| saur | 3 | 646,508 | +0.0283% | +0.0401% |
| chr21 | 3 | 7,740,646 | +0.1515% | **+0.1288%** |
| chr22_sm | 3 | 7,574,763 | +0.1343% | **+0.1144%** |
| ecoli | 1 | 1,069,622 | +0.0058% | +0.0292% |
| bsub | 1 | 986,945 | -0.0140% | +0.0006% |
| paer | 1 | 1,332,026 | +0.0200% | +0.0415% |
| saur | 1 | 630,977 | +0.0122% | +0.0575% |
| chr21 | 1 | 7,783,286 | +0.2218% | **+0.2015%** |
| **mean, level 3** | | | +0.0601% | **+0.0596%** |

The wiring recovers **15.0%** of the removal's cost on chr21 and **14.8%** on chr22_sm.
On every bacterium, at both levels, W2 is WORSE than W1: the bit splits mixer contexts
and brings no information the mixer can use there.

## Size, reference mode (level 1, the `cr` default)

| pair | W0 | W2 | change |
|---|---:|---:|---:|
| ecoli_ind / ecoli | 12,212 | 12,126 | -0.7042% |
| w3110 / ecoli | 2,129 | 2,082 | -2.2076% |
| o157 / ecoli | 362,870 | 363,643 | +0.2130% |
| chr21_ind / chr21 | 101,525 | 101,074 | -0.4442% |

## Memory and time (full chr21, min of 3 alternating rounds, run alone)

| | W0 | W2 | change |
|---|---:|---:|---:|
| encode, level 3 | 86.0 s | 83.7 s | **-2.7%** |
| decode, level 3 | 87.6 s | 82.4 s | -5.9% |
| peak RSS, level 3 | 1,260 MB | 1,132 MB | **-10.2%** |
| encode, level 1 | 41.9 s | 38.7 s | -7.6% |
| decode, level 1 | 42.7 s | 39.5 s | -7.5% |
| peak RSS, level 1 | 748 MB | 620 MB | -17.1% |

Run-to-run spread within an arm reached 8.5 s (W2 L3 encode 83.7 / 85.0 / 92.2 s), so the
time column is reported, not claimed.

## Verdict against the bar (exact figures)

| condition | bar | W2 | |
|---|---:|---:|---|
| mean size change, level 3 | <= +0.05% | +0.0596% | FAIL |
| worst plain file, either level | <= +0.10% | +0.2015% (chr21 L1) | FAIL |
| worst reference pair | <= +0.50% | +0.2130% (o157) | pass |
| peak RSS, chr21 L3 | <= -8% | -10.2% | pass |
| encode time, chr21 L3 | <= -5% | -2.7% | FAIL |
| wiring recovers >= half of W1's chr21 cost | >= 50% | 15.0% | FAIL |

**Rejected.** And by the fourth condition, whatever the size cost had been, the wiring
did not earn its name: what is lost is the removal's, and the bit gives back a seventh.

Against the memory lever already measured: HASHBITS_MAX 26->25 buys -31% RAM on chr21 for
+0.051%. W2 buys -10.2% for +0.129% -- about 7.5x worse per MB. It is not a memory lever.

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| P1 | W1: E. coli +0.02..+0.06%, chr21 +0.20..+0.40% (L3) | **miss, both low**: E. coli +0.0134%, chr21 +0.1515% -- barely above the zeroed-input floor (+0.153% on the slice); the two context bits were worth almost nothing |
| P2 | W2 recovers < half of W1's chr21 cost | hit (15.0%) |
| P3 | bacteria pass (|change| < 0.05%), chr21 fails (> +0.10%) | hit at L3 (saur L1 +0.0575% is the one bacterial exception) |
| P4 | RSS -10%, encode -3..-8% | hit (-10.2%, -2.7% L3 just outside, -7.6% L1) |
| P5 | at least one reference pair worse than +0.50% | **miss, inverted**: three of four pairs GAIN (-0.44..-2.21%) |
| overall | rejected | hit |

## What it taught

1. **The 16-mer model is worth its anchor, not its signal.** "A 16-base agreement exists on
   the alignment I follow" recovers 15%. The rest is what only a second table gives: the
   most recent occurrence of the 16-mer, which is often not the 13-mer's position, and a
   second alignment held while the first one follows something else.
2. **The two context bits it fed were close to free to lose** (P1's miss): removing the
   input AND the bits costs about what removing the input alone did.
3. **Reference mode is the opposite case** (P5's inversion), and it is not decided here:
   four pairs, looked at, W1 never run in that mode. It gets its own pre-registration with
   held-out pairs: docs/ref-nomatch16-prediction.md.
