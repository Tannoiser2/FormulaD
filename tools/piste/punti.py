"""Mosaico di ritagli ingranditi attorno a dei punti, con le caselle (puntino e numero, colore per corsia).
punti.py <caselle.json> <img> <out.jpg> <zoom> <larg> <alt> x,y x,y ..."""
import sys, json, cv2, numpy as np
d = json.load(open(sys.argv[1])); im = cv2.imread(sys.argv[2]); Z = float(sys.argv[4]); W, H = int(sys.argv[5]), int(sys.argv[6])
col = {1: (255, 80, 0), 2: (0, 160, 0), 3: (0, 100, 255), 0: (200, 0, 200)}
pezzi = []
for a in sys.argv[7:]:
    cx, cy = [int(v) for v in a.split(',')]
    x0, y0 = max(0, cx - W // 2), max(0, cy - H // 2)
    t = cv2.resize(im[y0:y0 + H, x0:x0 + W], None, fx=Z, fy=Z, interpolation=cv2.INTER_CUBIC)
    for s in d['spaces']:
        x, y = s['pos']
        if x0 <= x < x0 + W and y0 <= y < y0 + H:
            p = (int((x - x0) * Z), int((y - y0) * Z))
            cv2.circle(t, p, 4, col.get(s['lane'], (0, 0, 0)), -1)
            cv2.putText(t, str(s['id']), (p[0] + 5, p[1] - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 3)
            cv2.putText(t, str(s['id']), (p[0] + 5, p[1] - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.42, col.get(s['lane'], (0, 0, 0)), 1)
    cv2.putText(t, f'{x0},{y0}', (4, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 255), 1)
    full = np.zeros((int(H * Z), int(W * Z), 3), np.uint8); full[:t.shape[0], :t.shape[1]] = t
    pezzi.append(full)
n = 2 if len(pezzi) > 1 else 1
righe = [np.hstack(pezzi[i:i + n] + [np.zeros_like(pezzi[0])] * (n - len(pezzi[i:i + n]))) for i in range(0, len(pezzi), n)]
cv2.imwrite(sys.argv[3], np.vstack(righe), [cv2.IMWRITE_JPEG_QUALITY, 85]); print(np.vstack(righe).shape)
