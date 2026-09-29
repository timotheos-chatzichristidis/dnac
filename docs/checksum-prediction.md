# A flipped byte must be refused -- pre-registration

Written 2026-09-29, before any code. Since v0.11.0 a TRUNCATED archive is refused
(docs/truncation.md). A byte flipped inside a complete archive still decodes to wrong
bytes at exit 0, which is the one failure this project refuses everywhere else.

## Design (decided here, before measuring)
- **What is checked:** the ORIGINAL bytes, i.e. the decoder's output, end to end. That
  covers every section (coded body, `-j` blocks, the case list, the codon letters) with
  one check, and it also catches the class of bug this project has met three times: an
  encoder and a decoder that disagree (geometry, cue, level) and write wrong bytes at
  exit 0.
- **Hash:** CRC-64/XZ (ECMA-182 polynomial, reflected, init and xorout all ones), the
  check xz uses by default. 8 bytes. Its standard check value
  (CRC of "123456789" = 0x995DC9BBDF1939FA) is asserted once, so a wrong table fails
  loudly. A 32-bit check would save 4 bytes per file, which is 0.0006% of the smallest
  genome here, and would let one corrupt file in 4 billion through instead of one in
  1.8e19.
- **Where:** a TRAILER, the last 8 bytes of the file, little-endian. No existing header
  offset moves, so every script that reads bytes 3, 5 or 16-31 keeps working. The decoder
  already holds the whole output in memory before writing it, so a mismatch leaves no
  output file.
- **How a file says it has one:** the third magic byte, `DNC?` -> `DNH?`. The family
  letters keep their meaning unchanged. 'H' (0x48) is 3 bits from 'C' (0x43), so no
  single-bit flip turns a new file into an old one. Old `DNC?` files are read exactly as
  before, with no check. v0.11.0 and older say "not a dnac file" to a `DNH?` file. That
  is a refusal, not a misreading.
- **Not covered:** state files (a cache, not an interchange format; the reference
  fingerprint already guards them). A flip that turns `H` into exactly `C`, an
  8-bit-specific change of one byte, makes the file read as an old one. The trailer is
  then trailing data and the output is still correct. Harm would need a second flip.

## Predictions / checks
C1  **Only the envelope moves.** For every file the new archive equals the v0.11.0
    archive with byte 2 changed from 'C' to 'H' and 8 bytes appended. Checked by bytes
    on every file both suites and the claim registry produce: levels 1-4, `-codon`, `-j`,
    case list, codon + case, reference mode. So **every published byte count moves by
    exactly +8**, bits/base only at the rounding edge, and no model changes.
C2  **Every flip is refused or harmless.** Every stream in the flip set, with single
    bytes changed (every header byte, 40 random positions in the body, every trailer
    byte, XOR 0x01 and XOR 0xFF each), either exits != 0 with no output file left or
    decodes to exactly the right bytes. Zero wrong outputs at exit 0, and no crash
    (signal exit). v0.11.0 is run on the same flips as a negative control and must
    produce wrong outputs at exit 0.
C3  **Old files still read.** tests/v080, tests/v090, and a new tests/v0110 (streams
    written by the v0.11.0 tag: plain L1/L3, codon, `-j`, case, reference) decode
    byte-exact.
C4  **Time:** encode and decode time on full chr21 change by less than 1% of the run
    (CRC over 47 MB against ~90 s). Reported, with the 24% noise caveat; not a bar.
C5  Both suites grow with the flip, old-stream and wrong-decoder cases, and are watched
    failing on v0.11.0 first. The body comparison in roundtrip.sh (`tail -c +17` twin
    vs case file) has to strip the trailers; that is an expected edit, not a failure.
Then the re-measurement: verify-claims fast and slow. Every red row must be a byte count
that moved by exactly +8 (or a figure derived from one). Each is re-anchored from the
new run. Any other red row stops the release.

## Decision rule
C1 or C2 failing anywhere stops the change until it is understood. If C1 fails, a model
moved; that is a bug by definition, since nothing here touches the model. C3 failing
stops the change. C4 over 1% is reported and discussed, not fitted away.
