"""Mosaico dei cartelli L/C: segni.py <img> <out> x0,y0,x1,y1 ..."""
import sys
from PIL import Image
im = Image.open(sys.argv[1]); bs = [[int(v) for v in a.split(',')] for a in sys.argv[3:]]
Z = 5; W = sum((b[2] - b[0]) * Z for b in bs); H = max((b[3] - b[1]) * Z for b in bs); out = Image.new('RGB', (W, H)); x = 0
for b in bs:
    c = im.crop(b).resize(((b[2] - b[0]) * Z, (b[3] - b[1]) * Z), Image.LANCZOS); out.paste(c, (x, 0)); x += c.size[0]
out.save(sys.argv[2])
