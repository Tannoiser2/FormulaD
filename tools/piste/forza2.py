"""Come forza.py ma su tutte le doppie frecce di una curva (bordi: presente/assente; centro: verso 1, verso 3, assente)
e con qualunque numerazione delle caselle. forza2.py <caselle.json> <spec.json> <id curva>"""
import json, subprocess, sys, copy, itertools
sys.setrecursionlimit(600)
g, spf, cid = sys.argv[1], sys.argv[2], int(sys.argv[3]); sp = json.load(open(spf))
c = [x for x in sp['curve'] if x['id'] == cid][0]
def monta(v):
    s = copy.deepcopy(sp)
    for k in s['forche']:
        if s['forche'][k] in (0, 1, 3): s['forche'][k] = v
    json.dump(s, open('/tmp/_s.json', 'w'))
    subprocess.run([sys.executable, '-I', 'bin/monta.py', g, '/tmp/_s.json', '/tmp/_m%d.json' % v], capture_output=True)
    return {x['id']: x for x in json.load(open('/tmp/_m%d.json' % v))['caselle']}
A, B = monta(1), monta(3)
dentro = {i for i in A if A[i].get('c') == cid}
fk = [k for k in sp['forche'] if k in dentro]
base = {}; alt = {}
for i in dentro:
    succ = [x for x in A[i]['n'] if A[x]['l'] == A[i]['l'] or x not in dentro][:1] or A[i]['n'][:1]
    base[i] = succ
for k in fk:
    s0 = base[k][0]
    if sp['forche'][k] == 2: alt[k] = {1: [x for x in A[k]['n'] if x != s0], 0: []}
    else: alt[k] = {1: [x for x in A[k]['n'] if x != s0], 3: [x for x in B[k]['n'] if x != s0], 0: []}
ing = [i for i in dentro if any(i in A[p]['n'] for p in A if p not in dentro)]
adesso = tuple(1 if sp['forche'][k] == 2 else sp['forche'][k] if sp['forche'][k] else 1 for k in fk)
buone = []
for combo in itertools.product(*[sorted(alt[k]) for k in fk]):
    n = dict(base)
    for k, v in zip(fk, combo): n[k] = base[k] + alt[k][v]
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
    except (RecursionError, ValueError):
        continue
    if L == c['L'] and C == c['C']:
        buone.append((sum(a != b for a, b in zip(combo, adesso)), combo))
buone.sort(); print(len(buone), 'combinazioni tornano; forche', fk, 'adesso', adesso)
for d, combo in buone[:6]: print('  cambi', d, [(k, v) for k, v, a in zip(fk, combo, adesso) if v != a])
