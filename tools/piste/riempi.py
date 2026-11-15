"""Chiude i buchi di una o due caselle lungo ogni corsia (di solito accanto alle righe delle curve e sul traguardo).
riempi.py <caselle.json> <uscita.json> <img> <anteprima.jpg> a,b a,b a,b    (prima e seconda casella di ogni corsia)"""
import sys, json, cv2, numpy as np
g = json.load(open(sys.argv[1])); by = {s['id']: s for s in g['spaces']}; im = cv2.imread(sys.argv[3]); nuove = []; nid = 9500
for l, a in enumerate(sys.argv[5:8], 1):
    st, se = [int(v) for v in a.split(',')]
    resto = {s['id'] for s in g['spaces'] if s['lane'] == l} - {st, se}; ch = [st, se]
    while resto:
        p = np.array(by[ch[-1]]['pos']); d = p - np.array(by[ch[-2]]['pos']); d = d / np.hypot(*d); best = None; bd = 1e9
        for i in resto:
            v = np.array(by[i]['pos']) - p; n = np.hypot(*v)
            if n < 150 and (v @ d) / n > 0.1 and n < bd: bd = n; best = i
        if best is None: break
        if bd > 66 and not (1000 <= ch[-1] < 9000 and 1000 <= best < 9000):   # mai dentro una curva letta a mano
            k = 1 if bd < 112 else 2
            for j in range(1, k + 1):
                q = p + (np.array(by[best]['pos']) - p) * j / (k + 1); nid += 1
                s = {'id': nid, 'pos': [round(float(q[0]), 1), round(float(q[1]), 1)], 'lane': l, 'rot': 0, 'next': [], 'corner': None, 'sector': 0}
                nuove.append(s); by[nid] = s; ch.append(nid)
        ch.append(best); resto.discard(best)
    # chiusura sull'inizio
    p = np.array(by[ch[-1]]['pos']); q0 = np.array(by[st]['pos']); bd = np.hypot(*(q0 - p))
    if 66 < bd < 150:
        k = 1 if bd < 112 else 2
        for j in range(1, k + 1):
            q = p + (q0 - p) * j / (k + 1); nid += 1
            nuove.append({'id': nid, 'pos': [round(float(q[0]), 1), round(float(q[1]), 1)], 'lane': l, 'rot': 0, 'next': [], 'corner': None, 'sector': 0})
    print('corsia', l, 'in fila', len(ch), 'fuori', len(resto), 'ultima', ch[-1], by[ch[-1]]['pos'])
g['spaces'] += nuove; json.dump(g, open(sys.argv[2], 'w')); print('aggiunte', len(nuove), [(s['lane'], [round(v) for v in s['pos']]) for s in nuove])
W = 150; Z = 2; pezzi = []
for s in nuove[:24]:
    x0, y0 = max(0, int(s['pos'][0]) - W // 2), max(0, int(s['pos'][1]) - W // 2)
    t = cv2.resize(im[y0:y0 + W, x0:x0 + W], None, fx=Z, fy=Z)
    for o in g['spaces']:
        x, y = o['pos']
        if x0 <= x < x0 + W and y0 <= y < y0 + W:
            cv2.circle(t, (int((x - x0) * Z), int((y - y0) * Z)), 5, (255, 0, 255) if o['id'] > 9500 else {1: (255, 80, 0), 2: (0, 160, 0), 3: (0, 100, 255)}[o['lane']], -1)
    f = np.zeros((W * Z, W * Z, 3), np.uint8); f[:t.shape[0], :t.shape[1]] = t; pezzi.append(f)
if pezzi:
    while len(pezzi) % 6: pezzi.append(np.zeros_like(pezzi[0]))
    cv2.imwrite(sys.argv[4], np.vstack([np.hstack(pezzi[i:i + 6]) for i in range(0, len(pezzi), 6)]), [cv2.IMWRITE_JPEG_QUALITY, 80])
