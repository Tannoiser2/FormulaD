"""Prova, una alla volta, le letture alternative delle frecce di una curva e dice quali fanno tornare L e C.
varianti.py <caselle.json> <spec.json> <id curva>"""
import json, subprocess, sys, copy
g, spf, cid = sys.argv[1], sys.argv[2], sys.argv[3]
sp = json.load(open(spf))
def prova(nome, s):
    json.dump(s, open('/tmp/_s.json', 'w'))
    o = subprocess.run([sys.executable, '-I', 'bin/monta.py', g, '/tmp/_s.json', '/tmp/_m.json'], capture_output=True, text=True).stdout
    l = [x for x in o.splitlines() if x.startswith('curva %s ' % cid)][0]
    print(('  OK  ' if 'OK' in l else '      ') + nome, l[l.index('percorso'):l.index(')', l.index('corto')) + 1]) if ('OK' in l or nome == 'adesso') else None
prova('adesso', sp)
c = [x for x in sp['curve'] if str(x['id']) == cid][0]
ids = [k for k in sp['forche'] if int(k) // 1000 == int(cid)]
for k in ids:
    s = copy.deepcopy(sp); del s['forche'][k]; prova('senza forca ' + k, s)
    if k[-3] == '2':
        s = copy.deepcopy(sp); s['forche'][k] = 4 - s['forche'][k]; prova('lato opposto ' + k, s)
for l in '123':
    a, b = c[l]
    for i in range(a, b + 1):
        if str(i) not in sp['forche']:
            for v in ([2] if l != '2' else [1, 3]):
                s = copy.deepcopy(sp); s['forche'][str(i)] = v; prova(f'aggiungi forca {i} verso {v}', s)
s = copy.deepcopy(sp); s['forca_lontana'] = True; prova('tutte lontane', s)
