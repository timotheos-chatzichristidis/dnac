#!/usr/bin/env python3
"""Build a tumour with an EXACT event count and an exact indel fraction.

`dnac tumor` cannot do this -- its TUM_PROFILES table fixes snv_per_mb and the
slip rate per profile -- and exp-008 needs burden held constant while
composition moves. So this applies the events directly.

Substitutions go to uniformly random distinct positions and change the base to
one of the other three. Indels are single-base, half insertions and half
deletions. Events are applied from the end of the sequence backwards so earlier
coordinates are never shifted.

Two indel contexts:

  random       (exp-008) indels at random positions; an insertion adds a random
               base. Byte-identical to the exp-008 applier -- checked.
  homopolymer  (exp-011) each indel is a slip in a distinct homopolymer run of
               >= 6, as dnamap's msi model defines one: the run gains or loses
               one copy of its own base. Everything else -- which positions are
               substituted and to what, and whether the i-th indel is an
               insertion or a deletion -- is drawn from the same random stream
               as the random context, so each homopolymer tumour is the exact
               twin of its exp-008 tumour except for where the indels sit.
               Runs containing a substituted position are not eligible.

Usage:
  python scripts/make_tumour.py <ref.fa> <out.fa> <truth.tsv> <n_events> <indel_fraction> <seed> [random|homopolymer]
"""
import sys, random, re

MIN_RUN = 6


def plan(seq, n_events, frac, seed):
    """The exp-008 draw, resolved without mutating: identical RNG call order."""
    n = len(seq)
    rng = random.Random(seed)
    n_indel = int(round(n_events * frac))
    n_sub = n_events - n_indel
    pos = rng.sample(range(1000, n - 1000), n_events)
    rng.shuffle(pos)
    subs, indels = sorted(pos[:n_sub]), sorted(pos[n_sub:])
    events = [(p, "SUB") for p in subs] + [(p, "INS" if rng.random() < 0.5 else "DEL")
                                           for p in indels]
    events.sort(key=lambda e: -e[0])
    out = []                                   # (pos, kind, base) back to front
    for p, kind in events:
        if kind == "SUB":
            out.append((p, kind, rng.choice([c for c in "ACGT" if c != chr(seq[p])])))
        elif kind == "INS":
            out.append((p, kind, rng.choice("ACGT")))
        else:
            out.append((p, kind, None))
    return out


def to_homopolymer(seq, events, seed):
    """Keep every substitution; move each indel into its own homopolymer run."""
    subs = [e for e in events if e[1] == "SUB"]
    kinds = [k for p, k, _ in sorted((e for e in events if e[1] != "SUB"))]
    if not kinds:
        return events, []
    sub_pos = sorted(p for p, _, _ in subs)
    s = seq.decode()
    runs = [(m.start(), len(m.group(0))) for m in re.finditer(r"A+|C+|G+|T+", s)
            if len(m.group(0)) >= MIN_RUN and 1000 <= m.start() < len(s) - 1000]
    import bisect
    free = [(a, L) for a, L in runs
            if bisect.bisect_left(sub_pos, a) == bisect.bisect_left(sub_pos, a + L)]
    rng = random.Random(seed * 1_000_003 + 11)  # independent of the exp-008 stream
    chosen = sorted(rng.sample(free, len(kinds)))
    moved = [(a, k, chr(seq[a]) if k == "INS" else None)
             for (a, L), k in zip(chosen, kinds)]
    return sorted(subs + moved, key=lambda e: -e[0]), chosen


def main(ref, out, truth, n_events, frac, seed, context="random"):
    n_events, frac, seed = int(n_events), float(frac), int(seed)
    if context not in ("random", "homopolymer"):
        sys.exit(f"unknown context {context!r}")
    raw = open(ref).read()
    seq = bytearray(raw[raw.index("\n") + 1:].replace("\n", "").upper(), "ascii")
    n = len(seq)
    events = plan(seq, n_events, frac, seed)
    chosen = []
    if context == "homopolymer":
        events, chosen = to_homopolymer(seq, events, seed)
    n_indel = sum(1 for e in events if e[1] != "SUB")
    n_sub = n_events - n_indel

    n_ins = n_del = 0
    for p, kind, base in events:                # already back to front
        if kind == "SUB":
            seq[p] = ord(base)
        elif kind == "INS":
            seq[p:p] = bytes(base, "ascii")
            n_ins += 1
        else:
            del seq[p]
            n_del += 1

    with open(out, "w") as f:
        f.write(f">tumour events={n_events} indel_fraction={frac:g} seed={seed}\n")
        s = seq.decode()
        for i in range(0, len(s), 60):
            f.write(s[i:i + 60] + "\n")

    with open(truth, "w") as f:
        f.write("type\ttgt_start\ttgt_end\tlen\n")
        f.write(f"#events\t{n_events}\n#substitutions\t{n_sub}\n#indels\t{n_indel}\n")
        f.write(f"#insertions\t{n_ins}\n#deletions\t{n_del}\n")
        f.write(f"#indel_fraction\t{frac:g}\n#seed\t{seed}\n")
        f.write(f"#ref_bases\t{n}\n#tumour_bases\t{len(seq)}\n")
        if context == "homopolymer":
            f.write(f"#context\thomopolymer\n")
            kind_at = {p: k for p, k, _ in events if k != "SUB"}
            for a, L in chosen:
                f.write(f"#run\t{kind_at[a]}\t{a}\t{L}\n")
    print(f"events={n_events} sub={n_sub} indel={n_indel} "
          f"(ins {n_ins} / del {n_del})  {n} -> {len(seq)} bases  -> {out}")


if __name__ == "__main__":
    if len(sys.argv) not in (7, 8):
        sys.exit(__doc__)
    main(*sys.argv[1:])
