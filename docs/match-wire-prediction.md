# Match 16 as wiring -- pre-registration

Written 2026-10-11, before any code. Agreed as the next item on 2026-09-23 and left
unstarted through v0.10.0-v0.12.0. Source: Timotheos -- "drop the second anchor table,
give the mixer 'match >= 16' as context". This is a new mechanism for the MATCH layer,
not cue tuning (decision A, 2026-09-27, does not apply).

## What the 16-mer model does today (read from dnac.c at a2f2ca7)

`g_mm[1]` (`MMIN2` = 16) is a full second forward match model, and it is wired into
FIVE places, not one:

1. **its own hash table**: `hbits = mhb - 1`, so at the cap (mhb = 26, reached by
   E. coli and chr21 alike) 2^25 x 4 B = **128 MB**; one hash, one random store and
   (when idle) one random read per base;
2. **a mixer input** (input 13 at level 3), with its own `pr` counters;
3. **mixer context `mc[0]`** (`mix_ctx`): the `lb` bit, "long anchor running";
4. **mixer context `mc[2]`** (`mix_ctxs`): `g_mm[1].active` as the low bit;
5. **the cue's mix-in**: when the cue takes over, every missing master takes its phase,
   the 16-mer model included.

Not used by: SSE stage 1 (`apm1_ctx` reads `g_mm[0]` and the RC model only) and the RC
model (it anchors in the 13-mer table, measured better, 1.7118 vs 1.7139).

What is already known (docs/model-ablation.md, input zeroed, table and context bits
KEPT): leave-one-out +0.019% on E. coli, +0.153% on chr21_slice; correlation with the
13-mer model **0.90**, the highest pair in the codec with order 18 / order 22. On human,
removing a group costs up to 2.41x the sum of its single costs, so +0.153% is a floor,
not an estimate, for removing everything the model contributes.

## The mechanism

What the 13-mer model cannot see today: how far its OWN alignment agrees backwards.
When it anchors it already computes `back_agree(cand, np, MVERIFY)` (up to 32 bases)
and then throws the number away -- `mlen` starts at 1 whatever it was. Wiring keeps
it:

    vrun = back_agree length at anchor time      (0..MVERIFY = 32)
    hit  -> vrun++ (capped at MLENCAP)
    miss -> vrun = 0
    cue mix-in -> vrun = 0
    L16  = active && vrun >= 16

`L16` replaces `g_mm[1].active` in places 3 and 4. The table, the input and the cue
mix-in for the second model disappear (NMATCH = 1). `L16` is "a 16-base agreement
exists on the alignment I am following" -- what the 16-mer model's existence signalled
-- without a second table. What it CANNOT reproduce: the 16-mer table keeps the most
recent occurrence of each 16-mer, which can be a different, better position than the
most recent occurrence of the 13-mer, and the 16-mer model can hold one alignment
while the 13-mer model follows another.

## Arms (one scratch build, compile-time switch `MATCH_WIRE`)

- **W0** release (`MATCH_WIRE=0`): must be byte-identical to main (negative control).
- **W1** drop (`MATCH_WIRE=1`): NMATCH = 1, places 3 and 4 get a constant 0. The
  trivial opponent: what removing the model costs with no wiring at all.
- **W2** wire (`MATCH_WIRE=2`): NMATCH = 1, places 3 and 4 get `L16`.

The threshold is 16 and is NOT swept: the name of the idea fixes it, and a sweep would
be a tuning search with no held-out set. `MATCH_WIRE != 0` marks the build experimental
(lower-case family letter, state magic 'x'); `vrun` joins `state_save`/`state_load`.

## Protocol

Every archive decoded and compared with `cmp`; a size from a run that did not
round-trip is not recorded.

1. **Negative control**: W0 vs main, sha256-identical archives, `ecoli.fa` and
   `chr21_slice.fa`, levels 1 and 3.
2. **Size, plain mode**, W0/W1/W2:
   - level 3: `data/ecoli.fa`, `bsub.fa`, `paer.fa`, `saur.fa`, `chr21.fa` (full),
     `chr22_sm.fa` (case list);
   - level 1 (codon tracker on where its gate opens): the four bacteria and `chr21.fa`.
3. **Size, reference mode** (default level 1), W0/W2: `ecoli_ind`/`ecoli`,
   `w3110`/`ecoli`, `o157`/`ecoli`, `chr21_ind`/`chr21`. The sticky anchors live in
   both tables today, and this is the mode where a precise anchor should matter most.
4. **Memory and time**, W0 vs W2: full `chr21.fa`, levels 3 and 1, encode AND decode,
   peak RSS sampled, **min of 3, alternating** W0/W2 in one session (run-to-run noise
   here is 24%; a single run proves nothing). Run detached (`Start-Process`), never from
   a Claude background shell.

## Bar (fixed now)

W2 is a FORMAT CANDIDATE only if ALL of these hold:

- **size, level 3**: mean change over the six level-3 files <= **+0.05%**, and no
  plain-mode file at either level worse than **+0.10%**;
- **size, reference mode**: no pair worse than **+0.50%** (outputs are KB-sized, so
  the tolerance is wider, not the standard looser);
- **cost**: full-chr21 level-3 peak RSS <= **-8%** AND encode time <= **-5%**
  (min of 3 vs min of 3).

**And the wiring must earn its name**: W2 must recover at least **half** of W1's
level-3 cost on `chr21.fa` (cost(W2) <= 0.5 x cost(W1)). If it does not, any success is
the removal's, not the wiring's, and is reported that way.

If W2 *gains* size (mean <= -0.05% at level 3, no file worse than +0.10%), the cost
conditions are waived.

Anything else: rejected, recorded in negative-results.md. Every comparison against the
exact figure, never a rounded display.

**The comparison that must appear in the result whatever happens**: HASHBITS_MAX 26->25
already buys -31% RAM on chr21 for +0.051% (no time). Per MB, W2 has to be judged
against that. If W2's size cost per MB saved is worse, it is not a memory lever, and it
stands or falls on time alone.

## What adoption would cost (not decided by this step)

Removing a model changes what levels 1-4 mean, and the level byte is format: redefining
a level makes every existing archive decode to wrong bytes at exit 0. So W2 would need
new family letters (old ones still read through the two-model path), a full
re-measurement of every published figure, both round-trip suites, and verify-claims
fast + slow. A pass here makes it a candidate for that decision, which is Timotheos's.

## Predictions (mine, written before any code)

P1  W1 costs E. coli +0.02..+0.06%, chr21 full +0.20..+0.40% at level 3: the zeroed-input
    floor (+0.019% / +0.153%) plus the two context bits, plus the human group effect.
P2  W2 recovers LESS than half of W1's chr21 cost: what the 16-mer model contributes is
    mostly the independent anchor (different bucket, different position), which a flag
    on the 13-mer alignment cannot reproduce. The wiring-earns-its-name condition fails.
P3  W2 passes the size bar on the four bacteria (|change| < 0.05%) and fails it on
    chr21 (> +0.10%).
P4  Peak RSS on chr21 level 3 -10% (128 of ~1,254 MB); encode time -3..-8%, so the
    time condition is marginal.
P5  At least one reference pair (most likely `chr21_ind`) worse than +0.50%.

Overall prediction: **rejected**. Written down so that a pass is a surprise worth
reading, not a result I argued myself into.

Timotheos's prediction: none given (2026-10-11): "no prediction, but patience -- we will see what comes out".
