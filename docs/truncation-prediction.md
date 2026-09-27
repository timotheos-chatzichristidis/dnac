# A truncated archive must be refused -- pre-registration

Written 2026-09-28, before any code. Found 2026-09-27 while writing the codon tracker's
round-trip cases: a `.dnac` cut inside its coded body decodes to WRONG bytes at exit 0.
This is true of v0.10.0 too (checked on a plain level-1 stream cut to 200 bytes: exit 0,
306,872 bytes written). That is the one failure this project refuses everywhere else.

## Cause
`rdec_byte` returns 0xFF once the coded data runs out, silently, and decoding goes on.

## Fix (decoder only, no format change)
Count the reads past the end in `RDec`. If, when a span has been decoded, it read past
the end even once, the archive is refused with a message and a non-zero exit, and no
output file is left behind. This covers the main body, every `-j` block and the case list.
Because it changes no stream, it also protects files written by v0.10.0 and v0.9.0 when
they are read by this build.

## What it does NOT catch, stated in advance
A byte flipped inside a stream of the right length. That needs a checksum stored in every
file, which moves every published byte count, so it is left to its own release.

## Predictions / checks
T1  No false refusal: a valid stream never reads past its end. Checked on every stream of
    both round-trip suites, every benchmark file at levels 1-4, reference mode, -j 8, the
    stored v0.8.0 (tests/v080) and v0.9.0 (tests/v090) streams, and the codon streams.
T2  Every truncation is refused: each of the streams above cut to 50%, 90%, and "one byte
    short" is refused with exit != 0 and no output file.
T3  Round-trip suites grow by the new truncation cases, and are watched failing on the
    v0.10.0 build first.
If T1 fails anywhere, meaning some valid stream does read past its end, the check becomes
"more than k bytes past the end" only if k is derived from the coder, not fitted to the
failures. Otherwise the fix is dropped and the finding stays open.
