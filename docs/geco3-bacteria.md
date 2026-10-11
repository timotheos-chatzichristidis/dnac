# GeCo3 on the bacteria, with the codon tracker -- result

Pre-registration: docs/geco3-bacteria-prediction.md (commit ab02db0). Run 2026-10-11 on
this machine, one session, one process at a time, single run per row (times reported, not
claimed: run-to-run noise here is 24%). dnac = main (v0.12.0, a2f2ca7), every archive
decoded and compared with `cmp`. GeCo3 = bench-external/geco3-master as built for the
README, run as verify-claims.ps1's `Geco` does; its decoder is not run, so its sizes are
**unverified**. Inputs: plain ACGT `.seq` (`scripts/mkseq.sh`), sha256 prefix: ecoli
e999dceccb76562d, bsub 71572ae0b98f44a6, paer f969830bbe6aa58b, saur 2e602647c6f2d713.

The control: GeCo3 `-l 9` on E. coli gives 1,096,763 B = 1.8903 bpb, and dnac `-l 3` gives
1,092,643 B = 1.8832 -- both exactly the README's figures. The setup measures what the
README measured.

## Result

| genome (bases) | tool | bytes | bits/base | compress | vs best GeCo3 |
|---|---|---:|---:|---:|---:|
| E. coli (4,641,652) | **dnac `-l 1`** (default, tracker) | 1,068,546 | **1.8417** | **6.65 s** | **-2.57%** |
| | dnac `-l 3 -codon` | 1,064,985 | 1.8355 | 11.17 s | -2.90% |
| | dnac `-l 3` | 1,092,643 | 1.8832 | 11.12 s | -0.38% |
| | dnac `-l 1 -nocodon` | 1,093,862 | 1.8853 | 5.28 s | -0.26% |
| | GeCo3 `-l 9` (best) | 1,096,763 | 1.8903 | 10.81 s | -- |
| | GeCo3 `-l 16` | 1,097,350 | 1.8913 | 97.35 s | +0.05% |
| | GeCo3 `-l 14` | 1,098,095 | 1.8926 | 30.11 s | +0.12% |
| B. subtilis (4,215,606) | **dnac `-l 1`** | 985,295 | **1.8698** | **6.61 s** | **-2.02%** |
| | dnac `-l 3 -codon` | 983,568 | 1.8665 | 10.72 s | -2.20% |
| | dnac `-l 3` | 1,001,737 | 1.9010 | 9.71 s | -0.39% |
| | dnac `-l 1 -nocodon` | 1,002,330 | 1.9021 | 6.36 s | -0.33% |
| | GeCo3 `-l 9` (best) | 1,005,647 | 1.9084 | 10.10 s | -- |
| | GeCo3 `-l 14` | 1,006,478 | 1.9100 | 26.90 s | +0.08% |
| | GeCo3 `-l 16` | 1,006,600 | 1.9102 | 108.74 s | +0.09% |
| P. aeruginosa (6,264,404) | **dnac `-l 1`** | 1,331,123 | **1.6999** | **9.64 s** | **-3.80%** |
| | dnac `-l 3 -codon` | 1,326,789 | 1.6944 | 14.88 s | -4.12% |
| | dnac `-l 3` | 1,381,317 | 1.7640 | 18.25 s | -0.18% |
| | dnac `-l 1 -nocodon` | 1,384,840 | 1.7685 | 8.40 s | **+0.08%** |
| | GeCo3 `-l 16` (best) | 1,383,766 | 1.7671 | 101.14 s | -- |
| | GeCo3 `-l 14` | 1,386,483 | 1.7706 | 28.58 s | +0.20% |
| | GeCo3 `-l 9` | 1,388,228 | 1.7728 | 13.44 s | +0.32% |
| S. aureus (2,821,360) | **dnac `-l 1`** | 630,282 | **1.7872** | **3.68 s** | **-2.65%** |
| | dnac `-l 3 -codon` | 629,047 | 1.7837 | 7.39 s | -2.84% |
| | dnac `-l 3` | 645,837 | 1.8313 | 6.67 s | -0.25% |
| | dnac `-l 1 -nocodon` | 646,335 | 1.8327 | 3.98 s | -0.17% |
| | GeCo3 `-l 16` (best) | 647,458 | 1.8359 | 50.56 s | -- |
| | GeCo3 `-l 9` | 647,678 | 1.8365 | 8.63 s | +0.03% |
| | GeCo3 `-l 14` | 648,305 | 1.8383 | 19.57 s | +0.13% |

**On all four bacteria the dnac default (`-l 1`, tracker on) is 2.0-3.8% smaller than
GeCo3's best level and faster than GeCo3's fastest.** Without the tracker the margin is
0.2-0.4%, and on P. aeruginosa level 1 `-nocodon` is 0.08% BEHIND GeCo3 `-l 16`: the old
margin was thin, the tracker is what makes it a lead.

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| B1 | dnac `-l 1` beats GeCo3's best by 2-4.5% on all four | hit: 2.57, 2.02, 3.80, 2.65% |
| B2 | dnac `-l 1` faster than every GeCo3 level on all four | hit (6.65 vs 10.81, 6.61 vs 10.10, 9.64 vs 13.44, 3.68 vs 8.63 s) |
| B3 | GeCo3 `-l 16` never better than `-l 9`/`-l 14` | **miss**: `-l 16` is GeCo3's best on P. aeruginosa and S. aureus |
| B4 | `-l 3 -codon` smallest dnac setting everywhere, < 0.3% over `-l 1`, at 2x the time | half: smallest everywhere, yes; but 0.33% (E. coli) and 0.32% (P. aeruginosa) over `-l 1`, at 1.5-2.0x |

## What goes to the README (separate change, through a PR)

Proposed: a bacteria block in the head-to-head table with the default (`-l 1`), `-l 3
-codon`, and GeCo3's best and fastest level per genome, each with a verify-claims row in
tier `extern`; and the E. coli rows updated so the table no longer shows only the pre-tracker
level 3. The sentence "on all three datasets dnac has a setting that is at once faster and
smaller than every GeCo3 setting tested" extends to seven datasets, with the default as
that setting on all four bacteria.
