"""Porta nel gioco un circuito tracciato: file delle caselle, tabellone, miniatura e immagine per i telefoni.
installa.py <id> <circuito montato.json> <tabellone.jpg|png>"""
import sys, shutil, os
from PIL import Image
pid, js, img = sys.argv[1:4]
base = os.path.join(os.path.dirname(__file__), '..', '..')
shutil.copy(js, f'{base}/assets/piste/{pid}.json')
im = Image.open(img).convert('RGB')
im.save(f'{base}/assets/piste/{pid}.jpg', quality=88)
open(f'{base}/assets/piste/{pid}.jpg.import', 'w').write('[remap]\n\nimporter="keep"\n')
m = im.copy(); m.thumbnail((480, 480)); m.save(f'{base}/assets/piste/mini/{pid}.webp', quality=80)
w = im.copy(); w.thumbnail((1800, 1800)); w.save(f'{base}/web/img/piste/{pid}.webp', quality=72)
print('installato', pid, im.size)
