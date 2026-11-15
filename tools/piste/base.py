"""Fa il file di caselle di partenza dalle caselle trovate con fila.py: base.py <fila.json> <uscita.json>"""
import sys, json
c = json.load(open(sys.argv[1]))
json.dump({'spaces': [{'id': k + 1, 'pos': o['pos'], 'lane': o['lane'], 'rot': 0, 'next': [], 'corner': None, 'sector': 0} for k, o in enumerate(c)]}, open(sys.argv[2], 'w'))
