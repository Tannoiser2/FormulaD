# Tracciare un circuito nuovo

Ogni circuito ha bisogno di `assets/piste/<id>.jpg` (il tabellone) e `assets/piste/<id>.json` (caselle, collegamenti,
curve e fermate, griglia, traguardo, box, caselle vicine). Gli 11 presenti vengono dal modulo TTS «Formula D: Scripted».

Per gli altri tabelloni (Formula Dé 4-34 e i cittadini di Formula D) la rete delle caselle va ricavata dall'immagine.
Il progetto dell'autore del modulo (github.com/c4tachan/tts-formula-d-2.0, cartella `tools/extract`) ha un rilevatore
a passi: `find_grid` (caselle), `find_corners` (curve e codici), `find_arrows --write` (frecce delle curve),
`find_adjacency` (caselle vicine), `find_pit` (box). Le immagini di tutti i tabelloni sono in `tracks/raw`.

`rileva.py` lancia quei passi con due ritocchi che servono ai tabelloni Formula Dé:

    FD_ESTRAI=<cartella tools/extract>  FD_TRACKS_DIR=...  FD_OUT_DIR=...   (dentro la cartella del progetto clonato)
    FD_ASFALTO=90,128,8,100      soglie di colore dell'asfalto (tinta min e max, saturazione min e max)
    FD_FLAG=x1,y1,x2,y2,spessore la bandiera a scacchi del traguardo, indicata a mano in pixel
    python3 tools/piste/rileva.py find_grid FDe04

## A che punto è (prova su Spa, FDe04)

- con `FD_ASFALTO=90,128,8,100` e `FD_FLAG=2194,312,2244,372,22` `find_grid` trova 533 caselle (51 su divisioni
  ipotizzate): i rettilinei sono buoni, nelle curve strette mancano o si spostano caselle;
- `find_corners` non chiude l'anello delle curve (17 linee rosse trovate, una è di troppo o ne manca una);
- `find_arrows` segnala frecce senza casella e corsie senza sbocco.

Quindi ogni tabellone va corretto a mano dopo il rilevamento (caselle delle curve, linee rosse, frecce, fermate lette
dal tabellone, box) e poi verificato con `tests/sim.gd`. L'editor nel browser dello stesso progetto
(`tools/editor/server.py`) serve proprio a questo.
