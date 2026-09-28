# Codon tracker, round 3: a per-file gate -- result

Run 2026-09-27, pre-registered in `docs/codon-gate-prediction.md` (commit 855eebc). The two
new genomes were fetched after that commit: P. aeruginosa PAO1 NC_002516.2 (sha256 902fa552...),
S. aureus NCTC 8325 NC_007795.1 (sha256 04b865e3...). Gate statistic:
`python scripts/pilot/codon-gate.py <fasta>...`. Tracker = round 2's build
(`scripts/pilot/codon-tracker2.patch`), unchanged. Every archive decoded and compared with
cmp. The gated size is emulated as the chosen branch's archive + 1 byte, as registered.

| genome | G | gate | rel | gated | gain | bar |
|---|---:|---|---:|---:|---:|---|
| E. coli | 3.8858 | ON | 1,093,425 | 1,066,574 | **2.4557%** | >= 1.5 met |
| B. subtilis | 5.0875 | ON | 1,002,525 | 985,501 | **1.6981%** | >= 1.0 met |
| **P. aeruginosa** (new) | 3.2574 | ON | 1,382,299 | 1,327,858 | **3.9384%** | >= 1.0 met |
| **S. aureus** (new) | 3.4728 | ON | 646,500 | 629,956 | **2.5590%** | >= 1.0 met |
| chr21_slice (human) | 1.1736 | OFF | 2,104,484 | 2,104,485 | **+1 byte** | <= +0.1% met |

| | prediction | outcome |
|---|---|---|
| V1 | G >= 3.0 on bacteria, <= 1.3 on human | held (3.26-5.09 against 1.17) |
| V2 | P. aeruginosa 1.5-3.0%, S. aureus 1.0-2.5% | **failed high on both**: 3.94% and 2.56% |

**The bar passes on every condition.** The gate separates the four bacteria from human
sequence by a wide margin: the lowest bacterium sits 2.8x above the human value. On the two
genomes nobody had looked at, the tracker gains more than predicted, not less. The high-GC
P. aeruginosa gains the most, which fits a strong codon-position GC bias.

## Status: format candidate, not adopted
By the rule, the codon tracker is now a format candidate. What remains, each step to be
pre-registered on its own:
1. the real implementation: the header flag in dnac.c, the gate computed in C, state
   files, `-j` blocks, and reference mode (priming would need the tracker too);
2. the time cost (+32% encode on E. coli): whether it goes into the default level, a new
   level, or an opt-in flag;
3. the full re-measurement of every published figure and both round-trip suites (for a
   non-bacterial file the stream stays release + 1 byte, and whether even that byte can be
   avoided is part of step 1);
4. a check against GeCo3 and the other bacterial-genome benchmarks.
None of that is done. **Nothing here has touched dnac.c on any branch.**
