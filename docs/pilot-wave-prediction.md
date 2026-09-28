# Pilot-wave step 2 -- pre-registration (written 2026-09-26, before any run)

Question: does the master anchor (mi==0, 13-mer) sit where the STATIC field puts
it (the most recent previous occurrence of the current 13-mer = a fresh hash
lookup), or does its path memory carry it elsewhere -- and when it does, is the
memory right?

Instrument: scratch copy of dnac.c, counters only, archive must be byte-identical
to the release build (checked with cmp) and must round-trip.
At each base, when master active && mlen>0 && fresh candidate exists:
  agree  = (anchor source == fresh source)
  on disagreement: which of seq[anchor], seq[fresh] equals the next base.
Also lag histograms (log2 bins) A (anchor) and R (fresh); TV distance.
Files: ecoli.fa, chr21_slice.fa, level 3, k 22.

Predictions:
P1  agreement: E. coli >= 80%; chr21_slice between 30% and 70%.
P2  on disagreements the ANCHOR hits more often than the fresh source, both files.
P3  TV(A,R) over log2-lag bins < 0.10 on both files.

Decision rule (fixed now):
- P2 holds  -> path memory is real and ALREADY exploited (the codec's
  "do not re-anchor on every miss" rule, measured long ago). The memory row of
  the pilot-wave table is a relabel. Step 2 closes with no new mechanism.
- P2 fails on either file (fresh beats anchor on disagreements) -> a candidate
  mechanism exists (consult the fresh field on disagreement); it gets its own
  pre-registration with a size bar before anything is built.
- P1/P3 describe the geometry only; they decide nothing on their own.
