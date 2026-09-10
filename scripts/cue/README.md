# scripts/cue: how the nudge and cue figures were measured

These are the scripts behind `docs/nudge.md`, `docs/cue*.md`,
`docs/real-human.md`, `docs/competitors.md`, `docs/remaining.md` and
`docs/speed.md`, together with the raw numbers they produced. They were run from
a scratch directory holding the test genomes, so they carry relative and a few
absolute paths from that machine. They are here so the figures can be traced,
not yet as a one-command re-derivation.

**Not yet wired into `verify-claims.ps1` or CI.** No figure from these documents
has an anchor sentence or an executable recipe in the registry, and CI does not
build `-DDNAC_CUE`. That is the first job of a v0.9.0 (see below).

| file | what it does |
|---|---|
| `measure.sh <exe> <label>` | the 10 E. coli targets (control, 3 × substitution, random indel, homopolymer slip), round-trips each, appends bytes to `sizes.tsv` |
| `measure_real.sh <exe> <label>` | W3110, O157, `ecoli_ind`, `chr21_ind`, round-tripped, to `real.tsv` |
| `score.py` | per-event cost in bits: (target − zero-event control) × 8 / 2000 |
| `halves.sh`, `halves.py` | `-map` per-event cost in the first and second half of each target (the osmosis measure) |
| `sweep.sh` | the nudge's labelled L × D sweep |
| `competitors.sh` | zstd, dnac, HRCM and GeCo3 on CHM13 against GRCh38 chr21 |
| `hrcm-windows.patch` | the changes that let HRCM run on Windows: `getopt` skips the mode word, binary file I/O, a larger command buffer, 7-Zip's `7za.exe` for the PPMd step, and its intermediate files kept instead of `rm`-ed. None of them touches its algorithm |

`evidence/`: the raw outputs (`sizes.tsv`, `real.tsv`, `halves.tsv`,
`timing.tsv`, `lvl.tsv`, `competitors.tsv`), plus the four real-pair `-map`
files (CHM13 chr21 and chr22, v0.8.0 and cue, gzipped) that the
shared/diverged/novel splits were computed from.

Test genomes (not committed): `make_tumour.py` from the bitshape repository
builds the E. coli targets. CHM13 chr21 is NCBI `CP068257.2` and chr22 is
`CP068256.2`. GRCh38 chr22 is Ensembl release 110.
