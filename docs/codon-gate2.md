# Codon gate, round 2 -- result: neither rule adoptable; the release gate also has a FALSE NEGATIVE

Pre-registration: docs/codon-gate2-prediction.md (commit 67e1c5f, before any genome below
was fetched). Run 2026-10-11, branch `codon-euk`, same scratch build as docs/codon-euk.md
(`DNAC_CODON_FORCE`). Level 1. Every archive -- whole files and samples -- decoded and
compared with `cmp`; 0 failures.

Unseen genomes as fetched (defline confirmed for every one; sha256 prefix):
pfal1 NC_004325.2 83a1b01f088643e3, ddis1 NC_007087.3 e9c8b9312136ef29, osat1 NC_029256.1
756fc5bcde350fb8, mmus19 NC_000085.7 495e2591cd2d18fc, drer1 NC_007112.7 d0706fbaa937058f,
mtub NC_000962.3 a7ac0ccec9a03cea, hpyl NC_000915.1 3bf9e1bc5d301d0e, spne NC_003028.3
276f102ceaca7467, mjan NC_000909.1 eb4f0ad97e8fe0b4.

## Result

gain = forced tracker vs `-nocodon` on the whole file; sample = the same on the middle
256 Kbase; regret in percentage points (0 = the rule picked the better arm).

| genome | G | gain | sample | REL | T3 | TG |
|---|---:|---:|---:|---:|---:|---:|
| P. falciparum chr 1 | 2.0637 | +0.4969% | +1.0840% | 0 | **0.4969** | 0 |
| D. discoideum chr 1 | 5.3090 | +1.6342% | +1.3220% | 0 | 0 | 0 |
| O. sativa chr 1 | 2.1207 | -0.4231% | -0.3179% | **0.4231** | 0 | 0 |
| M. musculus chr 19 | 1.1020 | -0.3107% | -0.1924% | 0 | 0 | 0 |
| D. rerio chr 1 | 1.1372 | -0.6340% | -0.1969% | 0 | 0 | 0 |
| M. tuberculosis | 2.0180 | +2.1954% | +1.0691% | 0 | **2.1954** | 0 |
| **H. pylori** | **1.7440** | **+2.7749%** | +1.9491% | **2.7749** | **2.7749** | **2.7749** |
| S. pneumoniae | 9.5892 | +2.1334% | +1.3733% | 0 | 0 | 0 |
| M. jannaschii | 5.6183 | +2.3234% | +1.8966% | 0 | 0 | 0 |
| **mean regret, unseen** | | | | **0.3553** | 0.6075 | 0.3083 |

Development files (reported, decide nothing):

| genome | G | gain | sample | REL | T3 | TG |
|---|---:|---:|---:|---:|---:|---:|
| S. cerevisiae | 9.3036 | +0.9360% | **-0.0329%** | 0 | 0 | **0.9360** |
| S. pombe | 7.4125 | +0.5786% | **-0.0179%** | 0 | 0 | **0.5786** |
| A. thaliana chr 1 | 2.8121 | -0.0812% | -1.7609% | 0.0812 | 0 | 0 |
| C. elegans chr I | 1.9032 | -0.4149% | -0.1370% | 0 | 0 | 0 |
| D. melanogaster 2L | 2.4594 | -0.0926% | -0.1400% | 0.0926 | 0 | 0 |
| E. coli | 3.8858 | +2.2855% | +1.5546% | 0 | 0 | 0 |
| B. subtilis | 5.0875 | +1.6083% | **-0.0971%** | 0 | 0 | **1.6083** |
| P. aeruginosa | 3.2574 | +3.8835% | +3.5794% | 0 | 0 | 0 |
| S. aureus | 3.4728 | +2.4732% | +2.2791% | 0 | 0 | 0 |
| chr21_slice | 1.1736 | -0.2393% | -0.1742% | 0 | 0 | 0 |
| **mean regret, development** | | | | 0.0174 | 0.0000 | 0.3123 |

TG time: E. coli level 1 encode 6.11 s (min of 3), the two sample encodes 0.65 s:
**+10.7%**.

## Verdict against the rule (exact figures)

| condition | T3 | TG |
|---|---|---|
| 1. mean regret below REL's 0.3553 | 0.6075, FAIL | 0.3083, pass |
| 2. never above REL by > 0.05 pp | P. falciparum +0.50, M. tuberculosis +2.20, FAIL | pass |
| 3. closes no genome with gain >= 1.0% | closes M. tuberculosis (+2.20%), FAIL | leaves H. pylori (+2.77%) closed, FAIL |
| 4. TG time <= +10% | -- | +10.7%, FAIL |

**Neither is adoptable. The gate is not changed.** TG fails by the letter of condition 3
(its G >= 2.0 pre-filter never lets H. pylori reach the trial; REL shares that miss) and
by 0.7 pp on time; and the development files, which decide nothing, show the deeper
problem -- a 256 Kbase sample is too short for the tracker to lock on, so TG would have
closed B. subtilis (+1.61%) and both yeasts.

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| table | G and gain per genome | mixed. Misses that matter: M. tuberculosis G 2.02 (said 4-7), H. pylori G 1.74 (said 3-5), M. jannaschii G 5.62 (said 2.5-4); D. discoideum gain +1.63% (said up to +1.0%) |
| G1 | REL has a false positive on the unseen set (rice or P. falciparum) | hit: rice, -0.42% |
| G2 | T3 fails condition 3 on a prokaryote, an AT-rich one (M. jannaschii) | hit for the wrong genome: M. tuberculosis, the HIGH-GC one (65%), G 2.02 |
| G3 | TG adoptable and wins; +6% time | **failed**: not adoptable; +10.7% |

## What it says

1. **The release gate's worst error is a false negative, not the false positives.**
   H. pylori, a bacterium whose tracker gains 2.77%, has G 1.74 and is coded without it.
   The two false positives of docs/codon-euk.md cost 0.08-0.09%; rice costs 0.42%; this
   costs 2.77%. And M. tuberculosis sits at G 2.02 -- 0.02 from the same fate, for 2.20%.
2. **G is a poor proxy in BOTH directions.** Gain against G across all 19 files has no
   usable threshold: H. pylori (1.74) gains 2.8%, rice (2.12) loses 0.4%, M. tuberculosis
   (2.02) gains 2.2%, the worm (1.90) loses 0.4%. What separates the winners is gene
   structure (intron-free, dense coding), which period-3 mutual information does not see.
3. **A short trial is not a cure either.** At 256 Kbase the sample's sign was wrong on 3 of
   the 10 development files (all three under-estimates, all gene-dense).
4. **The one rule with zero regret by construction is the trivial one: code the file both
   ways and keep the smaller.** Its cost is a second encode -- but the codec is already
   threaded, so on two cores the wall time need not move; the price is CPU and memory
   (two model sets, ~750 MB each at chromosome scale, level 1). A low pre-filter (the
   vertebrates sit at 1.10-1.17, the lowest gainer at 1.74) would keep human-scale files
   from paying anything.

## Next step (to be pre-registered, not done here)

"Both ways, keep the smaller" at level 1 for files with G >= 1.5, the two encodes in
parallel threads: measure wall time, CPU time and peak memory on E. coli, H. pylori and
full chr21 (where it must cost nothing), and confirm on genomes not used in either round.
