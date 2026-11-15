class_name Motore
extends RefCounted
## Le regole di Formula D (base e avanzate), senza grafica.
## Lo stato `s` è fatto di soli dati: si salva e si ricarica così com'è.
## Il motore va avanti da solo (dadi neri, ordine di gioco) finché serve una decisione: `s.attesa`
## dice quale ({tipo: "marcia"|"mossa", auto, ...}) e `applica()` la riceve. Quello che succede
## finisce in `eventi`, che l'interfaccia mostra uno alla volta.

const SCALATA_AVANZATA := [{}, {"cambio": 1}, {"cambio": 1, "freni": 1}, {"cambio": 1, "freni": 1, "motore": 1}]
const FRENATA_MASSIMA := 6
const ALLA_PARI := 0.25

var s: Dictionary = {}
var pista: Pista
var opzioni: Dictionary = {}
var eventi: Array = []
var rng := RandomNumberGenerator.new()
var _segnalini_in_sospeso := 0
var _in_movimento := -1

# ------------------------------------------------------------------ creazione

## conf: {regole, pista, giri, auto: [{nome, pilota, tipo, uid}], seme}
static func nuova(conf: Dictionary) -> Motore:
	var m := Motore.new()
	m.pista = Pista.carica(conf.pista)
	if conf.has("seme"):
		m.rng.seed = conf.seme
	else:
		m.rng.randomize()
	var regole: String = conf.get("regole", "base")
	m.s = {"regole": regole, "pista": conf.pista, "giri": int(conf.get("giri", m.pista.giri)), "fase": "gara", "turno": 1,
		"ordine": [], "auto": [], "danni": [], "arrivi": [], "attesa": null, "sforzo": false, "n_danni": 0}
	# griglia: ognuno tira il dado nero, il più alto parte in pole
	var tiri := []
	for i in conf.auto.size():
		tiri.append([m.rng.randi_range(1, 20) * 100 + m.rng.randi_range(0, 99), i])
	tiri.sort_custom(func(a, b): return a[0] > b[0])
	var testo := []
	for k in tiri.size():
		var i: int = tiri[k][1]
		var c: Dictionary = conf.auto[i]
		var pf := {}
		for z in Dati.zone(regole):
			pf[z.id] = int(z.inizio)
		var a := {"i": m.s.auto.size(), "nome": c.nome, "pilota": int(c.pilota), "posto": Dati.PILOTI[int(c.pilota)].posto,
			"tipo": c.get("tipo", "ia"), "uid": c.get("uid", ""), "c": m.pista.griglia[k], "marcia": 0, "pf": pf, "giro": 0,
			"ferm": -1, "fuori": false, "perche": "", "posto_arrivo": 0, "testa": false, "max_marcia": 0, "stallo": -1,
			"mosso": -1, "partito": false, "dado": 0, "tiro_griglia": tiri[k][0] / 100}
		m.s.auto.append(a)
		m.s.ordine.append(a.i)
		testo.append("%d. %s (%d)" % [k + 1, a.nome, a.tiro_griglia])
	m._msg("Griglia di partenza (dado nero): " + "   ".join(testo), "ordine")
	m._riordina()
	return m

static func da_salvataggio(testo: String) -> Motore:
	var d = str_to_var(testo)
	if not (d is Dictionary) or not d.has("auto"):
		return null
	var m := Motore.new()
	m.s = d
	m.pista = Pista.carica(d.pista)
	if m.pista == null:
		return null
	m.rng.randomize()
	if m.s.attesa != null and m.s.attesa.tipo == "mossa":
		m._calcola_opzioni()
	return m

func salva() -> String:
	return var_to_str(s)

# ------------------------------------------------------------------ eventi

func _msg(testo: String, tipo := "info", auto := -1) -> void:
	eventi.append({"t": "msg", "testo": testo, "tipo": tipo, "auto": auto})

func preleva_eventi() -> Array:
	var e := eventi
	eventi = []
	return e

# ------------------------------------------------------------------ utilità

func avanzate() -> bool:
	return s.regole == "avanzate"

func in_gara(a: Dictionary) -> bool:
	return not a.fuori and a.posto_arrivo == 0

func _in_pit(a: Dictionary) -> bool:
	var c = pista.per_id.get(a.c)
	return c != null and c.pit

func _inizio(a: Dictionary, zona: String) -> int:
	for z in Dati.zone(s.regole):
		if z.id == zona:
			return int(z.inizio)
	return 0

func _nero() -> int:
	return rng.randi_range(1, 20)

func _puo_pit(a: Dictionary) -> bool:
	return a.giro >= 1 and a.giro < s.giri and not pista.pit.is_empty()

func classifica() -> Array:
	var out := []
	for i in s.arrivi:
		out.append(i)
	var corsa := []
	for a in s.auto:
		if in_gara(a):
			corsa.append(a)
	corsa.sort_custom(func(x, y): return _chiave(x) > _chiave(y))
	for a in corsa:
		out.append(a.i)
	var fuori := []
	for a in s.auto:
		if a.fuori:
			fuori.append(a)
	fuori.sort_custom(func(x, y): return x.get("fuori_n", 0) > y.get("fuori_n", 0))
	for a in fuori:
		out.append(a.i)
	return out

func _chiave(a: Dictionary) -> float:
	return a.giro * pista.lunghezza + float(pista.lungo.get(a.c, 0.0))

# ------------------------------------------------------------------ usura

func _usura(a: Dictionary, usura: Dictionary, motivo: String, controlla := true) -> void:
	var perso := {}
	for z in Dati.zone(s.regole):
		var n := int(usura.get(z.id, 0))
		if n > 0:
			a.pf[z.id] -= n
			perso[z.id] = n
			if avanzate() and (z.id == "carrozzeria" or z.id == "motore"):
				for k in n:
					_lascia_segnalino(a)
	if perso.is_empty():
		return
	eventi.append({"t": "usura", "auto": a.i, "usura": perso, "motivo": motivo, "pf": a.pf.duplicate()})
	_msg("%s perde %s (%s)" % [a.nome, Dati.testo_usura(s.regole, perso), motivo], "usura", a.i)
	if controlla:
		_controlla_fuori(a)

func _lascia_segnalino(a: Dictionary) -> void:
	if not avanzate():
		return
	if _in_movimento == a.i:
		_segnalini_in_sospeso += 1
	else:
		_metti_segnalino(a.c)

func _metti_segnalino(cid: String) -> void:
	var c = pista.per_id.get(cid)
	if c == null or c.pit:
		return
	s.n_danni += 1
	s.danni.append({"id": s.n_danni, "c": cid})
	eventi.append({"t": "segnalino", "c": cid, "id": s.n_danni})

func _controlla_fuori(a: Dictionary) -> void:
	if a.fuori:
		return
	for z in Dati.zone(s.regole):
		if z.has("fuori") and a.pf[z.id] <= z.fuori:
			_elimina(a, "%s a zero" % z.nome)
			return

func _elimina(a: Dictionary, perche: String) -> void:
	if a.fuori or a.posto_arrivo > 0:
		return
	a.fuori = true
	a.perche = perche
	a.fuori_n = s.turno * 100 + a.giro
	a.dove = a.c
	eventi.append({"t": "fuori", "auto": a.i, "c": a.c, "perche": perche})
	_msg("%s è fuori gara: %s" % [a.nome, perche], "fuori", a.i)
	if avanzate():
		if _in_movimento == a.i:
			_segnalini_in_sospeso += 1
		else:
			_metti_segnalino(a.c)
	if _in_movimento != a.i:
		a.c = ""

# ------------------------------------------------------------------ marce

## Le marce che l'auto può innestare: [{m, costo, fuori}]
func marce(a: Dictionary) -> Array:
	var out := []
	if a.testa or a.marcia == 0:
		return [{"m": 1, "costo": {}, "fuori": false}]
	if a.max_marcia > 0:
		for m in range(1, a.max_marcia + 1):
			out.append({"m": m, "costo": {}, "fuori": false})
		return out
	var da: int = a.marcia
	var esente := _in_pit(a)
	for m in range(1, min(6, da + 1) + 1):
		var costo := {}
		if m < da - 1 and not esente:
			var saltate := da - m - 1
			if saltate > 3:
				continue
			if avanzate():
				if a.pf.cambio <= 0:
					continue
				costo = SCALATA_AVANZATA[saltate].duplicate()
			else:
				costo = {"ps": saltate}
		var fuori := false
		for z in Dati.zone(s.regole):
			if z.has("fuori") and z.id != "gomme" and a.pf[z.id] - int(costo.get(z.id, 0)) <= z.fuori:
				fuori = true
		out.append({"m": m, "costo": costo, "fuori": fuori})
	return out

# ------------------------------------------------------------------ mosse

## Che cosa costa finire la mossa come `o` a un'auto che aveva `pf`: {usura, testa, fuori}
func usura_mossa(o: Dictionary, pf: Dictionary) -> Dictionary:
	var w := {}
	var fuori := ""
	var testa := false
	if not avanzate():
		var n: int = o.freno + o.oltre
		if n > 0:
			w["ps"] = n
	else:
		var b: int = o.freno
		if b > FRENATA_MASSIMA:
			fuori = "impossibile frenare %d caselle" % b
		var scie := int(o.get("scia_curve", 0))
		if b > 0 or scie > 0:
			var freni: int = min(b, 3) + scie
			var gomme: int = max(0, b - 3)
			var ha: int = max(0, pf.freni)
			if freni > ha:
				gomme += freni - ha
				freni = ha
			if freni > 0:
				w["freni"] = freni
			if gomme > 0:
				w["gomme"] = gomme
		var n: int = o.oltre
		if n > 0:
			var t: int = pf.gomme - int(w.get("gomme", 0))
			if n < t:
				w["gomme"] = int(w.get("gomme", 0)) + n
			elif n == t:
				w["gomme"] = int(w.get("gomme", 0)) + n
				testa = true
			elif t <= 0 and n == 1:
				testa = true
			else:
				w["gomme"] = int(w.get("gomme", 0)) + n
				if fuori == "":
					fuori = "lungo di %d alla curva %d con %d Gomme" % [n, o.curva, max(0, t)]
	if o.mancate >= 2:
		fuori = "curva %d senza le fermate obbligatorie" % o.curva
	return {"usura": w, "testa": testa, "fuori": fuori}

func _effetto(a: Dictionary, o: Dictionary, suo_box: bool) -> Dictionary:
	var e := usura_mossa(o, a.pf)
	if e.fuori == "":
		for z in Dati.zone(s.regole):
			if not z.has("fuori"):
				continue
			var resta: int = a.pf[z.id] - int(e.usura.get(z.id, 0))
			if suo_box and ((avanzate() and z.id == "gomme") or not avanzate()):
				resta = int(z.inizio)
			if resta <= z.fuori:
				e.fuori = "%s a zero" % z.nome
				break
	return e

func _costo(a: Dictionary, o: Dictionary) -> float:
	var oo := o
	var c = pista.per_id.get(o.casella)
	if c != null and c.pit and o.freno > 0:
		oo = o.duplicate()
		oo.freno = 0
	var e := _effetto(a, oo, false)
	var tot := 0.0
	for k in e.usura:
		tot += e.usura[k]
	if e.fuori != "":
		tot += 1000.0
	return tot

func _apri_mossa(a: Dictionary, tiro: int) -> void:
	s.attesa = {"tipo": "mossa", "auto": a.i, "tiro": tiro}
	_calcola_opzioni()

func _calcola_opzioni() -> void:
	opzioni = opzioni_per(s.auto[s.attesa.auto], s.attesa.tiro)

## Come andrebbe un tiro di `tiro` dopo aver innestato la marcia `opz` (per l'IA): le opzioni di mossa.
func prova(a: Dictionary, opz: Dictionary, tiro: int) -> Dictionary:
	var m0: int = a.marcia
	var pf0: Dictionary = a.pf
	a.marcia = opz.m
	a.pf = pf0.duplicate()
	for k in opz.costo:
		a.pf[k] -= opz.costo[k]
	var r := opzioni_per(a, tiro)
	a.marcia = m0
	a.pf = pf0
	return r

func opzioni_per(a: Dictionary, tiro: int) -> Dictionary:
	var occupate := {}
	var marce_altre := {}
	for b in s.auto:
		if b.i != a.i and b.c != "" and in_gara(b):
			occupate[b.c] = true
			marce_altre[b.c] = b.marcia
	var costo := func(o): return _costo(a, o)
	var reach := Mosse.raggiungi(pista, a.c, tiro, {"occupate": occupate, "fermate": a.ferm, "pit": _puo_pit(a),
		"posto": a.posto, "costo": costo})
	for cid in reach:
		if pista.per_id[cid].pit:
			reach[cid].freno = 0
	if avanzate():
		var altre := Mosse.scia(pista, reach, {"occupate": occupate, "marce": marce_altre, "marcia": a.marcia,
			"min_marcia": 4, "spazi": 3, "posto": a.posto, "costo": costo})
		for cid in altre:
			if not reach.has(cid) or _costo(a, altre[cid]) < _costo(a, reach[cid]):
				reach[cid] = altre[cid]
	var segnati := {}
	for d in s.danni:
		segnati[d.c] = true
	for cid in reach:
		var o: Dictionary = reach[cid]
		var c = pista.per_id[cid]
		var suo_box: bool = c.box != "" and c.box == a.posto and cid != a.c
		var e := _effetto(a, o, suo_box)
		e.box = suo_box
		e.finisce = o.traguardo and a.giro + 1 > s.giri
		if e.finisce:
			e.usura = {}
			e.testa = false
			e.fuori = ""
		e.tocca = []
		if e.fuori == "" and not e.finisce and not c.pit:
			var acc: Array = pista.vicini.get(cid, [])
			for b in s.auto:
				if b.i != a.i and in_gara(b) and b.c != "" and acc.has(b.c) and not _in_pit(b):
					e.tocca.append(b.i)
		e.pericoli = []
		if avanzate() and not e.finisce:
			for k in range(1, o.percorso.size()):
				if segnati.has(o.percorso[k]):
					e.pericoli.append(o.percorso[k])
		o.eff = e
	return reach

# ------------------------------------------------------------------ il giro di gioco

func _riordina() -> void:
	var posti := []
	var in_ordine := []
	for k in s.ordine.size():
		var a: Dictionary = s.auto[s.ordine[k]]
		if in_gara(a) and pista.lungo.has(a.c):
			posti.append(k)
			in_ordine.append({"a": a, "era": k, "chiave": _chiave(a), "interno": pista.interno(a.c), "pit": _in_pit(a)})
	in_ordine.sort_custom(func(x, y):
		if x.pit != y.pit:
			return y.pit
		if x.chiave != y.chiave:
			return x.chiave > y.chiave
		return x.era < y.era)
	var i := 0
	while i < in_ordine.size():
		var j := i
		while j < in_ordine.size() - 1 and in_ordine[j + 1].pit == in_ordine[i].pit \
				and in_ordine[i].chiave - in_ordine[j + 1].chiave < ALLA_PARI * pista.cella:
			j += 1
		var gruppo := in_ordine.slice(i, j + 1)
		gruppo.sort_custom(func(x, y):
			if x.a.marcia != y.a.marcia:
				return x.a.marcia > y.a.marcia
			if x.interno != y.interno:
				return x.interno > y.interno
			return x.era < y.era)
		for k in gruppo.size():
			in_ordine[i + k] = gruppo[k]
		i = j + 1
	for k in in_ordine.size():
		s.ordine[posti[k]] = in_ordine[k].a.i

func di_turno():
	if s.fase != "gara":
		return null
	for i in s.ordine:
		var a: Dictionary = s.auto[i]
		if in_gara(a) and a.mosso != s.turno and a.stallo != s.turno:
			return a
	return null

func _in_corsa() -> int:
	var n := 0
	for a in s.auto:
		if in_gara(a):
			n += 1
	return n

## Va avanti finché serve una decisione o la gara è finita.
func avanza() -> void:
	var giri_vuoti := 0
	while s.fase == "gara" and s.attesa == null:
		if _in_corsa() == 0:
			s.fase = "fine"
			eventi.append({"t": "fine"})
			var nomi := []
			var cl := classifica()
			for k in cl.size():
				var a: Dictionary = s.auto[cl[k]]
				nomi.append(("%d. " % a.posto_arrivo if a.posto_arrivo > 0 else "rit. ") + a.nome)
			_msg("Bandiera a scacchi! " + "   ".join(nomi), "arrivo")
			return
		var a = di_turno()
		if a == null:
			s.turno += 1
			_riordina()
			eventi.append({"t": "turno", "n": s.turno, "ordine": s.ordine.duplicate()})
			giri_vuoti += 1
			if giri_vuoti > 3:
				return
			continue
		giri_vuoti = 0
		_inizia(a)

func _inizia(a: Dictionary) -> void:
	eventi.append({"t": "tocca", "auto": a.i})
	if not a.partito:
		a.partito = true
		var v := _nero()
		var lampo := 20 if avanzate() else 17
		if v == 1:
			a.stallo = s.turno
			_nero_evento(a, v, "partenza", "motore spento! Resta fermo e parte al prossimo turno", true)
			return
		elif v >= lampo:
			_nero_evento(a, v, "partenza", "partenza lampo! Avanza subito di 4 caselle", false)
			a.marcia = 1
			a.dado = 4
			_apri_mossa(a, 4)
			return
		_nero_evento(a, v, "partenza", "partenza regolare, in 1a", false)
	var opz := marce(a)
	if opz.is_empty():
		# senza Cambio e con la marcia troppo alta per il limite: non dovrebbe succedere
		opz = [{"m": max(1, a.marcia - 1), "costo": {}, "fuori": false}]
	if opz.size() == 1:
		_scegli_marcia(a, opz[0])
	else:
		s.attesa = {"tipo": "marcia", "auto": a.i}

func _nero_evento(a: Dictionary, v: int, motivo: String, testo: String, male: bool) -> void:
	eventi.append({"t": "nero", "auto": a.i, "valore": v, "motivo": motivo, "testo": testo, "male": male})
	_msg("%s, dado nero %d: %s (%s)" % [a.nome, v, testo, motivo], "avviso" if male else "info", a.i)

func _scegli_marcia(a: Dictionary, opz: Dictionary) -> void:
	s.attesa = null
	_in_movimento = a.i
	_segnalini_in_sospeso = 0
	if not opz.costo.is_empty():
		_usura(a, opz.costo, "scalata dalla %s alla %s" % [Dati.NOMI_MARCE[a.marcia], Dati.NOMI_MARCE[opz.m]])
	if a.fuori:
		_fine_mossa(a)
		return
	var facce: Array = Dati.DADI[opz.m]
	var k := rng.randi() % facce.size()
	var v := int(facce[k][0])
	var in_pit := _in_pit(a)
	a.marcia = opz.m
	a.max_marcia = 0
	a.testa = false
	a.dado = v
	eventi.append({"t": "dado", "auto": a.i, "marcia": opz.m, "valore": v, "faccia": k})
	_msg("%s innesta la %s e tira %d" % [a.nome, Dati.NOMI_MARCE[opz.m], v], "tiro", a.i)
	s.sforzo = int(Dati.SFORZO.get(opz.m, 0)) == v and not in_pit
	_apri_mossa(a, v)

## Riceve una decisione: {t: "marcia", m} oppure {t: "mossa", c}. Ritorna false se non è valida.
func applica(az: Dictionary) -> bool:
	if s.attesa == null:
		return false
	var a: Dictionary = s.auto[s.attesa.auto]
	if s.attesa.tipo == "marcia" and az.get("t") == "marcia":
		for o in marce(a):
			if o.m == int(az.get("m", 0)):
				_scegli_marcia(a, o)
				avanza()
				return true
		return false
	if s.attesa.tipo == "mossa" and az.get("t") == "mossa":
		var cid := str(az.get("c", ""))
		if not opzioni.has(cid):
			return false
		_muovi(a, cid)
		avanza()
		return true
	return false

func _muovi(a: Dictionary, cid: String) -> void:
	var o: Dictionary = opzioni[cid]
	var e: Dictionary = o.eff
	s.attesa = null
	opzioni = {}
	_in_movimento = a.i
	var rapida := 0
	a.c = cid
	a.ferm = o.fermate
	eventi.append({"t": "muovi", "auto": a.i, "percorso": o.percorso, "scia": int(o.get("scia", 0))})
	if int(o.get("scia", 0)) > 0:
		_msg("%s prende la scia%s" % [a.nome, "" if o.scia == 1 else " %d volte" % o.scia], "info", a.i)
	if e.finisce:
		a.giro += 1
		_arriva(a)
	else:
		if o.traguardo:
			a.giro += 1
			eventi.append({"t": "giro", "auto": a.i, "giro": a.giro})
			if a.giro > 1:
				_msg("%s inizia il giro %d di %d%s" % [a.nome, a.giro, s.giri, " - ultimo giro!" if a.giro == s.giri else ""], "giro", a.i)
		var motivi := []
		if o.freno > 0 and not e.usura.is_empty():
			motivi.append("frenata di %d" % o.freno)
		if o.oltre > 0:
			motivi.append("lungo di %d alla curva %d" % [o.oltre, o.curva])
		if int(o.get("scia_curve", 0)) > 0:
			motivi.append("scia fin dentro la curva")
		_usura(a, e.usura, ", ".join(motivi), false)
		if e.box:
			rapida = _sosta(a)
		if e.testa and not a.fuori:
			a.testa = true
			eventi.append({"t": "testacoda", "auto": a.i})
			_msg("%s va in testacoda! Ripartirà in 1a" % a.nome, "avviso", a.i)
		if e.fuori != "":
			_elimina(a, e.fuori)
		_controlla_fuori(a)
	# i segnalini lasciati durante la mossa vanno dove è finita
	for k in _segnalini_in_sospeso:
		_metti_segnalino(cid)
	_segnalini_in_sospeso = 0
	_in_movimento = -1
	if a.fuori:
		a.c = ""
	if in_gara(a):
		for j in e.tocca:
			var b: Dictionary = s.auto[j]
			if not in_gara(b):
				continue
			if in_gara(a):
				_collisione(a, b)
			if in_gara(b):
				_collisione(b, a)
		for pid in e.pericoli:
			if not in_gara(a):
				break
			var v := _nero()
			if v <= 4:
				_nero_evento(a, v, "detriti", "l'auto prende un colpo", true)
				_usura(a, {"tenuta": 1}, "detriti in pista")
			else:
				_nero_evento(a, v, "detriti", "passa indenne", false)
	if s.sforzo:
		s.sforzo = false
		_msg("Motore sotto sforzo! Tutte le auto in 5a e 6a tirano il dado nero", "avviso", a.i)
		for b in s.auto:
			if in_gara(b) and (b.marcia == 5 or b.marcia == 6) and not _in_pit(b):
				var v := _nero()
				if v <= 4:
					_nero_evento(b, v, "motore", "il motore soffre", true)
					_usura(b, {"motore": 1} if avanzate() else {"ps": 1}, "motore sotto sforzo")
				else:
					_nero_evento(b, v, "motore", "il motore tiene", false)
	if rapida > 0 and in_gara(a):
		a.marcia = 4
		a.max_marcia = 0
		a.dado = rapida
		_apri_mossa(a, rapida)
		return
	_fine_mossa(a)

func _fine_mossa(a: Dictionary) -> void:
	_in_movimento = -1
	for k in _segnalini_in_sospeso:
		_metti_segnalino(a.c if a.c != "" else str(a.get("dove", "")))
	_segnalini_in_sospeso = 0
	a.mosso = s.turno
	if a.fuori:
		a.c = ""

func _collisione(a: Dictionary, b: Dictionary) -> void:
	var v := _nero()
	var colpo := v == 1 if avanzate() else v <= 4
	if colpo:
		_nero_evento(a, v, "contatto con %s" % b.nome, "collisione!", true)
		_usura(a, {"carrozzeria": 1} if avanzate() else {"ps": 1}, "collisione con %s" % b.nome)
	else:
		_nero_evento(a, v, "contatto con %s" % b.nome, "nessun danno", false)

## Sosta nel proprio box. Ritorna le caselle della ripartenza immediata (sosta rapida), o 0.
func _sosta(a: Dictionary) -> int:
	for z in Dati.zone(s.regole):
		if not avanzate() or z.id == "gomme":
			a.pf[z.id] = int(z.inizio)
	a.max_marcia = 4
	eventi.append({"t": "box", "auto": a.i, "pf": a.pf.duplicate()})
	if not avanzate():
		_msg("%s si ferma al box: tutti i PS recuperati, ripartirà al massimo in 4a" % a.nome, "info", a.i)
		return 0
	_msg("%s si ferma al box: gomme nuove" % a.nome, "info", a.i)
	var v := _nero()
	if v <= 10:
		var n := int(ceil(v / 2.0))
		_nero_evento(a, v, "sosta ai box", "sosta rapida! Riparte subito in 4a per %d casell%s" % [n, "a" if n == 1 else "e"], false)
		return n
	_nero_evento(a, v, "sosta ai box", "sosta lenta: riparte al prossimo turno, al massimo in 4a", false)
	return 0

func _arriva(a: Dictionary) -> void:
	s.arrivi.append(a.i)
	a.posto_arrivo = s.arrivi.size()
	a.dove = a.c
	a.c = ""
	eventi.append({"t": "arrivo", "auto": a.i, "posto": a.posto_arrivo})
	if a.posto_arrivo == 1:
		_msg("%s vince la gara!" % a.nome, "arrivo", a.i)
	else:
		_msg("%s taglia il traguardo: %d° posto" % [a.nome, a.posto_arrivo], "arrivo", a.i)

# ------------------------------------------------------------------ per i telefoni e gli ospiti

## Lo stato in forma compatta, da mandare a telefoni e ospiti.
func vista() -> Dictionary:
	var v := {"regole": s.regole, "pista": s.pista, "giri": s.giri, "fase": s.fase, "turno": s.turno, "ordine": s.ordine,
		"cl": classifica(), "danni": [], "auto": [], "att": null}
	for d in s.danni:
		v.danni.append(d.c)
	for a in s.auto:
		v.auto.append({"n": a.nome, "p": a.pilota, "u": a.uid, "tp": a.tipo, "c": a.c, "m": a.marcia, "pf": a.pf, "g": a.giro,
			"f": a.fuori, "pa": a.posto_arrivo, "t": a.testa, "d": a.dado, "mo": a.mosso == s.turno, "w": a.perche,
			"dv": a.get("dove", "")})
	if s.attesa != null:
		var a: Dictionary = s.auto[s.attesa.auto]
		var att := {"tipo": s.attesa.tipo, "auto": a.i, "uid": a.uid}
		if s.attesa.tipo == "marcia":
			att.marce = marce(a)
		else:
			att.tiro = s.attesa.tiro
			att.da = a.c
			var l := []
			for cid in opzioni:
				var o: Dictionary = opzioni[cid]
				var e: Dictionary = o.eff
				var p := pista.pos(cid)
				l.append({"c": cid, "x": int(p.x), "y": int(p.y), "mo": o.mosse, "u": e.usura, "fu": e.fuori, "te": e.testa,
					"bx": e.box, "fi": e.finisce, "to": e.tocca.size(), "pe": e.pericoli.size(), "sc": int(o.get("scia", 0)),
					"fr": o.freno, "ol": o.oltre})
			att.opz = l
		v.att = att
	return v
