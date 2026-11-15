"""Costruisce il file del circuito per il gioco dalle caselle corrette e dalla descrizione fatta a mano.
monta.py <caselle.json> <descrizione.json> <uscita.json>
Controlla anche, per ogni curva, il percorso più lungo e più corto contro i numeri stampati sul tabellone (L e C)."""
import sys, json, math
import numpy as np
d = json.load(open(sys.argv[1])); sp = json.load(open(sys.argv[2]))
by = {s['id']: s for s in d['spaces']}
catena = {int(k): v for k, v in d['ordine'].items()}
pos = {i: np.array(by[i]['pos'], float) for i in by}
lane = {i: by[i]['lane'] for i in by}
succ, pred = {}, {}
for l, ch in catena.items():
    for k, i in enumerate(ch):
        succ[i] = ch[(k + 1) % len(ch)]; pred[ch[(k + 1) % len(ch)]] = i
dirv = {i: (pos[succ[i]] - pos[i]) for i in by}
lung = {i: float(np.hypot(*dirv[i])) for i in by}
# le celle lunghe (curve interne) non devono falsare: lunghezza tipica
tip = float(np.median(list(lung.values())))
def rel(a, b):
    t = dirv[a] / max(1e-6, lung[a]); v = pos[b] - pos[a]
    return float(v @ t), float(-v[0] * t[1] + v[1] * t[0])
# curve
curva = {i: 0 for i in by}
for c in sp['curve']:
    for l in (1, 2, 3):
        a, b = c[str(l)]; ch = catena[l]; ka, kb = ch.index(a), ch.index(b)
        k = ka
        while True:
            curva[ch[k]] = c['id']
            if k == kb: break
            k = (k + 1) % len(ch)
# caselle a contatto nelle corsie accanto (stesso criterio delle piste del modulo: si sovrappongono lungo la corsia)
VA, VB = [set(x) for x in sp.get('vieta', [[], []])]   # due gruppi di caselle che si sfiorano senza toccarsi (ponte e galleria)
accanto = {i: [] for i in by}
for a in by:
    for b in by:
        if abs(lane[a] - lane[b]) != 1: continue
        if (a in VA and b in VB) or (a in VB and b in VA): continue
        v = pos[b] - pos[a]
        if abs(v[0]) > 110 or abs(v[1]) > 110: continue
        lu, la = rel(a, b)
        meta = 0.5 * (min(lung[a], 1.6 * tip) + min(lung[pred[b]] if False else lung[b], 1.6 * tip))
        if abs(lu) < 0.93 * meta and abs(la) < 1.7 * 0.62 * tip:
            accanto[a].append((b, lu))
vicini = {i: set() for i in by}
for a in by:
    vicini[a].add(succ[a]); vicini[succ[a]].add(a)
    for b, lu in accanto[a]:
        vicini[a].add(b); vicini[b].add(a)
# collegamenti
forche = {int(k): v for k, v in sp.get('forche', {}).items()}
nxt = {}
avvisi = []
scelte = {}
for a in by:
    out = [succ[a]]
    if curva[a] == 0:
        for b, lu in accanto[a]:
            if lu > 0.1 * tip and curva[b] == 0 and b not in out:
                out.append(b)
    elif a in forche:
        l2 = forche[a]
        if l2 == 0:
            # corsia centrale: la forca pende verso l'interno della curva (guardando due caselle prima e dopo)
            ch = catena[2]; k = ch.index(a); n = len(ch)
            u = pos[a] - pos[ch[(k - 2) % n]]; w = pos[ch[(k + 2) % n]] - pos[a]
            gira = u[0] * w[1] - u[1] * w[0]
            lati = {}
            for b, lu in accanto[a]:
                lati[lane[b]] = rel(a, b)[1]
            destra = max(lati, key=lambda q: lati[q]); sinistra = min(lati, key=lambda q: lati[q])
            l2 = destra if gira > 0 else sinistra
            scelte[a] = l2
        cand = [(lu, b) for b, lu in accanto[a] if lane[b] == l2 and lu > sp.get('soglia_forca', 0.05) * tip]
        if not cand:
            cand = [(rel(a, b)[0], b) for b in by if lane[b] == l2 and 0 < rel(a, b)[0] < 2.2 * tip and abs(rel(a, b)[1]) < 1.9 * 0.62 * tip]
        if cand:
            out.append(max(cand)[1] if sp.get('forca_lontana') else min(cand)[1])
        else:
            avvisi.append(f'forca di {a} verso corsia {l2}: nessuna casella trovata')
    nxt[a] = out
for a, extra in sp.get('collega', {}).items():
    for b in extra:
        if b not in nxt[int(a)]: nxt[int(a)].append(b)
for a, via in sp.get('scollega', {}).items():
    nxt[int(a)] = [b for b in nxt[int(a)] if b not in via]
# settori: s0 dopo la bandiera, poi curva/rettilineo alternati lungo la corsia centrale
sett = {}
for l, ch in catena.items():
    k0 = ch.index(sp['traguardo'][l - 1]); n = 0; prima = True
    for j in range(len(ch)):
        i = ch[(k0 + j) % len(ch)]
        if curva[i]:
            sett[i] = 'c%d' % curva[i]; n = curva[i]
        else:
            sett[i] = 's%d' % n
# box
P = sp['pit']; caselle = []
def casella(i, extra=None):
    r = math.degrees(math.atan2(dirv[i][1], dirv[i][0])) % 360
    c = {'id': str(i), 'p': [round(float(pos[i][0]), 1), round(float(pos[i][1]), 1)], 'r': round(r, 1), 'l': lane[i], 's': sett[i], 'n': [str(x) for x in nxt[i]]}
    if curva[i]: c['c'] = curva[i]
    return c
out_c = {i: casella(i) for i in by}
pit_ids = []
lst = P['corsia']   # [[x, y], ...] dall'ingresso all'uscita
def ang(a, b): return round(math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])) % 360, 1)
ultimo_settore = 's%d' % max(c['id'] for c in sp['curve'])
for k, p in enumerate(lst):
    pid = 'p%d' % k
    q = lst[k + 1] if k + 1 < len(lst) else pos[P['uscita'][0]]
    dopo = k >= P['dopo_bandiera']
    c = {'id': pid, 'p': p, 'r': ang(p, q), 'l': 0, 's': 's0' if dopo else ultimo_settore, 'n': [], 'pit': True}
    if k + 1 < len(lst): c['n'].append('p%d' % (k + 1))
    else: c['n'] += [str(x) for x in P['uscita']]
    caselle.append(c); pit_ids.append(pid)
    posto = P['box'].get(str(k))
    if posto:
        t = np.array(q, float) - np.array(p, float); t /= np.hypot(*t); nrm = np.array([-t[1], t[0]]) * P['lato']
        bp = [round(p[0] + nrm[0] * P['scarto'], 1), round(p[1] + nrm[1] * P['scarto'], 1)]
        b = {'id': 'b%d' % k, 'p': bp, 'r': c['r'], 'l': 0, 's': c['s'], 'n': list(c['n']), 'pit': True, 'box': posto}
        c['n'].insert(0, b['id']); caselle.append(b); pit_ids.append(b['id'])
for a in P['ingresso']:
    out_c[a]['n'].append('p0')
tutte = caselle + [out_c[i] for l in (1, 2, 3) for i in catena[l]]
trag = [str(x) for x in sp['traguardo']] + ['p%d' % P['dopo_bandiera']] + (['b%d' % P['dopo_bandiera']] if str(P['dopo_bandiera']) in P['box'] else [])
res = {'id': sp['id'], 'nome': sp['nome'], 'giri': sp['giri'], 'img': sp['img'], 'dadi': sp.get('dadi'),
       'curve': [{'id': c['id'], 'stops': c['stops']} for c in sp['curve']], 'griglia': [str(x) for x in sp['griglia']],
       'traguardo': trag, 'pit': {'entry': [str(x) for x in P['ingresso']], 'exit': [str(x) for x in P['uscita']], 'spaces': pit_ids},
       'vicini': {str(a): sorted(str(b) for b in v) for a, v in vicini.items()}, 'caselle': tutte}
json.dump(res, open(sys.argv[3], 'w'), separators=(',', ':'), ensure_ascii=False)
# controlli
from collections import Counter
print(len(tutte), 'caselle; uscite per casella:', dict(Counter(len(c['n']) for c in tutte)))
entr = Counter(x for c in tutte for x in c['n'])
print('forche della corsia centrale:', scelte)
print('senza ingressi:', [c['id'] for c in tutte if entr[c['id']] == 0], ' avvisi:', avvisi)
print('vicini per casella:', dict(Counter(len(v) for v in vicini.values())))
# percorso piu' lungo e piu' corto dentro ogni curva (numero di caselle toccate)
for c in sp['curve']:
    dentro = [i for i in by if curva[i] == c['id']]
    ins = [i for i in dentro if curva[pred[i]] != c['id'] or any(curva[p] != c['id'] for p in by if i in nxt[p])]
    memo = {}
    def lungo(i, f):
        if (i, f) in memo: return memo[(i, f)]
        dn = [x for x in nxt[i] if curva[x] == c['id']]
        esce = any(curva[x] != c['id'] for x in nxt[i])
        vals = [1 + lungo(x, f) for x in dn] + ([1] if esce or not dn else [])
        memo[(i, f)] = f(vals); return memo[(i, f)]
    ingressi = [i for i in dentro if any(curva[p] != c['id'] and i in nxt[p] for p in by)]
    L = max(lungo(i, max) for i in ingressi); C = min(lungo(i, min) for i in ingressi)
    n = {l: sum(1 for i in dentro if lane[i] == l) for l in (1, 2, 3)}
    ok = (c.get('L') in (None, L)) and (c.get('C') in (None, C))
    print(f"curva {c['id']} fermate {c['stops']}: corsie {n}, percorso lungo {L} (stampato {c.get('L')}), corto {C} (stampato {c.get('C')}) {'OK' if ok else '<<< DIVERSO'}")
