#!/usr/bin/env python3
"""Experiment B (docs/after-090-prediction.md): does a slip keep its sign?

Reads the TSV a -DDNAC_CUEPROF build writes (pos, shift, tied) and reports, for
each file, the statistics the prediction named -- all of them on NON-TIED loads
only, and every one against an independence baseline computed from that run's
own marginal rather than against 50%.

Why: the cue's search tries -a before +a at every distance, so whenever both
signs would have matched, the negative one wins. That alone makes consecutive
signs agree more often than chance, with no biology in it. Dropping tied loads
removes the artifact at the source; the baseline catches whatever is left.

    python scripts/cue/after090-momentum.py <label>=<file.tsv> ...
"""
import sys


def load(path):
    rows = []
    with open(path, encoding="utf-8") as fh:
        head = fh.readline()
        if not head.startswith("pos"):
            raise SystemExit("%s: not a cue-profile file" % path)
        for line in fh:
            parts = line.split()
            if len(parts) != 3:
                continue
            rows.append((int(parts[0]), int(parts[1]), int(parts[2])))
    return rows


def stats(rows):
    n_all = len(rows)
    neg_all = sum(1 for _, s, _ in rows if s < 0)
    untied = [s for _, s, t in rows if not t]
    n = len(untied)
    if n < 2:
        return None
    neg = sum(1 for s in untied if s < 0)
    p = neg / n                                  # marginal, non-tied
    same = sum(1 for a, b in zip(untied, untied[1:]) if (a < 0) == (b < 0))
    pairs = n - 1
    obs = same / pairs
    base = p * p + (1 - p) * (1 - p)             # what independence would give
    return {
        "n_all": n_all,
        "neg_all": neg_all / n_all if n_all else 0.0,
        "n": n,
        "tied_frac": 1 - n / n_all if n_all else 0.0,
        "p_neg": p,
        "obs": obs,
        "base": base,
        "excess": (obs - base) * 100.0,          # percentage points
        "mean_abs": sum(abs(s) for s in untied) / n,
    }


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    print("%-16s %8s %7s %9s %8s %9s %9s %9s %8s" % (
        "file", "loads", "tied", "P(neg)all", "P(neg)", "P(same)", "baseline",
        "excess", "mean|s|"))
    for arg in argv[1:]:
        label, _, path = arg.partition("=")
        if not path:
            label, path = path or arg, arg
        st = stats(load(path))
        if st is None:
            print("%-16s  too few non-tied loads to say anything" % label)
            continue
        print("%-16s %8d %6.1f%% %9.3f %8.3f %9.3f %9.3f %+8.2f%s %8.2f" % (
            label, st["n_all"], st["tied_frac"] * 100, st["neg_all"], st["p_neg"],
            st["obs"], st["base"], st["excess"], "pp", st["mean_abs"]))


if __name__ == "__main__":
    main(sys.argv)
