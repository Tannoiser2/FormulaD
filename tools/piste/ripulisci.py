"""Prepara il tabellone per il rilevatore: ridipinge di asfalto le righe colorate delle curve che stanno dentro la strada
(non i cordoli) e, se dato, il traguardo. ripulisci.py <img> <out.png> hmin hmax smin smax [x0,y0,x1,y1,larg]"""
import sys, cv2, numpy as np
im = cv2.imread(sys.argv[1]); h = cv2.cvtColor(im, cv2.COLOR_BGR2HSV); a, b, c, d = [int(v) for v in sys.argv[3:7]]
H, S, V = h[..., 0], h[..., 1], h[..., 2]
asf = ((H >= a) & (H <= b) & (S >= c) & (S <= d) & (V > 110)).astype(np.float32)
col = np.median(im[asf > 0], axis=0)
riga = ((H < 36) | (H > 168)) & (S > 90) & (V > 140)
quota = cv2.boxFilter(asf, -1, (31, 31))
dentro = cv2.dilate((riga & (quota > 0.56)).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
out = im.copy(); out[dentro] = col
if len(sys.argv) > 7:
    x0, y0, x1, y1, w = [int(v) for v in sys.argv[7].split(',')]; cv2.line(out, (x0, y0), (x1, y1), [int(v) for v in col], w)
cv2.imwrite(sys.argv[2], out); print('ridipinti', int(dentro.sum()), 'pixel; asfalto', col)
