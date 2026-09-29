# A flipped byte must be refused -- result

Run 2026-09-29, pre-registered in `docs/checksum-prediction.md` (commit 672ed50).

## The change
Every stream now ends in a CRC-64/XZ of the ORIGINAL bytes (8 bytes, little-endian),
and says so with `DNH` in place of `DNC`. The family letter after it keeps its meaning.
The decoder holds the whole output in memory, checks it against the trailer, and only
then writes it; on a mismatch it refuses and leaves no file. `DNC` streams (v0.11.0 and
older) are read exactly as before, with no check. v0.11.0 and older say "not a dnac file"
to a `DNH` stream.

One decoder change was not in the pre-registration, and C2 is why it exists. A flip in a
high byte of the stored length (byte 11 with XOR 0xFF) made the length about 4 GB. The
decoder then decoded gigabytes of garbage before the checksum could refuse it: 8 of
1,790 flips did not finish in 120 s. `decode_span` now stops at the first read past the
end of its data. A valid stream never does that (v0.11.0's truncation T1), so no valid
stream is affected; both suites re-ran after it.

## Results

| | prediction | outcome |
|---|---|---|
| C1 | every archive = the v0.11.0 archive with 'C'->'H' and 8 bytes appended | **held, 19/19** (levels 1-4, `-codon`, `-nocodon`, `-j 8`, codon blocks, k=16, case list, case blocks, codon + case, messy CRLF, empty file, one byte, reference L1/L3); claim rows: every byte count moved by exactly +8 |
| C2 | every flip refused or harmless, none wrong, none crashing | **held after the fix above**: 1,786 flips on 8 streams, 1,770 refused, 16 harmless, 0 wrong, 0 hung. v0.11.0 on the same kind of flips: **396 of 1,788 wrong at exit 0**, 8 hung, 1,336 refused |
| C3 | old streams still read | held: tests/v080, tests/v090 and the new tests/v0110 (plain L1/L3, codon, codon blocks, codon + case, reference) decode byte-exact |
| C4 | < 1% time | held: the CRC alone is 0.087 s over the 47.5 MB of chr21 (best of 5), about 0.08% of a run. Whole runs cannot resolve it: two runs of the same binary differ by up to 40 s |
| C5 | suites grow, fail on v0.11.0 first | held: `scripts/roundtrip.sh` 330/330 (v0.11.0: 7 fail, all new cases); `adversarial.ps1` 209/209 (v0.11.0: 6 fail). CI's two other builds (cue off, experimental) 330/330 each |

The 16 harmless flips are all byte 4, the maximum order `k`. Moving it from 22 to 23 or
to 233 keeps the same order set, so the models, and the bytes, do not change.

v0.11.0 already refused three flips in four. A flip desynchronises the range decoder,
which then often reads past its end, and the truncation check catches it. The fourth
flip is the one this release is for.

## Not covered
State files (a cache; the reference fingerprint guards them). A flip that turns 'H' into
exactly 'C' makes the stream read as an old one. The trailer is then trailing data, and
the output is still right; the suites check this. Harm would need a second flip.
