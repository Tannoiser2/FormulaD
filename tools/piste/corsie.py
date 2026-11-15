"""Mette in ordine le caselle di ogni corsia seguendo la pista e segnala spaziature sospette.
corsie.py <in.json> <out.json> <partenza corsia1> <partenza corsia2> <partenza corsia3> [lane=id,id ...]"""
import sys, json, numpy as np
d = json.load(open(sys.argv[1]))
for a in sys.argv[6:]:
    l, ids = a.split('='); ids = {int(x) for x in ids.split(',')}
    for s in d['spaces']:
        if s['id'] in ids: s['lane'] = int(l)
by = {s['id']: s for s in d['spaces']}
ordine = {}
for lane, coppia in zip((1, 2, 3), sys.argv[3:6]):
    st, secondo = [int(x) for x in coppia.split(',')]
    resto = {s['id'] for s in d['spaces'] if s['lane'] == lane and not s.get('pit')}
    ch = [st, secondo]; resto.discard(st); resto.discard(secondo)
    dirp = np.array(by[secondo]['pos']) - np.array(by[st]['pos']); dirp = dirp / np.hypot(*dirp)
    while resto:
        p = np.array(by[ch[-1]]['pos']); best = None; bd = 1e9
        for i in resto:
            v = np.array(by[i]['pos']) - p; dist = np.hypot(*v)
            if dist > 95: continue
            if dirp is not None and np.dot(v, dirp) < -0.2 * dist: continue
            if dist < bd: bd = dist; best = i
        if best is None: break
        v = np.array(by[best]['pos']) - p; dirp = v / np.hypot(*v)
        ch.append(best); resto.discard(best)
    ordine[lane] = ch
    sp = [np.hypot(*(np.array(by[ch[(k + 1) % len(ch)]]['pos']) - np.array(by[ch[k]]['pos']))) for k in range(len(ch))]
    print('corsia', lane, 'in catena', len(ch), 'rimaste fuori', sorted(resto), 'chiusura', round(sp[-1]))
    for k in range(len(ch)):
        loc = np.median(sp[max(0, k - 4):k + 5])
        if sp[k] < 0.62 * loc or sp[k] > 1.45 * loc:
            print('   spaziatura', round(sp[k]), 'tra', ch[k], 'e', ch[(k + 1) % len(ch)], 'media locale', round(loc), 'a', [round(v) for v in by[ch[k]]['pos']])
d['ordine'] = {str(k): v for k, v in ordine.items()}
json.dump(d, open(sys.argv[2], 'w'))
