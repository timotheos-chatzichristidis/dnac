# The cue against the competitors, on a real human pair: pre-registered

**Written 2026-09-10, before any competitor ran on this pair.** Committed alone.
The result goes in `docs/competitors.md`.

`docs/real-human.md` showed the cue makes dnac 5.97% better on CHM13 chr21
against GRCh38 chr21. It did not show whether dnac with the cue is any good
*against the tools people would actually use*. This is that test. It is the
rule from `bitshape/docs/METHOD.md` row 7: before any "beats X", run the
simplest same-input method, and put it in the table.

## The field

| tool | kind | input | round-trip verified? |
|---|---|---|---|
| `zstd -19 --long=27 --patch-from=<ref>` | the trivial one: a general diff | both tables | yes |
| **HRCM** (Yao et al. 2019, built from `github.com/haicy/HRCM`) | a specialist reference compressor, alignment/match style | FASTA | yes |
| **GeCo3** reference mode, the authors' two templates (`benchmark.ps1` `$PARAMR`, `$PARAMH`) | same family as dnac (context mixing) | plain ACGT | **no**: GeDe3 fails on every input on this machine (`README.md`), so these are stored sizes only |
| dnac v0.8.0 | — | both | yes |
| dnac `-DDNAC_CUE` | — | both | yes |

HRCM changes needed to run on Windows, none of which touch its algorithm:
`getopt` skips the mode word (mingw does not permute), file I/O in binary mode,
a larger command buffer, and the 7-Zip PPMd step pointed at `7za.exe` 26.03.
Checked first on HRCM's own example (hg17 → hg18 chr22): 73,470 B, and it
round-trips byte-identically.

## Inputs

- **FASTA table:** `chm13_chr21.fa` (NCBI `CP068257.2`, 70-column) against
  `dnac/chr21.fa` (GRCh38, with its 6.6 M `N`).
- **Plain table:** the same sequences as bare ACGT: `chm13_chr21.seq`
  (45,090,682 b) against `grch38_chr21.seq` (40,088,619 b, the file `dnac`'s
  GeCo3 benchmark already uses).

## Premises

| premise | value | command |
|---|---|---|
| dnac v0.8.0, FASTA | 586,615 B | `docs/real-human-prediction.md` |
| dnac cue, FASTA | 551,594 B | `docs/real-human.md` |
| CHM13 bits under v0.8.0 in windows ≥ 1.0 bits/base (sequence GRCh38 lacks) | 23.4% | same |
| dnac vs GeCo3 reference mode, E. coli pairs | dnac 19.6% ahead (W3110), 1.1% ahead (O157) | dnac `README.md` |

## Predictions

**C1.** The cue build is **≥ 2x smaller** than zstd `--patch-from`, in both
tables. *80%.*

**C2.** The cue build is **≥ 3% smaller** than the better of GeCo3's two
templates (plain table). *55%.* The pair is diverged (a sixth of CHM13 is not in
GRCh38), and on the diverged E. coli pair dnac led by only 1.1%. The cue adds
6%.

**C3.** The cue build is **≥ 10% smaller** than HRCM (FASTA table). *50%.* HRCM
is built for pairs of assemblies of the same individual or near-identical
versions. On sequence it cannot match it falls back to storing the raw bases
through PPMd, and here that is 23% of the problem.

**C4, no prediction, reported whichever way:** whether v0.8.0 *without* the cue
already beats each competitor. That is what tells us whether the cue changed
the ranking or only widened a lead.

## Time

Every competitor is far faster than dnac (HRCM took 4.6 s on the chr22 example.
dnac needs minutes). Times are reported from one run each and are **not a
claim**: this machine's run-to-run noise is 24%, and the gap is orders of
magnitude, not percent.
