# scripts/cue: how the nudge and cue figures were measured

These are the scripts behind `docs/nudge.md`, `docs/cue*.md`,
`docs/real-human.md`, `docs/competitors.md`, `docs/remaining.md` and
`docs/speed.md`, together with the raw numbers they produced.

**They run from a clean checkout.** Every path comes from the repository root
(`common.sh`), the data is fetched or rebuilt by one command each, and every
figure they produced now has a row in `verify-claims.ps1` that re-derives it.
Until v0.9.0's Batch 1 none of that was true: the scripts carried one machine's
absolute paths, the targets existed nowhere but that disk, and no figure in
these documents had an executable recipe.

## The data

| what | how |
|---|---|
| the ten controlled E. coli targets | `sh scripts/cue/make-targets.sh` — rebuilt from `ecoli.fa` in about 6 s, and checked against `targets.sha256`, so a rebuild that drifts is seen rather than compared |
| CHM13 chr21 / chr22, GRCh38 chr22 | `sh scripts/get-data.sh --cue` — by accession (`CP068257.2`, `CP068256.2`) and Ensembl release 110, checked against `data.sha256` |
| GRCh38 chr21 | the repository's own `chr21.fa` (`sh scripts/get-data.sh --human`) |
| HRCM | built from `hrcm-windows.patch` into `bench-external/cue/hrcm/` |

`make_tumour.py` is a verbatim copy of the bitshape repository's
`scripts/make_tumour.py` at commit `5d2b645`; it is vendored so this repository
can rebuild its own test data, and it is not modified here. The targets are
deterministic: the same reference and seed give the same bytes.

## The scripts

| file | what it does |
|---|---|
| `common.sh` | paths, and the table of build flags behind each label (`base`, `cue`, `noroom`, `mf`, `mf_noroom`, `cue2`, `nudge`, `L6D12` …) |
| `make-targets.sh` | rebuilds the ten E. coli targets and verifies them |
| `measure.sh <label>` | those ten targets, round-tripped, to `sizes.tsv` |
| `measure_real.sh <label>` | W3110, O157, `ecoli_ind`, `chr21_ind`, round-tripped, to `real.tsv` |
| `score.py` | per-event cost in bits: (target − zero-event control) × 8 / 2000 |
| `halves.sh`, `halves.py` | `-map` per-event cost in the first and second half of each target (the osmosis measure) |
| `sweep.sh` | the nudge's labelled L × D sweep |
| `batch3.sh <stage> <level> <label>...` | Batch 3's sweep and add-back, at a chosen level: stages `screen` (the ten targets + `ecoli_ind` + `o157`), `human` (`chr21_ind`, CHM13 chr21), `heldout` (CHM13 chr22), `plain` (no reference), to `batch3.tsv` |
| `batch3-time.sh <level> <rounds> <label>...` | paired encode timings of CHM13 chr21, labels alternating inside each round, to `batch3-time.tsv` |
| `batch3-score.py` | Batch 3's tables: per-event bits, and every file as a percentage against the same level's `base` and `cue` |
| `competitors.sh` | zstd, dnac, HRCM and GeCo3 on CHM13 against GRCh38 chr21 |
| `hrcm-windows.patch` | the changes that let HRCM run on Windows: `getopt` skips the mode word, binary file I/O, a larger command buffer, 7-Zip's `7za.exe` for the PPMd step, and its intermediate files kept instead of `rm`-ed. None of them touches its algorithm |

| `batch4.sh` | Batch 4's identity checks: the pinned `4932ffe` hazard (P0), the run-time cue against the compiled one (P1), the cue switched off against the v0.8.0 tag (P2), E. coli against itself (P7). Builds from three sources, prints PASS/FAIL, exits non-zero on any failure |
| `batch4-release.sh [section...]` | the cue documents' claims re-measured at the release settings, `rel` against `v08`, at levels 3 and 1: the ten targets and their halves, the E. coli pairs, `chr21_ind`, CHM13 chr21/chr22 with maps and the window split, and the `.seq` pair; to `rel/sizes.tsv` |

**Since v0.9.0 (Batch 4) the labels are records, pinned to their source.** The
cue became a run-time feature, `-DDNAC_CUE`, the nudge and `CUE_BACK` left
`dnac.c`, and `CUE_MINLEN`'s default moved from 16 to 4. So `build` in
`common.sh` compiles every label from `4932ffe`'s `dnac.c` -- the last source
that measured anything here -- with exactly the flags in `defines_for`. Only
`rel` (the release) and `v08` (the cue switched off, byte-identical to the
v0.8.0 tag) compile the working tree. `batch4.sh` is what ties the two worlds
together: the working tree with `-DCUE_MINLEN=16` writes `4932ffe -DDNAC_CUE`'s
bytes, but the magic. Timing Batch 4 uses `batch3-time.sh` with
`OUT=$WORK/batch4-time.tsv` and the labels `cue_M4 rel v08@3`.

Everything is written to `bench-external/work/cue/`, which is scratch.
**Run one of these at a time.** They all build to `$WORK/dnac_<label>.exe`, and
Windows will not let a link overwrite a running binary: two stages at once fail
at the linker (seen once, 2026-09-13). Set `WORK=` to a different directory if
two really must run together.

## Where the figures are defended

`verify-claims.ps1` holds a row — anchor sentence plus executable recipe — for
every figure in those six documents that a machine can re-derive:

    ./verify-claims.ps1 -Tier cue     # 65 min: per-event costs, the osmosis,
                                      # the sweep, the 2x2, the levels
    ./verify-claims.ps1 -Tier slow    # 2 h 52 min: the real human pairs,
                                      # the window splits, chr21_ind
    ./verify-claims.ps1 -Tier extern  # zstd --patch-from, HRCM, GeCo3

One tier at a time: GeCo3 on chr21 takes 9.2 GB, and two tiers at once on a
16 GB machine slow each other down without anything going red.

Those rows COMPILE the build they defend, so they need a compiler (`DNAC_CC`,
default `gcc`) and Python (`PYTHON`) for the osmosis arithmetic. Timings are the
deliberate exception: none of the wall-clock figures in those documents has a
row, because run-to-run noise on this machine is 24%.

`evidence/`: the raw outputs of the original 2026-09-10 session (`sizes.tsv`,
`real.tsv`, `halves.tsv`, `timing.tsv`, `lvl.tsv`, `competitors.tsv`), plus the
four real-pair `-map` files (CHM13 chr21 and chr22, v0.8.0 and cue, gzipped)
that the shared/diverged/novel splits were computed from. They are the record of
what was measured then; the rows above are what re-measures it now.
