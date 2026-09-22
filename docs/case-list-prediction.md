# The case mask as an interval list: pre-registered

**Written 2026-09-22**, after `docs/case-mask.md` and before any code for
this design. Branch `case-mask`. The bar is not new: `docs/case-mask.md`
fixed it before this design existed. The result goes in `docs/case-list.md`.

## Why this design, and not a better bit model

`docs/case-mask.md`: a one-bit-per-base case model cost **1.20×** a bzip2'd
list of run lengths. By the rule written before that run, a failed condition 1
means the interval list is what gets built. Tuning the bit model until it wins
would move a failed mechanism onto a number already seen, which is ruled out.

The structural reason the list should win is the reason the bit model lost.
Case changes 119,986 times in 40,088,619 bases. A list pays at the boundaries.
A bit model pays at every position.

## The design

1. **The encoder uppercases every lowercase `a/c/g/t` outside a `>` line**
   (the header rule already in `docs/case-mask.md`), then codes the result
   with v0.9.0's unchanged model. **The main stream is therefore exactly the
   stream of the uppercase file.**
2. The case is stored as the **alternating run lengths over base positions**:
   an uppercase run first (possibly 0), then lowercase, then uppercase, and so
   on. A base position is an `A/C/G/T` byte, after uppercasing, outside a `>`
   line.
3. Each run length `v = len + 1` is coded with dnac's own range coder, as an
   adaptive Elias-gamma code. The unary part (⌊log₂v⌋) takes a context of
   (run parity, bit index). Each mantissa bit takes a context of (run parity,
   ⌊log₂v⌋, bit index, up to the two leading mantissa bits already coded).
   Nothing else. The contexts are fixed here, before any length is seen.
4. Layout, only in the case families (`DNCK`/`DNCM`, and the others in
   `CASE_LETTER`): after the 8-byte length, **8 bytes for the run count and
   8 bytes for the section size**, then the section, then the body exactly as
   v0.9.0 writes it.
5. A file with no lowercase base outside a header is written as v0.9.0 wrote
   it. Reference mode keeps the literal path, as before.

The decoder decodes the body exactly as v0.9.0 does, then walks the output
once with the same header rule and applies the runs.

## Predictions

| | prediction |
|---|---|
| **L1, the size** | the case section is **130,000 to 165,000 B** on chr21, central guess 148,000 |
| **L2, the separation, exact** | the `dna_sm` archive = the `dna` archive + section + 16 B, **to the byte**, and the body is `cmp`-identical to the `dna` archive's body |
| **L3, no cost without case** | every uppercase file byte-identical to v0.9.0 (as C6) |
| **L4, lossless** | 229/229, plus the nine mixed-case files from `docs/case-mask.md` at `-j 1` and `-j 4`; threaded = `-DDNAC_NO_THREADS` |

**The prediction most likely to be wrong is L1.** bzip2 sees the lengths as
decimal text and can exploit repeated values and sequences of them. An
order-0 gamma code with parity contexts cannot, and RepeatMasker's most
common element (Alu, ~300 bases) produces many near-identical lengths.

## D-L, the decision rule

Adopted only if **all** of these hold:

1. section ≤ **156,305 B** on chr21 **and** ≤ **161,224 B** on chr22. These
   are the opponent's lists, fixed in `docs/case-mask.md`;
2. L2 holds exactly;
3. L3 holds exactly;
4. L4 holds.

If 1 fails, the list is **not** shipped with a relaxed bar in this session,
and the numbers go to Timotheos as they are. The case is then a decision about
what a −27%-versus-today fix is worth against losing to bzip2, and that is his
to make, not a measurement's.
