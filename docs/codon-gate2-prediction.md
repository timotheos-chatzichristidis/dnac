# Codon gate, round 2: fixing the false positives -- pre-registration

Written 2026-10-11, after docs/codon-euk.md and before any genome below was fetched.

## Why

The release gate (tracker on if G >= 2.0) opened on A. thaliana chr 1 (G 2.81) and on
D. melanogaster 2L (G 2.46), and the tracker LOST there (-0.08%, -0.09%). G measures how
strong the period-3 signal is, not whether the tracker can follow it through introns.
Changing the gate is an encoder decision only (the family letter already tells the
decoder) and moves no published figure (every README file has G >= 3.26 or <= 1.17).

## Rules compared

- **REL** release: ON if G >= 2.0.
- **T3** threshold 3.0: ON if G >= 3.0. Fitted to docs/codon-euk.md: it closes both false
  positives there and keeps all four bacteria (lowest 3.26) open.
- **TG** trial gate: if G >= 2.0, code a sample both ways at the file's level and keep the
  tracker only if the sample with it is smaller by at least 0.10%. Sample: the 262,144
  bases (256 Kbase) around the middle of the file's bases, or the whole file if it has
  fewer. Emulated here by cutting that stretch out at line boundaries, prepending a
  one-line header, and compressing it with `-nocodon` and with the tracker forced
  (DNAC_CODON_FORCE, same scratch build as docs/codon-euk.md). A real implementation would
  code the same bases from memory; the emulation's header byte costs both arms equally.

## Genomes (all UNSEEN; fetched by accession after this commit)

Eukaryotes: P. falciparum 3D7 chr 1 `NC_004325`, D. discoideum AX4 chr 1 `NC_007087`,
O. sativa (rice) chr 1 `NC_029256`, M. musculus chr 19 `NC_000085`, D. rerio chr 1
`NC_007112`.
Prokaryotes: M. tuberculosis H37Rv `NC_000962`, H. pylori 26695 `NC_000915`,
S. pneumoniae TIGR4 `NC_003028`, M. jannaschii (an archaeon) `NC_000909`.
If an accession's defline does not name the expected organism, that genome is DROPPED,
not replaced.

The 10 files of the earlier rounds (five eukaryotes, four bacteria, chr21_slice) are
reported under every rule for completeness and decide nothing.

## Measurements

Per genome, level 1: G (`DNAC_CODON_DEBUG`), size with `-nocodon` (E0), size with the
tracker forced (E2), both decoded and `cmp`'d. For TG, the sample sizes both ways (also
round-tripped). TG's time cost: E. coli level 1 encode, release vs release + the two
sample encodes, min of 3 alternating rounds, run alone.

**Regret** of a rule on a genome = (size the rule picks - min(E0, E2)) / E0, in %. A rule
that picks the better arm has regret 0.

## Decision rule (fixed now)

A candidate (T3 or TG) is ADOPTABLE if, on the UNSEEN genomes:
1. its mean regret is lower than REL's;
2. on no genome is its regret above REL's by more than 0.05 pp;
3. it closes no genome whose forced gain is >= 1.0%;
4. TG only: the two sample encodes add <= 10% to E. coli level-1 encode time.

If both are adoptable, the lower mean regret wins; within 0.01 pp, T3 (no time cost).
**If no unseen genome has G in [2.0, 3.0), T3's threshold is untested and T3 is not
adoptable** -- it would rest only on the genomes it was fitted to; TG can still be judged
on the rest. If REL's regret is zero on every unseen genome, nothing is changed and the two
known false positives are recorded as a known miss of under 0.1%.

Adoption itself (the gate in dnac.c, both suites, verify-claims) is a separate step and
Timotheos's decision.

## Predictions (mine)

| genome | G | forced gain |
|---|---|---|
| P. falciparum chr 1 (80% AT) | 2 - 4 | -0.2 .. +0.5% |
| D. discoideum chr 1 | 3 - 6 | +0.3 .. +1.0% |
| O. sativa chr 1 | 2 - 3 | -0.2 .. +0.1% |
| M. musculus chr 19 | 1.1 - 1.4 | -0.5 .. -0.2% |
| D. rerio chr 1 | 1.1 - 1.4 | -0.5 .. -0.2% |
| M. tuberculosis | 4 - 7 | +2 .. +4% |
| H. pylori | 3 - 5 | +1.5 .. +3% |
| S. pneumoniae | 3 - 5 | +1.5 .. +3% |
| M. jannaschii | 2.5 - 4 | +1 .. +2.5% |

G1  REL has at least one false positive on the unseen set (rice or P. falciparum).
G2  T3 fails condition 3 on at least one prokaryote: an AT-rich genome (M. jannaschii)
    falls under 3.0 while its tracker gains over 1%. A threshold is the wrong shape.
G3  TG is adoptable and wins: it measures the gain itself. Its time cost on E. coli is
    about +6% (two 256 Kbase encodes against a 4.6 Mbase file).

Timotheos's prediction: none given ("patience, we will see").
