# Batch 3: the sweep and the add-back — written before the first run

**Registration, 2026-09-13.** Pass 4 of the routine in `docs/v0.9.0-plan.md`:
*is this the best version of itself?* Nothing below has been measured. The only
runs made before this file was committed are the baseline the session opens with
(`scripts/roundtrip.sh` 203/203, `verify-claims.ps1 -Tier fast`) and the
byte-identity check of the two instrument changes described next.

## What Batch 2 hands over, and where the sweep therefore runs

There are two defaults now (`docs/reference-free.md`): **level 3 reference-free,
level 1 + cue with a reference.** The cue's effect is −5.97% on a real human
pair and −0.045% plain, so **the sweep runs at level 1 in reference mode**,
where a parameter can be seen to matter at all. Any winner is then re-checked
where the mechanism is quiet (level 3, and plain mode) before it is adopted.

## Two instrument changes first (not experiments)

1. **`CUE_MINLEN` was not `#ifndef`-guarded.** `-DCUE_MINLEN=8` would have been
   a redefinition warning whose value gcc then ignores, so that sweep point
   would have silently measured 16 again — exactly the "silence is not success"
   failure this project keeps finding. Guarded now.
2. **Four `L1_*` knobs** (`L1_NMIX`, `L1_IR`, `L1_STCM`, `L1_ORDERS`) give level
   1 back one level-3 part at a time, so the add-back can be asked one part at a
   time. They are diagnostic, not format: the model set a level names travels in
   the header, so anything adopted becomes a **new level number** in Batch 4,
   never a redefinition of level 1 (the rule level 4 was added under).

Both default to the shipping behaviour, and the unflagged build is
**byte-identical** before and after, checked on E. coli at levels 1, 3 and 4:
1,093,749 / 1,092,692 / 1,092,756 B. The first two also re-derive Batch 2's
reference-free table.

## The centre, and the grid

The cue has never been swept: `CUE_L = 3`, `CUE_D = 12`, `CUE_SWITCH = 12`,
`CUE_MINLEN = 16` are the values `docs/cue-prediction.md` registered before the
mechanism was written, and every figure on this branch uses them. That build is
the **centre** (`cue`). One parameter moves at a time:

| label | flag | what it changes |
|---|---|---|
| `cue_L2`, `cue_L4` | `CUE_L` 2, 4 | bases of backward agreement needed to load the cue |
| `cue_D6`, `cue_D20` | `CUE_D` 6, 20 | largest phase shift searched, either way |
| `cue_S8`, `cue_S16` | `CUE_SWITCH` 8, 16 | cue confidence needed before the masters take its phase |
| `cue_M8`, `cue_M24` | `CUE_MINLEN` 8, 24 | how established a match must have been for its miss to load the cue |
| `noroom`, `mf`, `mf_noroom` | `CUE_ROOM=0`, `CUE_MIXFREE=1`, both | the room corners of `docs/remaining.md`, now at level 1 |
| `cue_x4`, `cue_ir`, `cue_stcm`, `cue_ord` | `L1_NMIX=4`, `L1_IR=1`, `L1_STCM=1`, `L1_ORDERS=1` | add-back: level 1 + cue plus one level-3 part |
| `base_x4` | `L1_NMIX=4`, no cue | the control the P13 test needs |

## The staging rule, fixed now

- **Stage A (screen).** `base`, `cue`, the eight sweep points and the three
  corners, on the ten controlled E. coli targets + `ecoli_ind` + `o157`, level
  1, reference mode. Per-event bits as in `score.py`.
- **Stage B (human).** `chr21_ind` and CHM13 chr21 against GRCh38 chr21, level
  1, for: `base`, `cue`, every Stage-A build whose random-indel cost is within
  2% of the best there, and all four add-backs plus `base_x4` regardless (a
  part that earns its time must be judged on human sequence).
- **Stage C (confirm).** CHM13 **chr22** for whatever Stage B proposes, and for
  nothing else. Held-out means held out: it never chooses a parameter.
- **Plain re-check.** Any candidate also runs `ecoli.seq` and `chr21.seq` plain
  at levels 1 and 3, because a setting tuned where the mechanism is loud can
  cost where it is quiet.

Timing, where a prediction needs it: paired, labels alternating inside each of
three rounds, minimum quoted, encode of CHM13 chr21 at level 1 with a FASTA
reference (priming included) — the same measurement as `docs/speed.md`, whose
figure is 85.8 s against v0.8.0 level 3's 206.9 s. Run-to-run noise here is 24%,
so no timing claim is made from a single round.

Every file is decoded and `cmp`-ed before its size is recorded
(`scripts/cue/batch3.sh`).

## Predictions

Sizes and bits are compared against the **centre** unless stated. "Indel bits"
means the random-indel cost per event on the E. coli targets, mean of three
seeds; the centre's level-3 value is 28.75 bits against v0.8.0's 48.25.

| | prediction |
|---|---|
| **P1** | `CUE_L`: **`cue_L2` beats the centre on indel bits, by 0–6%; `cue_L4` is worse, by 0–10%.** The cue's own argument is that it can listen on less evidence because a wrong candidate costs almost nothing, and after an indel the true shifted phase only accumulates backward agreement one base at a time, so L is a delay. Falsified if `cue_L4` is the best of the three |
| **P2** | `CUE_D` on the controlled targets: all of {6, 12, 20} within **3%** of each other on indel and slip bits, and I expect under 1%. The indels there are single-base and the search tries the smallest shift first, so D should be inert |
| **P3** | `CUE_D` on real human sequence: `cue_D20` within **[−0.30%, +0.10%]** of the centre on CHM13 chr21, and I expect the difference to be under 0.10%. Real indels are longer than one base, but the long ones are re-anchored rather than cued |
| **P4** | `CUE_SWITCH`: **`cue_S8` beats the centre on indel bits by 0–8%, `cue_S16` is worse by 0–8%.** The handover is what stops the masters missing; sooner is fewer missed bases. Falsified if `cue_S16` is the best of the three |
| **P5** | `CUE_MINLEN`: all of {8, 16, 24} within **3%** on the controlled targets (matches there are long), but on CHM13 chr21 `cue_M8` is the better side, by 0–0.5%, because a real diverged pair has shorter established matches |
| **P6** | **The whole sweep finds less than 1.0%.** The best single point improves CHM13 chr21 at level 1 by **< 1.0%** against the centre. Base rate: before the cue, dnac's largest single improvement in its history was 0.8% |
| **P7** | The room corners repeat at level 1 what `docs/remaining.md` found at level 3: `mf_noroom` is the cheapest per event on the controlled targets, and all four corners sit within **0.30%** of each other on CHM13 chr21 |
| **P8** | Add-back, four mixer experts (`cue_x4`): **gains ≥ 0.20%** on CHM13 chr21 for **≤ 10%** encode time. Point estimate −0.5% |
| **P9** | Add-back, other-strand training (`cue_ir`): gains **0.10–0.50%** for **+10–20%** time |
| **P10** | Add-back, tolerant models (`cue_stcm`): **gains ≥ 0.50%** for **+20–35%** time. Point estimate −1.0%. This is the part aimed at exactly what a diverged pair is made of |
| **P11** | Add-back, the master order set (`cue_ord`): gains **≥ 0.50%** for **+30–50%** time. Point estimate −0.8% |
| **P12** | Ranked by size gain on CHM13 chr21: `cue_stcm` ≥ `cue_ord` > `cue_x4` > `cue_ir`, and **no single add-back closes more than half** the 568,133 → 551,594 B gap between level 1 + cue and level 3 + cue (i.e. none gains more than 1.45%) |
| **P13** | The Batch 2 hypothesis, tested: reference-free at level 1, **the cue's gain with four experts is larger than with two** (`cue_x4`/`base_x4` against `cue`/`base`, on chr21.seq and ecoli.seq). And four experts closes **less than half** of the +0.532% gap between level 1 + cue and level 3 base on chr21 plain. Falsified if the gain is not larger with four experts — which would retire the hypothesis rather than confirm it |
| **P14** | Every build in this batch passes `sh scripts/roundtrip.sh` (203/203), and every size recorded round-trips under `cmp` |

## The decision rules, fixed now

- **D1 — adopt a swept parameter** only if it improves CHM13 chr21 at level 1 by
  **≥ 0.20%** against the centre, **and** costs **≤ 0.05%** on chr21 plain at
  level 3, **and** chr22 confirms it with the same sign and at least half the
  magnitude. Otherwise **the centre stands** and the sweep is recorded as having
  found nothing, which is a result.
- **D2 — adopt an add-back into the reference-mode default** only if it gains
  **≥ 1.0% for ≤ 20%** added encode time, or **≥ 0.5% for ≤ 10%**, **and** the
  resulting build stays **≥ 2.0x faster** than v0.8.0 level 3 on the real pair
  (the published headline is 2.4x; a default that gives that up is a different
  claim). Anything adopted becomes a new level number in Batch 4.
- **D3 — chr22 confirms, never chooses.** If chr22 disagrees with chr21 in sign,
  nothing is adopted and the disagreement is the finding.
- **D4 — a parameter is not adopted for being equal.** Ties go to the centre,
  because every published figure on this branch was measured with it.

## What this cannot answer

- The controlled targets are E. coli with 2,000 synthetic events; their
  per-event costs are a *mechanism* readout, not a claim about human data.
- Timings are on one 4-core laptop with 24% run-to-run noise; only ratios
  measured back to back are quoted, and no timing figure gets a claim row
  (the standing rule from `ablate.ps1`).
- The add-back asks what a part is worth *on top of level 1 + cue*, one part at
  a time. Interactions between two added-back parts are not measured, and a
  leave-one-out style test understates a group by up to 2.4x on human sequence
  (`docs/model-ablation.md`) — the same caution applies in reverse here.
