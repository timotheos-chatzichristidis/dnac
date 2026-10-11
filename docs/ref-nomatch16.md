# Reference mode without the 16-mer model -- result: REJECTED

Pre-registration: docs/ref-nomatch16-prediction.md (commit 6717a46). Run 2026-10-11 on
branch `match-wire` with the same scratch builds as docs/match-wire.md (W0 =
`MATCH_WIRE=0`, byte-identical to main; W1 = `MATCH_WIRE=1`; W2 = `MATCH_WIRE=2`).
Every archive decoded with `dr` and compared with `cmp`.

Held-out inputs, sha256 prefix, recorded before the first held-out run:
`bsub_py79.fa` (CP006881.1) 5bc64b267bdaee0f, `saur_usa300.fa` (NC_007793.1)
8788b06d9d5b785f, `paer_pa14.fa` (NC_008463.1) c46d3e046d17b6b4, `bsub_mut2.fa`
bc9b445bf5713ce2, `paer_mut2.fa` 9fbf879357840339 (`dnac mut <src> <out> 2 11`, run in
`data/`), and the pairs of docs/real-human.md: `chm13_chr21.fa` 4d1247a97808717b,
`chm13_chr22.fa` 421bfb2e930b0e6e, `grch38_chr21.fa` 2064bcc6b46ff2d1,
`grch38_chr22.fa` d5e39a482c32faf2.

## Step 1: development (pairs already seen), level 1

| pair | R0 | R1 drop | R2 wire |
|---|---:|---:|---:|
| ecoli_ind / ecoli | 12,212 | -0.7288% | -0.7042% |
| w3110 / ecoli | 2,129 | -3.4758% | -2.2076% |
| o157 / ecoli | 362,870 | +0.1835% | +0.2130% |
| chr21_ind / chr21 | 101,525 | +0.0867% | -0.4442% |
| **mean** | | **-0.9836%** | -0.7857% |

By the rule, the candidate is **R1**.

## Step 2: held-out, R1 vs R0

| pair | kind | L1 R0 | L1 change | L3 R0 | L3 change |
|---|---|---:|---:|---:|---:|
| PY79 / 168 | real strain | 3,665 | **+1.4734%** | 3,616 | **+1.0785%** |
| USA300 / NCTC 8325 | real strain | 32,759 | **+0.5281%** | 32,650 | **+0.5391%** |
| PA14 / PAO1 | real strain, diverged | 195,668 | +0.0010% | 195,026 | +0.0867% |
| bsub `mut` 2 per mille | simulated | 18,593 | -0.8982% | 18,257 | -0.3451% |
| paer `mut` 2 per mille | simulated | 27,663 | -0.4772% | 27,139 | +0.0774% |
| CHM13 / GRCh38 chr21 | real human | 563,039 | **+1.4601%** | 547,027 | **+1.1435%** |
| CHM13 / GRCh38 chr22 | real human | 761,666 | **+1.3197%** | 742,185 | **+1.0881%** |
| **mean** | | | **+0.4867%** | | **+0.5240%** |

## Verdict against the bar (exact figures)

| condition | bar | R1 | |
|---|---:|---:|---|
| mean, level 1 | <= -0.30% | +0.4867% | FAIL |
| mean, level 3 | <= 0.00% | +0.5240% | FAIL |
| worst pair, either level | <= +0.50% | +1.4734% (PY79 L1) | FAIL |

**Rejected on every condition.** The development gain does not exist on real pairs.

## Predictions, scored

| | prediction | outcome |
|---|---|---|
| P1 | R1 and R2 within 0.1 pp on development | **miss**: 0.20 pp apart on the mean, 0.53 pp on chr21_ind |
| P2 | near-identical bacterial pairs gain -0.5..-2%, PA14 loses | **split by kind**: the simulated pairs gain (-0.90, -0.48%), the REAL near-identical strain loses most (PY79 +1.47%); PA14 flat |
| P3 | human pairs gain -0.05..-0.30% | **inverted**: +1.46% and +1.32% |
| P4 | level-1 mean passes narrowly | **failed**: +0.49% |

## What it taught: a simulated pair is not a proxy for a real one

Every development pair that gained was either simulated (ecoli_ind, chr21_ind are
`dnac mut` outputs: substitutions only) or tiny (w3110, 2 kB, where 47 B is 2.2%). Every
REAL held-out pair at kB scale or above lost, by 0.5-1.5%. The mechanism is in what a
`mut` pair does not contain: indels and rearrangements. After an indel the 13-mer model
has lost the alignment and must re-anchor; the 16-mer model, whose table is the most
recent occurrence of a LONGER context, re-finds the right place in the reference after
fewer bases and with fewer wrong anchors. On a substitution-only pair there is nothing to
re-find, and the second model is pure redundancy -- which is exactly the hypothesis the
pre-registration wrote down, and it held only on the data that cannot test it.

The same shape as two earlier findings (CLAUDE.md, "the per-event E. coli screen does
not predict the human pair"): a cheap stand-in moved the opposite way from the real
thing. **For any decision about the match layer, simulated `mut` pairs are a regression
check, never evidence.** Real pairs (strains, CHM13/GRCh38) decide.
