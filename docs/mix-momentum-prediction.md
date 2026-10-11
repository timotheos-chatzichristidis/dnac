# Residual momentum in the mixer -- pre-registration

Written 2026-09-29, before any code. Source: Timotheos's "wave as least-energy balancing"
(2026-09-29). In dnac the potential is the code length, -log2 p, and the mixer falls into
it by plain gradient descent: no inertia, no wave. The version of that fall WITH inertia
is heavy-ball momentum (Polyak 1964), which is the damped oscillator
`e'' + 2*zeta*w*e' + w^2*e = 0` applied to the weights. Timotheos calls it "residual
momentum" (εναπομείνουσα ορμή).

This is a new mechanism for the MIXER, not cue tuning (docs on the cue: decision A,
2026-09-27).

## Prior art (quick check, not exhaustive)
PAQ-family mixers update by plain online gradient descent (Mahoney). cmix uses Adam, but
only inside its LSTM, not in the PAQ-style mixer. No report of heavy-ball momentum in a
logistic mixer was found. GeCo3's network was not checked.

## The mechanism
Per weight, a velocity `m` of the same shape as the weights:

    m <- beta*m + (1-beta) * LR * err * st
    w <- w + m

The `(1-beta)` factor is deliberate. Under a steady gradient the step equals today's step,
so the effective learning rate does not move. MIX_LR retuning was already rejected by
measurement (it sits at its optimum), so a gain here has to come from the inertia itself,
i.e. from smoothing the gradient over time, not from a hidden learning-rate change.
`beta = 0` must compile to today's code and give byte-identical archives.

Variants: **A** = first layer (the NMIX experts) only; **B** = first and second layer,
same beta. The velocity joins `state_save`/`state_load`. `MIX_MOM != 0` marks the build
experimental (lower-case family letter).

## Protocol
1. Negative control: `MIX_MOM=0` build vs main: identical archives (sha256) on E. coli
   and chr21_slice at levels 1 and 3.
2. Development: beta in {0.5, 0.8, 0.9} x {A, B} at level 3 on `ecoli.fa` and
   `chr21_slice.fa`. The best configuration is the one with the lowest mean size change
   over the two files. If the best beta is 0.9 (the edge), 0.95 is run once and may
   replace it; nothing else is added.
3. Held-out, the chosen configuration only, every run round-tripped:
   `data/bsub.fa`, `data/paer.fa`, `data/saur.fa`, `data/chr21.fa` (full), `data/chr22_sm.fa`
   at level 3; and all four bacteria + chr21_slice at level 1 (codon tracker on) as a
   regression check.
4. Encode time on full chr21, level 3, min of 2 each, reported only (timing noise here
   is 24%).

## Bar (fixed now)
Adopt as a format candidate only if, on the held-out files at level 3:
- mean size change <= **-0.30%** (the same bar the cue candidates faced), and
- no held-out file, at any level, worse than **+0.05%**, and
- full-chr21 encode time no worse than **+10%**.
Anything else: rejected and recorded in negative-results.md. The bar is compared to the
exact figure, never a rounded display.

## Predictions (mine)
P1  Dev gain between 0.00% and -0.15% for the best configuration; below the bar.
P2  The best beta is the smallest (0.5): mixer slots are sparse (64 contexts x 4 experts),
    so a slot's velocity is often stale when it is next used, and inertia is paid for in
    lag after every change of region.
P3  B no better than A: the second layer has one weight per expert and already learns
    slowly (MIX_LR2 = half of MIX_LR).
P4  Human gains more than bacteria, if anything gains: repeats switch regime often, and a
    low-pass on the gradient is what cuts noise between switches.
Timotheos's prediction: open (to be added before step 2 runs, if he gives one).
