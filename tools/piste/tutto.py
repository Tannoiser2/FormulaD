"""Veduta d'insieme del circuito montato: caselle (colore per corsia) e collegamenti di cambio corsia. tutto.py <montato.json> <img> <out> [x0 y0 x1 y1]"""
import sys, json, cv2
d = json.load(open(sys.argv[1])); im = cv2.imread(sys.argv[2]); by = {c['id']: c for c in d['caselle']}
col = {1: (255, 80, 0), 2: (0, 160, 0), 3: (0, 100, 255), 0: (200, 0, 200)}
for c in d['caselle']:
    p = tuple(int(v) for v in c['p'])
    for n in c['n']:
        q = tuple(int(v) for v in by[n]['p'])
        cv2.line(im, p, q, (0, 0, 0) if by[n]['l'] == c['l'] else (0, 0, 255), 1, cv2.LINE_AA)
for c in d['caselle']:
    cv2.circle(im, tuple(int(v) for v in c['p']), 5, col[c['l']], -1)
for k, i in enumerate(d['griglia']): cv2.putText(im, str(k + 1), tuple(int(v) + 6 for v in by[i]['p']), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
if len(sys.argv) > 4:
    x0, y0, x1, y1 = [int(v) for v in sys.argv[4:8]]; im = im[y0:y1, x0:x1]
z = min(1.0, 1560 / max(im.shape[:2]))
cv2.imwrite(sys.argv[3], cv2.resize(im, None, fx=z, fy=z, interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 85])
