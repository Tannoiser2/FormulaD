"""Cerca le combinazioni dei lati delle forche della corsia centrale di una curva che fanno tornare L e C.
forza.py <caselle.json> <spec.json> <id curva>   (ogni forca centrale: verso 1, verso 3 oppure assente)"""
import json, subprocess, sys, copy, itertools
sys.setrecursionlimit(400)
g, spf, cid = sys.argv[1], sys.argv[2], int(sys.argv[3]); sp = json.load(open(spf))
c = [x for x in sp['curve'] if x['id'] == cid][0]
mid = [k for k in sp['forche'] if int(k) // 1000 == cid and k[-3] == '2']
def monta(v):
    s = copy.deepcopy(sp)
    for k in mid: s['forche'][k] = v
    json.dump(s, open('/tmp/_s.json', 'w'))
    subprocess.run([sys.executable, '-I', 'bin/monta.py', g, '/tmp/_s.json', '/tmp/_m%d.json' % v], capture_output=True)
    return {x['id']: x for x in json.load(open('/tmp/_m%d.json' % v))['caselle']}
A, B = monta(1), monta(3)
dentro = {i for i in A if A[i].get('c') == cid}
base = {i: list(A[i]['n']) for i in dentro}
alt = {}
for k in mid:
    succ = A[k]['n'][0]
    alt[k] = {1: [x for x in A[k]['n'] if x != succ], 3: [x for x in B[k]['n'] if x != succ], 0: []}
    base[k] = [succ]
ing = [i for i in dentro if any(i in A[p]['n'] for p in A if p not in dentro)]
adesso = tuple(sp['forche'][k] for k in mid); buone = []
for combo in itertools.product((1, 3, 0), repeat=len(mid)):
    n = dict(base)
    for k, v in zip(mid, combo): n[k] = base[k] + alt[k][v]
    ml, mc = {}, {}
    def lungo(i):
        if i not in ml: ml[i] = 1 + max([0] + [lungo(x) for x in n[i] if x in dentro])
        return ml[i]
    def corto(i):
        if i not in mc:
            mc[i] = 1 if any(x not in dentro for x in n[i]) else 1 + min(corto(x) for x in n[i] if x in dentro)
        return mc[i]
    try:
        L = max(lungo(i) for i in ing); C = min(corto(i) for i in ing)
    except RecursionError:
        continue
    if L == c['L'] and C == c['C']:
        buone.append((sum(a != b for a, b in zip(combo, adesso)) + 2 * sum(1 for v in combo if v == 0 and v not in adesso), combo))
buone.sort(); print(len(buone), 'combinazioni tornano; forche centrali', mid, 'adesso', adesso)
for d, combo in buone[:8]: print('  cambi', d, combo)
