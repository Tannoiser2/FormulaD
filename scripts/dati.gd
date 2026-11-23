class_name Dati
extends RefCounted
## Dati fissi di Formula D: dadi, regolamenti, scuderie, piloti, circuiti.

## Facce dei sei dadi delle marce (dal modulo): valore e rotazione del modello perché quella faccia stia in alto.
const DADI := {
	1: [[1, 54.74, 0, 125.26], [2, 305.26, 0, 125.26], [1, 0, 0, 250.53], [2, 0, 0, 0]],
	2: [[3, 270, 0, 0], [3, 0, 0, 270], [4, 0, 0, 90], [4, 90, 0, 0], [4, 0, 0, 0], [2, 0, 0, 180]],
	3: [[5, 35.26, 0, 315], [8, 35.26, 0, 45], [6, 324.74, 0, 45], [7, 324.74, 0, 315], [7, 35.26, 0, 225], [6, 35.26, 0, 135],
		[8, 324.74, 0, 135], [4, 324.74, 0, 225]],
	4: [[9, 296.28, 0, 0], [10, 63.72, 0, 180], [7, 313.83, 0, 130.61], [9, 313.83, 0, 229.39], [12, 0.28, 0, 180], [7, 359.72, 0, 0],
		[8, 343.82, 0, 62.34], [11, 343.82, 0, 297.66], [11, 16.18, 0, 242.34], [8, 16.18, 0, 117.66], [12, 46.17, 0, 310.61],
		[10, 46.17, 0, 49.39]],
	5: [[19, 48.24, 0, 299.91], [13, 311.76, 0, 119.91], [15, 48.24, 0, 60.09], [18, 311.76, 0, 240.09], [19, 60.71, 0, 226.83],
		[16, 299.29, 0, 313.17], [13, 299.29, 0, 46.83], [12, 60.71, 0, 133.17], [15, 352.65, 0, 250.37], [12, 7.35, 0, 289.63],
		[16, 352.65, 0, 109.63], [18, 7.35, 0, 70.37], [17, 19.4, 0, 217.74], [14, 340.6, 0, 322.26], [11, 340.6, 0, 37.74],
		[14, 19.4, 0, 142.26], [11, 318.09, 0, 180], [17, 41.91, 0, 0], [20, 0.1, 0, 0], [20, 359.9, 0, 180]],
	6: [[25, 342, 0, 58.28], [26, 18, 0, 238.28], [27, 342, 0, 121.72], [22, 342, 0, 238.28], [21, 0, 0, 180], [30, 0, 0, 0],
		[24, 18, 0, 301.72], [23, 54, 0, 301.72], [28, 306, 0, 121.72], [29, 54, 0, 58.28], [30, 270, 0, 180], [27, 54, 0, 238.28],
		[21, 0, 0, 90], [25, 54, 0, 121.72], [23, 330, 0, 200.91], [24, 330, 0, 20.91], [26, 30, 0, 20.91], [30, 0, 0, 270],
		[26, 306, 0, 301.72], [28, 342, 0, 301.72], [25, 30, 0, 159.09], [29, 30, 0, 200.91], [24, 306, 0, 58.28],
		[23, 18, 0, 121.72], [29, 18, 0, 58.28], [28, 330, 0, 339.09], [22, 30, 0, 339.09], [21, 90, 0, 0], [27, 330, 0, 159.09],
		[22, 306, 0, 238.28]],
}
const MODELLI_DADI := ["", "FirstGearDice", "SecondGearDice", "ThirdGearDice", "FourthGearDice", "FifthGearDice", "SixthGearDice"]
const INTERVALLI := ["", "1-2", "2-4", "4-8", "7-12", "11-20", "21-30"]
const NOMI_MARCE := ["folle", "1a", "2a", "3a", "4a", "5a", "6a"]
const COLORI_MARCE := [Color(0.4, 0.4, 0.4), Color(0.93, 0.83, 0.05), Color(0.95, 0.42, 0.05), Color(0.72, 0.13, 0.15),
	Color(0.05, 0.5, 0.1), Color(0.36, 0.1, 0.55), Color(0.05, 0.25, 0.65)]
## Il tiro che mette sotto sforzo i motori in 5a e 6a.
const SFORZO := {5: 20, 6: 30}

## Zone di usura per regolamento. fuori: l'auto è eliminata quando la zona scende a quel valore (o sotto).
const ZONE := {
	"base": [{"id": "ps", "nome": "Punti Struttura", "breve": "PS", "inizio": 18, "fuori": 0}],
	"avanzate": [
		{"id": "gomme", "nome": "Gomme", "breve": "Gomme", "inizio": 6, "fuori": -1, "max": 14},
		{"id": "freni", "nome": "Freni", "breve": "Freni", "inizio": 3, "max": 7},
		{"id": "cambio", "nome": "Cambio", "breve": "Cambio", "inizio": 3, "max": 7},
		{"id": "carrozzeria", "nome": "Carrozzeria", "breve": "Carrozz.", "inizio": 3, "fuori": 0, "max": 7},
		{"id": "motore", "nome": "Motore", "breve": "Motore", "inizio": 3, "fuori": 0, "max": 7},
		{"id": "tenuta", "nome": "Tenuta di strada", "breve": "Tenuta", "inizio": 2, "fuori": 0, "max": 7},
	],
}
const NOMI_REGOLE := {"base": "Regole base", "avanzate": "Regole avanzate"}

## Assetto libero: 20 punti da ripartire, con questi limiti per zona.
const ASSETTO_TOTALE := 20
const ASSETTO_MIN := 1
## L'assetto che usa il computer quando la ripartizione è libera.
const ASSETTO_IA := {"gomme": 8, "freni": 3, "cambio": 2, "carrozzeria": 3, "motore": 2, "tenuta": 2}

## Gomme (regola facoltativa con il meteo).
const GOMME := ["dure", "morbide", "pioggia"]
const NOMI_GOMME := {"dure": "Dure", "morbide": "Morbide", "pioggia": "Da pioggia"}
const DESCR_GOMME := {
	"dure": "Asciutto: nessun effetto. Pioggia: +3 caselle quando la mossa tocca una curva.",
	"morbide": "Asciutto: +1 casella facoltativa (solo il primo giro), lungo in curva costa il doppio. Pioggia: +3 in curva.",
	"pioggia": "Pioggia: +1 casella quando la mossa tocca una curva. Asciutto: lungo in curva costa il doppio.",
}

## Meteo: 0 bello (fisso), 1 variabile (asciutto), 2 pioggia variabile, 3 pioggia (fissa).
const NOMI_METEO := ["Bel tempo", "Variabile", "Pioggia (variabile)", "Pioggia"]
## Gare su strada con le regole avanzate: l'auto di ogni pilota (gomme, freni, cambio, carrozzeria, motore, tenuta).
const AUTO_STRADA := {
	"litsu": [7, 3, 2, 2, 3, 3], "jack": [9, 2, 2, 2, 3, 2], "julien": [8, 4, 2, 2, 3, 2], "jenny": [4, 6, 2, 3, 3, 2],
	"derek": [6, 3, 2, 4, 3, 3], "diane": [6, 4, 2, 3, 3, 3], "stanley": [7, 2, 3, 2, 3, 3], "temana": [6, 3, 3, 3, 3, 3],
	"dimitri": [5, 4, 3, 3, 3, 4], "montoya": [5, 5, 3, 2, 3, 2],
}
const ABILITA := {
	"litsu": ["Che dolcezza!", "Chi taglia il traguardo mentre lei è in gara avanza di una casella in meno."],
	"jack": ["Re della derapata", "In ogni curva può allungare o accorciare la mossa di una casella, pagando 1 Gomme."],
	"julien": ["Rana della pioggia", "Ritira il dado del meteo quando dice pioggia; sotto la pioggia in curva scivola di 1 casella invece di 3."],
	"jenny": ["Meccanica esperta", "Al traguardo recupera 4 punti invece di 2."],
	"derek": ["Aggressivo", "Chi collide con lui tira il dado nero due volte."],
	"diane": ["Scatto bruciante", "A parità di posizione muove sempre per prima, anche in griglia."],
	"stanley": ["Autoradio", "Una volta per gara lancia la radio contro un'auto accanto: il dado nero dice quale zona perde 1 punto."],
	"temana": ["Rottame", "Una volta per giro lascia un segnalino detriti dove parte; sui detriti perde Tenuta solo con 1 o 2."],
	"dimitri": ["Piccolo genio", "Motore sotto sforzo: perde Motore solo con 1-3 (1-2 se piove)."],
	"montoya": ["Nitro migliore", "Quando usa il Nitro può avanzare di 3 caselle in più."],
}
## Autoradio di Stanley: dado nero fino a ... -> zona.
const RADIO := [[4, "gomme"], [7, "freni"], [10, "cambio"], [13, "carrozzeria"], [17, "motore"], [20, "tenuta"]]

static func zone_ids() -> Array:
	return ["gomme", "freni", "cambio", "carrozzeria", "motore", "tenuta"]
const COLORI_ZONE := {"ps": Color(0.95, 0.8, 0.1), "gomme": Color(0.25, 0.2, 0.7), "freni": Color(0.5, 0.75, 0.1),
	"cambio": Color(0.1, 0.6, 0.6), "carrozzeria": Color(0.9, 0.6, 0.1), "motore": Color(0.85, 0.15, 0.1), "tenuta": Color(0.6, 0.2, 0.7)}

## Le cinque scuderie (due auto ciascuna) e i dieci piloti delle carte originali.
const SCUDERIE := {
	"bianca": {"nome": "Bianca", "colore": Color(0.95, 0.95, 0.95), "scuro": Color(0.78, 0.2, 0.2)},
	"gialla": {"nome": "Gialla", "colore": Color(0.98, 0.82, 0.08), "scuro": Color(0.45, 0.2, 0.6)},
	"verde": {"nome": "Verde", "colore": Color(0.2, 0.72, 0.2), "scuro": Color(0.95, 0.5, 0.1)},
	"rossa": {"nome": "Rossa", "colore": Color(0.86, 0.1, 0.1), "scuro": Color(0.98, 0.8, 0.1)},
	"blu": {"nome": "Blu", "colore": Color(0.15, 0.55, 0.95), "scuro": Color(0.9, 0.95, 1.0)},
}
## posto: il nome del box sul circuito (dal modulo). variante: la seconda auto della scuderia ha la livrea più scura.
const PILOTI := [
	{"id": "dimitri", "nome": "Dimitri Tzarof", "scuderia": "rossa", "posto": "Red", "variante": 0},
	{"id": "jack", "nome": "Jack Owens", "scuderia": "blu", "posto": "Blue", "variante": 0},
	{"id": "stanley", "nome": "Stanley Washington", "scuderia": "gialla", "posto": "Yellow", "variante": 0},
	{"id": "derek", "nome": "Derek Manson", "scuderia": "verde", "posto": "Green", "variante": 0},
	{"id": "diane", "nome": "Diane Montfort", "scuderia": "bianca", "posto": "White", "variante": 0},
	{"id": "jenny", "nome": "Jenny Slivers", "scuderia": "rossa", "posto": "Pink", "variante": 1},
	{"id": "montoya", "nome": "Montoya Cadena", "scuderia": "blu", "posto": "Purple", "variante": 1},
	{"id": "temana", "nome": "Temana Matahi", "scuderia": "gialla", "posto": "Orange", "variante": 1},
	{"id": "julien", "nome": "Julien Marcellin", "scuderia": "verde", "posto": "Teal", "variante": 1},
	{"id": "litsu", "nome": "Li Tsu Sin", "scuderia": "bianca", "posto": "Brown", "variante": 1},
]

const PISTE := ["FDMonaco", "FDHockenheim", "FDSebring", "FDValencia", "FDSingapore", "FDAustin", "FDBuddh", "FDSotchi", "FDe01", "FDe02", "FDe03", "FDe04", "FDe06", "FDe08a", "FDe10", "FDe12", "FDe13", "FDe15", "FDe16", "FDe18", "FDe19", "FDe22a"]

static func zone(regole: String) -> Array:
	return ZONE[regole]

static func colore_auto(pilota: int) -> Color:
	var p: Dictionary = PILOTI[pilota]
	var c: Color = SCUDERIE[p.scuderia].colore
	return c.darkened(0.28) if p.variante == 1 else c

static func valori_dado(marcia: int) -> Array:
	var v := []
	for f in DADI[marcia]:
		v.append(int(f[0]))
	return v

static func nome_zona(regole: String, id: String) -> String:
	for z in ZONE[regole]:
		if z.id == id:
			return z.nome
	return id

## "2 Freni, 1 Gomme"
static func testo_usura(regole: String, usura: Dictionary) -> String:
	var parti := []
	for z in ZONE[regole]:
		var n := int(usura.get(z.id, 0))
		if n > 0:
			parti.append("%d %s" % [n, z.breve])
	return ", ".join(parti)

const REGOLE_IN_BREVE := """[b]Scopo[/b] - Tagliare per primi il traguardo dopo i giri stabiliti.

[b]Il turno[/b] - Gioca per prima l'auto in testa, poi le altre in ordine di posizione. A parità, prima la marcia più alta, poi chi è più all'interno della curva. Al tuo turno scegli la marcia e tiri il dado di quella marcia: l'auto avanza di tante caselle quante ne indica il dado.

[b]Marce[/b] - 1a: 1-2, 2a: 2-4, 3a: 4-8, 4a: 7-12, 5a: 11-20, 6a: 21-30. Si sale di una marcia alla volta. Si scala di una marcia gratis; scalando di più si saltano marce e l'auto si rovina (fino a 3 marce saltate).

[b]Rettilinei[/b] - Si può cambiare corsia ma non zigzagare: si va sempre per la via più breve. Non si passa attraverso le altre auto.

[b]Curve[/b] - Ogni curva ha un numero di fermate obbligatorie (il numero giallo sul tabellone): bisogna finire il movimento dentro la curva almeno quelle volte. Chi esce prima va «lungo»: paga 1 punto per ogni casella oltre la curva e non può cambiare corsia. Se mancano due o più fermate l'auto è eliminata.

[b]Frenare[/b] - Si può avanzare meno del tiro, pagando 1 punto per ogni casella non percorsa.

[b]Partenza[/b] - Dado nero: con 1 l'auto resta ferma (motore spento) e parte al turno dopo; con il risultato più alto fa una partenza lampo di 4 caselle; altrimenti parte in 1a.

[b]Motore sotto sforzo[/b] - Se esce 20 in 5a o 30 in 6a, tutte le auto in 5a o 6a tirano il dado nero: da 1 a 4 perdono 1 punto.

[b]Collisioni[/b] - Chi finisce il movimento accanto o dietro a un'altra auto tira il dado nero (e così l'auto toccata).

[b]Box[/b] - Nelle gare di più giri, tra un giro e l'altro si può entrare nella corsia dei box e fermarsi nel proprio box: si riparte al massimo in 4a. In corsia box non valgono frenate, scalate, collisioni e sforzo del motore.

[b]Regole base[/b] - Un'unica riserva di 18 Punti Struttura (PS) per tutto. Collisione: da 1 a 4 si perde 1 PS. Partenza lampo con 17-20. Al box si recuperano tutti i PS. A 0 PS l'auto è eliminata.

[b]Regole avanzate[/b] - Sei zone: Gomme 6, Freni 3, Cambio 3, Carrozzeria 3, Motore 3, Tenuta di strada 2.
- Andare lungo: 1 Gomme per casella. Se si perde l'ultimo punto Gomme l'auto va in testacoda (riparte in 1a); se servono più Gomme di quante ne restano è eliminata.
- Frenare: 1 Freni per casella fino a 3, dalla quarta casella anche 1 Gomme per casella; 7 caselle o più: eliminata. Senza Freni si consumano le Gomme.
- Scalare saltando 1 marcia: 1 Cambio; 2 marce: 1 Cambio e 1 Freni; 3 marce: 1 Cambio, 1 Freni e 1 Motore. Senza Cambio si scala di una marcia alla volta.
- Collisione: con 1 si perde 1 Carrozzeria. Motore sotto sforzo: da 1 a 4 si perde 1 Motore.
- Detriti: ogni punto Carrozzeria o Motore perso (e ogni auto eliminata) lascia un segnalino sulla casella. Chi ci passa sopra tira il dado nero: da 1 a 4 perde 1 Tenuta di strada.
- Scia: chi finisce tutto il tiro esattamente dietro un'auto, entrambe in 4a o più e chi segue con marcia uguale o più alta, può avanzare di altre 3 caselle. Se la scia porta dentro una curva costa 1 Freni.
- Box: si recuperano tutte le Gomme. Dado nero: da 1 a 10 sosta rapida, si riparte subito in 4a per metà del tiro (arrotondata per eccesso); da 11 a 20 si aspetta il turno dopo.
- A 0 di Carrozzeria, Motore o Tenuta di strada l'auto è eliminata.

[b]Assetto libero[/b] (regole avanzate) - Prima del via ognuno ripartisce 20 punti fra le sei zone: Gomme da 1 a 14, le altre da 1 a 7.

[b]Meteo e gomme[/b] (regole avanzate) - Prima del via il dado nero decide il tempo: da 1 a 7 pioggia, da 8 a 12 variabile, da 13 a 20 bel tempo. Con il tempo variabile, ogni volta che esce 20 in 5a o 30 in 6a si ritira: bel tempo fa migliorare, pioggia fa peggiorare.
- Sotto la pioggia: collisione con 1 o 2, motore sotto sforzo da 1 a 3, detriti da 1 a 5.
- Gomme dure: con la pioggia, quando la mossa tocca una curva, si avanza di 3 caselle in più.
- Gomme morbide: all'asciutto si può avanzare di 1 casella in più, ma andare lungo costa il doppio delle Gomme. Dopo un giro senza cambiarle il vantaggio sparisce, dopo due giri andare lungo costa il triplo. Con la pioggia, +3 in curva.
- Gomme da pioggia: con la pioggia +1 casella quando la mossa tocca una curva; all'asciutto andare lungo costa il doppio (il triplo dopo due giri).
- Al box si possono cambiare le gomme.

[b]Qualifiche a settori[/b] (facoltative; sempre nel campionato) - Il giro ha 3 settori, ognuno con un limite (32 meno 3 per ogni fermata delle sue curve, fra 12 e 26). In ogni settore si sceglie una marcia dalla 3a alla 6a e si tira: entro il limite si fanno i punti del dado, oltre di 1-4 il limite meno 2 per ogni casella in più, oltre di 5 o più testacoda (0). Vince il giro con più punti; a parità chi ha fatto di più nel 3° settore, poi il dado nero. Con 8 auto o più: Q1 (escono gli ultimi), Q2 (fino a 7), Q3 (4 auto, si gira dall'ultimo al primo). Un settore si può riprovare: con le regole base una volta per sessione, con le avanzate ogni nuovo tiro costa 1 Gomme per la gara (al massimo 2); con le avanzate anche un testacoda costa 1 Gomme.

[b]Campionato[/b] (regolamento di Gianluca Lari) - Più Gran Premi di fila con le qualifiche. Punti 8-6-4-2-1 ai primi cinque arrivati; classifica scuderie (i due piloti dello stesso colore); premio Gilles Villeneuve per chi guadagna più posizioni dalla griglia all'arrivo (chi non arriva conta ultimo). Ogni pilota ha 1 Punto Pilota per gara, che permette di ritirare il dado della marcia; i primi tre di ogni GP ne guadagnano uno in più per le gare seguenti (al massimo 4, si spendono prima quelli guadagnati).

[b]Gara su strada[/b] - Niente box. Una volta per giro, dopo il tiro, si può usare il Nitro: si avanza di tante caselle in più quante il numero della marcia, e vanno fatte tutte. Al traguardo (punto di controllo), con le regole base si recuperano 10 PS fino a 18; con le avanzate si recuperano tutte le Gomme e 2 punti nelle zone più rovinate.
Con le regole avanzate ogni pilota guida la sua auto, solo con gomme dure, e ha un'abilità:
- Li Tsu Sin: chi taglia il traguardo mentre lei è in gara avanza di una casella in meno.
- Jack Owens: in curva può allungare o accorciare la mossa di 1 casella, pagando 1 Gomme.
- Julien Marcellin: ritira il dado del meteo quando dice pioggia; sotto la pioggia in curva scivola di 1 invece di 3.
- Jenny Slivers: al traguardo recupera 4 punti invece di 2.
- Derek Manson: chi collide con lui tira il dado nero due volte.
- Diane Montfort: a parità di posizione muove sempre per prima.
- Stanley Washington: una volta per gara lancia la radio contro un'auto accanto (il dado nero dice quale zona perde 1 punto).
- Temana Matahi: una volta per giro lascia detriti dove parte; sui detriti perde Tenuta solo con 1 o 2.
- Dimitri Tzarof: motore sotto sforzo solo con 1-3 (1-2 se piove).
- Montoya Cadena: con il Nitro può avanzare di 3 caselle in più."""
