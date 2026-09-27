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
