import sys,csv,random
sys.path.insert(0,'/c/Users/Timotheos/Desktop/bitshape/scripts'.replace('/c/','C:/'))
from make_tumour import plan
lb=sys.argv[1]
seq=''.join(l.strip() for l in open('ref.fa') if not l.startswith('>')).upper().encode()
def half_bits(t):
    rows=list(csv.DictReader(open(f'{t}.{lb}.map.tsv'),delimiter='\t'))
    h=len(rows)//2
    return sum(float(r['bits']) for r in rows[:h]), sum(float(r['bits']) for r in rows[h:]), h*1000
def positions(k,s):
    if k=='hp':
        return [int(l.split()[2]) for l in open(f'hp_{s}.truth.tsv') if l.startswith('#run')]
    return [p for p,_,_ in plan(seq,2000,0 if k=='sub' else 1,s)]
c1,c2,_=half_bits('ctl')
for k in ['sub','hp','ind']:
    fa=fb=0
    for s in (1,2,3):
        a,b,cut=half_bits(f'{k}_{s}'); ps=positions(k,s)
        ea=sum(p<cut for p in ps); eb=len(ps)-ea
        fa+=(a-c1)*8/8/ea; fb+=(b-c2)/eb   # bits per event
    fa/=3; fb/=3
    print(f"{lb}\t{k}\t{fa:.2f}\t{fb:.2f}\t{fb/fa:.3f}")
