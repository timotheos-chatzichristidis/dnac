# A truncated archive must be refused -- result

Run 2026-09-28, pre-registered in `docs/truncation-prediction.md` (commit b56b8fb).

## The change (decoder only; no stream changes)
`RDec` counts reads past the end of its data (`rdec_byte` still returns 0xFF so the
decode can finish, but the read is counted). A span that read past its end is
refused: the single-span path, every `-j` block (the worker marks the block failed),
and the case list. Every failure after the decoder has opened its output now also
REMOVES that output. Before, several of those paths, the block-table check among them,
left an empty file behind.

## Results
`EXE=<build> bash scripts/pilot/trunc-check.sh`: 23 valid streams (E. coli L1-L4,
`-codon`, `-j 8`, `-j 4` codon blocks, chr21_slice L1/L3, soft-masked human with the
case list, soft-masked E. coli with case and codon, a tiny messy CRLF file, reference
mode at L1 and L3, and the stored v0.8.0 and v0.9.0 streams), each also cut to 50%,
90% and one byte short.

| | this build | v0.10.0 (negative control) |
|---|---:|---:|
| T1: valid streams decoded, correct bytes | **23/23** | 23/23 |
| T2: truncations refused, no output left | **69/69** | **1/69** |

| | prediction | outcome |
|---|---|---|
| T1 | no valid stream reads past its end | held (and both suites, below) |
| T2 | every truncation refused, no output | held, 69/69 |
| T3 | suites grow and are watched failing on v0.10.0 first | held: `scripts/roundtrip.sh` 296/296 (v0.10.0: 15 fail, exactly the new truncation and codon cases); `adversarial.ps1` 182/182 (v0.10.0: 7 fail) |

The first T2 run failed on blocked streams. Those were refused, but they left an empty
output file, because the block-table check closed the file without removing it. That is
the "no output file" half of the prediction, and it was fixed as described above.

## What remains
A byte flipped inside a complete stream still decodes to wrong bytes. Catching that
needs a checksum in every file, which moves every published byte count. It is left to
its own pre-registered release.
