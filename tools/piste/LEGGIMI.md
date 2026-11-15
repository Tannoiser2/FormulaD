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

## Come è stata fatta Spa (FDe04), passo per passo

Il rilevatore serve solo per il primo passo (le caselle). Il resto si fa con gli script di questa cartella; i dati
di Spa sono in `spa/` (`g7.json` le caselle corrette, `spec.json` tutto quello che si legge dal tabellone).

1. `rileva.py find_grid FDe04` con `FD_ASFALTO=90,128,8,100` e `FD_FLAG=2194,312,2244,372,22`: 533 caselle,
   buone nei rettilinei, da sistemare nelle curve strette.
2. `zona.py`, `crudo.py`, `curva.py`: ritagli ingranditi del tabellone con le sigle delle caselle, per guardare
   una curva alla volta.
3. `correggi.py`: sposta, toglie, aggiunge caselle (a Spa una trentina di ritocchi: bandiera, Eau Rouge, chicane).
4. `corsie.py`: mette in fila le tre corsie a partire dalla coppia "prima casella, seconda casella" di ognuna.
5. `spec.json`: nome, giri, traguardo, griglia, per ogni curva prima e ultima casella di ogni corsia, fermate e i
   numeri stampati sul cartello (L = percorso più lungo, C = più corto), corsia dei box, e le caselle con la
   doppia freccia (`forche`: 1 o 3 = corsia verso cui va la seconda freccia, 2 = dal bordo verso il centro,
   0 = decide il programma). `collega` / `scollega` correggono un singolo collegamento.
6. `monta.py g7.json spec.json FDe04.json`: costruisce il file del gioco e, per ogni curva, confronta il percorso
   più lungo e più corto con i numeri stampati. È il controllo che conta: se una freccia è letta male i numeri
   non tornano. `prova_forche.py` prova tutte le combinazioni dei lati incerti di una curva.
7. `tests/sim.gd 8 "" FDe04`: otto gare automatiche senza errori, poi le fotografie (`PISTA=FDe04 gfoto ...`).

Su Spa tutte le 8 curve tornano con i numeri stampati. Resta un margine: dove più letture delle frecce danno gli
stessi numeri (corsia centrale di alcune curve) è stata scelta la lettura che si vede sul tabellone ingrandito.
