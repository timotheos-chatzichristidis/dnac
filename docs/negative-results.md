# Negative results

Ideas that were built or measured and then **rejected by the measurement**. They
are kept here because they cost real time, and because knowing where a technique
*stops* working is worth as much as knowing where it starts.

---

## 1. The reference-mode advantage does not transfer outside DNA

*Measured 2026-08-16.*

`dnac`'s reference mode compresses one genome against another at ~0.003 bits/base
— a 4.6 Mbp *E. coli* genome stored in under 2 KB. The obvious question is
whether that is a property of the **architecture** (context mixing + tolerant
match models) or of the **data** (DNA). If it were the architecture, the same
engine would be a strong binary-delta compressor: firmware/OTA updates, container
image layers, database snapshots.

**It is the data.**

### Method

Real input: two consecutive Microsoft Edge builds (151.0.4129.78 → 151.0.4129.86),
complete files, no slicing. Every engine was measured the *same* way so none gets
an optimism advantage — the ideal bound of any reference mode is

    cost(target | ref) = C(ref ++ target) − C(ref)

`zstd -19 --patch-from` was also run as the real-world practical baseline. The
context-mixing engine used was the byte-level sibling of `dnac` (a separate
prototype, not part of this repository); `dnac` itself only models ACGT.

### Result

| pair | best general-purpose | CM ideal bound | verdict |
|---|---:|---:|---|
| `msedge_elf.dll` (3.98 MB) | 48,404 (xz -9e) | 166,196 | **3.4× worse** |
| `msedge.exe` (5.02 MB) | 3,326 (zstd --patch-from) | 8,857 | **2.7× worse** |
| `onnxruntime.dll` (10.9 MB) | 3,661 (zstd -19) | 13,686 | **3.7× worse** |
| *E. coli* W3110 vs MG1655 (control) | 244,124 (xz -9e) | **1,942** (`dnac cr`) | **126× better** |

Three independent binary pairs, the same answer each time. Note the CM figure is
an *optimistic* bound — a real implementation would be worse still.

### Why

Two different kinds of redundancy:

- **DNA is statistical and noisy.** Short matches riddled with substitutions.
  LZ77 breaks on every mutation; a substitution-tolerant match model plus context
  mixing is exactly the right tool.
- **Consecutive software builds are exact and long.** Megabytes of identical code
  that merely *shifted*. That is textbook LZ77 with a large window — already
  solved extremely well by xz, zstd, bsdiff and Courgette.

Porting `dnac`'s match models to bytes would not close the gap: its anchors
(MMIN=13/16 → a single position, substitution-tolerant) are built for noisy short
matches, not for exact copies displaced by megabytes. Closing it requires a real
LZ77 front-end — at which point you have rebuilt xz.

**Conclusion:** the advantage here is domain-specific. Do not re-attempt
binary/OTA delta with this engine without a new reason. The direction that
remains plausible is adjacent biological formats (FASTQ quality streams,
SAM/BAM, VCF, protein sequence), where the redundancy is the same
statistical/noisy kind.

---

## 2. Ideas rejected during development of the codec itself

Each of these was implemented and measured on real chr21 / *E. coli* data, and
reverted because it did not pay:

| idea | outcome |
|---|---|
| Aggressive match re-anchoring on every miss | worse — thrashes the anchor |
| Dinucleotide "orientation lens" derived context | cosmetic relabelling, no gain |
| Adding the order-1 base to the mixer weight-set context | no gain, more memory |
| Retuning `MIX_LR` | already at its optimum |
| Multiple match candidates per anchor bucket | +0.004 % for 2× the memory |
| A tandem/HOR periodicity model | redundant with the match model |
| An order-1 model stacked on top of MTF (byte sibling) | markedly worse — MTF *is* an order-1 decorrelator; stacking double-counts |

---

## 3. Block boundaries cannot be placed cheaply — parallel decode costs 2.5% to enter

*Measured 2026-08-19.*

Context mixing decodes at the same speed it encodes, because the decoder must
rebuild the identical probability for every bit before it can read it. The one
way to cut decode *wall-clock* is to split the file into blocks and decode them
on separate cores — which forces every block to be coded independently, since
block j cannot see blocks 0..j-1 while they are still being decoded elsewhere.
That constraint is reproducible with no threading at all: split the input,
compress the pieces separately, sum the sizes.

### What it costs (chr21.seq, 40 Mbp, charged as one header plus 8 B per block)

| blocks | bytes | vs whole | bits/base |
|---:|---:|---:|---:|
| 1 | 7,506,264 | — | 1.4979 |
| 2 | 7,695,168 | +2.52% | 1.5356 |
| 4 | 7,740,159 | +3.12% | 1.5445 |
| 8 | 7,836,208 | +4.40% | 1.5637 |

The cost is not per-boundary-uniform: the **first** cut costs ~188 KB and every
further cut only ~22 KB. Long-range repeats (Alu, LINE, satellite) are what the
match models live on, and severing the first one denies a block the bulk of the
genome's history; subdividing further denies progressively less that the block
cannot re-learn from its own 5-20 Mbp.

### Why placement does not rescue it

Two ways to choose better boundaries were measured, and neither works.

**Snap to assembly gaps.** A cut inside a run of `N` breaks no sequence
continuity, so it should be free. But chr21's 30 gaps all sit in the first 22% of
the file (the p-arm). For 8 equal blocks the boundaries at 37/50/62/75% have no
gap within 10-30% of the file, so snapping produces blocks with a 5:1 size ratio
— and a parallel decoder's wall-clock is set by its *largest* block, so the
speedup it was bought for is given straight back.

**Search locally for a cheap cut.** Boundary cost was measured at seven positions
in a 10 Mbp interior window: 11,803 to 13,846 bytes, a 17% spread on ~2 KB. And
the expensive midpoint cut is a plateau, not a spike — sweeping the full
chromosome at 44/47/50/53/56% gives 188.4, 187.4, 189.2, 187.7, 157.4 KB. There
is no narrow bad place to step around; the cost is intrinsic to how much history
the cut denies.

**Conclusion.** +2.52% is the entry ticket for *any* parallelism in
reference-free mode, and that alone puts dnac behind GeCo3 `-l 14` (1.5356 vs
1.5092) — the whole margin is 0.7%. Parallel decode is therefore only defensible
as an **opt-in** (`-j 1` default, byte-identical to today), never as the default.

Two findings from the same sweep are *positive* and worth keeping:
- **RAM does not multiply.** Tables are sized from the input length, so 8 blocks
  of 1/8 the size need 83 MB each against 595 MB for the whole file — 664 MB
  across 8 threads, 1.12x, not 8x.
- **Reference mode is far cheaper.** With every block starting from the same
  primed state, a boundary costs a flat ~245 B (E. coli: 229 / 246 / 255 B at
  N=2/4/8), because the reference still supplies the long-range matches that a
  reference-free block loses. The obstacle there is the opposite one: table sizes
  come from the reference, so each thread needs the full 600 MB (chr21: 1.25 GB).
  Sharing one *frozen* primed model across threads is the untested idea that
  would remove it.

---

## 4. `-j N` is a loss on high-coverage read data, and the prediction was inverted

*Measured 2026-09-04.*

Block mode gives 5.1x encode on 8 cores, and had never been measured on sequencing
reads. The reasoning on record was that *a reads file has no long-range structure
for a block boundary to cut*, so `-j 8` should cost under 1% against chr21's 4.4%.

It costs **+12.97% at `-j 2` and +86.50% at `-j 8`** on a 46x-coverage short-read
set — twenty times what a genome pays. The intuition was exactly backwards. At 46x
coverage a reads file has almost *only* long-range structure: reads sit in random
genome order, so a read overlaps one half a million positions away in the file,
not its neighbour. Every read depends uniformly on the whole file, and at `-j 8`
each block sees 5.8x coverage and relearns the genome from scratch.

Confirmed as a mechanism rather than a dataset quirk by predicting the opposite
case and checking it: at 0.0645x coverage (GIAB HG002) the same short-read blocking
costs only **+3.72%**, and an 11.5x ONT set is **−2.34%** — blocking makes it
*smaller* while running 3.4x faster. **Block cost tracks cross-read redundancy,
i.e. coverage — not read length and not file size.**

Not a table-geometry artefact: at these lengths the whole file and a 1/8 block
both saturate the caps at `hashbits=24, mhb=26`, so only the block-local model
differs.

---

## 5. Reference mode does not scale with the reference — it saturates at chromosome scale

*Measured 2026-09-04.*

`cr` primes the model on a reference and then codes the target through the normal
path; it does not care that the target is a reads file. Pointed at reads for the
first time, it looked like the best result the project had produced: reads that
chr21 explains went from 1.1270 to **0.2708 bits/base, −76.0%**. At 0.0645x
coverage that is the same neighbourhood as 0.2318 at 46x self-referential — the
reference substituting for roughly 700x more data.

The obvious extrapolation — that the whole read set would fall to ~0.27 with the
whole human genome primed — was written down explicitly as an extrapolation and
then **run. It was wrong by about a factor of five.** GRCh38 (2,948,627,755 bases,
2 h 11 m to prime, a 3.88 GB state file) gives Illumina **1.3253** (−16.9%) and
ONT **1.7745** (−1.25%).

The control isolates the cause. The same reads, three references:

| reference | bits/base |
|---|---:|
| none | 1.1270 |
| chr21 alone (40 Mbp) | **0.2708** |
| whole GRCh38 (2.95 Gbp) | **0.8639** |

**73x more reference — one that strictly contains the chr21 that worked — made it
3.2x worse.** The content is there; the index cannot reach it. Anchor tables hold
2^26 buckets at one position each: chr21 is 0.60 positions per bucket, the genome
is 43.9, so nearly every anchor is overwritten and the survivors are whatever was
primed last.

Lifting it needs 2^30–2^32 buckets — 8–34 GB of anchor tables plus 2.95 GB of
history. **An index problem, not a model problem**, and the same problem CRAM
solves with alignment instead of hashing.

*Method note worth more than the number:* the `MHBITS_MAX` sweep run the same
morning concluded "27 buys 0.092%, not worth it, 26 stays". Correct **on chr21**.
At genome scale that same parameter is the binding constraint on the entire mode.
A hyperparameter can look settled in one regime and be the ceiling in another —
state the regime with the sweep.

---

## 6. Compression-as-classifier is already published, and our edge is absent where it counts

*Checked 2026-09-05, before running the experiment.*

A model that predicts DNA well also scores how well a given reference explains an
unknown sample, which is a classifier — and the measured dynamic range is large:
the right organism as reference gives 496x, an unrelated one costs +0.14%.

That is **FALCON2** (Pratas & Pinho — the GeCo authors), published in
*Bioinformatics* in 2026. They also already measured the hypothesis this project
would have tested, that exact-k-mer tools go blind on short or damaged reads while
a compression model degrades gracefully: 0.968 AUPRC against Kraken2's 0.184, and
being 22x slower than Kraken2 was not disqualifying.

Our own head-to-head says the idea would not transfer here anyway. Against GeCo3's
reference templates dnac is 19.6% ahead on the near-identical pair and **1.1% ahead
on the diverged pair** — and diverged is the case classification actually needs help
with. Separation between a right and a wrong reference is set by biology, not by
the last 1% of modelling: **a better compressor is not a better classifier.**

Twenty minutes of prior-art reading closed a direction that would have cost weeks.

---

The governing question throughout: *after this change, is the next base easier to
predict?* If a transform only relabels what is already known, it is cosmetic — a
transform never reduces information on its own.
