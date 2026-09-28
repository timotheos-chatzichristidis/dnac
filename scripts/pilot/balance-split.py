#!/usr/bin/env python3
"""docs/balance-wave-prediction.md: split the slip-sign alternation by tandem/unique
context and by gap. Usage:
  python scripts/pilot/balance-split.py <label> <prof.tsv> <ref.fa> <target.fa>
The log's positions index ref+target bases as the v0.9.0-era profiling build counted
them (upper-case ACGT only), so both FASTAs are reduced the same way here."""
import sys
import numpy as np

W, RUN, PMAX = 20, 12, 6

def bases(path):
    raw = open(path, "rb").read()
    out, lines = [], raw.split(b"\n")
    for ln in lines:
        if ln.startswith(b">"):
            continue
        out.append(ln)
    b = np.frombuffer(b"".join(out), dtype=np.uint8)
    return b[np.isin(b, np.frombuffer(b"ACGT", dtype=np.uint8))]

def tandem_mask(s):
    n = len(s); cover = np.zeros(n + 1, dtype=np.int32)
    for p in range(1, PMAX + 1):
        eq = np.concatenate(([0], (s[:-p] == s[p:]).astype(np.int8), [0]))
        d = np.diff(eq); st = np.flatnonzero(d == 1); en = np.flatnonzero(d == -1)
        keep = (en - st) >= RUN
        for a, b in zip(st[keep], en[keep]):     # eq run a..b-1 covers bases a..b-1+p
            cover[a] += 1; cover[min(b + p, n)] -= 1
    return np.cumsum(cover)[:n] > 0

def excess(pairs):
    if len(pairs) < 50:
        return len(pairs), float("nan")
    a = np.array([x for x, _ in pairs]) < 0; b = np.array([y for _, y in pairs]) < 0
    obs = np.mean(a == b); pa, pb = a.mean(), b.mean()
    base = pa * pb + (1 - pa) * (1 - pb)
    return len(pairs), (obs - base) * 100

def main(label, tsv, ref, tgt):
    refn = len(bases(ref)); t = bases(tgt); m = tandem_mask(t)
    pre = np.concatenate(([0], np.cumsum(m)))
    rows = [tuple(map(int, l.split())) for l in open(tsv).read().splitlines()[1:] if l]
    untied = [(p, s) for p, s, ti in rows if not ti]
    # T0: exactly the after090-momentum.py statistic
    sg = np.array([s for _, s in untied]) < 0; p = sg.mean()
    t0 = (np.mean(sg[1:] == sg[:-1]) - (p * p + (1 - p) * (1 - p))) * 100
    off = [pp - refn for pp, _ in untied]
    bad = sum(1 for o in off if o < 0 or o >= len(t))
    def cls(o):
        lo, hi = max(0, o - W), min(len(t), o + W + 1)
        return "T" if pre[hi] - pre[lo] > 0 else "U"
    c = [cls(o) for o in off]
    groups = {"unique-unique": [], "tandem-tandem": [], "mixed": [], "near<100": [], "far>=1000": []}
    for i in range(len(untied) - 1):
        pr = (untied[i][1], untied[i + 1][1]); gap = off[i + 1] - off[i]
        k = "unique-unique" if c[i] == c[i + 1] == "U" else "tandem-tandem" if c[i] == c[i + 1] == "T" else "mixed"
        groups[k].append(pr)
        if gap < 100: groups["near<100"].append(pr)
        if gap >= 1000: groups["far>=1000"].append(pr)
    print("%s: refn=%d target=%d loads(untied)=%d out-of-range=%d tandem-loads=%.1f%% target-tandem=%.1f%%"
          % (label, refn, len(t), len(untied), bad, 100 * c.count("T") / len(c), 100 * m.mean()))
    print("  %-14s %9s %+8.2fpp" % ("all (T0)", len(untied) - 1, t0))
    for k, v in groups.items():
        n, e = excess(v); print("  %-14s %9d %+8.2fpp" % (k, n, e))

if __name__ == "__main__":
    main(*sys.argv[1:5])
