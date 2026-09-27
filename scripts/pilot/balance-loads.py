#!/usr/bin/env python3
"""docs/balance-loads-prediction.md. Usage:
  python balance-loads.py <chain.gz> <chrom> <prof.tsv> <refn>"""
import gzip, sys, bisect
import numpy as np

def indels_q(path, chrom):
    best, cur = None, None
    with gzip.open(path, "rt") as fh:
        for line in fh:
            f = line.split()
            if not f: continue
            if f[0] == "chain":
                cur = None
                if f[2] == chrom and f[7] == chrom and f[4] == "+" and f[9] == "+":
                    cur = {"s": int(f[1]), "q": int(f[10]), "b": []}
                    if best is None or cur["s"] > best["s"]: best = cur
                continue
            if cur is not None: cur["b"].append(tuple(map(int, f)))
    q, out = best["q"], []
    for b in best["b"]:
        q += b[0]
        if len(b) == 3:
            dt, dq = b[1], b[2]
            if (dq == 0 and 1 <= dt <= 50) or (dt == 0 and 1 <= dq <= 50): out.append(q)
            q += dq
    return sorted(out)

def excess(pairs):
    if len(pairs) < 50: return len(pairs), float("nan")
    a = np.array([x < 0 for x, _ in pairs]); b = np.array([y < 0 for _, y in pairs])
    pa, pb = a.mean(), b.mean()
    return len(pairs), (np.mean(a == b) - (pa * pb + (1 - pa) * (1 - pb))) * 100

def main(chain, chrom, tsv, refn):
    ev = indels_q(chain, chrom); refn = int(refn)
    rows = [tuple(map(int, l.split())) for l in open(tsv).read().splitlines()[1:] if l]
    u = [(p - refn, s) for p, s, t in rows if not t]
    def at(o):
        i = bisect.bisect_left(ev, o - 20)
        return i < len(ev) and ev[i] <= o + 20
    f = [at(o) for o, _ in u]
    ii = [(u[i][1], u[i + 1][1]) for i in range(len(u) - 1) if f[i] and f[i + 1]]
    nn = [(u[i][1], u[i + 1][1]) for i in range(len(u) - 1) if not f[i] and not f[i + 1]]
    print("%s: chain indels %d, loads %d, at an indel %.1f%%" % (chrom, len(ev), len(u), 100 * np.mean(f)))
    print("  indel-indel   n=%7d excess %+6.2fpp" % excess(ii))
    print("  neither       n=%7d excess %+6.2fpp" % excess(nn))

if __name__ == "__main__":
    main(*sys.argv[1:5])
