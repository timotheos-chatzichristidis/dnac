# Residual momentum in the mixer -- result

Run 2026-09-29, pre-registered in `docs/mix-momentum-prediction.md` (commit 33ede3e).
Verdict: **rejected**. Every file moved by less than 0.002%, in both directions. The
held-out mean is +0.0004%, against a bar of -0.30%.

The code is kept as `scripts/pilot/mix-momentum.patch` (`-DMIX_MOM=<beta per-mille>`,
`-DMIX_MOM2=1` for the second layer, velocity in the state file, build marked
experimental). `dnac.c` is unchanged.

## 1. Negative control
A `MIX_MOM=0` build and main produce identical archives (sha256) on E. coli and
chr21_slice at levels 1 and 3. The control could also fail: every beta != 0 build
changed the bytes.

## 2. Development (level 3, sizes in bytes, baseline = main)

| config | chr21_slice | E. coli | mean |
|---|---:|---:|---:|
| baseline | 2,104,484 | 1,093,425 | -- |
| A, beta 0.5 | 2,104,531 (+0.0022%) | 1,093,378 (-0.0043%) | **-0.00103%** |
| A, beta 0.8 | 2,104,550 (+0.0031%) | 1,093,383 (-0.0038%) | -0.00035% |
| A, beta 0.9 | 2,104,610 (+0.0060%) | 1,093,412 (-0.0012%) | +0.00240% |
| B, beta 0.5 | 2,104,549 (+0.0031%) | 1,093,386 (-0.0036%) | -0.00024% |
| B, beta 0.8 | 2,104,577 (+0.0044%) | 1,093,404 (-0.0019%) | +0.00125% |
| B, beta 0.9 | 2,104,626 (+0.0067%) | 1,093,419 (-0.0005%) | +0.00310% |

The chosen configuration is A with beta 0.5. It is not at the edge, so 0.95 was not run.

## 3. Held-out (A, beta 0.5; every run round-tripped, all ok)

| file | level | main | momentum | change |
|---|---:|---:|---:|---:|
| B. subtilis | 3 | 1,002,525 | 1,002,534 | +0.0009% |
| P. aeruginosa | 3 | 1,382,299 | 1,382,325 | +0.0019% |
| S. aureus | 3 | 646,500 | 646,488 | -0.0019% |
| chr21 (full) | 3 | 7,740,638 | 7,740,699 | +0.0008% |
| chr22 soft-masked | 3 | 7,574,755 | 7,574,789 | +0.0004% |
| **mean, level 3** | | | | **+0.00042%** |
| E. coli | 1 | 1,069,614 | 1,069,626 | +0.0011% |
| B. subtilis | 1 | 986,937 | 986,930 | -0.0007% |
| P. aeruginosa | 1 | 1,332,018 | 1,332,008 | -0.0008% |
| S. aureus | 1 | 630,969 | 630,963 | -0.0010% |
| chr21_slice | 1 | 2,112,249 | 2,112,269 | +0.0009% |

Bar: mean <= -0.30%: **failed** (+0.00042%). No file worse than +0.05%: held (worst
+0.0019%). Step 4 (timing) was not run: the size result decides the verdict alone, and
timing noise here is 24%.

## 4. Predictions

| | prediction | outcome |
|---|---|---|
| P1 | dev gain between 0.00% and -0.15%, below the bar | held (-0.00103%) |
| P2 | the smallest beta wins | held, in both variants; each larger beta is worse |
| P3 | B no better than A | held |
| P4 | human gains more than bacteria | failed; nothing gains beyond noise anywhere |

## 5. Reading (interpretation, not measured)
The effective step was held fixed, so the only new thing was inertia, i.e. a low-pass
on the gradient. It bought nothing, and more of it (a larger beta) cost more. The mixer's
error is therefore not dominated by gradient noise that averaging could remove. Its
problem is lag behind real changes of region, and inertia adds lag. The weight sets are
already split by context (64 per expert, 4 experts), which is PAQ's answer to
piece-wise stationary data. A ball rolling in a bowl that keeps moving does better by
following the bowl than by carrying its speed.

In the language of 2026-09-29: the economical damping for this "follower" is the
overdamped limit. The wave has nowhere to pay in the mixer.
