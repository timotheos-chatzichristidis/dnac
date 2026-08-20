# dnac — a lossless DNA compressor

A single-file lossless DNA compressor in C: a context-mixing codec over a binary
decomposition of `{A,C,G,T}`, with substitution-tolerant forward and
reverse-complement match models, a two-layer logistic mixer, chained SSE/APM
stages, a range coder, and an optional reference mode. On the sequences measured
here it compresses real genomes below **GeCo3**, the current open-source state of
the art, in both reference-free and reference-based modes.

No dependencies beyond libc. Builds clean with `-Wall -Wextra` on gcc and clang.
Every design decision was a falsifiable experiment on real genomes — kept when
the measurement rewarded it, reverted when it did not. What the measurement
*rejected* is written down as well, in
[docs/negative-results.md](docs/negative-results.md).

## Results (real genomes, bits per ACGT base — lower is better)

| method                         | human chr21 | E. coli | notes |
|--------------------------------|:-----------:|:-------:|-------|
| naive 2-bit packing            | 2.000       | 2.000   | no modelling |
| zip / Deflate                  | 2.305       | 2.416   | barely models DNA |
| **dnac** (k=22)                | **1.546**   | **1.883** | this project, on the FASTA files |

## Head-to-head vs GeCo3 — same machine, same input files

Published bits/base numbers are not comparable across papers (different
assemblies, different handling of `N` and line breaks, different denominators),
so "we match the state of the art" is worth nothing until it is measured
directly. GeCo3 was built from source and run here, on the plain ACGT sequence
files that the literature benchmarks on (`./mkseq.ps1`, `./benchmark.ps1`).

**Reference-free** — compressed size of the actual file. Every row below was
re-measured in a single session on one machine, with one build, so the times are
comparable to each other; mixing timings from different sessions is how the
numbers here went stale once already.

| dataset | tool | bits/base | compress | RAM |
|---------|------|:---------:|---------:|----:|
| human chr21 (40,088,619 bases) | **dnac `-l 3`** (default) | **1.4979** | 88.7 s | 1.24 GB |
| | **dnac `-l 2`** | **1.5039** | 60.0 s | |
| | **dnac `-l 1`** | **1.5065** | **46.6 s** | |
| | GeCo3 `-l 14` | 1.5092 | 174.1 s | |
| | GeCo3 `-l 9` | 1.5177 | 75.1 s | |
| | GeCo3 `-l 16` | *did not finish* | — | 8.4 GB, thrashed |
| chr21 slice (9,836,065 bases) | **dnac `-l 3`** | **1.7114** | 20.8 s | ~0.4 GB |
| | **dnac `-l 1`** | 1.7178 | **9.7 s** | |
| | GeCo3 `-l 16` | 1.7163 | 224.8 s | 8.4 GB |
| | GeCo3 `-l 14` | 1.7195 | 42.6 s | |
| E. coli (4,641,652 bases) | **dnac `-l 3`** | **1.8833** | **9.4 s** | ~0.6 GB |
| | GeCo3 `-l 9` | 1.8903 | 11.4 s | |
| | GeCo3 `-l 16` | 1.8913 | 130.6 s | 8.4 GB |

**On all three datasets dnac has a setting that is at once faster and smaller
than every GeCo3 setting tested.** On E. coli and the chr21 slice that setting is
the default `-l 3`; on the full chromosome `-l 1` beats GeCo3 `-l 9` on both axes
(46.6 s vs 75.1 s, 1.5065 vs 1.5177) while `-l 3` beats `-l 14` on both.

GeCo3's maximum level needs 8.4 GB, which did not fit alongside anything else on
this 16 GB machine for the full chromosome — it spent 7 minutes at 19% CPU
swapping before being stopped. The 10 MB chr21 slice exists in the table so that
`-l 16` gets measured on human sequence at a size where it does fit.

**Reference-based**, with the GeCo3 authors' own reference templates from their
`benchmark/run_ref.sh` (`-rm 20:500:1:35:0.95/3:100:0.95 -rm 13:200:... -lr 0.03
-hs 64`, and the hybrid variant that adds target models):

| pair | dnac | GeCo3 ref models | GeCo3 hybrid |
|------|-----:|-----------------:|-------------:|
| W3110 vs MG1655 (near-identical strains) | **1,060 B** | 1,404 B | 1,319 B |
| O157:H7 vs MG1655 (diverged strains) | **361,417 B** | 431,652 B | 365,401 B |

(Stored file sizes on the plain-ACGT `.seq` files, as everywhere in this
section. The same pairs measured on the original FASTA files cost a little more
— 1,931 B for W3110 — because the headers and newlines are stored too.)

### What the head-to-head actually says

- **dnac is ahead reference-free on every sequence and every GeCo3 level tested**,
  including their heaviest (`-l 16`) where it can be run at all — and on the
  slice it gets there in 20.8 s where `-l 16` needs 224.8 s and 8.4 GB.
- **It is ahead on speed too, not only ratio.** That was not true of the numbers
  published before v0.3.0: they compared our *maximum* level against GeCo3's
  *fast* one, and carried a chr21 time (194 s) measured before the `-O3`,
  prefetch and stretch-table work. The honest comparison is the table above.
- **Reference-based it is now ahead on both pairs**: 1% better than their best
  configuration on the diverged one, and 20% better on the near-identical one
  (1,060 bytes against 1,319 for a whole 4.6 Mbp genome).
- Note that GeCo3's heaviest level is *worse* than its own level 9 on E. coli
  (1.8913 vs 1.8903, 20× the time): more models is not automatically better —
  the same lesson our own rejected experiments taught.

So the claim that holds: *"ahead of GeCo3 on these sequences in both modes"* — measured here, on identical files, not quoted
from a paper. It is one machine and three sequences; that is the honest scope.

One thing that belongs next to any such claim: these are stored file sizes,
while GeCo3 additionally self-reports a payload figure ~4 KB smaller than its
file — noise on chr21, 0.007 bpb on E. coli. XM (Java) has not been run.

**Decompression speed is unmeasured on the GeCo3 side, and this README used to
claim otherwise.** Until 2026-08-19 it said GeCo3 decompresses several times
faster because ours is symmetric and theirs is not. Neither half was checked.
The GeDe3 build here fails on every input tested — `Bad input file - attempted
read past end of file`, a 0-byte output, exit 1, reproducible from 100 KB to
4.6 Mbp — so the "1.8 s" in `bench-external/results.md` was the time it took to
fail, and `benchmark.ps1` reported `lossless=True` because it hashed a copy of
the original against the original instead of against anything a decoder wrote.
Both are fixed; the harness now runs a negative control at startup. Meanwhile
GeCo3's own help text (`src/msg.c:268`) says: *"the decompression is symmetric,
therefore the same resources, namely time and memory will be used as in the
compression."* So the honest statement is that **both codecs are symmetric by
design**, ours measurably so (10.4 s compress, 10.7 s decompress on E. coli),
and no comparison between the two decoders exists here.

*chr21 = Ensembl GRCh38, 40,088,619 ACGT bases (the 6.6M `N` gap bytes and
newlines are handled losslessly but excluded from bits/base). Compression is
lossless — every result here was verified by SHA-256 round-trip.*

## Compression levels

Most of the codec's time goes into models that earn very little. Measured by
ablation on the 10 MB chr21 slice, inverted-repeat training and the
substitution-tolerant context models cost ~21% of the run *each* while together
they are worth 0.29% of compressed size. Three levels expose that trade:

| level | models | time | bits/base | vs max |
|:-----:|--------|-----:|----------:|--------|
| 1 `fast` | 6 orders, 2 mixing experts, no IR, no tolerant models | 9.7 s | 1.7190 | **2.1× faster**, +0.37% size |
| 2 `balanced` | all orders, 4 experts, no IR, no tolerant models | 13.8 s | 1.7175 | 1.4× faster, +0.29% |
| 3 `max` (default) | everything | 20.0 s | 1.7126 | — |

```sh
dnac c in.fa out.dnac 22 1     # k=22, level 1
dnac d out.dnac back.fa        # no level needed: it is in the header
```

The level is stored in the header, not passed to the decoder, because it decides
*which models exist* — it is part of the format, not a hint. A primed state
carries its level too, and decoding a stream with a state primed at a different
level is refused: the reference fingerprint cannot catch that mismatch, since
the reference is the same file and only the model set differs.

Two results worth noting, both the same lesson the rest of this project keeps
teaching: **six order models compress better than eight**, and **two mixing
experts beat four**, at these sizes. More models is not automatically better.

**The ordering is a trade, not a guarantee.** Level 3 is the smallest on the
real genomes measured above, but on highly repetitive or synthetic sequence the
extra models can cost more than they earn: on a 1 Mbase sample from `dnac gen`,
level 2 comes out **2% smaller than level 3**. The same effect shows up in
GeCo3 (`-l 16` worse than `-l 9` on *E. coli*) and in fqzcomp (`-s9` worse than
`-s7` on reads). Measure on your own data before assuming the maximum is best.

## Blocks (`-j N`) — buying decode wall-clock with ratio

Context mixing decodes at the speed it encodes: the decoder has to rebuild the
identical probability for every bit before it can read it, so it runs the whole
model too. The only way to cut *wall-clock* is to code the file as N independent
blocks and put them on N cores — and independence is the price, because block j
cannot see blocks 0..j-1 while other cores are still producing them.

| `-j` | bytes (E. coli, 4.6 Mbp) | vs one block |
|---:|---:|---:|
| 1 (default) | 1,092,692 | — |
| 2 | 1,100,603 | +0.72% |
| 4 | 1,108,086 | +1.41% |
| 8 | 1,116,080 | +2.14% |

What it buys, measured on the full chr21 (40 Mbp) on an 8-core machine:

| `-j` | bytes | encode | decode |
|---:|---:|---:|---:|
| 1 | 7,506,264 | 112.6 s | 83.5 s |
| 2 | 7,695,177 | 50.8 s | 52.8 s |
| 4 | 7,740,168 | 32.8 s | 33.1 s |
| 8 | 7,836,217 | **22.2 s** | **22.0 s** |
| 16 | 7,914,651 | 21.7 s | 23.1 s |

5.1× on encode and 3.8× on decode at `-j 8`; `-j 16` buys nothing on 8 cores and
costs another percent, so more blocks than cores is only ever a loss. Both sides
speed up, because a block is independent in both directions.

On human chr21 the split costs more than on E. coli — +2.52% at N=2 and +4.40% at N=8 —
because long-range repeats (Alu, LINE, satellite) are where its compression comes
from, and a block cannot reach the ones behind it. That is why this is **opt-in
and will stay opt-in**: at 8 blocks chr21 goes to 1.5637 bpb, behind GeCo3's
1.5092, and the whole margin this project has is 0.7%. `-j 1` is the default and
is byte-for-byte identical to a build with no block support at all.

What it costs in memory depends on the size of the file, and the honest answer
has two halves. Tables are sized from the block, so smaller blocks mean smaller
tables — but that sizing is capped at 2^26, and once a block is large enough to
hit the cap it stops shrinking:

| input | `-j 1` | `-j 8` | |
|---|---:|---:|---|
| E. coli, 4.6 Mbp (580 kbase blocks) | 603 MB | 650 MB | 1.08×, effectively flat |
| human chr21, 40 Mbp (5 Mbase blocks) | 1,253 MB | 4,751 MB | **3.8×** |

So on a chromosome `-j 8` costs about 4.75 GB. Extrapolating the cap rather than
measuring it: above roughly 500 Mbases of input every block of 8 exceeds the
2^26 cap, each thread holds a full-size table, and memory approaches 8 × 1.25 GB.
Cores stop being the binding constraint before that point; memory starts.

(The first version of this paragraph claimed memory does not multiply at all.
That was measured on E. coli and generalised, which is wrong: see
docs/negative-results.md for why this project writes measurements down with
their scope attached.)

Reference mode is
not supported yet: every block would need its own copy of the primed model, which
is 1.25 GB for chr21 — ironically the mode where a block boundary is cheapest
(~245 B) is the one where it is most expensive in memory.

## Reference-based results (`cr` / `dr`) — the big lever

Two genomes of a species differ by ~0.1%, so a genome stored *against a
reference* costs a fraction of one stored alone. Same models, same code — the
reference is simply fed through them first (see below).

| target | reference | alone | with reference | smaller by |
|--------|-----------|:-----:|:--------------:|:----------:|
| E. coli W3110 (real strain) | E. coli MG1655 | 1.880 | **0.0033** | **565×** — 1,931 bytes for a 4.6 Mbp genome |
| chr21 of a simulated individual (0.1% SNPs + indels) | chr21 | 1.504 | **0.0227** | **66×** — 7.54 MB → 111 KB |
| E. coli, simulated individual | E. coli MG1655 | 1.885 | **0.0217** | 87× |
| E. coli O157:H7 (real, diverged strain) | E. coli MG1655 | 1.812 | **0.519** | 3.5× |
| E. coli MG1655 | *human chr21* (unrelated!) | 1.885 | 1.889 | −0.2% (degrades gracefully) |

The gain tracks how related the two sequences are, exactly as it should: nearly
identical strains cost almost nothing, a diverged strain of the same species
costs a third, an unrelated reference costs nothing extra and breaks nothing.

### Pay for the reference once (`prime`)

Priming is a full modelling pass over the reference — and it is paid *twice per
file*, by the compressor and again by the decompressor. For the actual use case
(many genomes against one reference) that pass is identical every time, so it can
be done once and saved:

```powershell
./dnac.exe prime reference.fa reference.state 22   # once
./dnac.exe cr target.fa out.dnac reference.state   # every time after
./dnac.exe dr out.dnac  back.fa  reference.state
```

| reference | priming pass | load a saved state | compress a 40 Mbase target |
|-----------|:------------:|:------------------:|:--------------------------:|
| E. coli (4.6 Mbp) | 10.0 s | **0.3 s** | — |
| human chr21 (40 Mbp) | 98 s | ~5 s | 188 s → **83 s** end-to-end |

A state file and the FASTA it came from are **interchangeable and produce
bit-identical output** (the adversarial suite checks exactly this): you can
compress with one and decompress with the other. Table sizes are therefore
derived from the reference alone, never from the target. The state is a cache in
host byte/float layout — big (616 MB for E. coli, 1,255 MB for chr21, since it
*is* the models' memory) and not an interchange format; the compressed stream is the
portable artefact.

The whole point in one line: **compression = prediction.** We never store the
sequence; we store only the *surprise*. Anything predictable costs almost nothing.

## How it works (the architecture, plain → technical)

Think of a committee playing "guess the next base," and a scribe who writes down
only where the committee was wrong.

```
        each byte of the file
                │
         ┌──────▼───────┐   "is this a base or junk (newline/header/N)?"
         │  flag model  │   contexted on run-length → periodic newlines ~free
         └──────┬───────┘
          base  │  non-base ──► order-0 literal model (separate, never pollutes DNA)
                ▼
   each base = 2 binary decisions over a tree {A,C,G,T}
                │
   ┌────────────▼───────────────┐   PREDICTORS (each gives P(next bit)):
   │  order models 1,2,3,..,k    │   • context models of many memory lengths
   │  match model, 13-base anchor│   • LZ-style "seen this stretch before?"
   │  match model, 16-base anchor│   • the same, but only on a surer anchor
   │  reverse-complement match   │   • "seen its reverse-complement before?"
   └────────────┬───────────────┘
        ┌────────▼────────┐   MIXER (logistic): blends predictors in the logit
        │   logistic mix  │   domain, weights learned online per match state —
        └────────┬────────┘   trusts whoever's been right lately
        ┌────────▼────────┐   SSE / APM ×2: recalibrates the probability by
        │  SSE / APM ×2   │   context (a model of the prediction's reliability)
        └────────┬────────┘
           ┌──────▼──────┐
           │ range coder │   spends bits ∝ −log2(probability of the truth)
           └─────────────┘
```

The components, bottom up:

- **Range coder** — 32-bit carryless (Subbotin style). Turns a probability into
  bits: likely → fraction of a bit, surprising → many bits. Bits are coded by
  *splitting* the range with a multiply rather than dividing it by a total
  frequency, and probabilities carry 14 bits. That combination matters far more
  than it looks: dividing throws away up to `total/range` of the interval per
  symbol, so simply asking for finer probabilities made things *worse* until the
  division went away. With a 12-bit probability the cost floor is 0.00035 bit per
  coded bit even when the model is certain — about 400 bytes per 4.6 Mbp genome,
  which is a third of what a genome costs when compressed against its own
  reference. Fixing the coder took that case from 1,365 to 1,085 bytes (1,088
  today: the level byte and the stored table geometry added three header bytes).
- **Binary tree over {A,C,G,T}** — each base is two bit-decisions
  (`{A,C}` vs `{G,T}`, then which one). This lets the powerful machinery below
  work on simple binary predictions.
- **Flag model** — before every byte, a binary "is this a base?" predictor.
  Its context is the *run-length* of consecutive bases since the last non-base,
  so fixed-width FASTA newlines become almost free. Non-bases go to a separate
  order-0 byte model and never touch the DNA history.
- **Order-model ensemble** — orders `{1,2,3,4,6,8,11,14,18,22}` up to `k`, all
  running at once. Low orders learn fast; high orders are specific. Orders ≤8 use
  direct tables, higher ones use hashed tables sized from the input length.
- **Bit counters with an adaptive rate** — each stored probability also keeps a
  4-bit observation count and moves by `1/(3n+2)` of the error: a brand-new
  context jumps straight to what it just saw, a well-established one barely
  budges. A fixed shift makes cold high-order contexts learn far too slowly.
- **Two forward match models** — each remembers where a recent k-mer last
  occurred and predicts the base that followed it. One uses a **short 13-base
  anchor** (sensitive: it re-finds diverged repeats — human Alus are only ~85%
  identical, so long exact anchors rarely hit) and one a **16-base anchor**
  (precise: when it fires it is rarely coincidence). Both are
  **substitution-tolerant**: a single mismatch (a SNP inside a repeat) doesn't
  break the match — confidence dips and recovers.
- **Reverse-complement match model** — the same, but for inverted repeats: it
  looks up the reverse-complement of the current context and predicts walking
  *backward* and complemented (`complement = 3 − base`). Biggest single win on
  human DNA (it's full of inverted repeats; backed by Chargaff's 2nd rule).
- **Substitution-tolerant context models** — two extra order models (16 and 20)
  that read a *repaired* history: when such a model's own top guess turns out
  wrong, it pushes the guess it made rather than the base that actually
  occurred, so one SNP inside a diverged repeat doesn't poison the next 20
  contexts. It resyncs to the true history after 8 failures. Unlike the match
  models, which follow one anchored position, these aggregate statistics over
  *every* past occurrence of the repaired context.
- **Inverted-repeat training** — DNA is double-stranded, so the stretch just read
  also exists physically as its reverse complement. After every base, each
  context model gets a second, free training example taken from that other
  strand: the last `order` bases form the context there, and the base that just
  fell out of the window is what follows them, complemented. Same tables, no
  extra prediction — a context first met as an inverted repeat is already warm
  when it later appears the normal way round. This was the largest single gain
  of the final round (−0.24%) and one of the few that helped bacterial DNA too.
  It is the same "mirroring" intuition as the reverse-complement match model,
  applied to the context models instead: GeCo calls the flag `ir`.
- **Two-layer mixer** — four logistic mixers ("experts") run over the same
  inputs, each keyed on a different context (which matches are running / the
  last three bases / match confidence / a global one) and each trained on its
  own error, so each specialises. A small learned second layer then decides how
  much to trust each expert, per node and per match state. This is what
  separates GeCo3 from GeCo2, and what PAQ has always done; on its own it was
  worth 0.13%, and it also made the tolerant models above start paying off —
  they were worth nothing under the single-layer mixer.
- **Reference mode** (`cr`/`dr`) — the reference genome is not diffed against;
  it is **run through the same models first** (counters, mixer weights, SSE
  curves and match anchors all learn it), and only then is the target coded.
  Encoder and decoder do this identically, so nothing extra is stored. Because
  it reuses the ordinary machinery, substitution tolerance, inverted repeats and
  order models all work *across* the file boundary — and an unrelated reference
  simply gets ignored by the mixer instead of corrupting anything. The header
  keeps a fingerprint of the reference, so decoding with the wrong one is
  refused rather than silently wrong.
- **Sticky reference anchors** (v0.4.0) — a bucket in the match-anchor table
  holds exactly one position (`MWAYS` is 1). Without care, the first time the
  *target* touches a bucket it **overwrites the reference's anchor there**, so
  the codec progressively stops pointing at the aligned position in the reference
  and starts pointing at its own recently-coded self. An anchor that points into
  the reference is now never overwritten; the target still claims every bucket
  the reference never used. Worth **5.4% on a chr21 individual** and 2.6%
  on the W3110/MG1655 pair (plain-ACGT files, 1,088 B -> 1,060 B), and it costs a diverged target nothing (O157 vs MG1655: +0.01%), because
  that target's own prophages and IS elements hash to buckets the reference never
  filled. Same memory, one condition in the store loop. It was found while
  measuring something else entirely — whether a primed model could be frozen so
  that parallel-decode threads could share one read-only copy.
- **SSE / APM** — two chained stages that recalibrate the mixed probability
  through learned, context-dependent curves: stage 1 keyed on which match models
  are live, stage 2 on the last 6 bases. Each is blended 50/50 with its own
  input — the mixer is already well calibrated, so a raw APM output adds noise.

`k` (the CLI argument, default 22) is the **maximum model order**.

## The journey (every change was measured on chr21)

```
2.305  zip / Deflate
1.931  context-mixing ensemble of order models
1.677  + forward match model (repeats)
1.645  + substitution tolerance (diverged repeats / SNPs)
1.602  + reverse-complement match (inverted repeats)
1.597  + SSE / APM second stage
1.558  + adaptive-rate counters, per-match-state mixer weights,
          13-base anchor + 2nd match model, 10-order ensemble,
          2-stage SSE, input-sized hash tables
1.554  + checksummed, 2-way set-associative hash buckets (also 13% faster)
1.551  + two-layer mixing (4 context-keyed experts + a learned second layer),
          substitution-tolerant context models, retuned counter rate
1.547  + inverted-repeat training: every context model also learns from the
          reverse-complement strand (the single biggest win of that round)
1.546  + a multiplying binary coder at 14-bit probability resolution, which
          matters most where the model is nearly always right (see below)
─────
~1.57–1.60  academic SOTA (GeCo3 / XM)

    0.0238  the same chromosome coded against a reference (see the table above)
            — and 0.0033 for a real E. coli strain against another
```

The 1.597 → 1.558 round was measured one change at a time on a 10 MB chr21 slice
(fast loop), then confirmed end-to-end on the full chromosome. By far the biggest
single item was **shortening the match anchor from 16 to 13 bases** (−0.8% alone):
the match model's job on human DNA is finding *diverged* repeats, and a 16-base
exact anchor is simply too rare inside an 85%-identical Alu. Everything else in
that line was worth 0.05–0.4% each.

Earlier, a separate cleanup mattered too: replacing the original 5th "escape"
symbol with a clean 4-symbol base model + the run-length flag removed a hidden
`log2(5) = 2.32` bits/base ceiling that was making naive high-`k` *worse* than
2-bit packing.

### Ideas the measurement *rejected* (kept honest)

- **Aggressive match re-anchoring on every miss** — plausible, but made chr21
  *worse*: real genomes are repetitive, so the post-SNP context often hash-hits,
  and re-anchoring there abandoned good diverged matches.
- **An "orientation" derived context** (dinucleotide inversion bit `AC=0/CA=1`)
  — a fair-fight entropy test (`feature_test.c`) showed it's a lossy *coarsening*
  of the bases: per context-bit it predicts strictly worse, and adds no
  information the order models lack.
- **A tandem/HOR periodicity model** — redundant with the match model (which
  already anchors at the period), and chr21's satellite arrays live in the
  centromeric `N` gaps anyway. Zero gain, +12% time → reverted.
- **Several match candidates per hash bucket** (with backward verification to
  pick the better one) — 0.004% for double the anchor memory. The anchor tables
  already have enough headroom that collisions are not what limits us.
- **lpaq-style bit-history states + a shared StateMap** instead of per-context
  probabilities — *worse* by 0.3% on human and 0.7% on bacterial DNA. A 4-bit
  count per side caps confidence near p=0.94, but a good order-16 DNA context is
  nearly deterministic and wants p>0.99. That design wins on text, where
  non-stationarity matters more than sharpness; DNA is the other case.
- **More table memory** — +1 and +2 doublings of every hash table changed chr21
  by 0.006%. We are not table-limited at these sizes.
- **Adding the order-1 base to the mixer's weight-set context** — +0.06% on
  chr21 but −0.04% on E. coli; splitting the weights 4 ways more just slowed
  learning. Kept the match-state context only.
- **Tuning `MIX_LR`** — swept 0.001 / 0.002 / 0.004 / 0.008: flat to worse.
  The mixer learning rate was already at its optimum; no free lunch there.

These are not failures; a falsifiable experiment that says "no" is the method
working. *Measured beats plausible.*

## Lossless on anything

Every byte round-trips. Non-`ACGT` bytes (headers, newlines, `N`, lowercase
soft-masking) go through the flag + literal path and never disturb the base
history. Encoder and decoder run **identical floating-point code in the same
order**, so the integer probability fed to the coder is bit-identical on both
sides. Verified by SHA-256 on real genomes *and* adversarial inputs (empty file,
all 256 byte values, messy CRLF/lowercase/N FASTA, pure newlines, random binary,
exact/diverged/inverted repeats), across many values of `k`.

## Build & run

**Linux / macOS / WSL:**

```sh
make                              # cc -O2 -Wall -Wextra -o dnac dnac.c -lm
make test                         # 191 SHA-256 round-trips (plain, reference, level, state, blocks)
sh scripts/get-data.sh --human    # fetch the exact genomes benchmarked below
make bench                        # bits/base on whatever is in ./data
```

**Windows / PowerShell:**

```powershell
./build.ps1            # compiles dnac.exe (gcc / clang / cl); needs -lm (handled)
./test.ps1             # full demo: generate, compress, verify round-trip, vs zip

# manual use
./dnac.exe gen sample.fa 2000000        # make a structured sample
./dnac.exe c  sample.fa  out.dnac 22    # compress (k = max model order, default 22)
./dnac.exe c  sample.fa  out.dnac 22 1  # ...at level 1 (fast); 3 = max, the default
./dnac.exe c  sample.fa  out.dnac 22 -j 8   # 8 independent blocks (see below)
./dnac.exe d  out.dnac   back.fa        # decompress (the level travels in the header)

# reference-based (the same reference is required to decompress)
./dnac.exe cr target.fa out.dnac reference.fa 22      # add a level: ... 22 1
./dnac.exe dr out.dnac  back.fa   reference.fa
./dnac.exe prime reference.fa reference.state 22  # pay the priming pass once
./dnac.exe cr target.fa out.dnac reference.state  # ...then reuse it
./dnac.exe mut genome.fa individual.fa 1.0 42     # simulate a resequenced genome

# measurement
./bench.ps1 -Exe .\dnac.exe -File .\chr21.fa -K 22   # round-trip + bits/base
./bench.ps1 ... -Fast                                # compress only (param sweeps)
./adversarial.ps1 -Exe .\dnac.exe                    # 144 losslessness round-trips
```

No compiler yet? `build.ps1` prints install options; **w64devkit** is the
quickest (one zip, has gcc). Higher `k` = deeper models = better but more memory
and time (chr21 at k=22 is ~5 s/Mbase round-trip, ~800 MB peak; hash tables are
sized from the input, so small files stay small).

Try a **real** genome: download a `.fa` from NCBI/Ensembl and
`./dnac.exe c real.fa real.dnac 20`.

## Files

- `dnac.c` — everything: range coder, binary coder, flag/literal models,
  order-model ensemble, two forward + one reverse-complement match model,
  logistic mixer, 2-stage SSE/APM, compress/decompress, sample generator.
- `feature_test.c` — standalone entropy experiment (the "orientation lens" test).
- `build.ps1`, `test.ps1` — Windows build & demo.
- `bench.ps1` — round-trip + bits/base for one build on one file (`-Fast` to
  compress only, for parameter sweeps).
- `adversarial.ps1` — 144 SHA-256-verified round-trips: 10 nasty inputs × 6
  values of `k`, × 3 compression levels, plus reference mode (unrelated/short/
  messy references, primed state files, FASTA↔state interchange) and the
  refusals: the wrong reference, and a state file from an older dnac.
  `scripts/roundtrip.sh` is the POSIX port CI runs and adds 5 more checks (an
  out-of-range level, the reference path at every level, and a state/stream
  level mismatch) for 149.
- `Makefile`, `scripts/*.sh` — the same build, losslessness and benchmark paths
  for Linux/macOS/WSL, plus `scripts/get-data.sh` which fetches the exact
  sequences the tables above were measured on, by accession.
- `docs/negative-results.md` — what was measured and rejected, including the
  test showing the reference-mode advantage does **not** transfer outside DNA.
- `.github/workflows/ci.yml` — every push builds on gcc and clang, Linux and
  macOS, and must pass all 191 round-trips, plus a cross-build portability check
  that compresses with one table geometry and decodes with another.
- `README.md` — this file.

## Where the remaining (small, hard) gains are

We're at the practical ceiling of this complexity class. The remaining levers are
incremental: multiple match candidates per hash bucket, checksummed hash slots so
high-order contexts stop blending on collision, a third anchor length, and
automated hyperparameter search (the parameter space is now big enough that
hand-tuning is the bottleneck — the frontier tools use a genetic algorithm for
exactly this). Going *substantially* below ~1.55 bits/base reference-free needs
heavier machinery (neural mixing, 2-pass) — a different complexity class. A
genuinely different game is **reference-based** compression (store a genome as
differences from a known reference), which reaches ~0.01–0.1 bits/base but solves
a different problem and needs the reference.

## The one principle

Judge every idea by a single question: *after this, is the next base easier to
predict?* If yes, it may help — measure it. If it only relabels what we already
know, it's cosmetic. That question, plus a SHA-256 round-trip, governed every
line here.

## Status and scope

This is a working codec, not a maintained product. It is lossless on arbitrary
input and the results above are reproducible from this repository, but there is
no stable file-format guarantee across versions: the header magic is bumped
whenever the bitstream changes. Compression levels (v0.2.0) bumped it from
`DNCA`/`DNCR` to `DNCB`/`DNCS`, storing the table geometry (v0.3.0) bumped it
again to `DNCC`/`DNCT`, and sticky reference anchors (v0.4.0) moved the reference
magic to `DNCU` — plain streams are unaffected by that change, so `DNCC` stayed
put. Older archives are refused with an explicit message
rather than misread. Reference mode additionally requires the exact same
reference, which it verifies by fingerprint and refuses when wrong.

Since v0.3.0 an archive is **no longer tied to the build that wrote it**. The
hash-table geometry used to be recomputed by the decoder from the compile-time
caps, which quietly made `-DHASHBITS_MAX` part of the format: a build with a
different cap decoded the same file to different bytes and reported success.
The geometry now travels in the header, so any build reads any archive — and CI
proves it by compressing with one geometry and decoding with another.

**Nor is it tied to the compiler's floating-point codegen**, which is the other
way a context-mixing codec can quietly become non-portable: the models are
predicted with doubles, and if two builds round differently the decoder rebuilds
a different probability and the stream desynchronises. (GeCo3 ships with exactly
this warning — that its files "might not decompress with a binary compressed in
a different computer or with a different compiler version or options".) Measured
here on 2026-08-19, same source, three floating-point configurations of gcc —
default SSE2, `-mfpmath=387` (x87 80-bit intermediates) and
`-march=native -ffp-contract=fast` (FMA): **byte-identical archives** on a
4.6 Mbp genome in both plain and reference mode, and every cross-decode lossless
(27 combinations at 400 kbases across three levels, 9 more in reference mode at
full scale). The reason is that every probability is quantized to 14 bits before
it reaches the range coder, so differences far below that vanish rather than
accumulating. CI additionally cross-decodes gcc-built and clang-built archives
in both directions.

Compression is symmetric: decompression costs roughly the same as compression
(E. coli: 10.4 s vs 10.7 s). That is inherent to context mixing — the decoder
must rebuild the identical probability for every bit before it can read it, so
it runs the whole model too. It is a real disadvantage against LZ-family tools,
where the expensive part is the *search* and only the encoder pays it. It is not
a disadvantage against GeCo3, whose own documentation states the same property.

## Licence

GPL-3.0-or-later — see [LICENSE](LICENSE). Copyright is held by the author, so
commercial licensing on different terms is available on request.

If you use this in academic work, citation metadata is in
[CITATION.cff](CITATION.cff).
