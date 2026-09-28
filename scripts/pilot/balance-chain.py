#!/usr/bin/env python3
"""docs/balance-chain-prediction.md: indel-sign alternation and restoring force
from a UCSC chain (codec-free). Usage:
  python scripts/pilot/balance-chain.py <hg38ToHs1.over.chain.gz> chr21 chr22"""
import gzip, sys
import numpy as np

LAGS = [100, 1000, 10000, 100000, 1000000]

def best_chain(path, chrom):
    best, cur = None, None
    with gzip.open(path, "rt") as fh:
        for line in fh:
            f = line.split()
            if not f:
                continue
            if f[0] == "chain":
                cur = None
                if f[2] == chrom and f[7] == chrom and f[4] == "+" and f[9] == "+":
                    cur = {"score": int(f[1]), "t": int(f[5]), "blocks": []}
                    if best is None or cur["score"] > best["score"]:
                        best = cur
                continue
            if cur is not None:
                cur["blocks"].append(tuple(map(int, f)))
    return best

def events(ch):
    t, ev, other = ch["t"], [], 0
    for b in ch["blocks"]:
        t += b[0]
        if len(b) == 3:
            dt, dq = b[1], b[2]
            if dq == 0 and 1 <= dt <= 50: ev.append((t, -dt))      # GRCh38 bases absent in CHM13
            elif dt == 0 and 1 <= dq <= 50: ev.append((t, dq))     # CHM13 insertion
            else: other += 1
            t += dt
    return np.array(ev), other

def excess(sa, sb):
    a, b = sa < 0, sb < 0
    obs = np.mean(a == b); pa, pb = a.mean(), b.mean()
    return len(a), (obs - (pa * pb + (1 - pa) * (1 - pb))) * 100

def dvar(pos, val, lo, hi, L):
    cum = np.concatenate(([0], np.cumsum(val)))
    x = np.arange(lo, hi - L, max(L // 4, 250))
    X = lambda q: cum[np.searchsorted(pos, q, side="right")]
    d = X(x + L) - X(x)
    return np.mean(d.astype(float) ** 2)

def main(path, chroms):
    rng = np.random.default_rng(20260926)
    for c in chroms:
        ch = best_chain(path, c); ev, other = events(ch)
        pos, val = ev[:, 0], ev[:, 1]; s = np.sign(val)
        gap = np.diff(pos)
        print("%s: best chain score %d, %d blocks, simple indels 1-50bp: %d (ins %d / del %d), other gaps %d"
              % (c, ch["score"], len(ch["blocks"]), len(ev), (s > 0).sum(), (s < 0).sum(), other))
        for lab, m in (("all", gap >= 0), ("near<100", gap < 100), ("far>=1000", gap >= 1000)):
            n, e = excess(s[:-1][m], s[1:][m]); print("  A %-10s n=%7d excess %+6.2fpp" % (lab, n, e))
        near = gap < 100
        eq = np.mean((s[:-1] != s[1:])[near] & (np.abs(val[:-1]) == np.abs(val[1:]))[near])
        print("  near pairs that are an exact undo (opposite sign, equal size): %.2f%%" % (100 * eq))
        lo, hi = pos.min(), pos.max()
        for L in LAGS:
            o = dvar(pos, val, lo, hi, L)
            sh = np.mean([dvar(pos, rng.permutation(s) * np.abs(val), lo, hi, L) for _ in range(20)])
            print("  B L=%-8d R=%.4f" % (L, o / sh))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
