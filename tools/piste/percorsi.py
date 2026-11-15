"""Stampa il percorso più lungo e più corto dentro una curva: percorsi.py <circuito montato.json> <id curva>"""
import json, sys
d = json.load(open(sys.argv[1])); cid = int(sys.argv[2]); by = {c['id']: c for c in d['caselle']}
dentro = {c['id'] for c in d['caselle'] if c.get('c') == cid}
ml, mc = {}, {}
def lungo(i):
    if i not in ml:
        ml[i] = max([[i]] + [[i] + lungo(x) for x in by[i]['n'] if x in dentro], key=len)
    return ml[i]
def corto(i):
    if i not in mc:
        esce = any(x not in dentro for x in by[i]['n'])
        mc[i] = [i] if esce else min([[i] + corto(x) for x in by[i]['n'] if x in dentro], key=len)
    return mc[i]
ing = [i for i in dentro if any(i in by[p]['n'] for p in by if p not in dentro)]
L = max((lungo(i) for i in ing), key=len); C = min((corto(i) for i in ing), key=len)
print('lungo', len(L), ' '.join(L)); print('corto', len(C), ' '.join(C))
