#!/usr/bin/env python3
"""docs/cue-source-prediction.md. Usage:
  python cue-source.py <label> <loads.tsv> <ref.fa> <target.fa> <chain.gz> <chrom>"""
import gzip, sys
import numpy as np

CODE = np.full(256, 255, dtype=np.uint8)
for i, ch in enumerate(b"ACGT"): CODE[ch] = i; CODE[ch + 32] = i     # lower case is a base since v0.10

def target_bases(path):
    """The target as the codec's history holds it: dnac codes bytes, so upper-case
    A/C/G/T inside a '>' header line are bases too (lower case there are not).
    Returns (codes, number of header bases before the sequence)."""
    lines = open(path, "rb").read().split(b"\n")
    hdr = np.frombuffer(b"".join(l for l in lines if l.startswith(b">")), dtype=np.uint8)
    body = np.frombuffer(b"".join(l.strip() for l in lines if not l.startswith(b">")), dtype=np.uint8)
    hb = CODE[hdr][np.isin(hdr, np.frombuffer(b"ACGT", dtype=np.uint8))]
    assert lines[0].startswith(b">") and sum(l.startswith(b">") for l in lines) == 1
    return np.concatenate((hb, CODE[body])), len(hb)

def raw(path):
    return np.frombuffer(b"".join(l.strip() for l in open(path, "rb") if not l.startswith(b">")), dtype=np.uint8)

def blocks(path, chrom):
    best, cur = None, None
    with gzip.open(path, "rt") as fh:
        for line in fh:
            f = line.split()
            if not f: continue
            if f[0] == "chain":
                cur = None
                if f[2] == chrom and f[7] == chrom and f[4] == "+" and f[9] == "+":
                    cur = {"s": int(f[1]), "t": int(f[5]), "q": int(f[10]), "b": []}
                    if best is None or cur["s"] > best["s"]: best = cur
                continue
            if cur is not None: cur["b"].append(tuple(map(int, f)))
    t, q, out = best["t"], best["q"], []
    for b in best["b"]:
        out.append((q, t, b[0])); q += b[0]; t += b[0]
        if len(b) == 3: t += b[1]; q += b[2]
    return np.array(out)

def excess(a, b):
    if len(a) < 50: return len(a), float("nan")
    a, b = a < 0, b < 0; pa, pb = a.mean(), b.mean()
    return len(a), (np.mean(a == b) - (pa * pb + (1 - pa) * (1 - pb))) * 100

def main(label, tsv, ref, tgt, chain, chrom):
    rr = raw(ref); rc = CODE[rr]
    tc, hdrb = target_bases(tgt)
    isb = rc != 255; refn = int(isb.sum()); idx = np.concatenate(([0], np.cumsum(isb)))
    S = np.concatenate((rc[isb], tc[tc != 255])).astype(np.int16)
    assert (tc == 255).sum() == 0, "target has non-bases; offsets would need mapping"
    L = np.loadtxt(tsv, skiprows=1, dtype=np.int64).reshape(-1, 4)
    pos, sh, tied, mp = L[:, 0], L[:, 1], L[:, 2], L[:, 3]
    # S0
    u = tied == 0; su = sh[u]
    t0 = excess(su[:-1], su[1:])[1]
    # hindsight: best shift over the next 30 bases
    D = np.arange(-12, 13); J = np.arange(30); n = len(pos)
    agree = np.zeros((n, len(D)), dtype=np.int16)
    for k, d in enumerate(D):
        src = mp[:, None] + d + J[None, :]; dst = pos[:, None] + 1 + J[None, :]
        ok = (src >= 0) & (src < len(S)) & (dst < len(S))
        agree[:, k] = np.where(ok, S[np.clip(src, 0, len(S) - 1)] == S[np.clip(dst, 0, len(S) - 1)], False).sum(1)
    mx = agree.max(1); chosen = agree[np.arange(n), sh + 12]
    conf = (chosen == mx) & (mx >= 24)
    # source class
    q3 = mp + sh                                       # instrument check: the 3 bases the cue matched
    back = np.mean((S[q3 - 1] == S[pos]) & (S[q3 - 2] == S[pos - 1]) & (S[q3 - 3] == S[pos - 2]))
    assert back == 1.0, "history misaligned: back-agreement %.4f" % back
    B = blocks(chain, chrom); off = pos - refn - hdrb
    i = np.clip(np.searchsorted(B[:, 0], off, side="right") - 1, 0, len(B) - 1)
    tpos = B[i, 1] + np.minimum(off - B[i, 0], B[i, 2])
    ortho_ref = idx[np.clip(tpos, 0, len(idx) - 1)]
    cls = np.where(mp >= refn, "self", np.where(np.abs(mp - ortho_ref) <= 1000, "ortholog", "paralog"))
    print("%s: refn=%d header bases=%d loads=%d  back-agreement 100%%  S0 excess %+.2fpp" % (label, refn, hdrb, n, t0))
    for c in ("ortholog", "paralog", "self"):
        m = cls == c; print("  class %-8s %5.1f%% of loads, confirmed %5.1f%%" % (c, 100 * m.mean(), 100 * conf[m].mean()))
    print("  confirmed overall %.1f%%" % (100 * conf.mean()))
    cu, su2, clu = conf[u], sh[u], cls[u]
    a, b = su2[:-1], su2[1:]
    both = cu[:-1] & cu[1:]; anyun = ~both
    print("  pairs confirmed-confirmed  n=%7d excess %+6.2fpp" % excess(a[both], b[both]))
    print("  pairs >=1 unconfirmed      n=%7d excess %+6.2fpp" % excess(a[anyun], b[anyun]))
    print("  pairs unconf-unconf        n=%7d excess %+6.2fpp" % excess(a[~cu[:-1] & ~cu[1:]], b[~cu[:-1] & ~cu[1:]]))
    for c in ("ortholog", "paralog", "self"):
        m = (clu[:-1] == c) & (clu[1:] == c)
        print("  pairs %-8s-%-8s     n=%7d excess %+6.2fpp" % ((c, c) + excess(a[m], b[m])))

if __name__ == "__main__":
    main(*sys.argv[1:7])
