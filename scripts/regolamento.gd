class_name Regolamento
extends RefCounted
## Il regolamento completo, diviso in capitoli: [titolo, testo in BBCode]. Descrive le regole come le applica
## questo gioco (dove c'è una semplificazione rispetto alla scatola è detto).

const CAPITOLI := [
["Il gioco", """[b]Scopo[/b]
Vince chi taglia per primo il traguardo dopo i giri stabiliti (1, 2 o 3). La gara continua finché tutte le auto sono arrivate o ritirate: così si stabiliscono anche gli altri posti.
Se più auto tagliano il traguardo nello stesso turno, arriva prima quella che va più caselle oltre la linea; a parità, chi l'ha tagliata per primo.

[b]Il materiale[/b]
- Il tabellone: il circuito diviso in caselle, su tre corsie (destra, centro, sinistra rispetto al verso di marcia) più la corsia dei box.
- Le curve: tratti con il fondo colorato e una bandierina gialla con un numero, le [b]fermate obbligatorie[/b] (1, 2 o 3).
- I sei dadi delle marce, ognuno con i suoi numeri, e il [b]dado nero[/b] a venti facce per partenza, collisioni, motore, meteo e così via.
- La plancia del pilota: la marcia innestata e i punti dell'auto (un'unica riserva con le regole base, sei zone con le avanzate).
- Fino a dieci auto, due per ognuna delle cinque scuderie (rossa, blu, gialla, verde, bianca; la seconda auto di ogni scuderia ha la livrea più scura).

[b]Regole base e avanzate[/b]
Le regole base sono rapide: un'unica riserva di punti e pochi tiri del dado nero. Le avanzate dividono l'auto in sei zone (gomme, freni, cambio, carrozzeria, motore, tenuta di strada) e aggiungono scia, detriti, meteo, assetto e le gomme. Nei capitoli che seguono, dove le regole cambiano è indicato."""],

["Griglia e partenza", """[b]La griglia[/b]
Si decide in due modi (si sceglie nella preparazione della gara):
- [b]Dado nero[/b]: ognuno tira il dado nero, chi fa di più parte in pole position, poi gli altri in ordine. Le parità si ritirano.
- [b]Qualifiche a settori[/b]: vedi il capitolo Qualifiche. Nel campionato ci sono sempre.

[b]La partenza[/b]
Al primo turno tutte le auto sono in folle. Ognuna, nel suo turno, tira il dado nero:
- [b]1[/b]: motore spento, l'auto resta ferma e parte al turno dopo in 1a.
- [b]20[/b] (con le regole base anche 17, 18, 19): partenza lampo, l'auto avanza subito di 4 caselle ed è in 1a.
- negli altri casi parte normalmente: tira il dado della 1a e avanza.
Dopo la partenza ogni auto è in 1a e cambia marcia come sempre."""],

["Il turno di gioco", """[b]Chi muove per primo[/b]
In ogni turno muove per prima l'auto in testa, poi le altre in ordine di posizione sul circuito. Le auto che hanno già tagliato il traguardo o sono ritirate non muovono più e lasciano la pista.
A parità di posizione (auto affiancate) muove prima chi ha la marcia più alta; a parità di marcia, chi è più all'interno della curva in cui si trova o, in rettilineo, della curva che viene dopo.
Le auto nella corsia dei box muovono dopo tutte quelle in pista.

[b]Cosa si fa nel proprio turno[/b]
1. Si sceglie la marcia (vedi Marce).
2. Si tira il dado di quella marcia: il numero è il [b]tiro[/b], le caselle da percorrere.
3. Si sceglie la casella di arrivo fra quelle raggiungibili: il gioco le mostra colorate con quanto costa arrivarci (freni, gomme, curva mancata...).
4. Eventuali extra: scia, Nitro, abilità.
5. Alla fine si controllano collisioni, detriti e motore sotto sforzo."""],

["Marce e dadi", """[b]I dadi delle marce[/b]
- 1a (dado a 4 facce): 1-2
- 2a (6 facce): 2-4
- 3a (8 facce): 4-8
- 4a (12 facce): 7-12
- 5a (20 facce): 11-20
- 6a (30 facce): 21-30

[b]Salire[/b]
Si sale al massimo di una marcia per turno (dalla 2a alla 3a, mai dalla 2a alla 4a). Si può restare nella stessa marcia.

[b]Scalare[/b]
Scalare di una marcia è gratis. Si può scalare di più saltando delle marce, fino a 3 marce saltate (dalla 6a alla 2a):
- regole base: 1 punto per ogni marcia saltata;
- regole avanzate: saltarne 1 costa 1 Cambio; 2 costano 1 Cambio e 1 Freni; 3 costano 1 Cambio, 1 Freni e 1 Motore. Senza punti Cambio si scala di una marcia alla volta.

[b]Sulla plancia[/b]
Le marce che si possono innestare sono illuminate. Passando sopra una marcia si vedono le caselle che si possono raggiungere con quel dado; toccandola si innesta e si tira."""],

["Muoversi sul circuito", """[b]Le caselle[/b]
L'auto avanza casella per casella seguendo i collegamenti del circuito: in avanti nella stessa corsia o in diagonale verso la corsia accanto. Non si torna mai indietro.

[b]Rettilinei[/b]
Si può cambiare corsia per superare o scegliere la traiettoria, ma si va sempre per la via più breve: non si può zigzagare per consumare caselle.

[b]Curve[/b]
Nelle curve valgono le frecce stampate sulle caselle: si va solo dove indicano.

[b]Le altre auto[/b]
Non si passa mai attraverso o sopra un'altra auto, e non ci si ferma su una casella occupata. Se la strada è chiusa bisogna fermarsi prima, e le caselle non percorse si pagano come una frenata.

[b]Frenare[/b]
Si può percorrere meno caselle del tiro, pagando le caselle non fatte:
- regole base: 1 punto per casella;
- regole avanzate: 1 Freni per casella fino a 3; dalla 4a alla 6a casella anche 1 Gomme per casella (4 caselle: 3 Freni e 1 Gomme; 6 caselle: 3 Freni e 3 Gomme). Frenare di 7 caselle o più elimina l'auto. Senza punti Freni si pagano in Gomme."""],

["Le curve", """[b]Fermate obbligatorie[/b]
Ogni curva ha sul tabellone una bandierina gialla con un numero: quante volte bisogna [b]finire il movimento dentro la curva[/b] prima di uscirne. Una curva da 1 chiede una fermata, da 2 due fermate in due turni diversi, e così via. Nell'ordine di gioco i pallini accanto al nome dicono quante fermate hai già fatto nella curva in cui sei.

[b]Andare lungo[/b]
Chi esce dalla curva senza aver fatto tutte le fermate «va lungo»:
- con [b]una sola fermata mancante[/b] paga ogni casella percorsa oltre la fine della curva: 1 punto per casella con le regole base, 1 Gomme per casella con le avanzate. Dopo essere uscito non può cambiare corsia;
- con [b]due o più fermate mancanti[/b] l'auto è eliminata.
Esempio: curva da 2, l'auto ha fatto una fermata ed esce di 3 caselle: paga 3.

[b]Testacoda[/b] (regole avanzate)
Se andando lungo si perde l'ultimo punto Gomme, l'auto va in testacoda: resta lì e riparte in 1a al turno dopo. Se servono più Gomme di quelle che restano, l'auto è eliminata.

[b]Curve vicine[/b]
Chi va lungo da una curva e finisce il movimento dentro la curva successiva non conta quella sosta come fermata della nuova curva.

[b]Ultima curva e traguardo[/b]
All'ultimo giro il controllo della curva si fa sempre prima del traguardo: chi taglia il traguardo andando lungo dall'ultima curva paga comunque le caselle oltre la curva."""],

["Collisioni, motore, detriti", """[b]Collisioni[/b]
Chi finisce il movimento accanto o subito dietro a un'altra auto tira il dado nero, e lo tira anche ognuna delle auto toccate:
- regole base: da 1 a 4 si perde 1 punto;
- regole avanzate: con 1 si perde 1 Carrozzeria (con la pioggia con 1 o 2).

[b]Motore sotto sforzo[/b]
Se esce 20 con il dado della 5a o 30 con quello della 6a, tutte le auto in 5a o in 6a (anche chi ha tirato) tirano il dado nero:
- da 1 a 4 si perde 1 punto (regole base) o 1 Motore (avanzate); con la pioggia da 1 a 3.

[b]Detriti[/b] (regole avanzate)
Ogni punto Carrozzeria o Motore perso, e ogni auto eliminata, lascia un segnalino detriti sulla casella. Chi passa o si ferma su una casella con detriti tira il dado nero: da 1 a 4 perde 1 Tenuta di strada (da 1 a 5 con la pioggia).

[b]Scia[/b] (regole avanzate)
Chi finisce [b]tutto il tiro[/b], senza frenare, nella casella esattamente dietro un'altra auto, con entrambe in 4a o più e la propria marcia uguale o più alta, può avanzare di altre 3 caselle girandole attorno. Se finisce di nuovo dietro un'auto può prendere un'altra scia. Se la scia porta dentro una curva costa 1 Freni.

[b]Eliminazione[/b]
- Regole base: a 0 punti l'auto è fuori gara.
- Regole avanzate: a 0 Carrozzeria, Motore o Tenuta di strada l'auto è fuori gara; Gomme e Freni hanno le loro regole (testacoda, frenate)."""],

["Box", """[b]Quando[/b]
Nelle gare di più giri, passando davanti ai box si può entrare nella corsia dei box, tranne all'ultimo giro. La sosta si fa nel box del proprio colore.

[b]Nella corsia dei box[/b]
Non valgono frenate, scalate, collisioni e motore sotto sforzo. Le auto in pista muovono prima di quelle nella corsia dei box.

[b]La sosta[/b]
- Regole base: si recuperano tutti i punti; si riparte al massimo in 4a.
- Regole avanzate: si recuperano tutte le Gomme e si possono cambiare le gomme (con il meteo). Il dado nero decide: da 1 a 10 sosta rapida, si riparte subito in 4a per metà del tiro (arrotondata per eccesso); da 11 a 20 sosta lunga, si riparte al turno dopo.

Nelle gare su strada non ci sono box: ci sono i punti di controllo (vedi Gara su strada)."""],

["Regole base", """[b]Punti Struttura[/b]
Ogni auto ha un'unica riserva di [b]18 Punti Struttura (PS)[/b] che paga tutto:
- andare lungo in curva: 1 per casella;
- frenare: 1 per casella non percorsa;
- scalare saltando marce: 1 per marcia saltata;
- collisione: 1 se il dado nero fa da 1 a 4;
- motore sotto sforzo: 1 se il dado nero fa da 1 a 4.
A 0 PS l'auto è eliminata. Al box si recuperano tutti i PS.

[b]Partenza[/b]
Partenza lampo con 17, 18, 19 o 20; motore spento con 1.

Le regole base non hanno scia, detriti, meteo e gomme."""],

["Regole avanzate", """[b]Le sei zone[/b]
Senza assetto libero ogni auto parte con:
- [b]Gomme 6[/b]: si consumano andando lungo e frenando molto;
- [b]Freni 3[/b]: frenare e scalare;
- [b]Cambio 3[/b]: scalare saltando marce;
- [b]Carrozzeria 3[/b]: collisioni;
- [b]Motore 3[/b]: motore sotto sforzo, scalate di 3 marce;
- [b]Tenuta di strada 2[/b]: detriti.

[b]Costi[/b]
- Andare lungo: 1 Gomme per casella (testacoda se si perde l'ultima, eliminata se non bastano).
- Frenare: 1 Freni per casella fino a 3, poi anche 1 Gomme per casella; 7 o più: eliminata.
- Scalare: 1 marcia saltata = 1 Cambio; 2 = 1 Cambio + 1 Freni; 3 = 1 Cambio + 1 Freni + 1 Motore.
- Collisione: 1 Carrozzeria con 1 al dado nero.
- Motore sotto sforzo: 1 Motore da 1 a 4.
- Detriti: 1 Tenuta di strada da 1 a 4.

[b]Assetto libero[/b] (si sceglie nella preparazione, solo in circuito)
Prima del via ognuno ripartisce 20 punti fra le zone: Gomme da 1 a 14, le altre da 1 a 7. Un'auto con tante Gomme perdona le curve, una con tanti Freni frena di più, e così via."""],

["Meteo e gomme", """[b]Il tempo[/b] (regole avanzate, se si sceglie «Meteo: dado nero»)
Prima del via il dado nero decide il tempo confrontandolo con la tabella stampata sul circuito (in genere: da 1 a 7 pioggia, da 8 a 12 variabile, da 13 a 20 bel tempo).
- [b]Bel tempo[/b] o [b]pioggia[/b]: restano così tutta la gara.
- [b]Variabile[/b]: si parte all'asciutto. Ogni volta che esce 20 in 5a o 30 in 6a si ritira il dado del meteo: il tempo può migliorare o peggiorare.

[b]Con la pioggia[/b]
Collisione con 1 o 2; motore sotto sforzo da 1 a 3; detriti da 1 a 5.

[b]Le gomme[/b]
Prima del via (e a ogni sosta ai box) si scelgono le gomme:
- [b]Dure[/b]: nessun effetto all'asciutto. Con la pioggia, quando la mossa tocca una curva, si avanza di 3 caselle in più.
- [b]Morbide[/b]: all'asciutto si può avanzare di 1 casella in più, ma andare lungo costa il doppio delle Gomme. Dopo un giro senza cambiarle il vantaggio sparisce; dopo due giri andare lungo costa il triplo. Con la pioggia +3 in curva.
- [b]Da pioggia[/b]: con la pioggia +1 casella quando la mossa tocca una curva; all'asciutto andare lungo costa il doppio (il triplo dopo due giri).
Le caselle in più si vedono sul tabellone come caselle facoltative."""],

["Qualifiche a settori", """Le qualifiche sono facoltative nelle gare singole e sempre presenti nel campionato. Si corrono così (proposta di un amico, al posto del giro cronometrato).

[b]I settori[/b]
Il giro è diviso in 3 settori, ognuno con un terzo delle curve. Ogni settore ha un [b]limite[/b]: 32 meno 3 per ogni fermata obbligatoria delle sue curve, comunque fra 12 e 26. I limiti si vedono a ogni settore.

[b]Il tiro[/b]
In ogni settore si sceglie una marcia dalla 3a alla 6a e si tira il suo dado:
- tiro uguale o sotto il limite: si fanno tanti punti quanti il tiro;
- oltre il limite di 1-4: il limite meno 2 punti per ogni casella in più;
- oltre di 5 o più: testacoda, 0 punti (con le regole avanzate costa anche 1 Gomme per la gara).
Il giro vale la somma dei tre settori. Vince chi fa più punti; a parità chi ha fatto di più nel 3° settore, poi il dado nero.

[b]Riprovare[/b]
Un settore andato male si può ritirare: con le regole base una volta per sessione; con le avanzate ogni nuovo tiro costa 1 Gomme per la gara (al massimo 2).

[b]Le sessioni[/b]
Con 8 auto o più: Q1 per tutti (gli ultimi vengono fissati in fondo alla griglia), Q2 fino a 7 auto, Q3 con le ultime 4, che girano dall'ultima alla prima. Con meno auto una sola sessione."""],

["Campionato", """Il campionato segue il regolamento di Gianluca Lari (versione 1.2), con le qualifiche a settori al posto del giro cronometrato.

[b]Come si gioca[/b]
Si scelgono i circuiti (l'ordine in cui si toccano è l'ordine delle gare), i giri (il regolamento ne prevede 3) e i piloti. Prima di ogni Gran Premio ci sono le qualifiche, poi la gara. Fra un GP e l'altro il campionato si salva: dal menu «Continua il campionato».

[b]Punti[/b]
I primi cinque arrivati prendono [b]8, 6, 4, 2 e 1[/b] punti. Le auto ritirate non prendono punti.

[b]Classifiche[/b]
- [b]Piloti[/b]: somma dei punti; a parità conta chi ha vinto più gare.
- [b]Scuderie (costruttori)[/b]: la somma dei punti dei due piloti dello stesso colore.
- [b]Premio Gilles Villeneuve[/b]: premia chi guadagna più posizioni. In ogni gara si fa posizione di partenza meno posizione d'arrivo (partire 7° e arrivare 4° vale +3; partire 1° e arrivare 4° vale -3). Chi non arriva conta come ultimo. I punti si sommano gara dopo gara.

[b]Punti Pilota[/b]
- Ogni pilota ha [b]1 Punto Pilota permanente[/b], valido in ogni GP.
- I primi tre di ogni GP guadagnano [b]1 Punto Pilota provvisorio[/b] in più, da usare nei GP seguenti. In tutto non si possono avere più di 4 Punti Pilota.
- Un Punto Pilota permette di [b]ritirare il dado della marcia[/b] appena tirato; il nuovo risultato va accettato (a meno di spendere un altro punto).
- Si spendono prima i punti provvisori; quelli spesi non tornano. Il punto permanente torna a ogni GP.
Nel gioco il pulsante «Punto Pilota» compare dopo il tiro quando ne hai ancora.

[b]Regolamento Lari[/b]
Nel campionato si usa di solito anche il resto del regolamento di Gianluca Lari (le regole «Lari» nella preparazione): vedi il capitolo Regolamento Lari. Con il regolamento Lari:
- a ogni GP, dopo le qualifiche, ognuno prepara l'assetto della sua auto (20 punti fra le zone, come l'assetto libero);
- ogni auto ha 2 punti meccanici per gara per le riparazioni ai box;
- i Punti Pilota servono anche per ritirare il dado nero (vedi il capitolo).

[b]Rischio pilota e collaudatore[/b]
Un pilota che si fa male (rischio pilota) salta la gara seguente; un pilota che non ce la fa lascia il campionato. Al suo posto guida il [b]collaudatore[/b] della scuderia: i suoi punti vanno solo alla classifica scuderie, non a quella piloti.

[b]Premi di esperienza[/b]
A campionato finito i primi tre della classifica piloti guadagnano 1 Punto Pilota permanente per i campionati seguenti (al massimo 3 permanenti), la scuderia campione 1 punto meccanico in più (al massimo 2 in più). Valgono per i piloti con lo stesso nome e restano salvati su questo dispositivo.

[b]Non nel gioco[/b]
Il giro di qualifica cronometrato (ci sono le qualifiche a settori) e il sorteggio delle scuderie fra un campionato e l'altro: qui ogni giocatore sceglie la sua auto."""],

["Regolamento Lari", """Si sceglie nella preparazione con [b]Regole: Lari[/b]: sono le regole avanzate con le aggiunte del regolamento del campionato di Gianluca Lari (versione 1.2). Nel campionato sono la scelta normale, ma si possono usare anche in una gara singola.

[b]Punti Pilota[/b]
Ogni pilota ha 1 Punto Pilota per gara (nel campionato di più, vedi Campionato). Oltre a ritirare il dado della marcia (pulsante «Punto Pilota»), il gioco lo spende da solo per ritirare il [b]dado nero[/b] quando il risultato sarebbe grave: un danno in una zona già a zero, un ritiro, il rischio pilota.

[b]Cordoli[/b]
In curva, senza frenare:
- [b]cordolo interno[/b]: se la mossa passa su almeno una casella della corsia interna della curva, si può avanzare di 1 casella in più;
- [b]cordolo esterno[/b]: se la mossa finisce sulla terza di almeno tre caselle di fila nella corsia esterna, quella casella vale 3: si avanza di 2 caselle in meno.
Dopo il cordolo si controllano le sospensioni: dado nero da 1 a 4 (da 1 a 5 con la pioggia), 1 Tenuta di strada. Sul tabellone le caselle si vedono con la scritta CORDOLO.

[b]Motore fuori giri[/b]
Partendo da un rettilineo, dopo il tiro si può mandare il motore fuori giri: 1 Motore per tante caselle in più quanto il numero della marcia (1 in 1a, 6 in 6a). Vanno fatte tutte, senza frenare e senza scia dopo; non lascia detriti. Una volta per turno, solo se si ha almeno 1 Motore.

[b]KERS[/b] (Extra, si può usare anche senza il regolamento Lari)
In 4a o più, i due numeri più alti del dado (11-12 in 4a, 19-20 in 5a, 29-30 in 6a) caricano 1 punto KERS, fino a 3. Si usa dopo il tiro: con 1 punto +1 casella, con 2 +2, con 3 +4; si spendono sempre tutti. Con il KERS il Motore arriva al massimo a 2.

[b]Strada bloccata e tamponamento[/b]
Se le auto davanti chiudono la strada e bisogna frenare più di 6 caselle: le prime 6 si pagano come una frenata (3 Freni e 3 Gomme), le altre con punti di altre zone (il gioco toglie da quelle che ne hanno di più, senza portare a zero carrozzeria, motore e tenuta). Se non bastano, l'auto tampona quella davanti: perde tutta la Carrozzeria e tira la tabella dei danni al telaio; l'auto tamponata perde 1 Carrozzeria.

[b]Carrozzeria, motore e tenuta a zero[/b]
A zero l'auto non è eliminata. Se deve perdere un punto che non ha più tira il dado nero sulla tabella della zona:
- [b]Telaio (carrozzeria)[/b]: 1-2 incidente grave, ritiro e rischio pilota; 3-18 perde il musetto, al massimo in 3a; 19-20 testacoda e 2 punti persi a scelta.
- [b]Motore[/b]: 1-2 motore rotto, ritiro; 3-18 perde potenza, ogni dado dà sempre il numero più basso; 19-20 nessuna conseguenza, ma alla fine di ogni suo turno la prova di affidabilità: dado nero uguale o sotto la marcia e il motore cede.
- [b]Sospensioni (tenuta)[/b]: 1-2 danno irrimediabile, ritiro; 3-18 sospensioni rotte, +3 caselle obbligatorie quando la mossa tocca una curva e andare lungo costa il doppio; 19-20 testacoda e 2 punti persi a scelta.
Dopo la tabella, un altro punto perso nella stessa zona è un incidente grave: ritiro e rischio pilota. Senza Carrozzeria o Tenuta non si ha più il +1 delle gomme morbide.

[b]Rischio pilota[/b]
Dopo un incidente grave il dado nero: 1 il pilota non ce la fa (nel campionato lo sostituisce il collaudatore fino alla fine); 20 frattura, salta la gara seguente; 2-19 esce illeso.

[b]Box[/b]
Ogni auto ha [b]2 punti meccanici[/b] per gara (di più per la scuderia campione dell'anno prima). Alla sosta: gomme nuove e, con i punti meccanici, 1 punto per ognuno in Freni, Cambio, Carrozzeria, Motore o Tenuta (il gioco ripara prima le zone con danni gravi, che così tornano a posto). Poi il dado nero: 1-4 riparte subito in 4a per 2 caselle, 5-8 per 3, 9-12 per 4; 13-20 problemi ai box, riparte al turno dopo.

[b]Meteo variabile[/b]
Quando si ritira il dado del meteo, il risultato dice il tempo (pioggia o sereno; variabile lascia com'è). Se esce due volte di fila pioggia o due volte di fila sereno, il tempo non cambia più fino alla fine."""],

["Gara su strada", """[b]Il circuito[/b]
Si corre sugli stessi tabelloni ma con le regole delle gare cittadine:
- [b]niente box[/b];
- [b]Nitro[/b]: una volta per giro, dopo aver tirato il dado, si può usare il Nitro: si avanza di tante caselle in più quanto il numero della marcia innestata, e vanno fatte tutte;
- [b]punto di controllo[/b] al traguardo: con le regole base si recuperano 10 PS (fino a 18); con le avanzate si recuperano tutte le Gomme e 2 punti nelle zone più rovinate.

[b]Con le regole avanzate[/b]
Ogni pilota guida la sua auto (con i suoi punti già stampati sulla carta, solo gomme dure) e ha un'abilità (vedi Personaggi e abilità).

[b]Nitro in circuito[/b]
Nella preparazione, alla voce Extra, il Nitro si può aggiungere anche alle gare in circuito: funziona allo stesso modo."""],

["Personaggi e abilità", """Su strada con le regole avanzate ogni auto è guidata da un personaggio con un'abilità. Nella preparazione, alla voce Extra, i personaggi si possono aggiungere anche alle gare in circuito (solo con le regole avanzate). Senza personaggi i piloti hanno il nome che scegliete voi (si scrive sotto la carta).

- [b]Li Tsu Sin[/b] - Che dolcezza!: chi taglia il traguardo mentre lei è in gara avanza di una casella in meno.
- [b]Jack Owens[/b] - Re della derapata: in ogni curva può allungare o accorciare la mossa di una casella, pagando 1 Gomme.
- [b]Julien Marcellin[/b] - Rana della pioggia: ritira il dado del meteo quando dice pioggia; sotto la pioggia in curva scivola di 1 casella invece di 3.
- [b]Jenny Slivers[/b] - Meccanica esperta: al punto di controllo recupera 4 punti invece di 2.
- [b]Derek Manson[/b] - Aggressivo: chi collide con lui tira il dado nero due volte.
- [b]Diane Montfort[/b] - Scatto bruciante: a parità di posizione muove sempre per prima, anche in griglia.
- [b]Stanley Washington[/b] - Autoradio: una volta per gara lancia la radio contro un'auto accanto; il dado nero dice quale zona perde 1 punto (1-4 Gomme, 5-7 Freni, 8-10 Cambio, 11-13 Carrozzeria, 14-17 Motore, 18-20 Tenuta).
- [b]Temana Matahi[/b] - Rottame: una volta per giro lascia un segnalino detriti dove parte; sui detriti perde Tenuta solo con 1 o 2.
- [b]Dimitri Tzarof[/b] - Piccolo genio: con il motore sotto sforzo perde Motore solo con 1-3 (1-2 se piove).
- [b]Montoya Cadena[/b] - Nitro migliore: quando usa il Nitro può avanzare di 3 caselle in più.

Nel gioco la radio di Stanley e i detriti di Temana scattano da soli quando conviene."""],

["Come si gioca qui", """[b]Modi di gioco[/b]
- [b]Gara su questo schermo[/b]: contro il computer o in più a turno sullo stesso schermo.
- [b]Campionato[/b]: più GP di fila (vedi Campionato).
- [b]TV + telefoni[/b]: il tabellone su questo schermo, ogni pilota sceglie dal suo telefono inquadrando il QR code. Durante la gara il QR resta in basso a sinistra: se un telefono perde la gara basta inquadrarlo di nuovo (toccalo per ingrandirlo).
- [b]Gara online[/b]: ognuno gioca dal suo computer. Uno apre la gara e manda il codice di 4 lettere (o il link); gli altri scelgono «Entra in una gara» e scrivono codice e nome.

[b]Durante la gara[/b]
- La plancia a destra: passa sopra una marcia per vedere dove arrivi, tocca per innestarla e tirare.
- Le caselle raggiungibili sono colorate con quanto costano; tocca una casella per vederne il costo, toccala di nuovo per confermare.
- «Caselle» mostra la mappatura del circuito: un pallino per casella (blu corsia destra, verde centro, arancio sinistra, viola box), con la punta nel verso della casella.
- «Scritte» passa dalle icone alle parole sulle caselle.
- Telecamera: trascina con un dito per spostare, pizzica o usa la rotella per lo zoom, due dita per ruotare.
- Dal menu di pausa si salva la gara e la si riprende più tardi.

[b]Editor piste[/b]
Per correggere un circuito: si sceglie la pista, si tocca un pallino e lo si sposta, ruota, cambia di corsia; si aggiungono o tolgono traiettorie e caselle. Le correzioni restano su questo dispositivo; «Esporta JSON» crea il file da mandare per metterle nel gioco per tutti."""],
]
