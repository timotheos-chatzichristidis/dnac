# Where does each cue load copy from? -- result

Run 2026-09-27, pre-registered in `docs/cue-source-prediction.md` (commit d1667b3).
Recipe: `SRC=<build with scripts/pilot/cue-source.patch> REL=<branch build> sh scripts/pilot/cue-source.sh`,
then `python scripts/pilot/cue-source.py chr21 <tsv> <grch38.fa> <chm13.fa> <chain.gz> chr21`.
The logging build writes an archive byte-identical to the branch build and round-trips,
on both chromosomes.

## An instrument error, caught before any figure was read
The first analysis pass put the target 2 bases off. dnac codes BYTES, so the upper-case
C of "**C**P068257" and "**C**HM13" in the target's FASTA header are bases in its
history. The script now builds the history the way the codec does and ASSERTS that every
load's 3 matched bases agree (100% on both files) before computing anything. The
discarded pass had given "5% confirmed", a number that meant nothing. The same 2-base
offset sits in docs/balance-loads.md and docs/cue-oracle.md, where it is harmless: both
use a +-20-base window.

## Result

| | chr21 | chr22 | prediction | verdict |
|---|---:|---:|---|---|
| loads / unsplit excess | 196,227 / -1.12 pp | 275,495 / -1.10 pp | reproduce | **S0 held** |
| source: ortholog | 17.0% | 12.5% | <= 30% | **S1 held** |
| source: paralog (elsewhere in GRCh38) | 44.3% | 38.4% | | |
| source: self (earlier in CHM13) | 38.7% | 49.1% | | |
| confirmed in hindsight | 10.3% | 9.6% | >= 50% | **S2 failed** |
| (ortholog / paralog / self confirmed) | 26.8 / 5.3 / 8.7% | 27.8 / 5.4 / 8.3% | | |
| confirmed-confirmed pairs | +2.46 pp (n 3,452) | +2.72 pp (n 4,197) | >= -0.5 | **S3 held** |
| pairs with >= 1 unconfirmed | -1.21 pp | -1.18 pp | <= -1.5 | **S4 failed** |
| unconfirmed-unconfirmed | -1.45 pp | -1.32 pp | | |
| ortholog-ortholog / paralog-paralog / self-self | +2.27 / -1.04 / **-3.21** | +2.61 / -0.58 / **-2.84** | | |

**By the rule: mixed, so no claim.** S3 held and S4 missed its threshold on both
chromosomes, so the "it is the search" branch does not fire. The threshold stays where
it was set.

**What the numbers show, stated as description, not as verdict:**
- Loads that hindsight confirms keep their sign (+2.5 / +2.7 pp), like real indels in
  the chain (+13-15 pp) and like loads at chain indels (+5-7 pp). **Nowhere does a
  confirmed slip alternate.**
- The alternation lives in the loads hindsight does not confirm. It is strongest when
  CHM13 copies from itself (-3.2 / -2.8 pp).
- **Only ~10% of loads pick the shift that the next 30 bases favour.** That is the
  prediction that failed worst.

**One limit on "unconfirmed":** the criterion (best shift, >= 24/30 agreement) is strict
on diverged repeat copies. Paralogs confirm at only ~5%, and docs/cue-oracle.md showed
that the loads the chain cannot explain still earn 2.2-2.7%. "Unconfirmed" means "not
the best shift over 30 bases", not "useless". A load can pay for a few bases and still
fail this test.
