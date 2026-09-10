import collections,sys
S=collections.defaultdict(dict)
for f in ('sizes.tsv','real.tsv'):
    for l in open(f):
        lb,t,b=l.split(); S[lb][t]=int(b)
for lb in S:
    if 'ctl' not in S[lb]: continue
    c=S[lb]['ctl']; out=[lb, f"ctl {c}"]
    for k in ['sub','ind','hp']:
        v=[(S[lb][f'{k}_{s}']-c)*8/2000 for s in (1,2,3)]
        out.append(f"{k} {sum(v)/3:.2f}")
    for r in ['w3110','o157','ecoli_ind','chr21_ind']:
        if r in S[lb]: out.append(f"{r} {S[lb][r]} ({100*(S[lb][r]/S['base'][r]-1):+.2f}%)")
    print(' | '.join(out))
