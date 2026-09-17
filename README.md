# dnac — a lossless DNA compressor

A single-file lossless DNA compressor in C: a context-mixing codec over a binary
decomposition of `{A,C,G,T}`, with substitution-tolerant forward and
reverse-complement match models, a two-layer logistic mixer, chained SSE/APM
stages, a range coder, and an optional reference mode. On the sequences measured
here it compresses real genomes below **GeCo3**, the current open-source state of
the art, in both reference-free and reference-based modes.

**v0.9.0 adds one new mechanism, [the cue](#the-cue--the-one-new-mechanism-in-v090).**
When the match model loses its place — which is what an insertion or a deletion
does to it — a second match is loaded at a shifted phase and kept permanently in
the mixer, the way a DJ keeps one ear in the headphones. Losing your place now
costs 26.9 bits instead of 48.25, and a real human chromosome coded against
another person's is **6.75% smaller** (19.36% on the sequence they share). The
idea is not from the compression literature; it is Timotheos's own beatmatching
method, and [`docs/origin.md`](docs/origin.md) records how it arrived.

No dependencies beyond libc. Builds clean with `-Wall -Wextra` on gcc and clang.
Every design decision was a falsifiable experiment on real genomes — kept when
the measurement rewarded it, reverted when it did not. What the measurement
*rejected* is written down as well, in
[docs/negative-results.md](docs/negative-results.md).

**Read [Where this loses](#where-this-loses) alongside the results below.** It is
@@METAX@@x smaller than `zstd -19` on data with no reference and **635x slower to
decompress**; on aligned reads CRAM wins on structure, because an aligner hands it
each read's position for free; its reference mode saturates at about chromosome
scale; and the new reference-mode default is **9.84% worse than v0.8.0 on the
tightest bacterial pair**, which one argument fixes. Those figures are measured
to the same standard as the winning ones.

## Results (real genomes, bits per ACGT base — lower is better)

All three rows are the same two FASTA files, and bits/base counts only the
`ACGT` bases (the `N` gaps, headers and newlines are stored losslessly and
excluded from the denominator).

| method                         | human chr21 | E. coli | notes |
|--------------------------------|:-----------:|:-------:|-------|
| naive 2-bit packing            | 2.000       | 2.000   | no modelling |
| gzip `-9`                      | 2.2544      | 2.3769  | barely models DNA |
| **dnac** (k=22, default)       | **1.5447**   | **1.8845** | this project |

*(The E. coli cell read 1.883 until v0.9.0. That is the figure for the plain
ACGT `.seq` file, in a table whose note said "on the FASTA files" — a cell no
row covered, found when Batch 5 gave every cell one. The `zip` row went the
same way: it is `gzip -9` now, because `gzip -9` is a command this repository
can re-run and a zip made on a Windows desktop in 2026 is not.)*

## The cue — the one new mechanism in v0.9.0

A match model is a needle on an earlier copy of the sequence. A substitution
makes it wrong about one base. An **insertion or a deletion makes it wrong about
where it is**, and every base after that is out of phase — which is why one
extra letter between two human genomes used to cost more than three
substitutions put together (48.25 bits against 14.64). Until v0.9.0 the codec handled that the only way it knew: keep
playing out of time until confidence collapsed, then re-anchor from a fresh hash
lookup, throwing away the alignment it had.

The cue is the other answer. When a match that was established (four bases or
more) misses, dnac looks a few positions either side of where the needle is
(±12) for a place where the last three bases agree, and loads that **shifted
phase into a second, permanent match**. The cue does not take over when it is
loaded: it is an extra input to the mixer from that moment, and the mixer learns
online how far to trust it. Only once the cue has kept agreeing for twelve bases
does a master match that is still missing, and is less sure than the cue, move
to its position. One ear stays on the room, one stays in the headphones, and the
headphones never come off.

That last sentence is not a metaphor added afterwards. The mechanism is
Timotheos's DJ beatmatching method translated line for line — including the
details that carried the gain, which were his and not the obvious ones
(*permanently* one ear in and one out, never both; the cue heard *through* the
room). [`docs/origin.md`](docs/origin.md) records how it arose, including that
the assistant holding the idea filed it under existing frames twice before
building it. It is not in paq8px, GeCo3 or JARVIS3
([`docs/cue-prior-art.md`](docs/cue-prior-art.md)).

### What it costs to lose your place, before and after

Ten controlled targets: a 4.6 Mbase E. coli genome with 1,000 events of one kind
injected, coded against the unmodified genome. Bits per event is
`(target − control) × 8 / 2000`, the mean of three seeds, at level 3.

| event | v0.8.0 | v0.9.0 | |
|---|---:|---:|---|
| substitution | 14.64 bits | 14.75 bits | unchanged, as it must be — the cue is for phase, not for content |
| **random indel** | 48.25 bits | **26.90 bits** | −44% |
| **slip inside a homopolymer** | 31.43 bits | **11.60 bits** | −63% |

And it *learns* along the file, which is the part of the idea that was least
obvious and easiest to test. The same slip costs 14.76 bits in the first half of
a target and 8.44 in the second — **a fall of 43%** over one genome. Without the
cue the same measurement falls 9%.

### On two real people, at chromosome scale

CHM13 against GRCh38, whole chromosomes as FASTA, default settings. Windows of
1 kb are classed **once**, by what v0.8.0 paid for them, and then summed for
both builds — so the classes cannot move under the comparison.

| | chr21 | chr22 (held out) |
|---|---:|---:|
| v0.8.0, level 3 | 586,615 B | 794,330 B |
| v0.9.0, level 3 | **547,019 B** | **742,177 B** |
| whole file | **−6.75%** | **−6.57%** |
| on *shared* sequence (< 0.2 bits/base) | **−19.36%** | **−16.90%** |
| on diverged sequence (0.2–1.0) | −3.55% | −4.51% |
| on sequence one of them lacks (≥ 1.0) | −0.26% | −0.23% |

chr22 is the held-out set: nothing was ever tuned on it. The gain lives where
the mechanism says it should — on sequence the two people share, where a match
exists to lose the place in — and does not disturb sequence where no match
exists at all.

On simulated data the effect is larger still (a simulated chr21 individual is
**−11.52%**), and on bacteria smaller (a simulated E. coli individual −4.21%,
the diverged O157:H7 pair −0.18%): the cue pays in proportion to how many indels
there are to recover from.

### What it is not worth

**Without a reference it is worth almost nothing** — −0.11% on chr21, −0.005% on
E. coli, at level 3. It is a gain at level 3 on all four datasets tried (chr21,
a 10 MB slice of it, E. coli and a 200 Mbase metagenome), which is why it ships
always on; the mechanism needs a long established match to miss and a shifted
copy of it to exist, and without a reference that is only the file's own
repeats, which are rarer and come later
([`docs/reference-free.md`](docs/reference-free.md)). The README's reference-free
headline is not where this mechanism lives.

It is not free everywhere, and the places it costs are small and worth naming:
**+0.010% on E. coli at level 1** without a reference, **+0.013% at `-j 8`**
(a block is short, so there is less established match to lose), and **3 bytes on
1,060** on the plain-ACGT W3110 pair at level 3 — the one reference-mode case
where it is a loss at all.

It also costs about 3% of encode time, and two ideas that sounded better than
the plain version measured as nothing: alternating the two decks
([`docs/cue-back.md`](docs/cue-back.md)) and one refinement of "hearing the cue
through the room" ([`docs/cue-room.md`](docs/cue-room.md)). Both are written up
as failures, because the gain comes from the cue's *permanence* and not from
those.

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
| human chr21 (40,088,619 bases) | **dnac `-l 3`** (default) | **1.4964** | 88.0 s | 1.24 GB |
| | **dnac `-l 2`** | **1.5023** | 59.2 s | |
| | **dnac `-l 1`** | **1.5048** | **42.3 s** | |
| | GeCo3 `-l 14` | 1.5092 | 127.6 s | |
| | GeCo3 `-l 9` | 1.5177 | 77.6 s | |
| | GeCo3 `-l 16` | *did not finish* | — | 8.4 GB, thrashed |
| chr21 slice (9,836,065 bases) | **dnac `-l 3`** | **1.7105** | 22.1 s | ~0.4 GB |
| | **dnac `-l 1`** | 1.7168 | **10.6 s** | |
| | GeCo3 `-l 16` | 1.7163 | 91.6 s | 8.4 GB |
| | GeCo3 `-l 14` | 1.7195 | 40.2 s | |
| E. coli (4,641,652 bases) | **dnac `-l 3`** | **1.8832** | **10.0 s** | ~0.6 GB |
| | GeCo3 `-l 9` | 1.8903 | 11.4 s | |
| | GeCo3 `-l 16` | 1.8913 | 73.8 s | 8.4 GB |

**On all three datasets dnac has a setting that is at once faster and smaller
than every GeCo3 setting tested.** On E. coli and the chr21 slice that setting is
the default `-l 3`; on the full chromosome `-l 1` beats GeCo3 `-l 9` on both axes
(42.3 s vs 77.6 s, 1.5048 vs 1.5177) while `-l 3` beats `-l 14` on both.

GeCo3's maximum level needs 8.4 GB, which did not fit alongside anything else on
this 16 GB machine for the full chromosome — it spent 7 minutes at 19% CPU
swapping before being stopped. The 10 MB chr21 slice exists in the table so that
`-l 16` gets measured on human sequence at a size where it does fit.

**Reference-based**, with the GeCo3 authors' own reference templates from their
`benchmark/run_ref.sh` (`-rm 20:500:1:35:0.95/3:100:0.95 -rm 13:200:... -lr 0.03
-hs 64`, and the hybrid variant that adds target models):

| pair | dnac (default, `-l 1`) | dnac `-l 3` | GeCo3 ref models | GeCo3 hybrid |
|------|-----:|-----:|-----------------:|-------------:|
| W3110 vs MG1655 (near-identical strains) | 1,280 B | **1,063 B** | 1,404 B | 1,319 B |
| O157:H7 vs MG1655 (diverged strains) | 361,611 B | **360,752 B** | 431,652 B | 365,401 B |

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
- **Reference-based it is ahead on both pairs, at both levels** — but by how
  much depends on the level, and v0.9.0's default is the fast one. At `-l 3` it
  is 1.3% better than their best configuration on the diverged pair and 19.4%
  better on the near-identical one (1,063 bytes against 1,319 for a whole 4.6 Mbp
  genome). At the default those margins are 1.0% and **3.0%**: on a two-kilobyte
  output, what level 1's two-expert mixer gives up eats most of the lead. See
  [Where this loses](#the-new-default-is-984-worse-on-the-tightest-bacterial-pair).
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

## Where this loses

Everything above is where `dnac` wins. This section is where it does not, measured
with the same discipline, because a benchmark table that only reports its author's
victories is an advertisement.

Each figure says how it was obtained, because they were not all obtained the same
way. The metagenome table is round-tripped and re-derivable — `sh
scripts/get-data.sh --meta` fetches the same bytes and `./verify-claims.ps1 -Tier
meta` re-runs it. The reference-scale table is round-tripped but needs a
whole-genome priming pass (2 h 11 m, a 3.88 GB state file), so it is recorded with
its method rather than wired into the registry. The CRAM figure is arithmetic and
is labelled as such.

### The new default is 9.84% worse on the tightest bacterial pair

Since v0.9.0 `dnac cr` picks level 1, because with a reference that is 2.1x
faster than v0.8.0's default *and* 4% smaller on a real human pair. On the one
input where level 1 has nothing to win back, it is simply worse:

| pair, FASTA | v0.8.0 default (`-l 3`) | v0.9.0 default (`-l 1`) | v0.9.0 `-l 3` |
|---|---:|---:|---:|
| **W3110 vs MG1655** (near-identical) | 1,931 B | **2,121 B — +9.84%** | **1,916 B** |
| O157:H7 vs MG1655 (diverged) | 362,666 B | 362,862 B — +0.05% | 362,006 B |

**The remedy is one argument** (`dnac cr target.fa out.dnac ref.fa 22 3`), and at
level 3 v0.9.0 is smaller than v0.8.0 on both pairs. The loss is also 190 bytes:
the percentage is large because a whole 4.6 Mbase genome stores in two
kilobytes, and that is the honest way to read it.

It is worth saying *why*, because the obvious explanation is wrong. It is not
that the output is small: a controlled divergence gradient (`dnac mut` at 0.05,
0.2, 1.0 and 5.0 per-mille against the same reference) costs level 1 only
−0.25%, +0.74%, +1.21% and +1.81% — and at the point whose output lands nearest
W3110's (2,018 bytes against 1,916), **level 1 is 5 bytes smaller, where W3110
is 205 bytes larger**. Nor is it the smaller model set that level 1 drops:
switching level 1's mixer from two experts to level 3's four, and changing
nothing else, gives 1,907 B — the whole gap, and then some. On a simulated E. coli individual the same switch recovers the gap
exactly (12,204 → 12,051, which *is* level 3's size); on the diverged pair only
a fifth of it. **On near-identical pairs the cost of level 1 is the mixer's
context, not its models.** That fix was priced on the human pair and rejected by
a rule fixed in advance: +21.1% time for −0.52% size ([`docs/batch3.md`](docs/batch3.md)).
It is the first candidate for the next release, and it is recorded here rather
than in a drawer.

### The lead over the best competitor is 1.57x at the default, not 1.62x

On the real human pair, plain ACGT, against the best of zstd `--patch-from`,
HRCM and GeCo3's own reference templates, v0.9.0 is the smallest — but how far
ahead depends on the level, and the default is the fast one:

| | best competitor | v0.9.0 `-l 3` | v0.9.0 default (`-l 1`) |
|---|---:|---:|---:|
| plain ACGT | 877,373 B (GeCo3 hybrid, unverified) | 541,353 B — **1.62x** | 557,497 B — **1.57x** |
| FASTA | 1,438,137 B (HRCM) | 547,019 B — **2.63x** | 563,031 B — **2.55x** |

Level 1 buys 2.1x the speed and gives up about 3% of the size to do it, so the
margin over the field narrows at exactly the setting most people will run.
GeCo3's sizes could not be verified here — its decoder fails on every input
tried — and HRCM drops a trailing empty line, so both are read generously in
their own favour ([`docs/competitors.md`](docs/competitors.md)).

### Against the general-purpose compressors, on data with no reference

Human gut metagenome (ENA `DRR003618`), first 200,000,000 bases. Nobody has a
reference genome for a metagenome, so this is the fair fight: our model against
theirs, no outside information for either side.

| tool | bytes | bits/base | encode | decode |
|------|------:|----------:|-------:|-------:|
| **dnac -l3** | 17,323,036 | **0.6929** | 439.8 s | 417.1 s |
| **dnac -l1** | 17,653,816 | **0.7062** | 187.1 s | 190.6 s |
| xz -9e | 25,072,456 | 1.0029 | 254.0 s | 2.0 s |
| zstd -19 --long=27 | 25,427,359 | 1.0171 | 150.7 s | **0.3 s** |
| bzip2 -9 | 46,527,654 | 1.8611 | 20.0 s | 6.3 s |
| gzip -9 | 49,936,274 | 1.9975 | 126.3 s | 1.8 s |

**1.47x smaller than zstd — a 31% saving, not the 2x that would make anyone
change tools.** Against gzip it is 2.88x, but gzip is not what you would choose
for a new archive.

### Decompression is 635x slower than zstd, and that is structural

`-l1` *encodes* in 187 s against zstd's 151 s — 24% slower, not the orders of
magnitude one might assume. Decoding is the problem: **190.6 s against 0.3 s.**

This does not get optimised away. A context-mixing decoder has to rebuild the
identical model, symbol by symbol, before it can read the next bit, so decode
time equals encode time by construction. At roughly 1 Mbase/s, re-reading a
petabyte of archived sequence is about 31 core-years. The only application where
that is acceptable is cold archive — written once, read almost never — which is
also the application where a 31% saving does not justify an unusual format for
data someone must still be able to read in twenty years.

### Against CRAM, on aligned reads: lost on structure, not on tuning

CRAM is handed each read's position by an aligner and stores only the differences
from the reference. Per 250 bp Illumina read that is roughly 15 bits for a
delta-coded position plus ~0.5 mismatches at ~10 bits each — **on the order of
0.08 bits/base**. `dnac`'s best measured figure on reads, with a reference small
enough to fit its index, is 0.2708; with a whole human genome primed, 1.3253.

*(That 0.08 is arithmetic, not a measurement — samtools does not run on Windows
and this was not executed. It would have to be wrong by more than 10x to change
the conclusion.)*

The gap is structural. Sequencing centres align anyway, because they need the
alignment to find variants, so CRAM gets the position for free. `dnac` searches
for it with a hash table, and the next section is what that search costs.

### Reference mode saturates at about chromosome scale

The anchor tables hold 2^26 buckets with one position each. chr21 has 40.1M
positions — 0.60 per bucket, essentially collision-free. A whole human genome has
2.95G — **43.9 per bucket**, so almost every anchor is overwritten. The same reads,
against three references:

| reference | bits/base |
|-----------|----------:|
| none | 1.1270 |
| chr21 alone (40 Mbp) | **0.2708** |
| whole GRCh38 (2.95 Gbp) | **0.8639** |

Giving the codec 73x more reference — a reference that strictly *contains* the
chr21 that worked — made it 3.2x worse. The content is there; the index cannot
reach it. Lifting that needs 2^30–2^32 anchor buckets, which is 8–34 GB of tables
plus 2.95 GB of history: a server, not a laptop.

### Compression-as-classifier already exists

A model that predicts DNA well also scores *how well a given reference explains a
sample*, which is a classifier. That is **FALCON2** (Pratas & Pinho — the GeCo
authors), published in *Bioinformatics* in 2026, and it already reports the result
this codec would have been tested for: on short, damaged reads it reaches 0.968
AUPRC where Kraken2 reaches 0.184.

Our own numbers say the idea would not transfer here anyway. Against GeCo3's
reference templates we are 19.4% ahead on the near-identical pair and **1.3%
ahead on the diverged pair** at `-l 3` (3.0% and 1.0% at the default) — and the
diverged case is the one classification needs help with. The cue did not change
that: it earns where a match exists to lose the place in, which is precisely the
near-identical case that was already easy. Separation between a right and a wrong
reference is set by biology, not by the last 1% of modelling: a better
compressor is not a better classifier.

## Compression levels

Most of the codec's time goes into models that earn very little. Measured by
ablation on the 10 MB chr21 slice, inverted-repeat training costs **13%** of the
run and the substitution-tolerant context models cost **19%**, while together
they are worth 0.291% of compressed size. Four levels expose that trade, listed
here fastest first — **the numbers are model-set identifiers, not a quality
ladder**, and level 4 is deliberately not "better than 3":

| level | models | time | bits/base | vs max |
|:-----:|--------|-----:|----------:|--------|
| 1 `fast` | 6 orders, 2 mixing experts, no IR, no tolerant models | 10.6 s | 1.7180 | 2.0× faster, +0.369% size |
| 2 `balanced` | all orders, 4 experts, no IR, no tolerant models | 14.6 s | 1.7166 | 1.4× faster, +0.292% |
| 4 `light` | 8 orders, 4 experts, IR, no tolerant models | 16.1 s | 1.7137 | 1.3× faster, +0.121%, **−31% RAM** |
| 3 `max` (default without a reference) | everything | 20.8 s | 1.7116 | — |

**Since v0.9.0 the default is per mode: level 3 without a reference, level 1
with one.** That is not a preference, it is where the measurement pointed and
the two modes pointed in opposite directions. Reference-free, level 1 costs
+0.46% against level 3 and the cue does not win it back — against a 0.85% margin
over GeCo3, that is most of the margin, so level 3 stays. With a reference the
cue does its work at level 1 and keeps it: the pair is 2.1x faster than v0.8.0's
default *and* 4.02% smaller, which is a setting that is better on both axes at
once ([`docs/reference-free.md`](docs/reference-free.md)). Where that default
loses is stated in [Where this loses](#where-this-loses), not buried here.

All four timed back to back in one session, minimum of three runs. The level
byte travels in the header, so `4` had to be a new value rather than a redefined
`3`: changing what an existing level means would make every archive already
written at that level decode to wrong bytes with exit 0. Levels 1–3 are
byte-identical before and after level 4 was added, and a decoder that predates it
refuses it by name.

```sh
dnac c in.fa out.dnac 22 1     # k=22, level 1
dnac c in.fa out.dnac 22 4     # level 4: a third less memory, 1.3x faster
dnac d out.dnac back.fa        # no level needed: it is in the header
```

**Level 4 is the memory setting.** It is level 3 minus the two tolerant models
and minus orders 3 and 18 — the two the correlation matrix showed to be nearly
redundant (order 18 correlates 0.91 with order 22; order 3 sits between orders 2
and 4). That is 11 prediction inputs instead of 15 and, more usefully, three
hashed tables instead of six. Measured peak resident set, not computed:

| dataset | RAM `-l 3` | RAM `-l 4` | bits/base `-l 4` | size cost |
|---|---:|---:|---:|---:|
| chr21, 40 Mbp | @@RAMC21L3@@ MB | **@@RAMC21L4@@ MB** | 1.5003 | +0.266% |
| E. coli, 4.6 Mbp | 604 MB | **508 MB** | 1.8834 | +0.008% |

The size cost grows with the sequence — +0.008% on a bacterial genome, +0.121% on
a 10 MB slice, +0.270% on a whole chromosome — because the models it drops are
the ones that earn over long range. Against the other memory lever, honestly:
`HASHBITS_MAX 26→25` buys the same −31% for +0.051%, five times cheaper. What it
does not buy is time. Level 4 is a *time* lever whose memory saving is a bonus,
and the two compose.

Those two percentages replace an earlier "~21% each", which was wrong for
inverted-repeat training — most likely measured before `ir_prefetch` was added to
overlap its cache miss, and then only ever re-read, never re-run. They are now
paired measurements: every configuration timed back to back inside one loop,
minimum of three runs, because run-to-run noise on this codec reaches 24% on
identical input for byte-identical output. The size half of the claim, which is
deterministic, has a row in `verify-claims.ps1`; the timings deliberately do not,
for the same reason no other wall-clock figure here does.

### Which of the predictors earns what

*(This table is v0.8.0's model set — 15 mixer inputs. v0.9.0 adds the cue, a
16th, which is not in it: the cue was measured as a mechanism, on the controlled
targets and on real pairs, rather than by leave-one-out. Everything else here
is unchanged by it.)*

`./ablate.ps1` answers the question the round-trip suites structurally cannot:
what any individual model is worth. It zeroes one input inside the mixer — the
input stops contributing *and* stops learning — while leaving table geometry and
memory untouched, which is what separates *"this model is worth nothing"* from
*"this model was crowded out of a smaller table"*.

The full tables for both a bacterial and a human genome are in
[`docs/model-ablation.md`](docs/model-ablation.md). The three findings that
change how the codec should be read:

- **No single order model is worth more than 0.11%**, and four inputs have
  *negative* value — removing them makes the file smaller.
- **The reverse-complement match model is the most valuable single input on human
  sequence** (+0.888% to remove, twice the next one). The cheapest model in the
  codec earns the most.
- **Leave-one-out understates a group by up to 2.4×** on human sequence: the
  mixer reroutes around any one missing input, so the per-input table is not a
  shopping list. Candidate model sets have to be measured as sets.

### `-map` — where the bits actually go

```sh
dnac c chr21.fa out.dnac 22 -map chr21.map.tsv -mapw 1000
```

While compressing, `-map` writes one row per window of `-mapw` bases (default
1000) with what that window cost: `-log2(p)` summed over every bit the coder
wrote. It is a diagnostic for tuning — it reads probabilities the coder computed
anyway and touches no model state, so **the archive is byte-identical with and
without it**, and both round-trip suites check exactly that. Encode only, and it
needs `-j 1`: with several blocks the windows would be filled in whatever order
the threads happen to finish.

The level is stored in the header, not passed to the decoder, because it decides
*which models exist* — it is part of the format, not a hint. A primed state
carries its level too, and decoding a stream with a state primed at a different
level is refused: the reference fingerprint cannot catch that mismatch, since
the reference is the same file and only the model set differs.

Two results worth noting, both the same lesson the rest of this project keeps
teaching: **six order models compress better than eight**, and **two mixing
experts beat four**, at these sizes. More models is not automatically better.

That second one flips with a reference, which is worth knowing before anyone
generalises it. On a near-identical pair at level 1, giving the mixer four
experts instead of two recovers the *whole* difference between level 1 and level
3 (W3110 2,121 → 1,907 B; a simulated E. coli individual 12,204 → 12,051 B,
exactly level 3's size) — while on the diverged pair it recovers a fifth, and on
a real human pair it was priced at +21% time for −0.52% size and turned down.
The mixer's context, not the model set, is what level 1 gives up where the
reference is very close.

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
| 1 (default) | 1,092,635 | — |
| 2 | 1,100,595 | +0.73% |
| 4 | 1,108,139 | +1.42% |
| 8 | 1,116,227 | +2.16% |

What it buys, measured on the full chr21 (40 Mbp) on an 8-core machine:

| `-j` | bytes | encode | decode |
|---:|---:|---:|---:|
| 1 | 7,498,339 | 88.4 s | 88.8 s |
| 2 | 7,687,850 | 50.8 s | 52.3 s |
| 4 | 7,732,528 | 32.0 s | 32.0 s |
| 8 | 7,828,539 | **23.2 s** | **23.5 s** |
| 16 | 7,907,062 | 22.4 s | 22.6 s |

**3.8× on encode and 3.8× on decode at `-j 8`** — the two are the same number,
which is the codec's symmetry showing: a block is independent in both
directions. `-j 16` on 8 cores buys 3% more speed for another 1% of size, which
is not a trade worth making; more blocks than cores has nothing left to give.

On human chr21 the split costs more than on E. coli — +2.53% at N=2 and +4.40% at N=8 —
because long-range repeats (Alu, LINE, satellite) are where its compression comes
from, and a block cannot reach the ones behind it. That is why this is **opt-in
and will stay opt-in**: at 8 blocks chr21 goes to 1.5622 bpb, behind GeCo3's
1.5092, and the whole margin this project has is 0.85%. `-j 1` is the default and
is byte-for-byte identical to a build with no block support at all.

What it costs in memory depends on the size of the file, and the honest answer
has two halves. Tables are sized from the block, so smaller blocks mean smaller
tables — but that sizing is capped at 2^26, and once a block is large enough to
hit the cap it stops shrinking:

| input | `-j 1` | `-j 8` | |
|---|---:|---:|---|
| E. coli, 4.6 Mbp (580 kbase blocks) | 604 MB | 650 MB | 1.08×, effectively flat |
| human chr21, 40 Mbp (5 Mbase blocks) | @@RAMC21J1@@ MB | @@RAMC21J8@@ MB | **@@RAMC21X@@×** |

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
reference is simply fed through them first (see below). **This is the mode the
cue was built for, and since v0.9.0 it defaults to level 1**, which is about
twice as fast as v0.8.0's default and still smaller on everything but the
tightest bacterial pair.

Bits per base of the target, at the default and at `-l 3`:

| target | reference | alone | default (`-l 1`) | `-l 3` | smaller by |
|--------|-----------|:-----:|:-----:|:-----:|:----------:|
| **CHM13 chr21 (a real second person)** | GRCh38 chr21 | 1.390 | **0.0999** | **0.0971** | 14.3× — 547,019 bytes for a chromosome |
| E. coli W3110 (real strain) | E. coli MG1655 | 1.880 | 0.0037 | **0.0033** | **570×** — 1,916 bytes for a 4.6 Mbp genome |
| chr21 of a simulated individual (0.1% SNPs + indels) | chr21 | 1.502 | 0.0203 | **0.0201** | 75× |
| E. coli, simulated individual | E. coli MG1655 | 1.886 | 0.0210 | **0.0208** | 91× |
| E. coli O157:H7 (real, diverged strain) | E. coli MG1655 | 1.812 | 0.5189 | **0.5176** | 3.5× |
| E. coli MG1655 | *human chr21* (unrelated!) | 1.885 | 1.891 | 1.889 | +0.23% (degrades gracefully) |

The gain tracks how related the two sequences are, exactly as it should: nearly
identical strains cost almost nothing, a diverged strain of the same species
costs a third, an unrelated reference costs nothing extra and breaks nothing.
The first row is the one that matters most and is the newest: it is not a
simulation but two real human assemblies, and it is the held-out kind of test —
[the cue section](#the-cue--the-one-new-mechanism-in-v090) has the chromosome 22
replication of it.

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
| E. coli (4.6 Mbp) | 5.9 s | **0.5 s** | — |
| human chr21 (40 Mbp) | 45.2 s | **0.6 s** | 80.6 s → **35.9 s** end-to-end |

(At the level `prime` and `cr` now pick with a reference, which is 1. Level 3
roughly doubles every figure in that table — v0.8.0 measured 98 s to prime chr21
and 188 s → 83 s end-to-end, and that is still what `-l 3` costs.)

A state file and the FASTA it came from are **interchangeable and produce
bit-identical output** (the adversarial suite checks exactly this): you can
compress with one and decompress with the other. Table sizes are therefore
derived from the reference alone, never from the target. The state is a cache in
host byte/float layout — big (481 MB for E. coli and 717 MB for chr21 at the
default level, 616 MB and 1,255 MB at `-l 3`, since it
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
   │  the cue (a shifted phase)  │   • "the match lost its place — here is the
   │                             │     same copy, a few bases over" (v0.9.0)
   │                             │     see The cue, above
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
- **The cue** (v0.9.0) — a *third* match, loaded at a shifted phase when a
  forward match that was established loses its place, and then kept permanently
  as a mixer input rather than replacing anything. Substitution tolerance above
  handles a wrong base; the cue handles a wrong *position*, which is what an
  insertion or a deletion produces. It is the only mechanism here that did not
  come from the compression literature — see [The cue](#the-cue--the-one-new-mechanism-in-v090).
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
  on the W3110/MG1655 pair (plain-ACGT files, 1,088 B -> 1,060 B, as v0.4.0
  measured it), and it costs a diverged target nothing (O157 vs MG1655: +0.01%), because
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
1.5447 + the cue (v0.9.0) — worth almost nothing here, and a great deal
          with a reference: see the section above
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
make test                         # 229 SHA-256 round-trips (plain, reference, level, state, blocks, the cue, v0.8.0 streams)
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
./dnac.exe c  sample.fa  out.dnac 22 1  # ...at level 1 (fast); 3 = max, the default without a reference
./dnac.exe c  sample.fa  out.dnac 22 -j 8   # 8 independent blocks (see below)
./dnac.exe d  out.dnac   back.fa        # decompress (the level travels in the header)

# reference-based (the same reference is required to decompress)
./dnac.exe cr target.fa out.dnac reference.fa 22      # level 1 by default here; add one: ... 22 3
./dnac.exe dr out.dnac  back.fa   reference.fa
./dnac.exe prime reference.fa reference.state 22  # pay the priming pass once (level 1 by default too)
./dnac.exe cr target.fa out.dnac reference.state  # ...then reuse it
./dnac.exe mut genome.fa individual.fa 1.0 42     # simulate a resequenced genome

# measurement
./bench.ps1 -Exe .\dnac.exe -File .\chr21.fa -K 22   # round-trip + bits/base
./bench.ps1 ... -Fast                                # compress only (param sweeps)
./adversarial.ps1 -Exe .\dnac.exe                    # 155 losslessness round-trips
./sweep-tables.ps1 -Macro MHBITS_MAX -Caps 26,25      # table size vs bits/base vs RAM
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
- `adversarial.ps1` — 155 SHA-256-verified round-trips: 10 nasty inputs × 6
  values of `k`, × 4 compression levels, plus reference mode (unrelated/short/
  messy references, primed state files, FASTA↔state interchange), the refusals
  (the wrong reference, a state file from an older dnac) and the check that
  `-map` leaves the compressed bytes byte-identical.
  `scripts/roundtrip.sh` is the POSIX port CI runs; it covers the same ground
  plus an out-of-range level, the reference path at every level, a state/stream
  level mismatch, the block modes, the cue's own cases (indel- and
  homopolymer-dense pairs, target = reference, the default levels, the stream
  families of streams and states) and the stored v0.8.0 streams in `tests/v080`,
  for 229.
- `ablate.ps1` — what each of v0.8.0's 15 prediction inputs is worth
  (`-Mode loo|diag|mask`). Drives `-DDNAC_ABLATE` / `-DDNAC_DIAG` in `dnac.c`:
  the first zeroes an input inside the mixer without touching table geometry, so
  the answer is the value of the *model* rather than of the memory it held; the
  second dumps the correlation matrix between inputs and verifies itself
  byte-identical to a normal build before printing. Every size round-trips
  first. Results in `docs/model-ablation.md`.
- `sweep-tables.ps1` — re-derives the table-size trade-off in `PROGRESS.md` §11
  (`-Macro HASHBITS_MAX|MHBITS_MAX`, `-Caps 26,25,24`). Every point round-trips
  and every archive's header is read back to confirm the geometry actually used.
  Answer: per unit of compression given up, `HASHBITS_MAX` buys 5.4x more memory
  than `MHBITS_MAX`, so the anchor tables keep their headroom and HASHBITS is the
  lever if memory has to come down.
- `Makefile`, `scripts/*.sh` — the same build, losslessness and benchmark paths
  for Linux/macOS/WSL, plus `scripts/get-data.sh` which fetches the exact
  sequences the tables above were measured on, by accession.
- `docs/` — the record of v0.9.0, one document per pre-registered experiment,
  each written *before* the run and scored after: `origin.md` (where the cue came
  from, and the two times it was dismissed), `cue.md`, `cue-room.md`,
  `cue-back.md` (two of his refinements, measured as failures and kept),
  `real-human.md`, `remaining.md`, `competitors.md`, `speed.md`,
  `reference-free.md`, `model-ablation.md`, and `batch1.md` … `batch5.md` for the
  five batches that turned those experiments into a release. `v0.9.0-plan.md`
  holds the five-pass routine every claim had to survive. **The figures in the
  older documents are the parameters they were measured at
  (`CUE_MINLEN=16`); the release re-measured all of them at 4, and that
  re-measurement is `batch4.md`.** Nothing was edited to match.
- `scripts/cue/*.sh` — the runnable form of those experiments: every label
  compiles the source that measured it (`4932ffe`), so a record can be
  re-derived years later without trusting that today's `dnac.c` is the same
  codec.
- `docs/negative-results.md` — six ideas that were built or measured and then
  rejected by the measurement: the reference-mode advantage does **not** transfer
  outside DNA; block boundaries cost 2.5% to enter and **+86%** on high-coverage
  reads; reference mode saturates at chromosome scale; and compression-as-a-
  classifier is already published work whose edge we do not have. Kept because
  knowing where a technique *stops* working is worth as much as knowing where it
  starts.
- `.github/workflows/ci.yml` — every push builds on gcc and clang, Linux and
  macOS, and must pass all 229 round-trips on the release build, the cue
  switched off and an experimental build, plus a cross-build portability check
  that compresses with one table geometry and decodes with another, and a check
  that the cue switched off writes the v0.8.0 tag's bytes.
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

**The one lever v0.9.0 leaves on the table, with its price already measured:**
four mixer experts at level 1 in reference mode. On a near-identical pair that
is the *entire* difference between level 1 and level 3 — and it overshoots it,
landing below both level 3 and v0.8.0 — while the models level 1 drops are worth
nothing there. On the real human pair it was priced at **+21.1% time for −0.52%
size** and a rule fixed in advance turned it down
([`docs/batch3.md`](docs/batch3.md)). Whether *reference mode* should price that
trade differently from the plain mode the rule was written for is the first
question of the next release, and it would remove the one loss this one ships
with.

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

**v0.9.0 turned the fourth letter into a family, and v0.8.0's archives still
decode.** `DNCC`/`DNCU`/`DNCP` (plain / reference / blocks) are v0.8.0's streams
and are read byte-for-byte by this release; `DNCE`/`DNCV`/`DNCQ` are the same
three with the cue; and a **lower-case** letter marks an archive written by an
experimental build — one that moved a cue parameter or a level-1 model knob —
which a release build refuses, and which refuses a release build's files. The cue
is therefore a *run-time* switch read out of the header, not a compile-time one,
and seven v0.8.0 streams are committed in `tests/v080/` so every build is
checked against files it did not write. Primed states carry the same
distinction (`DNACST02` without the cue, `DNACST03` with), because priming runs
the cue and moves the match anchors: a state and a stream from different
families are refused, like a level mismatch.

That design exists because the alternative was measured and it was silent. While
the cue was a compile flag, a `-DDNAC_CUE` archive carried v0.8.0's magic, and
the build without the flag decoded it to **wrong bytes at exit 0** — the same
shape as the v0.3.0 geometry bug, and it would have shipped with a v0.9.0 that
only flipped a default ([`docs/batch4.md`](docs/batch4.md)).

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
