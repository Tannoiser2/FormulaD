"""Ritaglio ingrandito di una zona: caselle numerate e collegamenti (frecce sottili: nere stessa corsia, rosse cambio).
Uso: zona.py <pista.json> <immagine> <uscita.jpg> <zoom> <id> <id> ...   (il riquadro contiene le caselle elencate)
     zona.py ... box x0 y0 x1 y1"""
import sys, json, cv2, numpy as np
d = json.load(open(sys.argv[1])); im = cv2.imread(sys.argv[2]); out = sys.argv[3]; Z = float(sys.argv[4])
col = {1: (255, 80, 0), 2: (0, 150, 0), 3: (0, 110, 255), 0: (200, 0, 200)}
by = {str(s['id']): s for s in d['spaces']}
arg = sys.argv[5:]
link = True
if 'nolink' in arg: link = False; arg.remove('nolink')
if arg[0] == 'box':
    x0, y0, x1, y1 = [int(v) for v in arg[1:5]]
else:
    P = np.array([by[i]['pos'] for i in arg]); x0, y0 = (P.min(0) - 45).astype(int); x1, y1 = (P.max(0) + 45).astype(int)
x0, y0 = max(0, x0), max(0, y0)
t = cv2.resize(im[y0:y1, x0:x1], None, fx=Z, fy=Z, interpolation=cv2.INTER_CUBIC)
def pt(p): return np.array([int((p[0] - x0) * Z), int((p[1] - y0) * Z)])
for s in d['spaces']:
    if not (x0 <= s['pos'][0] < x1 and y0 <= s['pos'][1] < y1): continue
    if link:
        for n in s.get('next', []):
            n = str(n)
            if n in by:
                A = pt(s['pos']); B = pt(by[n]['pos'])
                c = (0, 0, 0) if by[n].get('lane') == s.get('lane') else (0, 0, 230)
                cv2.arrowedLine(t, tuple(A), tuple((A + (B - A) * 0.8).astype(int)), (255, 255, 255), 3, cv2.LINE_AA, tipLength=0.25)
                cv2.arrowedLine(t, tuple(A), tuple((A + (B - A) * 0.8).astype(int)), c, 1, cv2.LINE_AA, tipLength=0.25)
for s in d['spaces']:
    if not (x0 <= s['pos'][0] < x1 and y0 <= s['pos'][1] < y1): continue
    c = col.get(s.get('lane', 0), (255, 255, 255))
    if s.get('pit'): c = (200, 0, 200)
    x, y = pt(s['pos'])
    cv2.circle(t, (x, y), 4, c, -1)
    tx = str(s['id'])
    cv2.putText(t, tx, (x - 10, y - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 3, cv2.LINE_AA)
    cv2.putText(t, tx, (x - 10, y - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.5, c, 1, cv2.LINE_AA)
cv2.putText(t, f"origine ({x0},{y0}) zoom {Z}", (6, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 255), 1)
cv2.imwrite(out, t, [cv2.IMWRITE_JPEG_QUALITY, 85]); print(t.shape[1], t.shape[0], (x0, y0))
