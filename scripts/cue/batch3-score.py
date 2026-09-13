"""Batch 3's tables, from the sizes scripts/cue/batch3.sh recorded.

    python scripts/cue/batch3-score.py [workdir]

Per-event costs come from the controlled targets the same way as score.py
((target - control) x 8 / 2000 events, meaned over three seeds); everything
else is a percentage against the same dataset's `base` build at the same
level, and against `cue` at the same level, which is the sweep's centre.
"""
import collections, os, sys

work = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', '..', 'bench-external', 'work', 'cue')
p = os.path.join(work, 'batch3.tsv')
S = collections.defaultdict(dict)        # S[(label, level)][dataset] = bytes
for l in open(p):
    lb, stage, ds, lvl, b = l.split()
    S[(lb, int(lvl))][ds] = int(b)

levels = sorted({lv for _, lv in S})
for lv in levels:
    labs = [lb for (lb, l) in S if l == lv]
    order = [x for x in ('base', 'cue') if x in labs] + sorted(set(labs) - {'base', 'cue'})
    print(f"\n=== level {lv} " + "=" * 50)
    hdr = f"{'build':<10}"
    for k in ('sub', 'ind', 'hp'):
        hdr += f"{k:>8}"
    for r in ('ecoli_ind', 'o157', 'chr21_ind', 'chm13_chr21', 'chm13_chr22',
              'ecoli_plain', 'chr21_plain'):
        if any(r in S[(lb, lv)] for lb in labs):
            hdr += f"{r:>22}"
    print(hdr)
    for lb in order:
        d = S[(lb, lv)]
        row = f"{lb:<10}"
        c = d.get('ctl')
        for k in ('sub', 'ind', 'hp'):
            seeds = [d[f'{k}_{s}'] for s in (1, 2, 3) if f'{k}_{s}' in d]
            row += f"{sum((v - c) * 8 / 2000 for v in seeds) / len(seeds):>8.2f}" if c and seeds else f"{'':>8}"
        for r in ('ecoli_ind', 'o157', 'chr21_ind', 'chm13_chr21', 'chm13_chr22',
                  'ecoli_plain', 'chr21_plain'):
            if not any(r in S[(x, lv)] for x in labs):
                continue
            if r not in d:
                row += f"{'':>22}"
                continue
            txt = f"{d[r]}"
            for ref, tag in (('base', 'b'), ('cue', 'c')):
                if r in S.get((ref, lv), {}) and lb != ref:
                    txt += f" {tag}{100 * (d[r] / S[(ref, lv)][r] - 1):+.3f}%"
            row += f"{txt:>22}"
        print(row)
