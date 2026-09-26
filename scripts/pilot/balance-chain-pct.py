#!/usr/bin/env python3
"""docs/balance-chain-chr20-prediction.md: R(L) and the observed D's percentile
among 200 sign permutations. Usage: python balance-chain-pct.py <chain.gz> chr..."""
import sys
import numpy as np
sys.path.insert(0, __file__.rsplit("/", 1)[0].rsplit("\\", 1)[0])
from importlib import import_module
bc = import_module("balance-chain")

def main(path, chroms):
    rng = np.random.default_rng(20260926)
    for c in chroms:
        ev, _ = bc.events(bc.best_chain(path, c)); pos, val = ev[:, 0], ev[:, 1]
        s, a = np.sign(val), np.abs(val); lo, hi = pos.min(), pos.max()
        for L in (100000, 1000000):
            o = bc.dvar(pos, val, lo, hi, L)
            null = np.array([bc.dvar(pos, rng.permutation(s) * a, lo, hi, L) for _ in range(200)])
            print("%s L=%-8d n_ev=%d R=%.4f percentile=%.1f%% (null 5th..95th: %.0f..%.0f, obs %.0f)"
                  % (c, L, len(ev), o / null.mean(), 100 * np.mean(null < o),
                     np.percentile(null, 5), np.percentile(null, 95), o))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
