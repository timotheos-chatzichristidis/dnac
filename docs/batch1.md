# Batch 1: instruments

**Run 2026-09-12**, one session, no codec change. The job was to make every
figure on this branch re-derivable by someone who is not this machine, and to
put each one behind a check that can go red.

## What was not true before

The discovery session (2026-09-10) measured the cue against pre-registered
predictions and wrote the numbers down. But:

- the ten controlled E. coli targets existed only on one disk;
- `scripts/cue/*.sh` carried that disk's absolute paths, and one of them
  imported `make_tumour.py` from a sibling repository by full path;
- CHM13 chr21/chr22 and GRCh38 chr22 were fetched by hand;
- **not one figure in `nudge.md`, `cue*.md`, `real-human.md`,
  `competitors.md`, `remaining.md` or `speed.md` had a row in
  `verify-claims.ps1`**, and CI did not build `-DDNAC_CUE` at all.

So the branch's evidence was in the state the project calls the dangerous one:
**read, not executed.** Nine wrong published figures have come out of exactly
that state.

## What it is now

**The data rebuilds.** `sh scripts/cue/make-targets.sh` regenerates the ten
targets from `ecoli.fa` in 6 s and checks all ten against `targets.sha256`;
they came back byte-identical. `sh scripts/get-data.sh --cue` fetches CHM13
chr21 and chr22 by accession and GRCh38 chr22 from Ensembl release 110, checks
them against `data.sha256`, and builds the plain-ACGT sides. `make_tumour.py`
is vendored (bitshape `5d2b645`, unmodified), so nothing outside this
repository is needed.

**The scripts run from a checkout.** All paths come from the repository root
(`scripts/cue/common.sh`), which also holds the one table of build flags per
label; `verify-claims.ps1` carries the same table on its side, and a self-test
below asserts the flags actually reach the compiler.

**150 new rows in `verify-claims.ps1`**, each with the two detectors the
registry has always used: the doc's own sentence, lifted verbatim, and a recipe
that re-measures the number now. They are spread over three tiers:

| tier | rows (new / total) | what it defends |
|---|---|---|
| `cue` | 90 / 90 | per-event costs, the osmosis, the nudge sweep, the 2×2, the level table |
| `slow` | 55 / 69 | the real human pairs, the window splits, `chr21_ind` |
| `extern` | 5 / 15 | zstd `--patch-from`, HRCM, GeCo3 on the real pair |

The registry went from 51 rows to 201.

Those rows **compile the build they defend** — the cue exists only behind
`-DDNAC_CUE`, and every ablation behind another flag — so twelve builds are
compiled and measured, exactly as `./ablate.ps1` does for the model set.

**Do not run two tiers at once.** Tried once and stopped: GeCo3 on chr21 takes
9.2 GB, this machine has 15.7, and everything slowed to a crawl while nothing
went red. Sizes are deterministic, so the numbers would still have been right
— which is exactly why a wasted afternoon is the only symptom.

**A deviation from the plan, stated.** Batch 1 asked for the E. coli figures in
the `fast` tier. They are in a new `cue` tier instead: `fast` is the gate that
runs before every commit, its whole value is that it is cheap enough to always
run, and these rows are an hour. `-Tier all` covers both, which is the exit
condition either way.

**CI builds the cue** on all three platforms, runs the 203-case round-trip
suite against it, and then asserts something the suite cannot see: that
`-DDNAC_CUE` produces a *different* archive from the unflagged build on an
indel-dense pair. A flag that silently fails to reach the compiler would leave
every figure on this branch a comparison of a build with itself, and every
check green.

## The self-test, which is the point of the exercise

`-SelfTest` already broke the three general detectors (anchor, value, error).
Four more, for the four new ways to be wrong that those three cannot see:

1. an unknown build label must stop the run, not measure the default build;
2. **`cue` and `base` must not produce the same bytes** — the silent-flag
   failure above, checked here at E. coli scale (41,139 → 41,138 B on the
   zero-event control, which is also `docs/cue.md`'s "control −1 B");
3. a wrong value on a real cue measurement must read DRIFT;
4. `roundtrip.sh` pointed at a file that is not a codec must not report
   203/203 — the round-trip rows parse a count out of another script's output,
   and a parser that always returns 203 would make the one claim that must
   never be wrong unfalsifiable;
5. the table of build flags exists twice — `CueDefs` in the registry and
   `defines_for` in `scripts/cue/common.sh` — and the two are compared label by
   label. Two copies that quietly disagree would mean the published figures and
   the scripts that produced them measured different builds.

All eight detectors were watched red before any green was trusted. The two
that earn their keep printed their evidence on the way past: the cue flag moves
the control archive 41,139 → 41,138 B, and the two flag tables agree on nine
labels.

## What is measured, and what is deliberately not

Every number in those six documents that a machine can re-derive has a row.
**No wall-clock figure does**, on the standing rule: run-to-run noise here is
24%, and a row that cannot go red for the right reason will one day go red for
the wrong one. That leaves `docs/remaining.md`'s T2 (+3.1% encode), the
competitor times, and `docs/speed.md`'s seconds column defended by their
method and their pairing, not by this registry — stated as such wherever they
appear.

## Results

**`-Tier cue`: 90 of 90 reproduce**, 65 minutes, nothing red. Every per-event
cost, every osmosis ratio, the whole nudge sweep, all four corners of the 2x2,
the level-1 table — and 203/203 round-trips on each of the six builds
`docs/remaining.md` claims them for. The interesting thing is that there is
nothing interesting: the numbers written down on 2026-09-10 are the numbers the
machine produces now, and there is now a recipe that says so.

Two independent paths were checked against each other on the way, because the
registry re-implements in PowerShell what `scripts/cue/measure.sh` does in sh:

- the shell path, run end to end on a fresh build and freshly rebuilt targets,
  gives `ctl 41139 | sub 14.64 | ind 48.25 | hp 31.43` — the v0.8.0 row of
  `docs/cue.md`, to the byte;
- the window analysis, run against the stored `-map` evidence, gives chr21
  −18.27% / −2.67% / −0.00% and chr22 −16.24% / −3.49% / −0.01%, with 85.8% of
  windows and 25.3% of bits shared — every figure in `real-human.md` and
  `remaining.md`'s T4.

**`-Tier slow`: 69 of 69**, 2 h 52 min. The real human pair came back to the
byte — 586,615 → 551,594 (−5.97%), shared windows −18.27% with the same 39,888
windows and the same bit sums, novel −0.00%, the R4 halves −13.26% and
−23.21%; chr22 794,330 → 748,025 (−5.83%) with −16.24% / −3.49% / −0.01%; the
plain-ACGT pair 581,022 → 545,982; cue level 1 at 568,133 (−3.15%); and
`chr21_ind` for all eight builds, including the four corners of the 2x2.

**`-Tier extern`: 15 of 15**, 19 min. zstd `--patch-from` 3,143,939 (FASTA) and
882,586 (plain), HRCM 1,438,137, GeCo3's two templates 1,243,961 and 877,373,
plus the ten pre-existing GeCo3 rows. HRCM's round-trip is checked the way the
doc states it: everything must match except the file's final empty line, and
anything else is a failure.

So **every figure on this branch that a machine can re-derive, re-derives** —
the 150 new rows and the 24 older ones that share those tiers, none needing an
edit. Nothing was found wrong, which after nine
wrong published figures is worth saying plainly: the discovery session's
numbers were right. What changed is that they are now executable.

`-Tier fast` (21/21) and `-Tier meta` (6/6) were run too, because the cue rows
changed `Size`, the function every older row goes through: **201 of 201 rows in
the registry reproduce**, which is Batch 1's exit condition.

The cost of that, measured on this machine, one tier at a time: `fast` 7 min,
`cue` 65 min, `slow` 2 h 52 min, `extern` 19 min, `meta` 30 min — five hours
for the whole registry, which is why only `fast` is a pre-commit gate.
