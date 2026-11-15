"""Mostra dove la soglia dell'asfalto trova la strada: maschera.py <img> <out> hmin hmax smin smax"""
import sys, cv2, numpy as np
im = cv2.imread(sys.argv[1]); h = cv2.cvtColor(im, cv2.COLOR_BGR2HSV); a, b, c, d = [int(v) for v in sys.argv[3:7]]
H, S, V = h[..., 0], h[..., 1], h[..., 2]
m = (H >= a) & (H <= b) & (S >= c) & (S < d) & (V > 120) & (V < 240)
o = np.where(m[..., None], im, 255).astype(np.uint8)
cv2.imwrite(sys.argv[2], cv2.resize(o, None, fx=0.55, fy=0.55, interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 80])
