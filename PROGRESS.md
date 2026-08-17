# PROGRESS — dnac status & next directions

Handoff context for Claude Code. Read together with `CLAUDE.md`. Dense on
purpose: every line is either a fact about where we are or a concrete next task.

## 1. Where we got (reference-free, single sequence)

bits/base on human chr21 (Ensembl GRCh38, 40,088,619 ACGT bases):

    2.305   zip / Deflate           (baseline reference point)
    1.931   context mixing          (committee of models + range coder)
    1.677   + match model           (long repeats, LZ-style predictor)
    1.645   + SNP tolerance         (substitution-tolerant matching)
    1.602   + reverse-complement    (inverted repeats)  <- original idea, kept
    1.597   + SSE / APM             (secondary estimation, the meta-layer)
    1.546   + tuning rounds 2026-08  (see below)
    ───────
    ~1.57–1.60  academic reference-free SOTA (GeCo3 / XM)

Round 2026-08-16 (1.597 → 1.5545, E. coli 1.9049 → 1.8858, all lossless):
adaptive-rate bit counters; mixer weight sets per match state; match anchor
16 → 13 bases (the single biggest item, −0.8%) plus a second forward match model
at 16; 10-order ensemble {1,2,3,4,6,8,11,14,18,22}; two chained SSE stages;
hash tables sized from the input length; checksummed 2-way set-associative
buckets (also 13% faster). Method: one change at a time on a 10 MB chr21 slice,
confirmed on the full chromosome (`bench.ps1`, `adversarial.ps1`).

We independently reconstructed essentially the GeCo3 architecture: a learned
mixer over multiple context models + substitution-tolerant models + repeat /
inverted-repeat models, refined by a secondary-estimation meta-layer. The stack
sits inside the reference-free SOTA band.

## 2. The SOTA claim — VERIFIED 2026-08-16 against GeCo3

GeCo3 was built from source (`bench-external/`) and run on the *same* plain-ACGT
files (`mkseq.ps1`), on this machine, via `benchmark.ps1`. Reference-free:

    human chr21 (40,088,619 bases)   dnac k=22   1.4979 bpb  194 s
                                     GeCo3 -l14  1.5092      200 s
                                     GeCo3 -l9   1.5177       74 s
    E. coli     (4,641,652 bases)    dnac k=22   1.8833 bpb   19 s
                                     GeCo3 -l9   1.8903       10.5 s
                                     GeCo3 -l16  1.8913      177 s

Reference-based, using the GeCo3 authors' own templates from their
`benchmark/run_ref.sh`: W3110 vs MG1655 — dnac 1,086 B, GeCo3 ref 1,404 B, GeCo3
hybrid 1,319 B. O157:H7 vs MG1655 — dnac 361,397 B, GeCo3 ref 431,652 B, GeCo3
hybrid 365,401 B. (The dnac figures were 1,085 / 361,396 when first measured;
compression levels later added a level byte to the header, so every stored file
is exactly one byte larger. Re-verified 2026-08-17.)

GeCo3 `-l 16` needs 8.4 GB and thrashed on this 16 GB machine for the full
chromosome, so it was also measured on a 10 MB chr21 slice where it fits:

    chr21 slice (9,836,065 bases)    dnac k=22   1.7114 bpb   47 s  ~0.4 GB
                                     GeCo3 -l16  1.7163      274 s   8.4 GB
                                     GeCo3 -l14  1.7195       61 s

(These dnac figures are after the 2026-08-16 second round below; the first
measurement had dnac at 1.5062 / 1.7194 and GeCo3 -l16 ahead on the slice.)

Verdict: **ahead of GeCo3 in BOTH modes on every sequence and level tested** —
reference-free including its heaviest level where that can be run at all, and
reference-based by 1% on the diverged pair and 18% on the near-identical one. Caveats that belong next to the claim: GeCo3 decompresses
several times faster (asymmetric design), we compare stored file sizes rather
than its self-reported payload (~4 KB smaller), and this is one machine and
three sequences. XM (Java) has not been run.

### Second round, same day: two-layer mixing + inverted-repeat training

    chr21.seq   1.5062 -> 1.4983      chr21 slice  1.7194 -> 1.7118
    chr21.fa    1.5545 -> 1.5466      E. coli      1.8844 -> 1.8836
    W3110 vs MG1655  1,391 -> 1,365 B    O157 vs MG1655  362,495 -> 361,600 B

What worked: **two-layer mixing** — four expert mixers over the same inputs, each
keyed on a different context and trained on its own error, combined by a learned
second layer (-0.13%); **substitution-tolerant context models** (orders 16, 20)
which were worth nothing under the single-layer mixer and started paying once the
second layer could weigh them (-0.04%); and **retuning the counter adaptation
rate** to 1/(3n+2) (-0.06%); and biggest of all, **inverted-repeat training**
(-0.24%): every context model also learns from the reverse-complement strand,
since after each base the window read on the other strand is a free second
training example (context = RC of the last order bases, next symbol = the
complement of the base that just fell out). That was the user's original
"mirroring" intuition, previously used only in the RC match model. It also helped
E. coli, which most of this round's changes did not. Cost: ~2.2x slower overall.

What did not: lpaq-style bit-history states + StateMap (worse by 0.3-0.7% —
capped confidence is wrong for near-deterministic DNA contexts), more table
memory (0.006%), a third tolerant model, second-layer learning rates above
0.0005.

### Third round: the coder's own floor (the near-identical-genome case)

Compressing a genome against an almost identical one, the model is right nearly
every time, so the cost is not modelling — it is the **arithmetic coder's
resolution**. With a 12-bit probability, `p` is clamped at 4095/4096, i.e. 0.00035
bit per coded bit even when the answer is certain: ~400 bytes per 4.6 Mbp genome,
a third of that file's total size. But raising the resolution alone made things
*worse* (14 bits helped, 15 hurt), because the frequency coder does
`range /= total` and discards up to `total/range` of the interval per symbol —
the two effects fought each other.

Fix: code bits by **splitting the range with a multiply** (LZMA-style) instead of
dividing by a total, then raise probabilities to 14 bits. Both effects now pull
the same way:

    W3110 vs MG1655   1,365 B -> 1,316 (multiply, 12 bits) -> 1,085 B (14 bits)
    chr21 slice       1.7118 -> 1.7114        E. coli  1.8836 -> 1.8833
    chr21.seq         1.4983 -> 1.4979        chr21.fa 1.5466 -> 1.5463

16-bit probabilities were slightly worse than 14 (1,188 B) — the bottom of the
range limits precision once `range >> PBITS` gets small. Lesson: when a file is
dominated by *certainty* rather than surprise, the entropy coder itself becomes
the bottleneck, and that is invisible on ordinary data.

## 3. Architectural fact that unlocks everything below

What we built is NOT fundamentally a DNA compressor. It is a **general-purpose
context-mixing engine** (range coder + mixer + SSE + match model) with
**DNA-specific models bolted on**. The engine is data-agnostic and reusable;
only the models encode domain knowledge.
- Task (c-implementer): refactor so models are **pluggable** behind a clean
  interface, and a file-type detector selects a model set. This is the
  precondition for sections 5 and 6.

## 4. REFERENCE-BASED compression — DONE 2026-08-16, and it is the whole story

The reference-free game is essentially won; gains there are fractions of a
percent. Compressing a genome **against a reference** gave two orders of
magnitude, using the existing models rather than new ones.

Implementation (`cr`/`dr` in `dnac.c`): **priming**, not diffing. Both encoder
and decoder read the reference FASTA, extract its bases, and run them through
`train_base()` — the full model path with no output — so counters, mixer weights,
SSE curves and match anchors all learn the reference before the target is coded.
`g_seq` holds reference+target, so matches reach across the boundary and all the
existing machinery (substitution tolerance, inverted repeats, order models) keeps
working. Header carries the reference's length + FNV-1a fingerprint, so the wrong
reference is refused rather than silently decoded.

Measured (all SHA-256 lossless):

    562x   E. coli W3110 vs MG1655 (real strains)  1.881 -> 0.0033 bpb
            = 1,942 bytes for a 4.6 Mbp genome (FASTA; 1,086 on the .seq)
     63x   simulated chr21 individual vs chr21     1.508 -> 0.0238 bpb
            = 7.55 MB -> 119 KB, 40 M bases
     86x   simulated E. coli individual            1.885 -> 0.0219 bpb
    3.5x   E. coli O157:H7 vs K-12 (diverged)      1.812 -> 0.519  bpb
    -0.2%  unrelated reference (human -> E. coli)  1.884 -> 1.887  bpb

The gain tracks relatedness exactly as theory says it should, and an unrelated
reference degrades gracefully instead of hurting.

**Primed state files (done same day).** Priming is a full pass over the reference
and it was being paid twice per file (compress + decompress). `dnac prime ref.fa
ref.state` writes the models' memory out once; `cr`/`dr` accept a state wherever
they accept a FASTA and auto-detect which it is. A state and its FASTA are
interchangeable and produce **bit-identical** streams (asserted in the adversarial
suite), which is why table sizes are derived from the reference alone.

    reference          priming pass   state load   40 Mbase target, end to end
    E. coli (4.6 Mbp)      10.0 s        0.3 s     -
    chr21   (40 Mbp)         98 s        ~5 s      188 s -> 83 s

Open follow-ups: a state is ~1 GB for a chromosome-sized reference (it *is* the
models' memory) — sparse encoding or mmap would help; batch mode (one prime, N
targets in one process) would remove even the load; and indel-heavy targets are
handled only through match tolerance, not by explicit alignment. Conceptual link:
this is where real genomic storage lives (CRAM-style).

## 5. Squeeze the last 1–2% (reference-free)

Current frontier tools (e.g. JARVIS3, 2025) win mainly by combining MORE models
plus automated parameter tuning — the parameter space is large enough that a
**genetic algorithm** (cf. OptimJV3) was needed to tune it.
- Status 2026-08-16: a first hand-tuning round took chr21 1.597 → 1.5577.
  Parameters in `dnac.c` are `#ifndef`-guarded so a sweep needs no source edits
  (`gcc -DMMIN=13 -DMIX_LR=0.002 ...`), and `bench.ps1 -Fast` is the fitness
  function. `MIX_LR` is already optimal; `MMIN`/`MMIN2`/`MASTER_ORDERS` were
  tuned on one 10 MB slice only, so they are the most likely to be overfit.
- Task: automate that loop (grid/random → GA) against held-out sequences.

## 6. Generalise the engine to other file types

The engine transfers; the models get re-chosen per domain. Priority order:
1. **Text / code** — context mixing's home turf (the enwik record holders are
   this architecture). Swap the 4-symbol alphabet for byte- and word-level
   context models + a dictionary model. Match model + SSE carry over unchanged.
   Benchmark on enwik8 vs xz/zstd.
2. **Protein / RNA / FASTQ** — change alphabet (20 symbols for protein); in
   FASTQ, model the quality-score stream separately.
3. **Time series / sensors** — replace context models with delta / linear-
   predictive / Gorilla-style XOR predictors feeding the SAME mixer.
4. **Lossless image** — 2D spatial / gradient predictors (predict pixel from
   up/left neighbours) into the same mixer+SSE. This is what beats PNG.
5. **Lossless audio** — LPC predictors in front of the same entropy backend.
- Note: vs mature general tools (zstd, lzma) we only expect to win where we
  exploit domain structure they ignore — exactly how we beat gzip on DNA.
  Context mixing is also SLOW; fine for research, a real cost for production.

## 7. Frontier / experimental: learned-manifold compression

The rigorous form of the "geometry of patterns" intuition. Take fixed-size
**chunks of the file as vectors**, learn a lower-dimensional surface (manifold)
they live near via an **autoencoder** (or vector quantization), and store each
chunk as **position-on-surface + small residual** for losslessness. Gain appears
only when chunks genuinely lie near the learned surface; random data has none.
- Task (architect → implementer): define unit (chunk size), similarity, and
  exact lossless reconstruction (position + residual), build a minimal
  autoencoder/VQ variant, and benchmark vs the symbolic engine in bits/byte.
- This is distinct from section 3's models: a *learned* representation, not a
  hand-built one.

## 8. Governing principles (do not drift from these)

- **Compression = prediction = modelling.** Bits are saved only by predicting
  the next symbol better, then spending bits in proportion to surprise.
- **Transforms/geometry never reduce information on their own.** Base changes,
  Fourier, SVG, "bytes as a sphere/wave" are bijections (relabelling): zero gain
  unless paired with a model that exploits the structure they expose. Judge every
  idea by: *does this make the next symbol easier to predict?*
- **Geometry must be learned FROM the data, not imposed on it** (section 7).
- **Cross-file / cross-genome redundancy is a separate, powerful axis** (shared
  dictionaries, dedup, reference-based) — section 4.
- **Every idea → a falsifiable experiment** with a predicted bits/base effect and
  a kill criterion. Measured beats plausible, always.

## 9. Hard invariants (never violate — see CLAUDE.md)

- Losslessness on ANY input; verify with SHA-256 roundtrip BEFORE any ratio claim.
- Decoder must mirror encoder exactly (model updates, order, rescaling).
- Range coder requires total frequency < BOT (1<<16); keep model totals capped.
- Benchmark on multiple datasets incl. adversarial (random, already-compressed):
  a change that helps structured data must not badly regress these.

## 10. Audit 2026-08-17 — after the levels/perf round

A full re-check of code and repo. Build clean at `-O3 -Wall -Wextra` (gcc 16.1),
CI green, tree in sync. Every published ratio re-measured and confirmed: E. coli
1.8833 bpb, the three levels 1.7190 / 1.7175 / 1.7126, base counts matching the
`.seq` sizes exactly. What the audit *did* catch, all of it left over from the
levels change the day before:

- **Every stored-size figure was one byte stale.** The level byte in the header
  made 1,085 → 1,086, 361,396 → 361,397, 1,941 → 1,942. The headline claim
  survives (1,086 B against GeCo3's 1,319) but the numbers were wrong as printed.
  *Lesson: a format change invalidates every absolute byte count in the docs, not
  just the ratios — the ratios rounded identically and hid it.*
- **Round-trip counts were stale and self-contradictory** — the README quoted
  both 60 and 112 for the same script. The levels commit message itself said
  "112 to 147"; the docs were never updated to match.
- **A v0.1.x state file was silently scraped as a FASTA** instead of refused,
  because `is_state_file` matched the full magic and an old state fell through to
  `ref_load`. Fixed: dispatch now matches the `DNACST` prefix, so a wrong-version
  state reaches `state_load` and is refused by name. The v0.1.x *stream* was
  already handled properly — this was the asymmetric half of that same change.
  Now covered by a test in both suites (148 / 143 round-trips).

Known and accepted: `cr`/`prime` silently ignore a user-supplied `k`/`lvl` when
the reference is a state file (the state's own values win). Consistent and
lossless, just quiet. There is also no checksum over the payload, so a corrupted
body decodes to garbage rather than an error — a deliberate format choice; the
reference fingerprint covers the reference, and headers are validated.
