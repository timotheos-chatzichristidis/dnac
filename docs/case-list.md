# The case mask as an interval list: result

**Run 2026-09-22**, on branch `case-mask`. Pre-registered in
`docs/case-list-prediction.md` (commit `5dda1e1`, pushed before any code for
this design). Level 3, k=22, plain mode. Every archive was decoded and
`cmp`-ed before its size was recorded.

## Scoreline

| | prediction | outcome |
|---|---|---|
| **L1**, the size | case section 130,000–165,000 B on chr21 | **held**: **143,081 B** (9.540 bits per run); chr22 147,004 B |
| **L2**, the separation, exact | `dna_sm` archive = `dna` archive + section + 16 B, body `cmp`-identical to `dna`'s | **failed as written**: 6,745 B over on chr21, body differs. Cause verified below: the premise was wrong, not the mechanism |
| **L3**, no cost without case | uppercase files byte-identical to v0.9.0 | **held**: E. coli, O157, W3110, `ecoli_ind`, `chr21_slice` |
| **L4**, lossless | 229/229, the nine mixed-case files at `-j 1`/`-j 4`, threads = no threads | **held** |

## D-L

| condition | requirement | measured | verdict |
|---|---|---:|---|
| 1 | section ≤ 156,305 B (chr21) and ≤ 161,224 B (chr22) | **143,081** (0.9154×), **147,004** (0.9118×) | **passes** on both |
| 2 | L2 exactly | 6,745 B over on chr21 | **fails as written** |
| 3 | L3 exactly | identical | passes |
| 4 | L4 | all lossless | passes |

Against today and against the opponent, whole archive:

| | v0.9.0 on `dna_sm` | case list | change | opponent total | change |
|---|---:|---:|---:|---:|---:|
| chr21 | 10,847,678 | **7,890,480** | **−27.26%** | 7,896,943 | −0.082% |
| chr22 | 10,741,570 | **7,574,755** | **−29.48%** | 7,586,309 | −0.152% |

## Why L2 failed: the twin was the wrong twin

L2 assumed that uppercasing `dna_sm` gives `dna`. That was checked in
`docs/case-mask.md` with `tr 'acgtn' 'ACGTN'`, so the check **also uppercased
`n`**. `dna_sm` chr21 has **1,261,364 lowercase `n`** (masked stretches of
N), and the design leaves `n` on the literal path, as both prediction
documents state. So the twin this codec actually produces is `dna_sm` with only
`a/c/g/t` uppercased, not `dna`.

Checked, not argued. That twin compressed by v0.9.0 is **7,747,383 B**, and:

- its body is **`cmp`-identical** to the case-list archive's body;
- 7,747,383 + 143,081 + 16 = **7,890,480**, the case-list archive **to the
  byte**.

So the separation L2 was meant to test holds exactly. The main stream is v0.9.0's
stream of the uppercase twin, and the case costs only its section. The 6,745 B
is what lowercase `n` costs on the literal path. It is v0.9.0's own cost for
those bytes, not something the list adds.

**By the letter of D-L, condition 2 fails, so the list is not adopted by this
document.** The prediction document said what happens then: the numbers go to
Timotheos as they are. The two readings are:

- **as written**: L2 named the `dna` archive, the sizes differ, and D-L says no;
- **as intended**: L2 was there to prove the case costs nothing beyond its
  section. That holds to the byte against the twin the design defines, and
  the gap is a premise error in the check, with a cause that was measured.

## What this leaves

- If adopted: soft-masked human sequence goes from **+40–45%** worse than
  uppercase to **+1.9%** (the section, plus the `n` cost). Uppercase files do
  not move, so no published figure needs re-measuring. It would still need its
  own claim rows, its round-trip cases added to both suites, and a release.
- **Lowercase `n` is the next 6.7 KB** (0.09% of chr21). Putting `n` into the
  case runs is a new design and needs its own pre-registration. It is not
  folded into this one after the fact.
