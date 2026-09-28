# Codon tracker, round 3: a per-file gate -- pre-registration

Written 2026-09-27. Timotheos chose "a third round, gate only" after round 2
(docs/codon-tracker2.md): bacteria pass (2.4558% / held-out 1.6982%), human fails (+0.3323%),
cause a winner's curse among six phase hypotheses on gene-poor sequence.

## The gate (fixed now, before any new genome is fetched)
The encoder decides once per FILE. Statistic G on the file's bases: the mean mutual
information between bases 3, 6, 9 and 12 apart, divided by the mean at 4, 5, 7, 8, 10 and 11
apart. That is how much stronger the codon period is than its neighbours. **The tracker is
on if G >= 2.0.** Figures already seen (docs/pilot-wave.md, 2026-09-27): E. coli ~3.9,
chr21 ~1.1. 2.0 sits between them in ratio terms and was chosen by that reasoning only.
The decision travels as one header byte. In this experiment the gated size is emulated as
(tracker archive if G >= 2.0, else release archive) + 1 byte. Both branches have been shown
to round-trip on their own, and the decision is a deterministic function of the input. A
real implementation is a format change and gets its own pre-registration and full
re-measurement.

## Genomes
- Seen: E. coli MG1655, B. subtilis 168, chr21_slice.fa (human).
- **New, held out, never looked at:** Pseudomonas aeruginosa PAO1 (NC_002516.2, high GC) and
  Staphylococcus aureus NCTC 8325 (NC_007795.1, low GC). They were chosen for their spread in
  GC, and fetched only after this file is committed.
Tracker = round 2's build, unchanged. Plain mode, level 3, k 22, every archive decoded and
compared.

## Predictions
V1  G >= 3.0 on all four bacteria; G <= 1.3 on chr21_slice.
V2  P. aeruginosa gated gain 1.5-3.0%; S. aureus 1.0-2.5%.

## Bar (fixed now)
Gated: E. coli >= 1.5%, B. subtilis >= 1.0%, P. aeruginosa >= 1.0%, S. aureus >= 1.0%, and
chr21_slice no more than +0.1% (the 1 byte included). The gate must switch the tracker ON
for all four bacteria and OFF for human. If everything passes, the codon tracker becomes a
format candidate, and the next steps (implementation of the flag, time cost decision, full
re-measurement, the level question) are pre-registered one by one. If anything fails, the
result is recorded as is.
