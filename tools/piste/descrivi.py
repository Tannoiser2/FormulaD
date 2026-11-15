"""Scrive la descrizione completa di un circuito (per monta.py) da pochi dati letti dal tabellone.
descrivi.py <caselle in fila.json> <curve.json> <base.json> <uscita spec.json>
base: {id, nome, giri, img, dadi, traguardo: [[x,y] corsia 1, 2, 3], pole: [x, y, corsia], secondo: [x, y, corsia], passo,
       pit: {corsia: [[x,y],...], primo_box, colori: [...], dopo_bandiera, lato, ingresso: [x, y, corsia], uscita: [x, y, corsia]}}"""
import sys, json
g = json.load(open(sys.argv[1])); cv = json.load(open(sys.argv[2])); b = json.load(open(sys.argv[3]))
by = {s['id']: s for s in g['spaces']}; ch = {int(k): v for k, v in g['ordine'].items()}
def vic(x, y, l): return min((s for s in g['spaces'] if s['lane'] == l), key=lambda s: (s['pos'][0] - x) ** 2 + (s['pos'][1] - y) ** 2)['id']
def dietro(i, n):
    c = ch[by[i]['lane']]; return c[(c.index(i) - n) % len(c)]
a, c2 = vic(*b['pole']), vic(*b['secondo']); gr = []
for k in range(5):
    gr += [a, c2]; a = dietro(a, b.get('passo', 3)); c2 = dietro(c2, b.get('passo', 3))
tr = [vic(p[0], p[1], l + 1) for l, p in enumerate(b['traguardo'])]
P = b['pit']; coppie = {'White': 'Brown', 'Yellow': 'Orange', 'Green': 'Teal', 'Red': 'Pink', 'Blue': 'Purple'}
nomi = [n for c in P['colori'] for n in (c, coppie[c])]
sp = {'id': b['id'], 'nome': b['nome'], 'giri': b.get('giri', 2), 'img': b['img'], 'dadi': b['dadi'], 'traguardo': tr, 'griglia': gr,
      'pit': {'corsia': P['corsia'], 'box': {str(P['primo_box'] + k): nomi[k] for k in range(10)}, 'lato': P['lato'], 'scarto': P.get('scarto', 11),
              'dopo_bandiera': P['dopo_bandiera'], 'ingresso': [vic(*P['ingresso'])], 'uscita': [vic(*P['uscita'])]},
      'curve': cv['curve'], 'forche': cv['forche']}
for k in ('collega', 'scollega', 'forca_lontana', 'vieta', 'soglia_forca'):
    if k in b: sp[k] = b[k]
sp['forche'].update({str(k): v for k, v in b.get('forche', {}).items()})
json.dump(sp, open(sys.argv[4], 'w'), indent=1, ensure_ascii=False)
print('griglia', [(i, [round(v) for v in by[i]['pos']]) for i in gr]); print('traguardo', tr, 'ingresso', sp['pit']['ingresso'], 'uscita', sp['pit']['uscita'])
