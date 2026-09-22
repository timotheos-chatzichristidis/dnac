# The case mask: result

**Run 2026-09-22**, on branch `case-mask`. Pre-registered in
`docs/case-mask-prediction.md` (commit `e635302`, pushed before any code or
measurement). Level 3, k=22, plain mode. Every archive was decoded and
`cmp`-ed before its size was recorded.

## The data

Ensembl release 110, GRCh38 chromosomes 21 and 22, `dna` and `dna_sm`.
Uppercasing `dna_sm` reproduces `dna` byte for byte on both chromosomes, and
`dna` chr21 is byte-identical in sequence to `data/chr21.fa`. chr21 is 53.61%
lowercase bases in 119,986 case runs; chr22 is 55.31%, in 124,658 runs.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **C1**, the size of the problem | v0.9.0 on `dna_sm` is +15% to +45% over `dna` | **held**: chr21 **+40.14%** (10,847,678 B against 7,740,638), chr22 **+44.67%** (10,741,570 against 7,425,085) |
| **C2**, the opponent | its case list is 1.0–4.0% of the `dna` archive | **held**: 156,305 B (bzip2 -9, the smallest of the three) = **2.019%**; chr22 161,224 B |
| **C3**, the separation | new build minus v0.9.0-on-`dna` equals the case bits' cost within ±64 B | **failed**: the difference is 196,389 B and the instrument sums 187,761 B, a gap of **8,628 B** (chr22: 4,162 B). Cause not established; see below |
| **C4**, the modelling claim | case bits cost 0.40–0.75× the opponent's list | **failed, inverted**: **1.2012×** on chr21, 1.1796× on chr22. The model is *worse* than bzip2 on a text file of run lengths |
| **C5**, replication | chr22 agrees with chr21, C4 within 0.15 | **held**, for the failure: 1.1796 against 1.2012 |
| **C6**, no cost without case | every uppercase file byte-identical to v0.9.0 | **held**, after one fix made before any size was read (below): E. coli, O157, W3110, `ecoli_ind` and `chr21_slice` are all identical |
| **C7**, time | — | **not run**: condition 1 had already failed, so time could not change the decision |

Round-trips: `scripts/roundtrip.sh` **229/229**, plus 9 new mixed-case files
at `-j 1` and `-j 4`, all lossless. Threaded and `-DDNAC_NO_THREADS` builds
give identical archives. A lowercase `cr` target round-trips and is
byte-identical to v0.9.0's. v0.9.0 refuses the new `DNCK` stream as "not a dnac
file", exit 1, and does not misread it. The `-DDNAC_CASEPROF` build writes the
same bytes as the plain build.

## D-C

| condition | requirement | measured | verdict |
|---|---|---:|---|
| 1 | smaller than the opponent's total | chr21 7,937,027 against **7,896,943** (**+0.5076%**); chr22 +0.4366% | **fails** |
| 2 | C6 exactly | identical | passes |
| 3 | lossless | 229/229 + new cases | passes |
| 4 | C7 | not run | — |

**The one-bit-per-base case model is not adopted.** By the rule written
before it ran, *"if 1 fails, the right design is the interval list itself, and
that is what gets built instead."*

## What was wrong with the prediction

**The match-position context was supposed to be the gain, and the whole model
lost to a general-purpose compressor that sees only run lengths.** C4 was
flagged in advance as the prediction most likely to fail, for the stated
reason: masking boundaries are annotation calls, not sequence facts. The data
do not refute that reason. They do not prove it either, since no ablation of
the match context was run.

The simpler explanation is structural. The bit model pays for every one of
40 million bases, even where the answer is nearly certain: the counter's floor
at 12-bit precision is about 0.00035 bits a base, about 1.75 KB on its own. It
also has to rediscover each run's end one base at a time. An interval list pays
only at the 120,000 boundaries. At 120,000 events in 40 million positions,
paying per event beats paying per position.

**C3's gap is not explained here.** The case bit feeds no base model, so the
base and flag bits should be identical bit for bit. An 8.6 KB excess over the
instrument means either that assumption is wrong somewhere, or that the
carryless coder loses precision when 40 million extra bits are interleaved.
Deciding which needs the `-map` instrument run on both files. It is written
down as open, not guessed.

## One fix, made before any size was read

The first build turned case mode on for **every** FASTA whose header contains
a lowercase `a`, `c`, `g` or `t`, which is almost all of them ("Escherichia
coli"). C6 caught it on E. coli and O157. Letters inside a `>` line are now
text, both in the prescan and in the encoder, exactly as in v0.9.0. The fix
changed which files enter case mode, not how case is modelled, and it was made
before any chr21 or chr22 case size existed.

## What this leaves

- **The problem is real and large**: dnac is 40–45% worse on soft-masked human
  sequence than on the same sequence in uppercase, and soft-masked is how
  Ensembl `dna_sm` and UCSC distribute genomes.
- **The lazy fix recovers nearly all of it**: uppercase + a bzip2'd run list is
  7,896,943 B against today's 10,847,678, **−27.2%** on chr21.
- The next design is the interval list, coded inside dnac. It needs its own
  pre-registration, and its bar is already fixed by this one: no worse than
  the opponent's 156,305 B on chr21.
