# The case mask: pre-registered

**Written 2026-09-22**, before any code or measurement, on branch `case-mask`
(from `main` at `6f63745`, v0.9.0). Nothing below has been run. The result will
go in `docs/case-mask.md`.

## What is wrong today

A lowercase base is not a base to dnac. `a`, `c`, `g` and `t` fail the flag
model's "is this a base?" test, go to the order-0 literal model, and **never
enter the base history** (`dnac.c` header comment, line 37). The FASTA
reference reader case-folds (`soft-masked bases count too`, line 1601); the
target path does not.

Soft-masking is how RepeatMasker output is distributed: Ensembl's `dna_sm`
files and UCSC's genome FASTA write repeats in lowercase. Repeats are exactly
what the match models, the RC model and the cue exist to exploit. So on a
soft-masked genome the codec codes its most predictable half with an order-0
model, and punches a hole in the history the other half is predicted from.

Every figure dnac has published was measured on uppercase input (`data/chr21.fa`
is Ensembl `dna`, with no lowercase in the sequence), so none of them sees this.

## The data, and why it is a clean test

Ensembl publishes GRCh38 chr21 twice: `dna` (the file we already use) and
`dna_sm`. **Same bases, same Ns, same line layout. Only the case differs.**
Uppercasing `dna_sm` must reproduce `dna` byte for byte, and that is checked
before anything is measured. chr22 in `dna_sm` is the held-out replication, as
it was for the cue.

## The mechanism

1. A lowercase `a/c/g/t` **is a base**: the flag model and the base models see
   exactly what they see on the uppercase file.
2. After the base's two bits, **one more bit: its case.** It is coded from its
   own small adaptive table and **never feeds any base model**. Its context:
   - the previous base's case;
   - how long the current case run has lasted (log₂ bucket);
   - **the case at the position the 13-base match model is pointing to**
     (none / upper / lower). This is the modelling claim. A repeat copy
     recurs, and its earlier copy was masked too, so the match model already
     knows where the masked stretch starts and ends.
3. The encoder scans the input first. **If it has no lowercase base, it writes
   v0.9.0's bytes exactly**, with the same magic. Only a file that contains a
   lowercase base gets a new stream family letter.

Lowercase `n` and every other non-base byte stay on the literal path as today.

**Scope:** plain mode (`c`) and blocks (`-j`). Reference mode (`cr`) keeps
today's literal path for lowercase target bases. Extending it would mean
carrying the reference's case into `g_seq` and into state files. That is a
state-format change, and it is not part of this experiment.

## The trivial opponent, measured first

Uppercase the file, compress it with dnac v0.9.0, and store the case separately
as a list of alternating run lengths over bases only, one number per line. Take
the smallest of `xz -9e`, `zstd -19` and `bzip2 -9` on that list. That is what
anyone would do in an afternoon, and the mechanism is only worth its code if it
beats it. It is essentially UCSC `.2bit`'s mask-block list, compressed.

## Predictions

All at level 3 and k=22, plain mode, every archive decoded and compared before
its size is recorded. Percentages are computed from byte counts and compared
**unrounded**.

| | prediction |
|---|---|
| **C1, the size of the problem** | v0.9.0 on `dna_sm` chr21 is **+15% to +45%** larger than v0.9.0 on `dna` chr21 |
| **C2, the opponent** | the opponent's case list costs **1.0% to 4.0%** of v0.9.0's `dna` chr21 archive |
| **C3, the separation** | the new build on `dna_sm` minus v0.9.0 on `dna` equals the case bits' own cost, summed as −log₂p by an instrument, **within ±64 bytes**. The case bit feeds no base model, so the base and flag bits must be the same bits |
| **C4, the modelling claim** | the case bits cost **0.40× to 0.75×** the opponent's case list on chr21. Central guess 0.6 |
| **C5, replication** | chr22 `dna_sm`: C1 and C4 hold, the ratio in C4 within 0.15 of chr21's |
| **C6, no cost where there is no case** | every uppercase file (every row in `verify-claims.ps1`) is **byte-identical** to v0.9.0 |
| **C7, time** | soft-masked chr21 encodes within **+5%** of uppercase chr21 under the same build (min of 3, the two alternating) |

**The prediction most likely to be wrong is C4.** RepeatMasker boundaries are
annotation calls, not sequence facts: two copies of the same repeat can be
masked at different lengths, and young copies can be left unmasked. If
boundaries do not recur with the copy, the match context earns little, and the
run-length context alone lands near the opponent.

## D-C, the decision rule, fixed now

The mechanism is adopted only if **all** of these hold:

1. On `dna_sm` chr21, the new build's archive is **smaller than the opponent's
   total** (dnac on the uppercased file, plus the best compressed case list).
2. **C6 holds exactly**: no uppercase file moves by a single byte. This is what
   lets it ship without re-measuring every published figure.
3. Lossless: `scripts/roundtrip.sh` 229/229, plus new cases written *before*
   the code: mixed case at every position of a line, lowercase `n`, a file that
   is entirely lowercase, a lowercase run crossing a `-j` block boundary, a
   single lowercase base, and a `cr` target with lowercase (literal path, must
   still round-trip).
4. C7 holds.

**The match-position context stays only if the case bits cost ≤ 0.80× the
opponent's list, on chr21 AND on chr22.** If it fails that, the mechanism
still ships (provided 1–4 hold), but with the run-length context alone.
Otherwise it is code that does not pay.

If 1 fails, and a one-bit-per-base model cannot beat a compressed interval
list, the right design is the interval list itself, and that is what gets built
instead.

## What is not being done

- No re-measurement of existing claims. C6 makes it unnecessary, and if C6
  fails the design is wrong, not the claims.
- No reference-mode case. It is scoped out above, with the reason.
- No case context for the base models. Masking says "this is a repeat". The
  match models already know when they are inside a repeat, and letting the
  annotation steer the prediction would make the bases' cost depend on
  RepeatMasker's version. Worth its own experiment after this one, not inside it.
