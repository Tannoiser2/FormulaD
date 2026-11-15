"""Ritaglio ingrandito senza scritte, con le coordinate del tabellone sui bordi. crudo.py <img> <out> <zoom> x0 y0 x1 y1"""
import sys, cv2
im = cv2.imread(sys.argv[1]); Z = float(sys.argv[3]); x0, y0, x1, y1 = [int(v) for v in sys.argv[4:8]]
t = cv2.resize(im[y0:y1, x0:x1], None, fx=Z, fy=Z, interpolation=cv2.INTER_CUBIC)
for gx in range((x0 // 20 + 1) * 20, x1, 20):
    cv2.line(t, (int((gx - x0) * Z), 0), (int((gx - x0) * Z), 6), (0, 0, 255), 1)
    cv2.putText(t, str(gx), (int((gx - x0) * Z) - 12, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 255), 1)
for gy in range((y0 // 20 + 1) * 20, y1, 20):
    cv2.line(t, (0, int((gy - y0) * Z)), (6, int((gy - y0) * Z)), (0, 0, 255), 1)
    cv2.putText(t, str(gy), (8, int((gy - y0) * Z) + 4), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 255), 1)
cv2.imwrite(sys.argv[2], t, [cv2.IMWRITE_JPEG_QUALITY, 88]); print(t.shape)
