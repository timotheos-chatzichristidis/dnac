# Codon phase as a context: the oracle ceiling -- result

Runs 2026-09-27. Pre-registered in `docs/codon-oracle-prediction.md` (b517d74), with the
controls replaced in `docs/codon-oracle-control-prediction.md` (fa3c55b) after the first
control proved void. Recipe: `COD=<build with scripts/pilot/codon-oracle.patch> REL=<branch build>
sh scripts/pilot/codon-oracle.sh` (and `CONTROLS=1` for the controls); labels from
`scripts/pilot/codon-labels.py`. The labels were checked before use: 0.32-0.33% of in-frame
+ strand codons are stops (the one terminal stop per gene), and GC by codon position is
0.589 / 0.408 / 0.559 (E. coli). Every archive was decoded and compared with cmp; the
patched build without variables is **byte-identical** to rel on both genomes; the build
asserts its history matches the label file base by base.

Plain mode, level 3, k 22:

| | E. coli MG1655 | gain | B. subtilis 168 | gain |
|---|---:|---:|---:|---:|
| rel | 1,093,425 B | -- | 1,002,525 B | -- |
| **oracle** (true phase) | 1,052,417 B | **3.7504%** | 971,726 B | **3.0721%** |
| shifted (void: a renaming) | 1,052,415 B | 3.7506% | 971,713 B | 3.0734% |
| nophase (coding + strand only) | 1,085,048 B | 0.7661% (20.4% of oracle) | 997,583 B | 0.4930% (16.0%) |
| randrot (phase not aligned across genes) | 1,081,059 B | 1.1309% (30.2%) | 993,743 B | 0.8760% (28.5%) |

| | prediction | outcome |
|---|---|---|
| C0 | none byte-identical to rel | held |
| C1 | oracle 1-4% on E. coli | held (3.7504%) |
| C2 | shifted < 1/3 of oracle | **void**: the control was a relabelling |
| C2' | each replacement control < 1/3 of oracle, both genomes | **held**: 20.4 / 30.2% and 16.0 / 28.5% |
| C3 | B. subtilis >= half of E. coli | held (3.07 vs 3.75) |
| N1 | nophase < 0.5% both | failed on E. coli (0.7661%), held on B. subtilis |
| N2 | randrot < 1.0% both | failed on E. coli (1.1309%), held on B. subtilis |

## By the rule: the lever is OPEN

The oracle clears 1.0% (E. coli) and 0.5% (B. subtilis), and neither real control reaches a
third of it. The margin is stated: randrot sits at 30.2% against 33.3%. **About 2.6 points
on E. coli and 2.2 on B. subtilis come from the phase itself**, meaning codon positions
aligned across genes. That is roughly ten times anything the cue experiments found. The
rule's next steps, in order: a prior-art search for phase-aware DNA compression, then a
pre-registered REAL phase tracker, which must infer the phase from the sequence alone. That
is the beatmatching problem again: lock onto period 3, and decide which strand.

What the oracle does not include: the tracker will pay for its mistakes, above all at gene
boundaries and on the strand choice. The ceiling is 3.75%. Where a real tracker lands
under it is the next measurement.

## Prior art (searched 2026-09-27)
- **A. J. Pinho, A. J. R. Neves, V. Afreixo, C. A. C. Bastos, P. J. S. G. Ferreira, "A three-state
  model for DNA protein-coding regions", IEEE TBME 53(11):2148-2155 (2006)**, from the Aveiro
  group behind GeCo. Three DETERMINISTIC states, each a finite-context model, cycling with
  position mod 3. They report gains over a single model and find that per-codon-position
  entropy differs between organisms. So the use of period 3 in DNA compression is occupied.
- The difference that matters here: a fixed mod-3 cycle does not know where genes start or
  which strand they are on. Across genes in random frames that is close to our **randrot**
  control (1.13% / 0.88%). The part our oracle adds on top of that, about 2.6 / 2.2 points,
  is phase ALIGNED to the genes, with strand. No compressor was found that infers it. That
  is the question a real tracker has to answer, and the full paper must be read before the
  tracker's pre-registration, in case it infers more than the abstract says.

**Update, same day, after reading further.** The TBME paper itself is paywalled, and no free
copy was found. The same group's open chapter (A. J. Pinho, A. J. R. Neves, D. A. Martins,
C. A. C. Bastos, P. J. S. G. Ferreira, "Finite-context models for DNA coding", in *Signal
Processing*, InTech 2010, cdn.intechopen.com/pdfs/9756.pdf) describes the three-state model
as one "for DNA protein-coding regions, i.e., for the parts of the DNA that carry information
regarding how proteins are synthesized". The companion ICASSP 2006 paper (Ferreira, Neves,
Afreixo, Pinho, "Exploring three-base periodicity for DNA compression and modeling") says it
uses the periodicity "usually found in exons". For "unrestricted DNA (coding and non-coding)"
the chapter moves to plain finite-context models with inverted-repeat updating, and drops the
three-state model. **Reading: the three-state model was applied to sequences that are
already coding regions, where the phase is known by construction. It was not applied to whole
genomes, where the phase must be found.** This rests on the chapter's wording, not on the
TBME paper's methods section. Two further searches found no compressor that infers reading
frame or phase on a whole genome. So "a whole-genome compressor that infers the aligned phase
and strand" appears unoccupied, stated with that limit.
