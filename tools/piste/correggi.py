"""Applica correzioni a mano alle caselle: sposta, aggiungi, togli.  correggi.py <in.json> <out.json> <correzioni.json>
correzioni: {"sposta": {"id": [x, y]}, "togli": [id], "aggiungi": [{"id":.., "pos":[x,y], "lane":n}]}"""
import sys, json
d = json.load(open(sys.argv[1])); c = json.load(open(sys.argv[3]))
by = {str(s['id']): s for s in d['spaces']}
for k, p in c.get('sposta', {}).items(): by[k]['pos'] = p
d['spaces'] = [s for s in d['spaces'] if str(s['id']) not in {str(x) for x in c.get('togli', [])}]
for a in c.get('aggiungi', []): d['spaces'].append({'id': a['id'], 'pos': a['pos'], 'lane': a['lane'], 'rot': 0, 'next': [], 'corner': None, 'sector': 0})
json.dump(d, open(sys.argv[2], 'w')); print(len(d['spaces']), 'caselle')
