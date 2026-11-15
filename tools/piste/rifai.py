"""Rifa a mano le caselle delle curve: toglie quelle rilevate dentro i riquadri e mette quelle lette dal tabellone.
rifai.py <caselle rilevate.json> <mano.json> <caselle uscita.json> <curve uscita.json>
mano: {"curve": [{"id", "stops", "L", "C", "togli": {"1": [x0, y0, x1, y1] oppure [[...], [...]], ...},
                  "1": [[x, y, f], ...], "2": ..., "3": ...}], "sposta": {id: [x, y]}, "togli": [id], "aggiungi": [[x, y, corsia]]}
Le caselle di ogni corsia vanno scritte nel verso di marcia; f = corsia verso cui punta la seconda freccia (0 o assente: nessuna)."""
import sys, json
d = json.load(open(sys.argv[1])); m = json.load(open(sys.argv[2]))
by = {str(s['id']): s for s in d['spaces']}
for k, p in m.get('sposta', {}).items(): by[k]['pos'] = p
via = {str(x) for x in m.get('togli', [])}
def nuova(i, x, y, l): return {'id': i, 'pos': [x, y], 'lane': l, 'rot': 0, 'next': [], 'corner': None, 'sector': 0}
nuove = []; curve = []; forche = {}
for c in m['curve']:
    voce = {'id': c['id'], 'stops': c['stops'], 'L': c.get('L'), 'C': c.get('C')}
    for l in ('1', '2', '3'):
        if 'togli' in c:
            r = c['togli'][l]
            for b in (r if isinstance(r[0], list) else [r]):
                for s in d['spaces']:
                    if s['lane'] == int(l) and b[0] <= s['pos'][0] <= b[2] and b[1] <= s['pos'][1] <= b[3]: via.add(str(s['id']))
        else:
            # senza riquadri: via le caselle rilevate della stessa corsia a meno di 30 pixel da una casella nuova
            for s in d['spaces']:
                if s['lane'] == int(l) and any((s['pos'][0] - p[0]) ** 2 + (s['pos'][1] - p[1]) ** 2 < 900 for p in c[l]): via.add(str(s['id']))
        ids = []
        for k, p in enumerate(c[l]):
            i = 1000 * c['id'] + 100 * int(l) + k + 1
            nuove.append(nuova(i, p[0], p[1], int(l))); ids.append(i)
            if len(p) > 2 and p[2]: forche[str(i)] = 0 if p[2] == 9 else p[2]   # 9 = corsia centrale, lato scelto dal programma
        voce[l] = [ids[0], ids[-1]]
    curve.append(voce)
d['spaces'] = [s for s in d['spaces'] if str(s['id']) not in via] + nuove
for k, a in enumerate(m.get('aggiungi', [])): d['spaces'].append(nuova(9000 + k, a[0], a[1], a[2]))
json.dump(d, open(sys.argv[3], 'w')); json.dump({'curve': curve, 'forche': forche}, open(sys.argv[4], 'w'), indent=1)
print(len(d['spaces']), 'caselle, tolte', len(via), 'messe', len(nuove))
