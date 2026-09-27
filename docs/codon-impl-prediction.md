# Codon tracker in dnac.c -- decision and implementation pre-registration

## Decision (Timotheos, 2026-09-27)
**A flag, on by default only at level 1.** At levels 2-4 the tracker runs only when asked
(`-codon`). This follows the rule of docs/codon-speed-prediction.md without re-reading it:
level 1's overhead is <= 10% (+7.8% / +9.0%), levels 2-4 fall in the 10-25% band. A new
level was rejected because the tracker depends on the file's CONTENT, not on which models
exist, and a codon variant of every level would double the level space.

## What gets built (branch `codon-phase`, from `pilot-wave`)
1. **Gate in C:** G = mean MI at lags 3, 6, 9, 12 over mean MI at 4, 5, 7, 8, 10, 11, on the
   file's bases, and the tracker is on if G >= 2.0. It must equal `scripts/pilot/codon-gate.py`
   to within 1e-9 on all five files of docs/codon-gate.md.
2. **Stream letters:** a codon-on stream gets NEW family letters (plain and blocks, with and
   without the case list). An older decoder then refuses it by name instead of misreading
   it. A gate-off stream keeps today's letter and bytes, so every file without codons stays
   **byte-identical to v0.10.0**. The scratch runs' "+1 byte" for gate-off disappears.
3. **Variants:** S1 at level 1 (tracker log table, phase in all orders); S123 at levels 2-4
   (log table, phase in orders <= 11, interleaved direct tables). Both are part of the format.
4. **Scope:** plain mode and `-j` blocks. The tracker state is thread-local and resets per
   block. The gate is computed once per file, on the whole file. **Reference mode (`cr`,
   `dr`, `prime`, state files) never uses the tracker** in this step. It was never tested
   there, so its letters, bytes and state files do not change.
5. **CLI:** `-codon` turns the tracker on for levels 2-4, and `-nocodon` turns it off at
   level 1. Both are encode-only; the decoder reads the letter.

## Checks, all of which must pass before any claim
I1  With the gate off, or in reference mode, the output is byte-identical to v0.10.0 on every
    file in the benchmark set (chr21_slice, chr21, E. coli at L2-4 without the flag, the
    reference pairs, and a soft-masked file).
I2  With the gate on, the archive equals the scratch tracker archive of docs/codon-speed.md
    in every byte after the magic letter (S1 at L1; S123 at L2, L3, L4) on E. coli,
    B. subtilis, P. aeruginosa and S. aureus.
I3  Both round-trip suites (adversarial.ps1, scripts/roundtrip.sh) pass, with new cases: a
    bacterium at each level, with and without the flags, `-j 4`, a soft-masked bacterium
    (case x codon), and a sequence that sits exactly at the gate threshold.
I4  An older build (v0.10.0) refuses a codon stream with a message and a non-zero exit, and
    does not write wrong bytes.
I5  `-DDNAC_NO_THREADS` and the threaded build produce identical archives with `-j`.
I6  verify-claims: every row that turns red is one whose recipe runs plain level 1 on a
    bacterium, and it is re-measured and updated in the same change. Any other red row is a
    bug.
