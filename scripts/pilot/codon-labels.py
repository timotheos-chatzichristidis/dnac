#!/usr/bin/env python3
"""docs/codon-oracle-prediction.md: per-base phase labels aligned to dnac's history.
  python codon-labels.py <genome.fa> <features.ft> <out-prefix>
Writes <out>.lab (true), <out>.shf (control: c -> c+1 mod 3) and <out>.seq (0..3 per
base, header bases included) and prints coverage."""
import sys
import numpy as np

CODE = np.full(256, 255, dtype=np.uint8)
for i, ch in enumerate(b"ACGT"): CODE[ch] = i; CODE[ch + 32] = i

def parse_ft(path):
    cds, cur = [], None
    for line in open(path):
        f = line.rstrip("\n").split("\t")
        if len(f) >= 2 and f[0] and f[1] and f[0][0] in "<>0123456789":
            a, b = int(f[0].lstrip("<>")), int(f[1].lstrip("<>"))
            if len(f) >= 3 and f[2]:
                cur = [(a, b)] if f[2] == "CDS" else None
                if cur is not None: cds.append(cur)
            elif cur is not None:
                cur.append((a, b))                       # join continuation
        elif len(f) >= 3 and f[2] and not f[0]:
            pass
    return cds

def main(fa, ft, out):
    lines = open(fa, "rb").read().split(b"\n")
    assert lines[0].startswith(b">") and sum(l.startswith(b">") for l in lines) == 1
    hdr = np.frombuffer(lines[0], dtype=np.uint8)
    hb = CODE[hdr][np.isin(hdr, np.frombuffer(b"ACGT", dtype=np.uint8))]
    body = CODE[np.frombuffer(b"".join(l.strip() for l in lines[1:]), dtype=np.uint8)]
    assert (body == 255).sum() == 0, "genome has non-ACGT bases; coordinates would need mapping"
    n = len(body); lab = np.full(n, 6, dtype=np.uint8); over = 0; ncds = 0
    for segs in parse_ft(ft):
        ncds += 1; k = 0
        for a, b in segs:
            if a <= b:   xs, base = np.arange(a - 1, b), 0
            else:        xs, base = np.arange(a - 1, b - 2, -1), 3
            c = (k + np.arange(len(xs))) % 3; k += len(xs)
            free = lab[xs] == 6; over += int((~free).sum())
            lab[xs[free]] = base + c[free]
    # controls (docs/codon-oracle-control-prediction.md)
    nph = np.where(lab < 3, 0, np.where(lab < 6, 3, 6)).astype(np.uint8)
    rrt = lab.copy(); rng = np.random.default_rng(20260927)
    gid = np.full(n, -1, dtype=np.int64)
    for gi, segs in enumerate(parse_ft(ft)):
        for a, b in segs:
            lo, hi = (a - 1, b) if a <= b else (b - 1, a)
            sel = np.arange(lo, hi); gid[sel[gid[sel] < 0]] = gi
    rot = rng.integers(0, 3, size=gid.max() + 2)
    m2 = (rrt < 6) & (gid >= 0)
    rrt[m2] = (rrt[m2] // 3) * 3 + (rrt[m2] % 3 + rot[gid[m2]]) % 3
    shf = lab.copy(); m = shf < 6
    shf[m] = (shf[m] // 3) * 3 + (shf[m] % 3 + 1) % 3
    pre = np.full(len(hb), 6, dtype=np.uint8)
    np.concatenate((pre, lab)).tofile(out + ".lab")
    np.concatenate((pre, shf)).tofile(out + ".shf")
    np.concatenate((pre, nph)).tofile(out + ".nph")
    np.concatenate((pre, rrt)).tofile(out + ".rrt")
    print("  randrot: %.1f%% of coding bases moved" % (100 * (rrt != lab)[lab < 6].mean()))
    np.concatenate((hb, body)).astype(np.uint8).tofile(out + ".seq")
    print("%s: %d bases (+%d header bases), %d CDS, coding %.1f%% (+ %.1f%%, - %.1f%%), overlap bases %d"
          % (out, n, len(hb), ncds, 100 * (lab < 6).mean(), 100 * (lab < 3).mean(),
             100 * ((lab >= 3) & (lab < 6)).mean(), over))

if __name__ == "__main__":
    main(*sys.argv[1:4])
