#!/usr/bin/env python3
"""Controlla che ogni carattere usato nei testi del gioco esista nei font (niente quadratini).

Uso: python3 tools/controlla_glifi.py
Legge le stringhe di scripts/*.gd e della pagina dei telefoni e le confronta con Racing Sans One (titoli)
e Barlow Condensed (testi). I titoli (UI.testo(..., true), h1, h2, .grande, .dado) devono stare in entrambi.
Esce con errore se manca qualcosa.
"""
import glob, json, os, re, sys
from fontTools.ttLib import TTFont

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
testi = []
for f in glob.glob(R + '/scripts/*.gd'):
    src = open(f, encoding='utf-8').read()
    src = '\n'.join(l for l in src.splitlines() if not l.strip().startswith('#'))
    testi += re.findall(r'"((?:[^"\\]|\\.)*)"', src)
for f in [R + '/web/js/telefono.js', R + '/web/shell.html', R + '/web/telefono.html']:
    src = open(f, encoding='utf-8').read()
    src = re.sub(r'(?m)^\s*//[^\n]*', '', src)
    testi += re.findall(r"'((?:[^'\\]|\\.)*)'", src)
    testi += re.findall(r'`([^`]*)`', src, re.S)
    testi += re.findall(r'>([^<>{}]+)<', src)
# i nomi dei circuiti e dei piloti finiscono nei titoli
for f in glob.glob(R + '/assets/piste/*.json'):
    testi.append(json.load(open(f, encoding='utf-8'))['nome'])
    testi.append(json.load(open(f, encoding='utf-8'))['nome'].upper())
caratteri = set(''.join(testi)) - set('\n\t\r')
errori = 0
for font in ['RacingSansOne-Regular.ttf', 'BarlowCondensed-Bold.ttf', 'BarlowCondensed-Medium.ttf']:
    cmap = TTFont(R + '/assets/font/' + font).getBestCmap()
    manca = sorted(ch for ch in caratteri if ord(ch) not in cmap and ord(ch) > 31)
    if manca:
        print(f'{font}: mancano {"".join(manca)!r} ' + ' '.join(f'U+{ord(c):04X}' for c in manca))
        errori += 1
    else:
        print(f'{font}: tutti i {len(caratteri)} caratteri presenti')
sys.exit(1 if errori else 0)
