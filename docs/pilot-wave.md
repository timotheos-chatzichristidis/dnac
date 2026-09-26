# Pilot wave: does the cue fall inside it? — result

**Run 2026-09-26** on `main` (`a61f1d7`, v0.10.0), in a scratch copy. Pre-registered in
`docs/pilot-wave-prediction.md`, written before the run; its SHA-256 at the moment the
run started was `ddd005a5e9a8443a5f4d81054a5d0c6de82782b808e5cf5f05ca5bc8b21fe8ba`,
and the file is committed unchanged.

## The question, and which pilot wave

Timotheos's question: does the beatmatching design fall inside Bohm's pilot-wave theory?

**Not Bohm's.** There the wave is not produced by the particle, it lives in configuration
space, and its predictions are those of ordinary quantum mechanics, so there is nothing
to measure. **The classical analogue does fit**: Couder and Fort's walking droplets
(Bush, *Pilot-wave hydrodynamics*, Annu. Rev. Fluid Mech. 2015). The droplet makes the
wave, the wave guides the droplet, the wave decays slowly (path memory), and the bounce
locks in phase with the bath.

| pilot-wave ingredient (droplets) | in dnac | fits? |
|---|---|---|
| particle with a definite position | the master anchor | yes |
| the particle makes its own wave | every base writes into the tables and counters | yes |
| memory that decays (parameter Me) | counter adaptation, cue decay | yes |
| phase locking to the forcing | the cue / beatmatching | yes |
| **guidance: the field steers the particle** | the anchor goes +1; jumps come from the hash | **no → step 3** |
| position statistics follow the wave (the Born analogue) | never measured | **→ step 2** |

The rows marked "yes" are relabelling and earn nothing. Only the last two could.

A caution from the analogue itself: the droplets' double-slit interference
(Couder & Fort 2006) did not replicate (Andersen et al. 2015; Pucci et al. 2018). What
held up is orbit quantization from path memory (Fort et al., PNAS 2010) and the corral
statistics (Harris et al. 2013).

## Step 2: path memory against the instantaneous field

The probe is `scripts/pilot/probe.patch`, applied to `dnac.c`. It only counts. At every
base, when the 13-mer master is active with `mlen > 0` and the bucket holds an earlier
occurrence, it compares the anchor's source (the particle) with the most recent earlier
occurrence of the same 13-mer (a fresh lookup: the static field). Level 3, k 22. On both
files the probe's archive is **byte-identical** to the release build's, and it
round-trips.

| | E. coli | chr21_slice | prediction | verdict |
|---|---:|---:|---|---|
| positions measured | 278,575 | 2,048,532 | | |
| anchor == fresh | 49.06% | 22.45% | ≥80% / 30–70% | **P1 failed, both** |
| on disagreement: anchor right | 40.85% | 54.27% | | |
| on disagreement: fresh right | 40.24% | 52.11% | anchor > fresh | **P2 held** (McNemar z ≈ 3.9 / 47) |
| both right / neither | 23.20 / 42.11% | 36.26 / 29.88% | | |
| TV distance, log2-lag histograms | 0.0518 | 0.0773 | < 0.10 | **P3 held** |

**By the rule fixed beforehand, P2 holding closes step 2.** Path memory is real: the
particle beats the field where they disagree. The codec already exploits it, through the
long-measured rule "do not re-anchor on every miss", so the memory row is relabelling.
The Born analogue holds in the weak sense (TV 5–8%): the particle sits roughly where the
static field would put it, with more mass at long lags, which is memory keeping old
sources.

**Where the prediction was wrong:** particle and field disagree more often than not, even
on E. coli.

**Not a lever, only noted:** the fresh lookup alone is right on 16–17% of disagreements.
The order-14+ models (which already sum every earlier occurrence) and the 16-mer deck
probably cover it. That is unverified, and it needs its own pre-registration before
anything is built.

## Step 3: guidance, closed by arithmetic

- Choosing the phase after a miss by the local field IS the cue. Riding and rotation are
  its variants, already measured (`docs/after-090*.md` on `after-0.9.0`).
- The one new variant is Timotheos's "+1/−1 depending on the previous step", Feynman's
  checkerboard (the Dirac equation in 1+1 dimensions, where mass is the rate of direction
  reversal). That would mean searching the reverse of the last slip first. The alternation
  it would exploit is already measured: −1.12 pp below chance on 196,227 loads (chr21).
  Its ceiling is 1 − H(0.489) ≈ 0.00035 bit per load, so ≈ 69 bits ≈ **9 B on chr21
  (0.0016%)**. Not built.

## Verdict

The mapping holds row for row, and every row that fits is a part dnac already has. The
analogy finds nothing to add.
