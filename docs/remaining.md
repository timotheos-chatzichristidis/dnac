# The remaining tests: result

**Run 2026-09-10.** Pre-registered blind in `docs/remaining-prediction.md`
(commit `f521918`, 21:03:52 +0300).

## Scoreline

| | prediction | outcome |
|---|---|---|
| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |
| **T2** | the cue costs < 10% time | **held**: +3.1% encode, +2.9% decode |
| **M1** | without the mixer's help, removing the room costs ≥ 3% | **failed, inverted**: it helps |
| **M2** | `mf_noroom` loses ≥ 1 point on `chr21_ind` | **failed**: 0.07 point |
| **M3** | substitutions within ±1% in every corner | **held** |
| **R22a** | chr22 whole file ≥ 2% smaller | **held**: **−5.83%** |
| **R22b** | chr22 shared windows ≥ 8% | **held**: **−16.24%** |
| **R22c** | chr22 novel windows within ±1% | **held**: −0.01% |
| **R22d** | lossless | **held** |

## T2. Time

`cr` then `dr` of `ecoli_ind.fa` against a primed E. coli state, v0.8.0 and cue
alternating, three rounds, minimum quoted:

| | encode | decode |
|---|---:|---:|
| v0.8.0 | 8.76 s | 8.68 s |
| cue | 9.03 s | 8.93 s |
| ratio | **1.031** | **1.029** |

## T3. The 2x2: where the osmosis lives

Cost per event in bits (E. coli targets, 3 seeds × 2,000 events) and
`chr21_ind` in bytes:

| mixer hears the cue through the match state? | cue table through the room? | random indel | slip | substitution | `chr21_ind` |
|---|---|---:|---:|---:|---:|
| yes | yes (`cue`) | 28.75 | 11.78 | 14.65 | 104,013 |
| yes | no (`noroom`) | 28.34 | 11.04 | 14.73 | 104,125 |
| no | yes (`mf`) | 27.78 | 10.49 | 14.63 | 104,007 |
| no | no (`mf_noroom`) | **27.41** | **9.78** | 14.68 | 104,082 |

**Hearing the cue through the room matters at neither layer.** On the
controlled targets every step that removes it makes the cue *cheaper*, because
fewer cells learn faster. The fully stripped cue is best there: slip 9.78 bits
against 11.78. On `chr21_ind` all four corners sit within 0.12% of each other.

So the gain, and the learning along the file measured in `docs/cue-room.md`,
come from the cue **existing and staying**: a second deck, loaded at the shifted
phase, permanently a mixer input, trusted by what it has earned. Not from
conditioning its trust on the master. That settles the question `cue-room.md`
left open. **The "never take the headphones off" half of Timotheos's method
holds. The "one ear through the other" half does not, in this model.**

The default stays `CUE_ROOM=1, CUE_MIXFREE=0`, since every result on this branch
was measured with it and the corners are within noise on real sequence. The
simpler build is a legitimate choice if the next test prefers it.

## T4. Replication: chromosome 22

T2T-CHM13 chr22 (`CP068256.2`, 51,324,926 b, no `N`) against GRCh38 chr22
(Ensembl release 110, 50,818,468 b, 11,658,691 `N`). Both round-trip.

| | v0.8.0 | cue | change |
|---|---:|---:|---:|
| **file** | 794,330 B | 748,025 B | **−5.83%** |
| shared windows (< 0.2 b/b, 85.8% of windows, 25.3% of bits) | | | **−16.24%** |
| diverged (0.2–1.0 b/b, 51.3% of bits) | | | −3.49% |
| novel (≥ 1.0 b/b, 23.4% of bits) | | | −0.01% |

chr21 gave −5.97% / −18.27% / −2.67% / −0.00%. **The second chromosome
reproduces the first within a fraction of a point on every row,** including the
exact zero on sequence one person lacks.
