"""Per-event cost in bits, from the sizes the measure scripts recorded.

    python scripts/cue/score.py [workdir]

(target - zero-event control) x 8 / 2000 events, meaned over the three seeds,
plus each real pair as a change against the `base` build (v0.8.0). The control
is what makes this a cost per event rather than a file size: it is the same
genome with no events in it, so everything the codec pays for the genome itself
cancels.
"""
import collections, os, sys

work = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', '..', 'bench-external', 'work', 'cue')
S = collections.defaultdict(dict)
for f in ('sizes.tsv', 'real.tsv'):
    p = os.path.join(work, f)
    if not os.path.exists(p):
        continue
    for l in open(p):
        lb, t, b = l.split()
        S[lb][t] = int(b)
if not S:
    sys.exit(f"no sizes.tsv or real.tsv in {work} -- run scripts/cue/measure.sh first")

for lb in S:
    if 'ctl' not in S[lb]:
        continue
    c = S[lb]['ctl']; out = [lb, f"ctl {c}"]
    for k in ['sub', 'ind', 'hp']:
        v = [(S[lb][f'{k}_{s}'] - c) * 8 / 2000 for s in (1, 2, 3)]
        out.append(f"{k} {sum(v)/3:.2f}")
    for r in ['w3110', 'o157', 'ecoli_ind', 'chr21_ind']:
        if r in S[lb]:
            pct = f" ({100*(S[lb][r]/S['base'][r]-1):+.2f}%)" if r in S.get('base', {}) else ""
            out.append(f"{r} {S[lb][r]}{pct}")
    print(' | '.join(out))
