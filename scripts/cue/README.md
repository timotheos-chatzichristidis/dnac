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
| `competitors.sh` | zstd, dnac, HRCM and GeCo3 on CHM13 against GRCh38 chr21 |
| `hrcm-windows.patch` | the changes that let HRCM run on Windows: `getopt` skips the mode word, binary file I/O, a larger command buffer, 7-Zip's `7za.exe` for the PPMd step, and its intermediate files kept instead of `rm`-ed. None of them touches its algorithm |

Everything is written to `bench-external/work/cue/`, which is scratch.

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
