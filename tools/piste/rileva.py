"""Lancia uno strumento di rilevamento dell'autore del modulo, con ritocchi per i tabelloni Formula Dé:
soglie dell'asfalto (FD_ASFALTO="hmin,hmax,smin,smax") e bandiera del traguardo indicata a mano
(FD_FLAG="x1,y1,x2,y2,spessore", in pixel dell'immagine).
Uso: python3 rileva.py <strumento> <pista> [argomenti dello strumento]"""
import sys, os
sys.path.insert(0, os.environ.get('FD_ESTRAI', '/home/claude/c4/tools/extract'))
import cv2, numpy as np
import detect_track
strumento = sys.argv[1]
if os.environ.get('FD_ASFALTO'):
    hmin, hmax, smin, smax = [int(x) for x in os.environ['FD_ASFALTO'].split(',')]
    def asfalto(hsv):
        H, S, V = hsv[..., 0], hsv[..., 1], hsv[..., 2]
        if detect_track.PALETTE["palette"] == "formula_de":
            return (H >= hmin) & (H <= hmax) & (S >= smin) & (S < smax) & (V > 120) & (V < 240)
        tinted = (H >= 10) & (H < 110) & (S >= 12)
        return (S < 50) & (V > 105) & (V < 205) & ~tinted
    detect_track.asphalt = asfalto
import find_grid
if os.environ.get('FD_FLAG'):
    x1, y1, x2, y2, sp = [int(float(x)) for x in os.environ['FD_FLAG'].split(',')]
    def bandiera(track, road, line):
        band = np.zeros(road.shape, np.uint8)
        cv2.line(band, (x1, y1), (x2, y2), 1, sp)
        return band
    find_grid._flag_band = bandiera
import importlib
mod = find_grid if strumento == 'find_grid' else importlib.import_module(strumento)
sys.argv = [strumento] + sys.argv[2:]
sys.exit(mod.main())
