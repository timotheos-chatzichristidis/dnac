#!/usr/bin/env python3
"""Tracker labels vs annotation, up to a RENAMING: the tracker is unsupervised, so its
label names are arbitrary. Best one-to-one mapping over all 7! permutations.
  python codon-track-diag.py <true.lab> <tracker.labels>"""
import sys, itertools
import numpy as np
lab = np.fromfile(sys.argv[1], np.uint8); tk = np.fromfile(sys.argv[2], np.uint8)
n = min(len(lab), len(tk)); lab, tk = lab[:n], tk[:n]
M = np.zeros((7, 7), np.int64); np.add.at(M, (tk, lab), 1)
best = max(itertools.permutations(range(7)), key=lambda p: sum(M[i, p[i]] for i in range(7)))
acc = sum(M[i, best[i]] for i in range(7)) / n
mapped = np.array(best)[tk]; cod = lab < 6
print("best renaming tracker->true:", best)
print("agreement all bases %.1f%%, coding bases %.1f%%" % (100 * acc, 100 * (mapped == lab)[cod].mean()))
print("tracker label use:", np.bincount(tk, minlength=7) / n)
print("confusion (rows tracker label, cols true label), % of bases:")
print(np.round(100 * M / n, 1))
