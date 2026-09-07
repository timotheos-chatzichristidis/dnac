# What each model is actually worth

`dnac -l3` blends **15 predictors** for every bit. Nothing in the repository used
to say what any of them earns. The round-trip suites run one binary with one
configuration, so they cannot see it; `verify-claims.ps1` defends the published
numbers, not the design behind them. This file is the third measurement, and
`./ablate.ps1` re-derives every table in it.

Every size below round-tripped before it was recorded. Sizes are deterministic
and are the claims; **no timing is published here** — run-to-run noise on this
codec was measured at 24% on identical input for byte-identical output, which is
wider than most of the effects in these tables.

## Method

`-DDNAC_ABLATE=<mask>` zeroes the stretch value of the selected inputs inside
`mix_predict`. A zeroed input contributes nothing to any expert **and stops
learning** — the mixer's gradient is proportional to `st[i]` — so what is removed
is the input, while table geometry, hashing and memory stay exactly as they were.

That distinction is the whole point. Deleting an entry from `MASTER_ORDER_LIST`
also changes how much table the remaining models get, so it cannot separate
*"this model is worth nothing"* from *"this model was crowded out of a smaller
table"*. The mask can.

The inputs, in the order `mix_predict` fills them at level 3, k=22:

| index | input | |
|---:|---|---|
| 0–9 | order models | 1, 2, 3, 4, 6, 8, 11, 14, 18, 22 |
| 10–11 | substitution-tolerant models | orders 16 and 20, on the repaired history |
| 12–13 | forward match models | `MMIN`=13, `MMIN2`=16 |
| 14 | reverse-complement match model | the other strand |

## Leave-one-out: what one input is worth on its own

Cost of removing exactly one input, as a percentage of compressed size.

| input | E. coli (4.6 Mbp) | chr21 slice (9.8 Mbp) |
|---|---:|---:|
| order 1 | +0.008% | +0.030% |
| order 2 | +0.012% | −0.001% |
| order 3 | +0.005% | **−0.002%** |
| order 4 | +0.023% | +0.002% |
| order 6 | +0.043% | **−0.004%** |
| order 8 | +0.106% | +0.075% |
| order 11 | +0.016% | +0.097% |
| order 14 | +0.008% | +0.074% |
| order 18 | +0.014% | +0.031% |
| order 22 | +0.009% | +0.007% |
| tolerant 16 | **−0.004%** | +0.002% |
| tolerant 20 | **−0.004%** | +0.020% |
| match 13 | +0.058% | +0.398% |
| match 16 | +0.019% | +0.153% |
| **reverse-complement** | **+0.227%** | **+0.888%** |

Three things worth stating plainly:

- **No single order model is worth more than 0.11%.** The ensemble does not rest
  on any one of them.
- **Four inputs have negative value** — removing them makes the file smaller.
  Order 3 and order 6 on human, both tolerant models on E. coli. The mixer
  spends capacity suppressing them and never fully succeeds.
- **The reverse-complement model is the single most valuable input on human
  sequence**, by a factor of two over the next one. The cheapest model in the
  codec — one hash lookup into a table another model already built — earns the
  most. Inverted repeats are not a curiosity in a genome; they are structure.

## Leave-one-out understates a group, and by how much

The mixer exists to reroute around a missing input, so removing inputs one at a
time systematically understates what they are worth **together**.

| removed together | sum of the single-input costs | measured together | ratio |
|---|---:|---:|---:|
| 5 inputs, chr21 slice | 0.204% | **0.300%** | 1.47× |
| 7 inputs, chr21 slice | 0.308% | **0.455%** | 1.48× |
| those 7 + the other match model | 0.706% | **1.704%** | 2.41× |
| 5 inputs, E. coli | 0.030% | 0.031% | 1.00× |

On bacteria the inputs really are near-copies and the costs add up. On human
sequence the information is **distributed**, not duplicated: the parts cover for
each other, so a table of single-input costs is not a shopping list. Anything
proposing to drop several models must be measured as a set (`-Mode mask`).

## Which models are near-duplicates

From `./ablate.ps1 -Mode diag -File ecoli.fa` — the correlation between inputs'
stretch values over 9.3 million coded bits. A DIAG build is byte-identical to a
normal one; the script verifies that before printing anything.

| pair | r |
|---|---:|
| order 18 ↔ order 22 | **0.91** |
| match 13 ↔ match 16 | **0.90** |
| order 3 ↔ order 4 | 0.81 |
| order 14 ↔ order 18 | 0.71 |
| match models ↔ order 22 | 0.73 |
| reverse-complement ↔ match models | 0.64 |
| tolerant models ↔ everything else | **0.00 – 0.05** |

The two 0.90+ pairs are the redundancy in the design, and the leave-one-out
table agrees: dropping *one* of a near-duplicate pair is nearly free, dropping
*both* is not. The tolerant models are the opposite case — completely
uncorrelated with every other input, which is what makes their near-zero
contribution interesting rather than merely small: the information they carry is
real and unique, and still does not pay for itself on these two genomes.

## Reduced configurations, measured end to end

Real builds, not masks — models actually removed, so the memory goes with them.
chr21 slice, level 3, all round-tripped.

| configuration | inputs | bytes | vs full |
|---|---:|---:|---:|
| full (`-l3`) | 15 | 2,105,617 | — |
| −tolerant, −order 3, −order 18 | 11 | 2,108,175 | +0.121% |
| −tolerant, −order 3, −order 18, −order 1, −order 14 | 9 | 2,111,210 | +0.266% |
| `-l2` (all orders, no IR, no tolerant) | 13 | 2,111,698 | +0.289% |
| `-l1` | 9 | 2,113,503 | +0.374% |

The same 11-input set costs **+0.012%** on E. coli. It drops three of the six
hashed tables (order 18 and both tolerant models), so it also removes roughly a
third of the codec's memory — the one lever measured so far that reduces both
memory *and* time, where shrinking the tables reduces memory only.

## That configuration shipped, as level 4

It is in the codec as `-l 4`, not as a patch to level 3, because the level byte
is format: redefining what "3" means would make every archive already written at
level 3 decode to wrong bytes with exit 0. Levels 1, 2 and 3 are byte-identical
before and after this change, and a decoder that predates level 4 refuses it by
name (`bad compression level in header: 4`) rather than misreading it.

Measured on the plain-ACGT sequence files, peak resident set sampled during the
run — memory here is measured, not computed from the table geometry:

| dataset | level | bits/base | size | peak RAM |
|---|---:|---:|---:|---:|
| chr21 (40.1 Mbase) | 3 | 1.4979 | 7,506,264 | 1,254 MB |
| chr21 | **4** | 1.5020 | 7,526,523 (+0.270%) | **869 MB (−30.7%)** |
| E. coli (4.6 Mbase) | 3 | 1.8833 | 1,092,692 | 603 MB |
| E. coli | **4** | 1.8834 | 1,092,756 (+0.006%) | **507 MB (−15.9%)** |

**The size cost grows with the sequence.** +0.006% on a bacterial genome,
+0.121% on a 10 MB slice, +0.270% on a whole chromosome — the models level 4
drops are the ones that pay off over long range, so the longer the input the more
they were earning. Quote the figure for the scale you are actually working at.

Against the other memory lever, honestly: `HASHBITS_MAX 26→25` buys the same −31%
for **+0.051%** on chr21, five times cheaper than level 4's +0.270%. What it does
not buy is time — that sweep measured no speed gain at all, while level 4 is 24%
faster on both sides. So level 4 is a *time* lever whose memory saving is a bonus,
and the two compose if a run needs both.

## What was closed by these measurements

- **The reverse-complement machinery is not under-exploited.** A file
  `X + rc(X)` costs 0.010% more than `X + X`; a diverged mirror (1% substitutions)
  costs 0.016% more than a diverged forward copy; and a 4× coverage read set with
  half its reads reverse-complemented compresses 0.05% *smaller* than the
  all-forward version. Mirrored structure is handled at parity with forward
  structure, and the leave-one-out table explains why it matters so much.
- **Canonical (strand-folded) bucket keying was rejected without being built.**
  It would make the inverted-repeat update land in the cache line the next base
  is about to read, worth an estimated 10–12% of run time — but it breaks the
  archive format, and the 11-input configuration above already buys more time
  than that without touching the format.
