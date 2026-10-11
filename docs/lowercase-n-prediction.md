# Lowercase `n` in the case list -- pre-registration

Written 2026-10-11, before any code or run. Next item of the post-v0.12.0 list. Ordered by
Timotheos the same day. `main` = ed2a8b7 (v0.12.0 + the GeCo3 bacteria rows), local branch
`lowercase-n`.

## Why

Since v0.10.0 a lowercase a/c/g/t outside a `>` line is coded as its uppercase twin, and the
case travels in a run-length list (docs/case-list.md). A lowercase `n` does not: it stays a
literal byte, and the model codes `n` and `N` as two different non-base symbols.
docs/case-list.md measured what that costs on chr21: **6,745 B** (the case-list archive minus the
archive of the twin with only a/c/g/t uppercased, to the byte). It also said this is "the next
6.7 KB", a new design that needs its own pre-registration. This is that pre-registration.

What is known before any run (counts outside `>` lines, every file in data/):

| file | lowercase `n` | lowercase a/c/g/t | uppercase `N` |
|---|---:|---:|---:|
| chr21_sm.fa | 1,261,364 | 21,491,066 | 5,360,000 |
| chr22_sm.fa | 948,691 | 21,658,340 | 10,710,000 |
| the other 9 files (bsub, chr21, chr21_ind, ecoli, ecoli_ind, o157, paer, saur, w3110) | 0 | 0 | 0 to 6,621,364 |

Only the two soft-masked chromosomes can move.

## The design

1. **When it applies.** A file goes into case mode if it has a lowercase a/c/g/t **or a lowercase
   `n`** outside a `>` line. If it also has at least one lowercase `n`, it is an **n-file**.
2. **For an n-file**, the case list counts its positions over the bytes A/C/G/T **and N** (after
   uppercasing) outside `>` lines, instead of over A/C/G/T only. Every `n` becomes `N` in the
   twin, so the model sees only `N`. The decoder lowercases an `N` exactly as it does a base.
3. **The flag.** An n-file sets the top bit of the 8-byte run count in the case-section header.
   A run count never reaches 2^63, so the bit is free. A file without a lowercase `n` leaves it
   clear and is written **byte for byte as v0.12.0 wrote it**. That holds for case files too.
   - No new family letter is used. The case and codon families would need 8 more release
     letters, and only X, Y and Z are unused.
   - A v0.10.0 to v0.12.0 decoder reading an n-file finds a run count it can never reach.
     `case_list_dec` then returns an error, so the file is refused ("corrupt case list",
     exit 1), never decoded to wrong bytes. This is checked, not assumed (R3).
4. Reference mode, the codon tracker, `-j` and state files are untouched. Reference mode still
   has no case list. The case list is a whole-file pass made before the model sees any byte.

Rejected without measuring: a second, separate list for `n` only. The case of an `n` follows the
masking around it, and one list sees that while two lists do not. That is a reason, not a
measurement, and it is stated here so that nobody later reads the choice as tested.

## The opponent

v0.12.0 on the same file, which is today's behaviour: chr21_sm **7,890,488 B**, chr22_sm
**7,574,763 B** (README, verify-claims rows `case-chr21`, `case-chr22`).

## Predictions (mine)

- **N1.** chr21_sm shrinks by 5,000 to 6,745 B. The upper bound is the literal path's measured
  cost. Uppercase `N` blocks inside the list add a few runs, and the uppercase `N` literals that
  are left still cost a little.
- **N2.** chr22_sm shrinks by 3,000 to 8,000 B. Its `n` cost was never measured, and it has
  fewer `n` but twice the `N`.
- **N3.** chr21's run count (119,986) changes by less than 1%, and its section (143,081 B) grows
  by less than 1 KB.
- **N4.** Compress and decompress times do not move outside noise. This is reported, not
  claimed: the noise here is 24%.

Timotheos's prediction: none given.

## Requirements (all must hold; any failure stops it)

- **R1.** All 9 files without a lowercase `n`, at levels 1 and 3, plus both suites' fixtures
  that have no `n`: archives sha256-identical to v0.12.0 (ed2a8b7).
- **R2.** Both n-files round-trip (`cmp`) at levels 1 and 3, plain and `-j 3`, and so do the
  new suite cases (`n` only; `n` at the first and last position; `n` mixed with `N`; `n` inside
  a `>` line, which must stay literal and must not make an n-file).
- **R3.** v0.12.0's decoder refuses an n-archive with a nonzero exit and writes no output file.
- **R4.** Body identity, which is the case list's invariant: the n-archive's body is
  `cmp`-identical to v0.12.0's archive of the twin with a/c/g/t/n uppercased, and the archive is
  that body + section + 16 B + trailer, to the byte.

## Decision rule (fixed now)

**Adoptable** if R1 to R4 hold **and** both chromosomes shrink by at least **0.05%** of the
v0.12.0 archive: chr21_sm by at least 3,945 B, chr22_sm by at least 3,787 B. That is about half
of the 0.09% ceiling on chr21. Below the bar on either chromosome, the change is not adopted and
`n` stays literal.

"Adoptable" is not "adopted". It is a format change: an n-archive cannot be read by v0.10.0 to
v0.12.0. It would need its own release, a re-measurement of the 10 `case-*` rows, new suite
cases and stored v0.12.0 streams. Whether about 6 KB per chromosome is worth that is Timotheos's
decision, made after the numbers.
