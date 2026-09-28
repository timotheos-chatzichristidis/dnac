#!/usr/bin/env python3
"""docs/codon-gate-prediction.md: G = mean MI at lags 3,6,9,12 / mean MI at 4,5,7,8,10,11.
  python codon-gate.py <fasta>..."""
import sys
import numpy as np
C = np.full(256, 255, np.uint8)
for i, ch in enumerate(b"ACGT"): C[ch] = i; C[ch + 32] = i
def mi(s, d):
    a, b = s[:-d].astype(np.int64), s[d:].astype(np.int64)
    j = np.bincount(a * 4 + b, minlength=16).reshape(4, 4) / len(a)
    pa, pb = j.sum(1), j.sum(0); m = j > 0
    return float((j[m] * np.log2(j[m] / np.outer(pa, pb)[m])).sum())
for p in sys.argv[1:]:
    b = np.frombuffer(b"".join(l.strip() for l in open(p, "rb") if not l.startswith(b">")), np.uint8)
    s = C[b]; s = s[s != 255]
    on = np.mean([mi(s, d) for d in (3, 6, 9, 12)]); off = np.mean([mi(s, d) for d in (4, 5, 7, 8, 10, 11)])
    G = on / off
    print("%-40s G = %.12f  -> tracker %s" % (p, G, "ON" if G >= 2.0 else "OFF"))
