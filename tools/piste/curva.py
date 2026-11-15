"""Ritaglio pulito di una zona con un puntino minuscolo e una sigla corta su ogni casella di curva (corsia+progressivo
nella curva), per leggere le frecce. curva.py <pista montata.json> <img> <out> <zoom> x0 y0 x1 y1"""
import sys, json, cv2
d = json.load(open(sys.argv[1])); im = cv2.imread(sys.argv[2]); Z = float(sys.argv[4]); x0, y0, x1, y1 = [int(v) for v in sys.argv[5:9]]
t = cv2.resize(im[y0:y1, x0:x1], None, fx=Z, fy=Z, interpolation=cv2.INTER_CUBIC)
col = {1: (255, 60, 0), 2: (0, 130, 0), 3: (0, 90, 255), 0: (200, 0, 200)}
for c in d['caselle']:
    x, y = c['p']
    if not (x0 <= x < x1 and y0 <= y < y1): continue
    px, py = int((x - x0) * Z), int((y - y0) * Z)
    cv2.circle(t, (px, py), 3, col[c['l']], -1)
    cv2.putText(t, c['id'], (px + 4, py + 4), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 2, cv2.LINE_AA)
    cv2.putText(t, c['id'], (px + 4, py + 4), cv2.FONT_HERSHEY_SIMPLEX, 0.38, col[c['l']], 1, cv2.LINE_AA)
cv2.imwrite(sys.argv[3], t, [cv2.IMWRITE_JPEG_QUALITY, 88]); print(t.shape)
