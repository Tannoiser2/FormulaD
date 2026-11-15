"""Prepara il tabellone per il rilevatore quando la strada si confonde con il resto: tiene solo un corridoio attorno a una
mezzeria disegnata a mano (anello chiuso), dipinge di verde tutto il resto e uniforma l'asfalto chiaro.
corridoio.py <img> <out.png> <mezza larghezza> <scala punti> "x,y x,y ..." [b,g,r asfalto]"""
import sys, cv2, numpy as np
im = cv2.imread(sys.argv[1]); w = int(sys.argv[3]); k = float(sys.argv[4])
pl = np.array([[float(v) * k for v in p.split(',')] for p in sys.argv[5].split()]).astype(np.int32)
cor = np.zeros(im.shape[:2], np.uint8); cv2.polylines(cor, [pl], True, 1, 2 * w)
out = im.copy(); out[cor == 0] = (60, 150, 60)
if len(sys.argv) > 6:
    col = [int(v) for v in sys.argv[6].split(',')]; h = cv2.cvtColor(im, cv2.COLOR_BGR2HSV); S, V = h[..., 1], h[..., 2]
    chiaro = (cor == 1) & (S < 45) & (V > 150) & (V <= 232)
    out[chiaro] = col
cv2.imwrite(sys.argv[2], out)
cv2.imwrite(sys.argv[2].replace('.png', '_v.jpg'), cv2.resize(out, None, fx=0.56, fy=0.56), [cv2.IMWRITE_JPEG_QUALITY, 80])
