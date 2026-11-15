"""Trova le caselle dei tratti senza curve dove il rilevatore non arriva: ogni casella è una macchia di asfalto
chiusa dalle righe scure. La corsia si ricava da che parte sta rispetto a una linea di mezzeria disegnata a mano
nel verso di marcia (corsia 1 a destra).
celle.py <img> <uscita.json> <anteprima.jpg> "x,y x,y x,y ..." ["x,y ..." altre mezzerie]"""
import sys, json, cv2, numpy as np
im = cv2.imread(sys.argv[1]); hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
S, V = hsv[..., 1].astype(int), hsv[..., 2].astype(int)
dentro = ((S < 62) & (V > 150) & (V < 216)).astype(np.uint8)
dentro = cv2.erode(dentro, np.ones((3, 3), np.uint8))
# la strada intera (asfalto e righe scure, senza i bordi bianchi): serve la distanza dal bordo per sapere la corsia
strada = ((S < 70) & (V > 60) & (V < 216)).astype(np.uint8)
strada = cv2.morphologyEx(strada, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
dist, vicino = cv2.distanceTransformWithLabels(strada, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
zy, zx = np.nonzero(strada == 0); etich = vicino[zy, zx]; dove = {int(e): (int(x), int(y)) for e, x, y in zip(etich, zx, zy)}
out = []; ante = im.copy()
for kk, a in enumerate(sys.argv[4:]):
    pl = np.array([[float(v) for v in p.split(',')] for p in a.split()])
    cor = np.zeros(dentro.shape, np.uint8); cv2.polylines(cor, [pl.astype(np.int32)], False, 1, 130)
    n, lab, st, cen = cv2.connectedComponentsWithStats(dentro & cor, 4)
    for i in range(1, n):
        if not 380 <= st[i, 4] <= 3200: continue
        c = cen[i]; best = None; tt = None
        for k in range(len(pl) - 1):
            p, q = pl[k], pl[k + 1]; t = q - p; L = np.hypot(*t); t = t / L; v = c - p
            s = float(v @ t); off = float(t[0] * v[1] - t[1] * v[0])
            if -8 <= s <= L + 8 and (best is None or abs(off) < abs(best)): best = off; tt = t
        if best is None or abs(best) > 62: continue
        cx, cy = int(c[0]), int(c[1]); d = float(dist[cy, cx])
        if d > 50: continue
        if d > 25: lane = 2
        else:
            e = np.array(dove[int(vicino[cy, cx])], float); r = np.array([-tt[1], tt[0]])   # r = destra del verso di marcia
            lane = 1 if float((c - e) @ r) < 0 else 3
        out.append({'pos': [round(float(c[0]), 1), round(float(c[1]), 1)], 'lane': lane, 'area': int(st[i, 4])})
        cv2.circle(ante, (int(c[0]), int(c[1])), 5, {1: (255, 80, 0), 2: (0, 160, 0), 3: (0, 100, 255)}[lane], -1)
    cv2.polylines(ante, [pl.astype(np.int32)], False, (0, 0, 255), 1)
json.dump(out, open(sys.argv[2], 'w')); print(len(out), 'caselle', {l: sum(1 for o in out if o['lane'] == l) for l in (1, 2, 3)})
xs = [o['pos'][0] for o in out]; ys = [o['pos'][1] for o in out]
x0, x1, y0, y1 = int(min(xs)) - 60, int(max(xs)) + 60, int(min(ys)) - 60, int(max(ys)) + 60
t = ante[max(0, y0):y1, max(0, x0):x1]; z = min(2.0, 1500 / max(t.shape[:2]))
cv2.imwrite(sys.argv[3], cv2.resize(t, None, fx=z, fy=z), [cv2.IMWRITE_JPEG_QUALITY, 85])
