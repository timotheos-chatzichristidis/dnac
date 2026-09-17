# Batch 5: claims and release — result

**Run 2026-09-17.** Pre-registered in `docs/batch5-prediction.md` (commits
`3339074` and `5ee9f33`) before the runs: the design F1–F8, the figures P1–P10,
the W3110 experiment W1–W5 and the decision rule D1. The session opened green on
`ba4c86e`: `make` clean, `sh scripts/roundtrip.sh ./dnac.exe` 229/229,
`./verify-claims.ps1 -Tier fast` 21/21.

## W: the one decision Batch 4 handed over

**The question.** Since v0.9.0, `dnac cr` defaults to level 1, and on the
tightest real bacterial pair that default is 9.84% larger than v0.8.0's. Is that
a property of near-identical pairs — in which case the default is wrong — or an
artefact of a 2 kB output, or content that level 3's dropped models earn on?

### The gradient (`sh scripts/cue/batch5-w3110.sh`)

`dnac mut` on MG1655 at four rates, seed 42 (SNPs at the rate, short indels at a
tenth of it), each coded against MG1655 by the release build at levels 3 and 1,
every archive round-tripped. The real pairs are in the same run at the same
settings.

| target | level 3 | level 1 | penalty | | SNPs | indels |
|---|---:|---:|---:|---:|---:|---:|
| `mut` 0.05 ‰ | 2,018 | 2,013 | **−5 B** | **−0.25%** | 232 | 23 |
| `mut` 0.2 ‰ | 3,767 | 3,795 | 28 B | +0.74% | 928 | 92 |
| `mut` 1.0 ‰ | 11,928 | 12,072 | 144 B | +1.21% | 4,641 | 464 |
| `mut` 5.0 ‰ | 42,933 | 43,710 | 777 B | +1.81% | 23,208 | 2,320 |
| `ecoli_ind` | 12,051 | 12,204 | 153 B | +1.27% | | |
| **W3110** | 1,916 | 2,121 | **205 B** | **+10.70%** | | |
| O157:H7 | 362,006 | 362,862 | 856 B | +0.24% | | |

(The four `mut` rows are the re-measurement with a canonical defline; see the
instrument finding below for why the first attempt's figures were different.)

**W1 held**: the whole simulated gradient stays under 2%, nowhere near 9.84%.
**W2 held**: the penalty is not a fixed overhead — it runs from −5 B to 777 B,
far past the "at least 3x" predicted, and it even changes sign. **W3 held,
decisively**: the 0.05 ‰ point produces **2,018 B**, within a hundred bytes of
W3110's 1,916, and at that matched output size level 1 is **5 bytes smaller**,
where W3110 pays **205 bytes more**. So **the loss is content, not size** — and
not merely smaller on the simulated pair but the other way round.

**W4 part held**, 3 of 4. The per-event arithmetic (level 1 pays +3.12 bits per
indel and saves 0.17 bits per substitution, Batch 4 R1) predicts 4.2, 16.7, 83.5
and 417.7 B against measured −5, 28, 144 and 777 — ratios −1.20, 1.68, 1.72,
1.86. The three larger rates sit inside the factor of 2.5 the prediction allowed
and all lean the same way, about 1.75x the predicted cost. The smallest rate has
the **wrong sign**: with only 23 indels in the whole genome, level 1 comes out
ahead. So the arithmetic is the right order and not the right number, and below
about a hundred events it does not even give the right direction — which is
another way of saying the isolated per-event screen does not predict a whole
file, the lesson `docs/batch3.md` already had to learn once.

### W5: which content, then

Added after W1–W4 were run and disclosed as such in the pre-registration. W3110
against MG1655 at level 1, release build, with one of level 3's parts switched
back on at a time (the `L1_*` diagnostics Batch 4 kept for exactly this):

| level 1 plus… | bytes | of the 205 B gap |
|---|---:|---:|
| nothing (the default) | 2,121 | — |
| the master order set (`L1_ORDERS`) | 2,131 | **−4.9%** (worse) |
| other-strand training (`L1_IR`) | 2,131 | −4.9% (worse) |
| the tolerant models (`L1_STCM`) | 2,126 | −2.4% (worse) |
| **four mixer experts (`L1_NMIX=4`)** | **1,907** | **104%** |

**W5a held** (one part dominates, and by more than the 40% predicted).
**W5b failed**: it is not the order set — that is a small *loss*, as are the
other two model add-backs. **W5c failed** with it, for the same reason: it
compared two things that both turn out to be inert here.

**The answer is the mixer's context, not the model set.** Level 1 has two
expert mixers where level 3 has four; giving level 1 four recovers the entire
gap on W3110 and overshoots it, landing below level 3 (1,907 against 1,916) and
below v0.8.0 (1,931). Checked on the other two pairs at the same settings, to
see how far it generalises:

| pair | level 1 | level 1, four experts | level 3 |
|---|---:|---:|---:|
| W3110 (near-identical) | 2,121 | **1,907** | 1,916 |
| `ecoli_ind` (simulated individual) | 12,204 | **12,051** | 12,051 |
| O157:H7 (diverged) | 362,862 | 362,675 | 362,006 |

On the simulated individual four experts recover the gap **exactly** — 12,051 is
level 3's own size, to the byte. On the diverged pair they recover a fifth. So
the finding is scoped: **where the reference is very close, what level 1 gives
up is the mixer's context, and almost nothing else.**

### D1: the default stays level 1, and the loss is stated

W1 held, and both real pairs whose output exceeds 100 kB stay under 3% (O157
+0.24%, CHM13 chr21 +2.93%). By the rule fixed before the runs, **the
reference-mode default stays level 1** and the README states the W3110 case in
both units — +9.84% and +190 bytes — with `-l 3` named as the remedy, which at
level 3 is also smaller than v0.8.0 on both bacterial pairs.

**What is not done here, and why.** Four experts at level 1 would remove this
loss outright and gain on every reference-mode pair measured. It was priced on
the human pair in Batch 3 — **+21.1% time for −0.523% size** — against a rule
fixed in advance (≥ 1.0% at ≤ 20%, or ≥ 0.5% at ≤ 10%), and it failed. Changing
the default now, on the strength of a result found after that rule was written,
is exactly the move the routine exists to prevent. It is recorded instead as the
first candidate for the next release, with its price attached, and it is in the
README where a reader will see it rather than in a drawer.

## P: the release figures, predicted then measured

Plain mode at the release is Batch 3's `cue_M4`, so P1–P3 were stated to the
byte from `docs/batch3.md` §5 before anything ran. They are the sharpest test in
this batch of Batch 4's P1 — that the run-time cue *is* the compiled cue — because
they extrapolate it to files and levels that check never touched.

| | claim | predicted | measured | |
|---|---|---:|---:|---|
| **P1** | E. coli `.seq`, level 3 | 1,092,635 ± 6 | **1,092,635** | held, to the byte |
| **P2** | chr21 `.seq`, level 3 | 7,498,337 ± 8 | **7,498,339** | held on the bytes, 2 past the centre. The bpb the prediction derived from them, 1.4963, was itself a rounding slip: 7,498,339 bytes is **1.4964** |
| **P3** | chr21 `.seq`, level 1 | 7,540,777 ± 8 | **7,540,777** | held, to the byte |
| **P4** | chr21 slice `.seq`, level 3 | 2,103,300–2,104,100 | **2,103,089** | **failed**, 211 B past the band — a bigger gain than predicted (−0.054%, not −0.009% to −0.044%) |
| **P6** | E. coli `-j 8` | within ±0.05% of 1,116,080 | 1,116,227 (+0.013%) | held |
| **P8** | W3110 `.fa`, levels 3 / 1 | 1,916 / 2,121 | **1,916 / 2,121** | held, to the byte |
| **P9** | `ecoli_ind` and O157 `.fa` | 12,051 / 12,204 and 362,006 / 362,862 | all four exact | held, to the byte |
| **P10** | level 4 with the cue | a gain, smaller than 0.05% | E. coli −0.005%, slice −0.054% | **part held**: a gain on both, but the slice is just past the band |

P8 and P9 are worth one more sentence than their table row. Batch 4 measured
those five numbers against a **primed state**; these rows compressed against the
**FASTA** reference instead, and got the same bytes. That is the state/FASTA
interchangeability the adversarial suite asserts, holding across a format change
and at the release settings.

The three near-misses (P4, P10, and the E. coli `-j` blocks going from neutral to
+0.013%) all point the same way: `CUE_MINLEN=4` makes the cue slightly *more*
active in plain mode than the extrapolation from `CUE_MINLEN=16` predicted, and
in block mode that costs a little rather than earning. It is 147 bytes on a
1.1 MB file, and it is stated here rather than rounded away.

## F: the rewrite, and what giving every cell a row turned up

**F1 held with one consequence worth naming.** `verify-claims.ps1` now compiles
two builds: `$dnac` is the release (no flags at all — the binary a reader of the
README would build), and `$v08` is the same source configured as v0.8.0, kept
only for the rows whose claim *is* a comparison. Every README figure was then
re-measured twice by independent code — once by `scripts/cue/batch5-readme.sh`
and once by the registry — and the two agreed everywhere. That is the check
Batch 4's window-split bug argued for: a figure computed once by one
implementation is a figure nobody has checked.

**A tenth wrong published figure, and the row that had never existed.** The
headline table said `| **dnac** (k=22) | 1.546 | 1.883 |` with the note "on the
FASTA files". 1.546 *is* `chr21.fa`. **1.883 is `ecoli.seq`** — the plain-ACGT
file. The FASTA figure is 1.8845. The error is small and it is the same shape as
the nine before it: the cell was published, read many times, and **never
executed**, because no row covered it while the row above and below it did. Both
cells now have one, and so does the `gzip -9` row that replaced the `zip` row —
`zip` was a number this repository could not re-run.

**F3 changed more of the README than expected.** Printing the reference-mode
tables at the default *and* at `-l 3` is what makes the level-1 loss visible
without a reader knowing this document exists — but it also moved the
competitor comparison. Against GeCo3's own reference templates, v0.8.0 was 19.6%
ahead on the near-identical pair; v0.9.0 is 19.4% ahead at `-l 3` and **3.0%
ahead at the default**, because on a 2 kB output level 1's two-expert mixer eats
most of the lead (W5). The "compression-as-classifier" section quoted that 19.6%
as evidence the idea would not transfer; it is now quoted at both levels, and
the conclusion is unchanged.

**A claim can now be held in two documents at once (`also`).** The release
figures live in `docs/batch4.md` as the record of the run that produced them and
in `README.md` as what the codec does today. Re-measuring them twice would have
doubled the most expensive tier for no extra information, so a row may carry a
second (doc, anchor) pair: one measurement, two sentences, and editing either
sentence by hand turns the claim red. Twenty rows use it. The self-test breaks
the second anchor exactly as it breaks the first, and was watched doing it —
`-SelfTest` now reports 4/4 instead of 3/3 on the always-run detectors.

### The instrument finding: `dnac mut` writes the caller's path into the data

The gradient rows were written to derive their own target -- `dnac mut` at the
rate and seed the document names -- rather than read a stored file, so that a
change to `mut` could not slip past them. Running them turned one row red:
`w5-mut50-penalty-pct` said 1.83% and measured 1.81%. The two targets were the
same size, and their **sequences hashed identically**. Only the FASTA header
differed:

    >simulated_individual from=C:\Users\...\ecoli.fa snp_per_mille=5.000 seed=42
    >simulated_individual from=C:/Users/.../ecoli.fa snp_per_mille=5.000 seed=42

`mut` records its input's path in the header, the header is compressed with
everything else, and a shell script spelling the reference with forward slashes
therefore produces a different archive from a PowerShell row spelling it with
backslashes: **2 bytes at level 3, 7 at level 1** on a 43 kB output. Enough to
move a published percentage by 0.02.

Both implementations now overwrite the first line with a canonical
`>mut_<rate>_seed42` before compressing, and the gradient was re-measured with
it. The general rule this adds, alongside "a figure only ever read rots": **a
recipe that generates its own input must generate a canonical one.** Two
implementations disagreeing is what caught it -- the same instrument that caught
Batch 4's window-split bug, working the same way.

## The two tables that quote wall-clock, re-run in one session

The head-to-head against GeCo3 and the metagenome bake-off both promise that
every row came from one session on one machine. v0.9.0 moves every dnac size in
them, so keeping v0.8.0's times beside v0.9.0's sizes would have broken exactly
that promise. Both were re-run end to end, dnac three rounds and GeCo3 two, the
minimum quoted.

| dataset | dnac | GeCo3 |
|---|---|---|
| E. coli | `-l 3` 1.8832 @ **10.0 s** | `-l 9` 1.8903 @ 11.4 s; `-l 16` 1.8913 @ 73.8 s |
| chr21 slice | `-l 3` 1.7105 @ **22.1 s**; `-l 1` 1.7168 @ 10.6 s | `-l 16` 1.7163 @ 91.6 s; `-l 14` 1.7195 @ 40.2 s |
| chr21 | `-l 3` 1.4964 @ 88.0 s; `-l 2` 1.5023 @ 59.2 s; `-l 1` 1.5048 @ **42.3 s** | `-l 14` 1.5092 @ 127.6 s; `-l 9` 1.5177 @ 77.6 s |

**The claim survives**: on all three datasets dnac still has a setting that is at
once faster and smaller than every GeCo3 setting tested. GeCo3's own times came
out well below the session the README quoted before (127.6 s against 174.1 on
chr21 `-l 14`, 91.6 against 224.8 on the slice at `-l 16`) while its sizes are
identical to the byte -- which is the 24% timing noise this project keeps
finding, seen from the other side, and the reason no wall-clock figure here has
a claim row.

Two invocation bugs surfaced while doing it, both of the same kind as the
defline: **a recipe that does not reproduce what it claims to.**

- `batch5-headtohead.sh` passed GeCo3 an absolute Windows path, and GeCo3 splits
  its arguments on `:`, so every GeCo3 row failed with `Error opening: C`. It
  runs in the work directory on a relative name now, which is what the registry
  already did.
- `batch5-meta.sh` piped into `zstd -c`. zstd writes a content-size field when it
  knows the input's length, so a pipe is **four bytes larger** than the
  registry's `-o file`, and `xz` on this machine resolves to a busybox applet
  that cannot compress at all. Every competitor is now invoked exactly as
  `verify-claims.ps1`'s `Ext` invokes it.

## The priming table is a level-1 table now

`prime` and `cr` default to level 1 with a reference, so every figure in "Pay for
the reference once" moved, and the state files with them:

| reference | priming pass | load a state | a 40 Mbase target | state |
|---|---:|---:|---:|---:|
| E. coli, 4.6 Mbp | 5.9 s | 0.5 s | — | **481 MB** (616 at `-l 3`) |
| chr21, 40 Mbp | 45.2 s | 0.6 s | 80.6 s → **35.9 s** | **717 MB** (1,255 at `-l 3`) |

**P7 failed, and in the opposite direction to the prediction.** It said the state
would be *larger* than 616 MB by less than 40 MB, because the cue adds a deck and
a mixer input to the model memory. At level 3 the state is unchanged to the
megabyte; at the default it is **22% smaller**, because the default is level 1
and level 1 holds fewer tables. The prediction simply forgot that Batch 4 moved
the default -- a miss of exactly the kind this batch found three of in the data.

The script also asserts, at chromosome scale, the thing that table claims in
passing and nothing else checks there: a state and the FASTA it came from write
the **same archive, byte for byte**.

### And the same trap once more: stderr sent to /dev/null

`batch5-meta.sh` reported `(xz -9e failed)` on both runs. Run by hand, `xz -9e`
compresses the 200 Mbase metagenome perfectly well, to **25,072,456 bytes** --
the exact figure the README has always printed -- in 252.1 s. The script could
not say why it failed, because the failing command's stderr went to
`/dev/null`. That is the trap `benchmark.ps1` taught this project in August
("do not pipe a tool's stderr to Out-Null in a harness whose job is to notice
the tool failed"), met again in a script written this session. The xz row was
therefore measured in a **second invocation, minutes after the first**, on the
same otherwise-idle machine, which is stated here rather than presented as part
of the one session the rest of that table came from.

A second thing that row settles: **xz, not zstd, is the smallest of the
general-purpose tools on this input** (25,072,456 against 25,427,359). The
README quoted "1.47x smaller than zstd" -- true, but zstd is not the toughest
competitor in its own table. It now reads 1.45x against xz *and* 1.47x against
zstd, so the comparison is against the best of the field and against the one
people actually run.

## R: what is green, and what still has to run

The rewrite is a documentation and registry change; `dnac.c` is untouched by
this batch, so losslessness and the format are exactly Batch 4's and are
defended by the same 229 round-trips.

| check | state |
|---|---|
| `sh scripts/roundtrip.sh ./dnac.exe` | **229/229**, at the start of the session and again at the end |
| `./adversarial.ps1` | **155/155** on the release build |
| `verify-claims.ps1 -Tier fast` | run with the new rows; see below |
| `-SelfTest` | **4/4** — ANCHOR, DRIFT, ERROR and the new second-anchor detector, each watched going red before it was trusted |
| `slow`, `extern`, `meta`, `cue`, `cue3`, `b4` | **still to run** |

The registry went **314 → 350 rows**. The tiers that defend the records
(`cue`, `cue3`, `b4`) compile `4932ffe` and are untouched by this batch except
for the twenty `also` anchors added to `b4`, which add no measurement.
