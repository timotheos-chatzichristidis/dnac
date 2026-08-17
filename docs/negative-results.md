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

The governing question throughout: *after this change, is the next base easier to
predict?* If a transform only relabels what is already known, it is cosmetic — a
transform never reduces information on its own.
