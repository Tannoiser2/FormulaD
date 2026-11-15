"""Per una curva prova tutti i lati possibili delle forche della corsia centrale e dice quali danno i percorsi
lungo/corto stampati sul tabellone. prova_forche.py <caselle> <spec> <curva>"""
import sys, json, itertools, subprocess, copy, os
sp = json.load(open(sys.argv[2])); cid = int(sys.argv[3])
base = subprocess.run([sys.executable, '-I', os.path.dirname(__file__) + '/monta.py', sys.argv[1], sys.argv[2], '/tmp/_m.json'], capture_output=True, text=True).stdout
scelte = eval([l for l in base.splitlines() if l.startswith('forche della corsia centrale')][0].split(':', 1)[1])
d = json.load(open('/tmp/_m.json')); cur = {c['id']: c.get('c', 0) for c in d['caselle']}
mie = [k for k in scelte if cur[str(k)] == cid]
c = [x for x in sp['curve'] if x['id'] == cid][0]
sol = []
for combo in itertools.product((1, 3), repeat=len(mie)):
    s2 = copy.deepcopy(sp)
    for k, v in zip(mie, combo): s2['forche'][str(k)] = v
    json.dump(s2, open('/tmp/_s.json', 'w'))
    o = subprocess.run([sys.executable, '-I', os.path.dirname(__file__) + '/monta.py', sys.argv[1], '/tmp/_s.json', '/tmp/_m2.json'], capture_output=True, text=True).stdout
    riga = [l for l in o.splitlines() if l.startswith('curva %d ' % cid)][0]
    if riga.endswith('OK'):
        diff = sum(1 for k, v in zip(mie, combo) if scelte[k] != v)
        sol.append((diff, dict(zip(mie, combo))))
sol.sort(key=lambda x: x[0])
print('forche centrali:', {k: scelte[k] for k in mie}); print(len(sol), 'combinazioni tornano con', c.get('L'), c.get('C'))
for dff, s in sol[:6]: print('  cambi', dff, {k: v for k, v in s.items() if scelte[k] != v})
