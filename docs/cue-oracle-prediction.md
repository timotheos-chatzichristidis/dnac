# The cue's false loads: what would a perfect filter buy? -- pre-registration

Written 2026-09-27, before any run. docs/balance-loads.md found that only 5-7% of cue
loads on the CHM13/GRCh38 pair lie within 20 bases of a real indel (UCSC hg38->hs1 chain).
The other 93-95% are false alarms that the cue later corrects. Before anyone designs a
filter, an ORACLE measures the ceiling: loads are allowed only where the chain says a real
indel is. The oracle is side information that the decoder gets from the same file, so
this is a bound, not a codec. It is a scratch build; `dnac.c` on the branch is untouched
and the patch is committed as `scripts/pilot/cue-oracle.patch`.

## Runs
Reference mode, level 3, k 22: target chm13_chrN.fa, reference grch38_chrN.fa, for chr21
(decides) and chr22 (replication). Every archive is decoded (with the same oracle file)
and compared before its size counts.
- rel      the build from this branch (v0.10.0 source)
- orc-at   the cue may load only within 20 b of a chain indel (target coordinates)
- orc-not  the complement: the cue may load only where there is NO chain indel
Priming is not gated (g_refbase is 0 then), only the target.

## Known context
The cue is worth -6.75% on chr21 at level 3 (586,615 -> 547,019 B, docs/batch4.md).

## Predictions
I0  instrument: rel reproduces 547,019 B (chr21) and 742,177 B (chr22); CHM13 carries no
    lower case, so v0.10.0 must equal v0.9.0 here.
O1  orc-at smaller than rel on chr21 by between 0% and 0.3% (the mixer already discounts
    the false loads, so the ceiling is low).
O2  orc-not larger than rel on chr21 by >= 3% (most of the cue's 6.75% is earned at real indels).

## Decision rule (fixed now)
Build a real false-load filter only if orc-at gains >= 0.6% on chr21 AND >= 0.3% on chr22.
The 0.6% is twice the standing 0.3% adoption bar, because a real filter recovers only part
of an oracle's gain. Otherwise the false-load lever is closed.
One limit stated in advance: orc-at is not a strict upper bound. If some false loads help,
a filter that keeps them could beat it. orc-not measures exactly that, and if it comes out
SMALLER than rel, the rule above is suspended and the result is reported as "false loads
help", with no filter built on that finding alone.
