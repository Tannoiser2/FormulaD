# Formula D

Versione digitale di **Formula D** (Asmodee), la corsa automobilistica con le marce e i dadi, fatta con Godot 4.7.
Si gioca qui: **https://tannoiser2.github.io/FormulaD/**

- **Tabellone originale in 3D**: si sposta trascinando, si avvicina con la rotella o pizzicando con due dita, si ruota
  con il tasto destro o girando due dita (funziona con mouse e con il tocco, anche su iPad).
- **Pezzi originali** dal modulo Tabletop Simulator «Formula D: Scripted»: le auto di Formula 1, i sei dadi delle marce
  (che rotolano in 3D), la plancia del pilota (base e avanzata) con i perni dei punti e la leva del cambio, i segnalini
  dei detriti, le carte dei dieci piloti delle cinque scuderie.
- **Anteprima della marcia**: il primo tocco su una marcia mostra sul tabellone tutte le caselle dove può portare e, tiro per
  tiro, che cosa costa nel caso migliore; il secondo tocco la conferma. La telecamera si può fermare («Telecamera: ferma»)
  perché non insegua ogni mossa.
- **Telefono**: plancia originale con le marce da toccare, punti dell'auto, il pezzo di pista che interessa e l'ordine di
  gioco; in verticale uno sotto l'altro, in orizzontale plancia a sinistra, pista al centro, ordine a destra.
- **22 circuiti**: Monaco, Hockenheim, Sebring, Valencia, Singapore, Austin, Buddh, Sochi e quattordici tracciati Formula Dé (Monaco, Zandvoort e variante, Spa-Francorchamps, Imola, Monza, Interlagos, Silverstone, Montreal, Hockenheim, Zeltweg, Barcellona, Suzuka, Nürburgring)
  (Monaco, Zandvoort e la sua variante). Ognuno ha la rete completa di caselle, corsie, frecce delle curve, griglia e box.
- **Regole base e avanzate**, da 1 a 3 giri, fino a 10 auto.
- **Piloti guidati dal computer** (prudente, normale, esperto) per giocare da soli.
- **Online e telefoni**: chi apre una stanza mostra il tabellone (TV, monitor, iPad); gli altri entrano con il gioco
  completo da un altro schermo oppure **dal telefono**, inquadrando il QR code, e da lì scelgono marcia e casella.
- **Tutto in italiano**, comprese le regole in breve dentro il gioco.
- **Gara salvata a ogni turno** (sul dispositivo e, per le stanze, anche su Firebase): dal menu, *Riprendi la gara salvata*.

## Come si gioca

1. **Gara su questo schermo** - scegli circuito, giri, regole e chi guida ognuna delle dieci auto (questo schermo,
   computer, oppure non corre). Con più auto su «Questo schermo» si gioca a turno.
2. **TV + telefoni / Online** - si apre una stanza con un codice di 4 lettere e il QR code. I posti segnati
   «Telefono / online» vengono presi da chi entra; quelli rimasti liberi alla partenza non corrono.
   Dal telefono: inquadra il QR (o apri `telefono.html` e scrivi il codice), scrivi il nome e aspetta il via.
   Da un altro computer o iPad: *Entra in una stanza* e scrivi il codice.
3. Al tuo turno **scegli la marcia** (i pulsanti hanno il colore del dado e dicono quanto costa scalare), il dado
   rotola e sul tabellone si colorano le **caselle dove puoi arrivare**: verde libera, gialla costa punti (il numero
   dice quanti), arancione testacoda, rossa ritiro, azzurra il tuo box, bianca il traguardo. Tocca una casella per
   leggere che cosa comporta, poi **Conferma** (o tocca di nuovo la stessa casella).
4. A destra, una sotto l'altra, l'ordine di gioco del turno (marcia, giro e punti di ogni auto: toccando una riga
   si inquadra quell'auto e si vede la sua plancia), la cronaca e la plancia; in alto a sinistra i dadi.
5. Le caselle raggiungibili sono colorate (verde libera, giallo costa punti...) con sopra l'icona della zona che si
   rovina e quanti punti si perdono; il pulsante «Sulle caselle» passa alle parole (Gomme 2, Freni 1...).
6. A fine gara **Rivedi la gara** fa il replay di tutta la corsa: in ogni turno le auto si muovono insieme, ognuna
   alla sua velocità, senza pause fra un turno e l'altro (si può rallentare, accelerare o interrompere).

Se un pilota da telefono si è distratto, chi ospita può premere **Decidi tu al suo posto**.

## Le regole seguite

Sono quelle dei due regolamenti del gioco (base e avanzato), come le applica il modulo «Formula D: Scripted», più alcune
regole facoltative che si accendono nella preparazione della gara (vedi sotto). In breve:

- marce 1a 1-2, 2a 2-4, 3a 4-8, 4a 7-12, 5a 11-20, 6a 21-30; si sale di una, si scala di una gratis e fino a tre
  saltate pagando;
- in rettilineo si va per la via più breve (niente zigzag), in curva valgono le frecce; ogni curva ha le sue fermate
  obbligatorie; chi esce prima va lungo e paga una casella alla volta, restando nella sua corsia; con due fermate
  mancanti l'auto è eliminata;
- si può frenare (avanzare meno del tiro) pagando;
- partenza con il dado nero (1 motore spento; 17-20 nelle regole base o 20 nelle avanzate: partenza lampo di 4 caselle);
- 20 in 5a o 30 in 6a: motori sotto sforzo per tutte le auto in 5a e 6a;
- collisioni per chi finisce accanto o dietro un'altra auto (tirano il dado nero chi arriva e chi è toccato);
- box tra un giro e l'altro: corsia senza frenate, scalate, collisioni né sforzo; si riparte al massimo in 4a;
- avanzate: sei zone (Gomme 6, Freni 3, Cambio 3, Carrozzeria 3, Motore 3, Tenuta 2), testacoda, scie, detriti,
  sosta rapida o lenta.

### Regole facoltative

- **Assetto libero** (avanzate, in circuito): prima del via ognuno ripartisce 20 punti fra le zone (Gomme 1-14,
  le altre 1-7). Il computer usa un assetto prudente.
- **Meteo** (avanzate): il dado nero decide il tempo al via (bel tempo, variabile, pioggia) e cambia con i motori
  sotto sforzo. Si scelgono le gomme dure, morbide o da pioggia, e al box si possono cambiare. Con la pioggia
  collisioni, sforzo e detriti sono più probabili.
- **Gara su strada** (base e avanzate): niente box, **Nitro** una volta per giro (si aggiungono tante caselle quanto
  la marcia), controllo al traguardo che rende qualche punto. Con le avanzate ogni pilota ha la sua auto e un'abilità.

Semplificazioni: la radio di Stanley e i detriti di Temana sono automatici; i punti del controllo vanno da soli alle
zone più danneggiate; niente sosta tecnica né giro di qualifica (la griglia la decide il dado nero); una sola tabella
del meteo per tutti i circuiti. I circuiti cittadini con le loro zone speciali (polizia, tunnel...) non ci sono ancora:
la gara su strada si corre sui circuiti presenti.

Il riepilogo completo è nel gioco (pulsante **Regole**) e in `scripts/dati.gd`.

Le auto che tagliano il traguardo o si ritirano lasciano la pista. Se più auto arrivano nello stesso turno, l'ordine
d'arrivo è quello di gioco (prima chi era davanti).

## Per chi lo sviluppa

- `scripts/` - `motore.gd` le regole (senza grafica, stato salvabile), `mosse.gd` il calcolo delle caselle
  raggiungibili (trasposizione della logica del modulo), `pista.gd` i circuiti e l'ordine di gioco, `ia.gd` i piloti
  del computer, `mondo.gd` il tavolo 3D e la visuale (mouse e tocco), `interfaccia.gd` + `plancia.gd` + `dado3d.gd`
  l'interfaccia, `menu.gd` menu e stanza, `main.gd` il collegamento di tutto, `rete.gd` il ponte con la pagina web.
- `assets/piste/` - per ogni circuito l'immagine del tabellone e il file `.json` con caselle, collegamenti, curve,
  griglia, traguardo, box e caselle vicine (estratti dal modulo). Per aggiungere un circuito servono questi due file
  e il suo nome in `Dati.PISTE`.
- `web/` - la pagina del gioco (`shell.html`), il ponte `js/ponte.js`, la pagina dei telefoni (`telefono.html`,
  `js/telefono.js`, `css/telefono.css`), `js/rete.js` (Firebase o rete locale per le prove), `js/suoni.js`.
- **Firebase**: progetto condiviso della ludoteca, radice `formulad`. Usa la **regola comune** `$game` della ludoteca,
  senza aggiungere nulla nella console: stanza in `formulad/rooms/<CODICE>` con `host`, `status`, `seats/<uid>`
  (i giocatori), `game` (lo stato della gara, a pezzi di 15000 caratteri), `acts` (le mosse, ognuna con il numero
  dello stato a cui risponde) e `labels` (la copia del salvataggio della gara, scritta solo da chi ospita).
  Riprendendo una gara con i telefoni si riapre la stessa stanza, con lo stesso codice.
  Le gare su un solo schermo si salvano sul dispositivo; il gioco prova anche a copiarle in
  `formulad/salvataggi/<uid>`, che funziona quando nella console è pubblicata la parte `salvataggi` della regola
  comune (oggi il database la rifiuta, e il gioco prosegue senza errori).
- Prove:
  - `godot --headless --path . -s tests/sim.gd -- 22` - gare automatiche su tutti i circuiti, controlla le regole e
    il salvataggio;
  - `godot --path . -s tests/foto.gd -- /tmp/foto 1920 1080 avanzate` - fotografie dell'interfaccia;
  - `tools/costruisci_web.sh` - esporta in `build/web` (gioco + telefoni);
  - `node tests/browser.mjs build/web /tmp/prova 2 600` - schermo grande, 2 telefoni e un ospite nel browser con la
    rete locale;
  - parametri della pagina: `?auto=1&bot=6&veloce=3` gara dimostrativa, `?stanza=2` apre subito una stanza che parte
    con 2 giocatori, `?s=CODICE` entra in una stanza, `?rete=locale` (schede dello stesso browser, senza Firebase);
  - `python3 tools/controlla_glifi.py` - nessun carattere fuori dai font.
- **Pubblicazione**: solo su richiesta, con *Actions, Pubblica, Run workflow* oppure con un commit che contiene
  `[pubblica]`. Con i segreti `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID` va anche sulla ludoteca privata.

Materiale di gioco © Asmodee / Eric Randall e Laurent Lavaur: questa conversione è per uso personale.
