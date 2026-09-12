"""Cost per event in the FIRST and SECOND half of each target: the osmosis.

    python scripts/cue/halves.py <label> [workdir]

Reads the -map files written by halves.sh (bit cost per 1,000-base window),
splits each target at its midpoint, subtracts the control's bits for the same
half, and divides by how many of that target's events fall in it. The ratio
(second / first) is the number docs/cue.md calls the osmosis: how much cheaper
an event has become by the time the file ends.

Event positions come from the same seeded draw that built the targets
(make_tumour.plan), except homopolymer slips, whose chosen runs are listed in
the truth file.
"""
import sys, os, csv

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from make_tumour import plan

lb = sys.argv[1]
work = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, '..', '..', 'bench-external', 'work', 'cue')
tgt = os.environ.get('TGT', os.path.join(here, '..', '..', 'bench-external', 'cue', 'ecoli-targets'))
ref = os.environ.get('REF') or os.path.join(here, '..', '..', 'ecoli.fa')

seq = ''.join(l.strip() for l in open(ref) if not l.startswith('>')).upper().encode()

def half_bits(t):
    rows = list(csv.DictReader(open(os.path.join(work, f'{t}.{lb}.map.tsv')), delimiter='\t'))
    h = len(rows) // 2
    return (sum(float(r['bits']) for r in rows[:h]),
            sum(float(r['bits']) for r in rows[h:]), h * 1000)

def positions(k, s):
    if k == 'hp':
        return [int(l.split()[2]) for l in open(os.path.join(tgt, f'hp_{s}.truth.tsv'))
                if l.startswith('#run')]
    return [p for p, _, _ in plan(seq, 2000, 0 if k == 'sub' else 1, s)]

c1, c2, _ = half_bits('ctl')
for k in ['sub', 'hp', 'ind']:
    fa = fb = 0
    for s in (1, 2, 3):
        a, b, cut = half_bits(f'{k}_{s}'); ps = positions(k, s)
        ea = sum(p < cut for p in ps); eb = len(ps) - ea
        fa += (a - c1) / ea; fb += (b - c2) / eb          # bits per event
    fa /= 3; fb /= 3
    print(f"{lb}\t{k}\t{fa:.2f}\t{fb:.2f}\t{fb/fa:.3f}")
