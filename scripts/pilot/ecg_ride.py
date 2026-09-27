#!/usr/bin/env python3
"""docs/ecg-ride-prediction.md: LIN vs FIX (fixed-tempo beat copy) vs RIDE
(tempo-following copy: cue reload at each R detection + ride +-1 per sample).
Every predictor is causal and integer and is run again as a decoder; the run
fails loudly if the reconstruction differs.
  python scripts/pilot/ecg_ride.py <dir-with-NNN.dat> 100 101 119 208"""
import sys
import numpy as np

W, LMIN, LMAX, REFR = 8, 120, 700, 72

def read212(path):
    b = np.fromfile(path, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
    s = b[:, 0] | ((b[:, 1] & 0x0F) << 8)
    return np.where(s >= 2048, s - 4096, s)            # channel 0 only

def entropy(r):
    _, c = np.unique(r, return_counts=True); p = c / c.sum()
    return float(-(p * np.log2(p)).sum())

BEATS = set(range(1, 14)) | {25, 34, 35, 38}   # MIT annotation codes that are beats

def read_atr(path):
    """Beat sample times from a MIT-format .atr file."""
    import numpy as np
    w = np.fromfile(path, dtype="<u2"); t, out, i = 0, [], 0
    while i < len(w):
        a, v = int(w[i]) >> 10, int(w[i]) & 1023
        if a == 0 and v == 0: break
        if a == 59:                                  # SKIP: 32-bit interval, high word first
            t += (int(w[i + 1]) << 16) | int(w[i + 2]); i += 3; continue
        if a == 63: i += 1 + (v + 1) // 2; continue  # AUX string
        if a in (60, 61, 62): i += 1; continue
        t += v
        if a in BEATS: out.append(t)
        i += 1
    return out

def run(mode, n, x=None, res=None, dets=None, fb="d2", log=None):
    """mode 'fix' or 'ride'. Encode (x given) -> residuals; decode (res given) -> x.
    dets: oracle beat times replacing the causal detector. fb: linear fallback."""
    enc = res is None
    dset = set(dets) if dets is not None else None
    X = [0] * n if not enc else list(map(int, x)); R = [0] * n
    last_det, rr, L, m = -10**9, 0, 0, 0.0
    ec = [0] * n; el = [0] * n; sc = 0; sl = 0            # past |err| of copy / linear
    for t in range(n):
        # prediction from the past only
        if fb == "d1": pl = X[t - 1] if t >= 1 else 0
        else: pl = 2 * X[t - 1] - X[t - 2] if t >= 2 else (X[t - 1] if t >= 1 else 0)
        pc = None
        if L and t - L - 1 >= 0:
            if mode == "ride" and t - L - 2 - W >= 0:
                best, bl = None, L
                for cand in (L, L - 1, L + 1):            # tie keeps L (tried first)
                    if not (LMIN <= cand <= LMAX) or t - cand - W - 1 < 0: continue
                    e = 0
                    for j in range(1, W + 1):
                        e += abs((X[t - j] - X[t - j - 1]) - (X[t - j - cand] - X[t - j - cand - 1]))
                    if best is None or e < best: best, bl = e, cand
                L = bl
            pc = X[t - 1] + (X[t - L] - X[t - L - 1])
        use_c = pc is not None and sc < sl
        p = pc if use_c else pl
        if enc: R[t] = X[t] - p
        else: X[t] = p + res[t]
        # update selector windows (errors of both predictors, known now)
        el[t] = abs(X[t] - pl); ec[t] = abs(X[t] - pc) if pc is not None else 10**6
        sl += el[t] - (el[t - W] if t >= W else 0)
        sc += ec[t] - (ec[t - W] if t >= W else 0)
        # causal R detection -> the cue load
        if dset is not None:
            det = t in dset
        elif t >= 3:
            q = X[t] - X[t - 3]
            m = max(float(q), m - m / 512.0)
            det = q > 0.5 * m and m > 0 and t - last_det > REFR
        else:
            det = False
        if det:
            if log is not None: log.append(t)
            if last_det > 0:
                rr = t - last_det
                if LMIN <= rr <= LMAX: L = rr
            last_det = t
    return R if enc else X

def accuracy(det, ref, tol=54):
    import bisect
    ref = sorted(ref); det = sorted(det)
    def near(a, b):
        return sum(1 for v in a if (lambda i: (i < len(b) and b[i] - v <= tol) or (i > 0 and v - b[i - 1] <= tol))(bisect.bisect_left(b, v)))
    return near(ref, det) / len(ref), near(det, ref) / len(det)

def main(d, recs):
    fb = "d1" if "--fallback=d1" in recs else "d2"
    oracle = "--oracle" in recs
    recs = [r for r in recs if not r.startswith("--")]
    print("fallback=%s detector=%s" % (fb, "ORACLE (.atr beats)" if oracle else "causal"))
    print("%-5s %8s %8s %8s %8s %9s %9s" % ("rec", "d1", "d2", "LIN", "FIX", "RIDE", "RIDEvsFIX"))
    for r in recs:
        x = read212("%s/%s.dat" % (d, r)); n = len(x)
        d1 = entropy(np.diff(x)); d2 = entropy(x[2:] - 2 * x[1:-1] + x[:-2]); lin = min(d1, d2)
        out = {}; dets = read_atr("%s/%s.atr" % (d, r)) if oracle else None
        if not oracle:
            import os
            if os.path.exists("%s/%s.atr" % (d, r)):
                lg = []; run("fix", n, x=x, log=lg)
                se, pp = accuracy(lg, read_atr("%s/%s.atr" % (d, r)))
                print("  %s causal detector vs .atr: sensitivity %.2f%%  positive predictivity %.2f%%" % (r, 100 * se, 100 * pp))
        for mode in ("fix", "ride"):
            res = run(mode, n, x=x, dets=dets, fb=fb)
            back = run(mode, n, res=res, dets=dets, fb=fb)
            if not np.array_equal(np.array(back), x):
                raise SystemExit("FAIL: %s %s does not decode" % (r, mode))
            out[mode] = entropy(np.array(res))
        f, g = out["fix"], out["ride"]
        print("%-5s %8.4f %8.4f %8.4f %8.4f %9.4f %+8.2f%%   RIDEvsLIN %+6.2f%%  (decoded OK)"
              % (r, d1, d2, lin, f, g, 100 * (g - f) / f, 100 * (g - lin) / lin))
        sys.stdout.flush()

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
