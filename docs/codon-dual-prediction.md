# Codon tracker: code both ways, keep the smaller -- pre-registration

Written 2026-10-11, after docs/codon-gate2.md and before any code. Agreed with Timotheos
the same day ("OK πάμε").

## Why

The release gate (G >= 2.0) is wrong in both directions: H. pylori (G 1.74) is coded
without the tracker it would gain 2.77% from; rice (G 2.12), A. thaliana (2.81) and
D. melanogaster (2.46) are coded with a tracker that loses 0.08-0.42%. No threshold on G
separates them, and a 256 Kbase trial misjudges gene-dense genomes (docs/codon-gate2.md).
The rule with zero regret by construction is to code the whole file both ways and keep the
smaller archive.

## The mechanism (scratch build, `-DCODON_DUAL=1`, branch `codon-euk`)

At level 1, with the default codon setting (no `-codon`/`-nocodon`), plain mode, one block,
no `-map`: if G >= **1.5**, two threads each build a full model set and code the whole file,
one without the tracker and one with it; the smaller span is written, under the family
letter that names its choice. Below 1.5 the file is coded once without the tracker, as
today. The choice is the encoder's alone: a release decoder must read every archive this
writes, because each one is byte-identical to an archive the release encoder can produce
(`-nocodon` or the tracker forced). No format moves.

1.5 is fixed now: the vertebrates measured 1.10-1.17, the lowest file whose tracker gained
1.74 (H. pylori). It is a cost filter, not a classifier -- above it the choice is measured.

## Protocol

1. **Negative control**: `CODON_DUAL=0` build sha256-identical to main (ecoli.fa,
   chr21_slice.fa, level 1).
2. **Identity**: on every file below, the dual archive must be byte-identical to the
   smaller of release `-nocodon` and release-with-tracker-forced, and must decode with the
   RELEASE `dnac.exe` (main) to the original (`cmp`).
3. **Unseen genomes** (fetched after this commit; none used in any earlier round):
   bacteria Vibrio cholerae N16961 chr 1 `NC_002505`, Campylobacter jejuni NCTC 11168
   `NC_002163`, Bacillus anthracis Ames `NC_003997`, Listeria monocytogenes EGD-e
   `NC_003210`; eukaryotes Candida albicans SC5314 chr 1 `NC_032089`, Leishmania major
   Friedlin chr 1 `NC_007242`, Zea mays chr 10 `NC_050105`; and Gallus gallus chr 28
   `NC_052559` as a vertebrate. A genome whose defline does not name the expected organism
   is dropped, not replaced.
4. **Cost**, run alone, min of 3 alternating rounds, release default vs dual, encode only
   (decode is untouched by construction): wall time, process CPU time and peak working set
   on E. coli, H. pylori (from round 2) and full chr21 (G 1.17: the dual path must not run,
   so all three numbers must match release within noise).

## Bar (fixed now)

The dual rule becomes a candidate for the default at level 1 if ALL hold:
- identity holds on every file (a single mismatch is a bug, and the rule is not judged
  until it is fixed and every file re-run);
- regret is 0 on every unseen genome, by measurement;
- full chr21: wall time within +5% of release (min of 3) and the same peak memory
  within 2%: the filter must keep human-scale files free;
- E. coli: wall time <= +25% of release (two threads on a machine with free cores), peak
  memory <= 2.2x release.

## Predictions (mine)

D1  Identity holds on every file (it is the same code run twice).
D2  On the unseen set, release has regret > 0 on at least one genome (some bacterium below
    G 2.0 or some eukaryote above it); dual's regret is 0 by construction.
D3  E. coli wall time +5..+15% (the two threads compete for memory bandwidth), CPU time
    +95..+105%, peak memory 1.9..2.05x.
D4  chr21: no measurable difference.

Timotheos's prediction: none given.
