# Batch 4: integration and format — written before the first run

**Registration, 2026-09-14.** Batch 4 of `docs/v0.9.0-plan.md`. Nothing below has
been measured. The only runs made before this file was committed are the
session's baseline on `4932ffe` (`scripts/roundtrip.sh` **203/203**,
`verify-claims.ps1 -Tier fast` **21/21**), extracting the v0.8.0 and `4932ffe`
sources with `git show`, compiling the v0.8.0 one, and compiling (not running)
the working-tree source that implements F1–F5 below, clean under
`-Wall -Wextra` in its three configurations.

An instrument note from that baseline: `roundtrip.sh` run from Git Bash with
w64devkit **first on PATH** fails on its first random case, because `head`
resolves to busybox's, which has no `/dev/urandom`. It printed `exit=1` and zero
cases, which is correct behaviour (it did not claim a pass), but it is the same
shell `verify-claims.ps1`'s `Resolve-Sh` already refuses. Build with w64devkit
on PATH; run the suite without it.

## What Batch 3 hands over

`CUE_MINLEN` 16 → 4 adopted by decision and not yet in `dnac.c`; the flip and the
re-measurement are one change; the old documents are records and keep their
numbers; the negative control is "costs nothing and stays lossless", not "silent";
no new level; paired speed ratio 2.12x (`docs/batch3.md` §9, the plan's Batch 4).

## The design, fixed now

**F1. The cue is compiled into every build and switched at run time; the switch
travels in the magic.** Today it is `#ifdef DNAC_CUE`, and a cue archive carries
the same magic (`DNCC`/`DNCU`/`DNCP`) as a v0.8.0 one. New streams get their own
letters, the old ones keep theirs:

| stream | v0.8.0 (no cue) | v0.9.0 (cue) |
|---|---|---|
| plain | `DNCC` | `DNCE` |
| reference | `DNCU` | `DNCV` |
| plain, blocks (`-j N`) | `DNCP` | `DNCQ` |

The header after the magic is unchanged, so **no byte count moves** because of the
format. A v0.9.0 decoder reads both families; a v0.8.0 decoder can only say "not a
dnac file" to the new letters, since it predates them.

**F2. The release parameters are `CUE_L 3`, `CUE_D 12`, `CUE_SWITCH 12`,
`CUE_MINLEN 4`, `CUE_ROOM 1`, `CUE_MIXFREE 0`, and every `L1_*` knob off.** A
build that overrides any of them is an **experimental build**: it writes the
lower-case letters (`DNCe`/`DNCv`/`DNCq`), refuses the upper-case cue letters, and
the release build refuses the lower-case ones, both by name. The reason is the
v0.3.0 geometry bug in a new place: a compile-time value that selects behaviour
and does not travel with the file. The `L1_*` knobs were called "diagnostic, not
format" in `docs/batch3-prediction.md`; they change the model set level 1 names,
so they are format, and that sentence was wrong. Two experimental builds with
*different* overrides still cannot tell each other apart — stated, not fixed:
experiments are compared by the scripts that built them.

**F3. Defaults.** The encoder writes cue streams (`CUE_DEFAULT 1`). `cr` and
`prime` with no level pick **level 1**; `c` keeps **level 3** (Batch 2's per-mode
decision). `-DCUE_DEFAULT=0 -DREF_LEVEL_DEFAULT=3` is v0.8.0's behaviour; its label
is `v08`.

**F4. State files record the cue.** Priming runs the cue (it moves master anchors
when it mixes in), so a state primed with it is a different model. `DNACST02`
stays readable and means *no cue*; new states are `DNACST03` (cue) and `DNACSTx3`
(experimental). A state and a stream of different families are refused by name,
the same way a level mismatch is. The cue's own table is still not saved: it is
reset at the end of priming on both paths, which is what keeps a state and its
FASTA interchangeable.

**F5. Flags.** Deleted: `DNAC_CUE` (no longer optional), `DNAC_NUDGE` (superseded
by the cue, `docs/nudge.md`), `CUE_BACK` (the failed alternating deck,
`docs/cue-back.md`). Kept, each experimental per F2: `CUE_ROOM` and `CUE_MIXFREE`
(the 2x2 of `docs/remaining.md`), the four `L1_*` knobs (how the add-back gets
asked again), and the `#ifndef` guards on the four cue parameters (sweeps).
`DNAC_PROF` stays and is not format.

**F6. History is pinned to the source that measured it — a disclosed deviation
from the handover.** The handover's item 3 asked for the `cue` label to become
`-DDNAC_CUE -DCUE_MINLEN=16`. After F1 and F5 that cannot reproduce the records:
`nudge`, `L*D*` and `cue2` would no longer compile, and every experiment label
would silently run through new code. Instead, **every label in `CueDefs` and
`defines_for` compiles `git show 4932ffe:dnac.c`**, the last source that measured
anything on this branch, with exactly the flags it was measured with. No
historical row should change value, and none should need an edit. The link from
those records to the shipping code is made by P1–P3 below instead, which are
stronger than a relabel: byte identity, not a matching number.

**F7. The registry.** The rows that defend `README.md` still describe v0.8.0 until
Batch 5 rewrites it, so they run the `v08` build (compiled from the current
source). The `fast` tier therefore needs a compiler from now on. New label `rel`
is the current source with no flags. New tier `b4` holds this batch's rows.

**F8. New round-trip cases** in `scripts/roundtrip.sh`: indel-dense (`dnac mut` at
a high rate), homopolymer-dense, target = reference (lossless only; "costs
nothing" needs two builds, so it is a registry row), the family refusals, and
**stored v0.8.0 streams** (`tests/v080/`, written by the v0.8.0 tag build from
`dnac gen` inputs the suite regenerates) decoded by the build under test.

## Predictions

"Identical" means `cmp` on the whole archive; "identical but the magic" means
`cmp` after byte 3 (0-based) is set equal.

| | prediction |
|---|---|
| **P0** | **The hazard F1 fixes is real today.** On `4932ffe`, an archive written by `-DDNAC_CUE` (reference mode, level 1, `ecoli_ind` against E. coli) and decoded by the unflagged build **does not come back, and the decoder exits 0**. Falsified if the decoder refuses it, or if it comes back |
| **P1** | **The runtime cue is the compiled cue.** The current source built with `-DCUE_MINLEN=16` writes archives **identical but the magic** to `4932ffe -DDNAC_CUE`, and the current source unflagged writes archives identical but the magic to `4932ffe -DDNAC_CUE -DCUE_MINLEN=4`: on `ecoli_ind` in reference mode at levels 1 and 3, `ecoli.seq` plain at levels 1 and 3, and plain `-j 4` at level 3 |
| **P2** | **The cue switched off is v0.8.0.** The `v08` build writes archives **identical** to the v0.8.0 tag build on the same five cases plus levels 2 and 4 plain |
| **P3** | Therefore the release sizes equal Batch 3's `cue_M4` sizes **to the byte**: CHM13 chr21 against GRCh38 at level 1 is **563,031 B** |
| **P4** | Every stored v0.8.0 stream decodes byte-identically with the release build |
| **P5** | The v0.8.0 decoder refuses every new-family stream with a non-zero exit; the release build refuses experimental streams and experimental builds refuse release streams, each with a non-zero exit and nothing written |
| **P6** | A `DNACST02` state primed by v0.8.0 decodes a v0.8.0 reference stream with the release build; used against a cue stream it is refused |
| **P7** | Target = reference at release settings is lossless and **costs nothing**: E. coli against itself at level 1 is **1,446 B**, against v0.8.0's 1,456 |
| **P8** | `rel` and `v08` both pass the extended suite with no failure |
| **P9** | The run-time switch costs **< 3%** encode time against `4932ffe -DCUE_MINLEN=4 -DDNAC_CUE` at level 1 on CHM13 chr21 (paired, labels alternating in three rounds, minimum). Point estimate under 1%: the branches are on per-base paths that already branch |
| **P10** | Every historical row (`fast`, `cue`, `cue3`, `slow`, `extern`, `meta`) passes **unchanged**, with no recipe or anchor edited beyond F6/F7's plumbing |

### The release figures at `CUE_MINLEN=4` (Batch 5's input)

Measured with `rel` against the v0.8.0 build, in the configurations the records
used, and additionally at level 1 where the record was level 3 (level 1 is now the
reference-mode default).

| | record (`CUE_MINLEN=16`, level 3 unless stated) | prediction for `rel` |
|---|---|---|
| **R1** | random indel 48.25 → 28.75 bits per event, substitution unchanged | indel **26.0–28.75** at level 3; substitution within **±0.25** bits of v0.8.0 |
| **R2** | simulated chr21 individual −8.70% | **−9.5% to −13%** at level 3 (`chr21_ind` moved −3.1% at level 1 in Batch 3) |
| **R3** | CHM13 chr21 −5.97% (551,594 B) | **−6.3% to −7.5%** at level 3 |
| **R4** | shared windows −18.27%, novel −0.00% | shared **−18.5% to −21%**; novel within **±0.05%** |
| **R5** | chr22 −5.83%, shared −16.24%, novel −0.01% | file **−6.1% to −7.3%**, shared **−16.5% to −19%**, novel within ±0.05% |
| **R6** | smallest of zstd / HRCM / GeCo3 templates, 1.6x ahead | still smallest, and **further ahead** than the record at both levels |
| **R7** | level 1 + cue −3.15% against v0.8.0 level 3 (568,133 against 586,615) | **−4.02%** (563,031, by P3); speed ratio against v0.8.0 level 3 **≥ 2.0x** paired |

## Decision rules, fixed now

- **D1.** If P1 or P2 fails, stop. The run-time conversion changed the float path
  or the model set, and no figure is measured on it until it is found.
- **D2.** If P9 fails (≥ 3%), the switch stays run-time (it is format) and the hot
  path gets specialised; the measurement is repeated and both are recorded.
- **D3.** No parameter moves in this batch. Batch 3 closed tuning; the release
  figures are reported as they come out, including any R prediction that fails.
- **D4.** If a historical row changes value (P10), that is a finding about pinning,
  not a row to edit.
