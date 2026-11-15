"""Caselle dei rettilinei senza rilevatore: lungo una mezzeria disegnata a mano (nel verso di marcia) misura la larghezza
della strada, la divide in tre corsie e in ogni corsia cerca le righe trasversali; ogni tratto fra due righe è una casella.
fila.py <img> <uscita.json> <anteprima.jpg> "x,y x,y ..." ["x,y ..." altri tratti]      (corsia 1 = a destra)"""
import sys, json, cv2, numpy as np
im = cv2.imread(sys.argv[1]); hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
H, S, V = [hsv[..., k].astype(int) for k in range(3)]
verde = (H > 22) & (H < 92) & (S > 45); bianco = (S < 28) & (V > 212); rosso = ((H < 14) | (H > 166)) & (S > 110) & (V > 120)
sabbia = (H >= 14) & (H <= 34) & (S > 60)
strada = ~(verde | bianco | rosso | sabbia) & (V > 70)
Vf = cv2.GaussianBlur(hsv[..., 2].astype(np.float32), (0, 0), 1.0)
hh, ww = strada.shape
def val(a, p):
    x, y = int(round(p[0])), int(round(p[1]))
    return a[y, x] if 0 <= x < ww and 0 <= y < hh else False
out = []; ante = im.copy()
for a in sys.argv[4:]:
    pl = np.array([[float(v) for v in p.split(',')] for p in a.split()])
    # punti ogni pixel lungo la mezzeria
    pts = []; tans = []
    for k in range(len(pl) - 1):
        p, q = pl[k], pl[k + 1]; L = np.hypot(*(q - p)); t = (q - p) / L
        for s in np.arange(0, L, 1.0): pts.append(p + t * s); tans.append(t)
    pts = np.array(pts); tans = np.array(tans)
    # tangenti lisciate
    kk = np.ones(41) / 41; tans = np.stack([np.convolve(tans[:, 0], kk, 'same'), np.convolve(tans[:, 1], kk, 'same')], 1)
    tans /= np.linalg.norm(tans, axis=1)[:, None]; nor = np.stack([-tans[:, 1], tans[:, 0]], 1)   # nor = destra del verso di marcia
    dx = []; sx = []
    for p, n in zip(pts, nor):
        # la striscia di strada più lunga attraverso la mezzeria (la mezzeria disegnata può essere spostata)
        r = [val(strada, p + n * o) for o in range(-110, 111)]
        best = (0, 0, 0); i = 0
        while i < len(r):
            if r[i]:
                j = i
                while j < len(r) and r[j]: j += 1
                if j - i > best[0]: best = (j - i, i - 110, j - 1 - 110)
                i = j
            else: i += 1
        dx.append(best[2]); sx.append(-best[1])
    med = lambda v: np.array([np.median(v[max(0, i - 30):i + 31]) for i in range(len(v))])
    dx = med(np.array(dx, float)); sx = med(np.array(sx, float))
    for lane, f in ((1, 5 / 6), (2, 3 / 6), (3, 1 / 6)):
        c = pts + nor * (dx - (dx + sx) * (1 - f))[:, None]          # f = quota di larghezza a partire dal bordo sinistro
        prof = np.array([np.mean([Vf[int(round(q[1])), int(round(q[0]))] for q in (p + n * o for o in (-7, -4, 0, 4, 7))
                                  if 0 <= int(round(q[0])) < ww and 0 <= int(round(q[1])) < hh] or [0]) for p, n in zip(c, nor)])
        red = np.array([val(rosso, p) or not val(strada, p) for p in c])
        base = np.array([np.median(prof[max(0, i - 25):i + 26]) for i in range(len(prof))])
        buio = (base - prof > 7) | red
        tagli = []; i = 0
        while i < len(buio):
            if buio[i]:
                j = i
                while j < len(buio) and buio[j]: j += 1
                tagli.append((i + j - 1) / 2); i = j
            else: i += 1
        for a0, a1 in zip(tagli, tagli[1:]):
            if 26 <= a1 - a0 <= 68:
                p = c[int((a0 + a1) / 2)]
                out.append({'pos': [round(float(p[0]), 1), round(float(p[1]), 1)], 'lane': lane})
                cv2.circle(ante, (int(p[0]), int(p[1])), 5, {1: (255, 80, 0), 2: (0, 160, 0), 3: (0, 100, 255)}[lane], -1)
            elif a1 - a0 > 68:
                p = c[int((a0 + a1) / 2)]; cv2.circle(ante, (int(p[0]), int(p[1])), 9, (255, 0, 255), 2)
        for t in tagli:
            p = c[int(t)]; cv2.circle(ante, (int(p[0]), int(p[1])), 2, (0, 0, 0), -1)
json.dump(out, open(sys.argv[2], 'w')); print(len(out), 'caselle', {l: sum(1 for o in out if o['lane'] == l) for l in (1, 2, 3)})
z = min(1.0, 1900 / max(ante.shape[:2])); cv2.imwrite(sys.argv[3], cv2.resize(ante, None, fx=z, fy=z), [cv2.IMWRITE_JPEG_QUALITY, 85])
