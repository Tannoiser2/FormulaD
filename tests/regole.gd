extends SceneTree
## Controlli mirati sulle regressioni delle regole ufficiali.

var errori := 0

func _controlla(ok: bool, messaggio: String) -> void:
	if not ok:
		errori += 1
		push_error(messaggio)

func _init() -> void:
	# Il passaggio iniziale sulla linea non consuma il primo giro delle gomme morbide.
	_controlla(Motore.eta_gomme(1) == 0, "le gomme invecchiano alla partenza")
	_controlla(Motore.eta_gomme(2) == 1, "il primo giro completato non invecchia le gomme")
	_controlla(Motore.eta_gomme(3) == 2, "il secondo giro completato non invecchia le gomme")

	var m := Motore.new()
	m.s = {"regole": "avanzate", "giri": 2, "strada": false}
	m.pista = Pista.carica("FDMonaco")
	_controlla(not m._puo_pit({"giro": 0}), "box ammessi prima del giro 1")
	_controlla(m._puo_pit({"giro": 1}), "box non ammessi fra giro 1 e giro 2")
	_controlla(not m._puo_pit({"giro": 2}), "box ammessi nell'ultimo giro")
	m.s.giri = 1
	_controlla(not m._puo_pit({"giro": 1}), "box ammessi in una gara di un giro")

	var o := {"freno": 0, "oltre": 1, "mancate": 0, "curva": 1}
	var pf := {"gomme": 0, "freni": 3}
	var e := m.usura_mossa(o, pf)
	_controlla(not e.fuori.is_empty() and not e.testa, "con zero Gomme un lungo causa ancora un testacoda")
	pf.gomme = 1
	e = m.usura_mossa(o, pf)
	_controlla(e.fuori.is_empty() and e.testa, "spendere l'ultimo punto Gomme non causa il testacoda")

	var tabelle := {
		"FDMonaco": [7, 12], "FDHockenheim": [7, 13], "FDSebring": [4, 10], "FDValencia": [3, 8],
		"FDSingapore": [8, 14], "FDAustin": [2, 8], "FDBuddh": [8, 12], "FDSotchi": [6, 13],
		"FDe01": [7, 12], "FDe02": [9, 13], "FDe03": [9, 13], "FDe04": [6, 13],
		"FDe06": [7, 13], "FDe08a": [4, 9], "FDe10": [3, 8], "FDe12": [7, 13],
		"FDe13": [6, 12], "FDe15": [7, 13], "FDe16": [5, 11], "FDe18": [4, 11],
		"FDe19": [6, 12], "FDe22a": [8, 14],
	}
	for pid in tabelle:
		var p := Pista.carica(pid)
		_controlla(p != null and p.meteo == tabelle[pid], "tabella meteo errata per %s" % pid)

	var prova := Pista.carica("FDMonaco")
	_controlla(prova.aggiungi_collegamento("i.s1.0", "o.s1.1"), "l'editor non aggiunge una traiettoria valida")
	_controlla(not prova.aggiungi_collegamento("i.s1.0", "o.s1.1"), "l'editor aggiunge due volte la stessa traiettoria")
	_controlla(not prova.aggiungi_collegamento("i.s1.0", "inesistente"), "l'editor accetta una destinazione inesistente")

	print("regole: %d errori" % errori)
	quit(1 if errori > 0 else 0)
