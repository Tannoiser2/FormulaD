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

## conf: {regole, pista, giri, auto: [{nome, pilota, tipo, uid}], seme, opzioni: {meteo, libero, strada}}
static func nuova(conf: Dictionary) -> Motore:
	var m := Motore.new()
	m.pista = Pista.carica(conf.pista)
	if conf.has("seme"):
		m.rng.seed = conf.seme
	else:
		m.rng.randomize()
	var regole: String = conf.get("regole", "base")
	var op: Dictionary = conf.get("opzioni", {})
	var av := regole == "avanzate"
	var strada := bool(op.get("strada", false))
	m.s = {"regole": regole, "pista": conf.pista, "giri": int(conf.get("giri", m.pista.giri)), "fase": "gara", "turno": 1,
		"ordine": [], "auto": [], "danni": [], "arrivi": [], "attesa": null, "sforzo": false, "n_danni": 0,
		"strada": strada, "libero": av and not strada and bool(op.get("libero", false)),
		"meteo_on": av and bool(op.get("meteo", false)), "meteo": -1}
	# griglia: ognuno tira il dado nero, il più alto parte in pole
	var tiri := []
	for i in conf.auto.size():
		# Diane Montfort vince le parità in griglia
		var diane: bool = strada and av and Dati.PILOTI[int(conf.auto[i].pilota)].id == "diane"
		tiri.append([m.rng.randi_range(1, 20) * 100 + (99 if diane else m.rng.randi_range(0, 98)), i])
	tiri.sort_custom(func(a, b): return a[0] > b[0])
	var testo := []
	for k in tiri.size():
		var i: int = tiri[k][1]
		var c: Dictionary = conf.auto[i]
		var pf := {}
		for z in Dati.zone(regole):
			pf[z.id] = int(z.inizio)
		if strada and av:
			var carta: Array = Dati.AUTO_STRADA[Dati.PILOTI[int(c.pilota)].id]
			var ids := Dati.zone_ids()
			for z in ids.size():
				pf[ids[z]] = int(carta[z])
		var da_preparare: bool = m.s.libero or (m.s.meteo_on and not strada)
		var a := {"pf0": pf.duplicate(), "gomme_tipo": "dure", "eta": 0, "nitro": -99, "radio": false, "scarto": -99,
			"pronto": not da_preparare,"i": m.s.auto.size(), "nome": c.nome, "pilota": int(c.pilota), "posto": Dati.PILOTI[int(c.pilota)].posto,
			"tipo": c.get("tipo", "ia"), "uid": c.get("uid", ""), "c": m.pista.griglia[k], "marcia": 0, "pf": pf, "giro": 0,
			"ferm": -1, "fuori": false, "perche": "", "posto_arrivo": 0, "testa": false, "max_marcia": 0, "stallo": -1,
			"mosso": -1, "partito": false, "dado": 0, "tiro_griglia": tiri[k][0] / 100}
		m.s.auto.append(a)
		m.s.ordine.append(a.i)
		testo.append("%d. %s (%d)" % [k + 1, a.nome, a.tiro_griglia])
	m._msg("Griglia di partenza (dado nero): " + "   ".join(testo), "ordine")
	if m.s.meteo_on:
		var r := m._dado_meteo("meteo al via")
		m.s.meteo = [3, 1, 0][r]
		m._msg("Meteo: %s" % Dati.NOMI_METEO[m.s.meteo], "ordine")
		m.eventi.append({"t": "meteo", "m": m.s.meteo})
	# la storia della gara per il replay: posizioni di partenza, poi ogni movimento e ogni uscita con il suo turno
	var via := {}
	for a in m.s.auto:
		via[str(a.i)] = a.c
	m.s.storia = {"via": via, "mosse": []}
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
	if a.has("pf0") and a.pf0.has(zona):
		return int(a.pf0[zona])
	for z in Dati.zone(s.regole):
		if z.id == zona:
			return int(z.inizio)
	return 0

func _nero() -> int:
	return rng.randi_range(1, 20)

func _puo_pit(a: Dictionary) -> bool:
	return a.giro >= 1 and a.giro < s.giri and not pista.pit.is_empty() and not s.get("strada", false)

func pioggia() -> bool:
	return int(s.get("meteo", -1)) >= 2

## Le abilità dei piloti valgono nelle gare su strada con le regole avanzate.
func abilita() -> bool:
	return s.get("strada", false) and avanzate()

func chi(a: Dictionary, id: String) -> bool:
	return abilita() and Dati.PILOTI[int(a.pilota)].id == id

func _c_e(id: String) -> bool:
	for b in s.auto:
		if in_gara(b) and chi(b, id):
			return true
	return false

## Dado nero del meteo: 0 pioggia, 1 variabile, 2 bel tempo. Julien Marcellin ritira quando esce pioggia.
func _dado_meteo(motivo: String) -> int:
	var v := _nero()
	var r := _esito_meteo(v)
	var testo: String = ["pioggia", "variabile", "bel tempo"][r]
	if r == 0 and _c_e("julien"):
		var v2 := _nero()
		_msg("Meteo (%s): esce %d, pioggia, ma Julien Marcellin ritira: %d" % [motivo, v, v2], "info")
		v = v2
		r = _esito_meteo(v)
		testo = ["pioggia", "variabile", "bel tempo"][r]
	eventi.append({"t": "nero", "auto": -1, "valore": v, "motivo": motivo, "testo": testo, "male": r == 0})
	return r

func _esito_meteo(v: int) -> int:
	var tab: Array = Dati.TABELLA_METEO
	if v <= int(tab[0]):
		return 0
	if v <= int(tab[1]):
		return 1
	return 2

func _cambia_meteo() -> void:
	var r := _dado_meteo("cambio del tempo")
	var prima: int = s.meteo
	if r == 2:
		s.meteo = max(0, s.meteo - 1)
	elif r == 0:
		s.meteo = min(3, s.meteo + 1)
	if s.meteo != prima:
		var testo: String = "comincia a piovere!" if s.meteo >= 2 and prima < 2 else ("smette di piovere" if s.meteo < 2 and prima >= 2 else "il tempo cambia")
		_msg("Meteo: %s (%s)" % [Dati.NOMI_METEO[s.meteo], testo], "avviso")
	else:
		_msg("Meteo: resta %s" % Dati.NOMI_METEO[s.meteo], "info")
	eventi.append({"t": "meteo", "m": s.meteo})

## Quanto costa ogni casella oltre la curva, a seconda delle gomme.
func _molt_lungo(a: Dictionary) -> int:
	if not s.get("meteo_on", false):
		return 1
	var t: String = a.get("gomme_tipo", "dure")
	var eta := int(a.get("eta", 0))
	if t == "morbide":
		return 3 if eta >= 2 else (1 if pioggia() else 2)
	if t == "pioggia":
		return 1 if pioggia() else (3 if eta >= 2 else 2)
	return 1

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
	_storia({"a": a.i, "x": "fuori"})
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
func usura_mossa(o: Dictionary, pf: Dictionary, molt := 1) -> Dictionary:
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
		var n: int = o.oltre * molt
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
	var e := usura_mossa(o, a.pf, _molt_lungo(a))
	if e.fuori == "":
		for z in Dati.zone(s.regole):
			if not z.has("fuori"):
				continue
			var resta: int = a.pf[z.id] - int(e.usura.get(z.id, 0))
			if suo_box and ((avanzate() and z.id == "gomme") or not avanzate()):
				resta = _inizio(a, z.id)
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

## Che cosa può succedere innestando la marcia `opz`: per ogni tiro possibile l'esito migliore, e tutte le
## caselle dove si può arrivare. {t: [[tiro, livello, punti persi]], c: [opzioni come nella vista]}
## livello: 0 libera, 1 costa punti, 2 testacoda, 3 ritiro.
func anteprima(a: Dictionary, opz: Dictionary) -> Dictionary:
	var valori := {}
	for f in Dati.DADI[opz.m]:
		valori[int(f[0])] = true
	var tiri := valori.keys()
	tiri.sort()
	var esiti := []
	var celle := {}
	var pesi := {}
	for tiro in tiri:
		var r := prova(a, opz, tiro)
		var meglio := [tiro, 3, 0]
		var peso_m := INF
		for cid in r:
			var e: Dictionary = r[cid].eff
			var tot := 0
			for k in e.usura:
				tot += int(e.usura[k])
			var liv := 3 if e.fuori != "" else (2 if e.testa else (1 if tot > 0 else 0))
			var peso := float(liv * 100 + tot)
			if peso < peso_m:
				peso_m = peso
				meglio = [tiro, liv, tot]
			if not pesi.has(cid) or peso < pesi[cid]:
				pesi[cid] = peso
				var p := pista.pos(cid)
				var voce := {"c": cid, "x": int(p.x), "y": int(p.y)}
				if not e.usura.is_empty():
					voce["u"] = e.usura
				if e.fuori != "":
					voce["fu"] = e.fuori
				if e.testa:
					voce["te"] = true
				if e.box:
					voce["bx"] = true
				if e.finisce:
					voce["fi"] = true
				var ex: Dictionary = r[cid].get("extra", {})
				for k in [["ni", "ni"], ["pi", "piu"], ["jk", "jk"]]:
					if int(ex.get(k[1], 0)) != 0:
						voce[k[0]] = int(ex[k[1]])
				if int(r[cid].get("scia", 0)) > 0:
					voce["sc"] = int(r[cid].scia)
				voce["r"] = snappedf(float(pista.per_id[cid].r), 0.1)
				celle[cid] = voce
		esiti.append(meglio)
	return {"t": esiti, "c": celle.values()}

## Le aggiunte facoltative al tiro: [{v: caselle in più, ni: Nitro usato}], la prima è «nessuna».
func _aggiunte(a: Dictionary) -> Array:
	var out := [{"v": 0, "ni": 0}]
	if _in_pit(a):
		return out
	var morbide: bool = s.get("meteo_on", false) and a.get("gomme_tipo", "") == "morbide" and not pioggia() \
		and int(a.get("eta", 0)) < 1
	if morbide:
		out.append({"v": 1, "ni": 0})
	if s.get("strada", false) and int(a.get("nitro", -99)) != a.giro and a.marcia >= 1:
		var bonus := [int(a.marcia)]
		if chi(a, "montoya"):
			bonus.append(int(a.marcia) + 3)
		for b in bonus:
			out.append({"v": b, "ni": b})
			if morbide:
				out.append({"v": b + 1, "ni": b})
	return out

## Caselle in più sotto la pioggia quando la mossa tocca una curva.
func _scivola(a: Dictionary) -> int:
	if not s.get("meteo_on", false) or not pioggia():
		return 0
	var t: String = a.get("gomme_tipo", "dure")
	var n := 1 if t == "pioggia" else 3
	if n == 3 and chi(a, "julien"):
		n = 1
	return n

func _tocca_curva(percorso: Array) -> bool:
	for k in range(1, percorso.size()):
		var c = pista.per_id.get(percorso[k])
		if c != null and c.c > 0 and not c.pit:
			return true
	return false

func opzioni_per(a: Dictionary, tiro: int) -> Dictionary:
	var occupate := {}
	var marce_altre := {}
	for b in s.auto:
		if b.i != a.i and b.c != "" and in_gara(b):
			occupate[b.c] = true
			marce_altre[b.c] = b.marcia
	var costo := func(o): return _costo(a, o)
	var agg := _aggiunte(a)
	var sciv := _scivola(a)
	var jack := [0, -1, 1] if chi(a, "jack") and not _in_pit(a) else [0]
	var litsu: bool = _c_e("litsu") and not chi(a, "litsu")
	var dist := {}
	for g in agg:
		for j in jack:
			for r in [0, sciv]:
				for l in [0, -1 if litsu else 0]:
					var d: int = tiro + int(g.v) + j + r + l
					if d >= 1:
						dist[d] = true
	var reach := {}
	var pesi := {}
	for d in dist:
		var r1 := Mosse.raggiungi(pista, a.c, d, {"occupate": occupate, "fermate": a.ferm, "pit": _puo_pit(a),
			"posto": a.posto, "costo": costo})
		for cid in r1:
			var o: Dictionary = r1[cid]
			if pista.per_id[cid].pit:
				o.freno = 0
			var curva := _tocca_curva(o.percorso)
			var base: int = tiro + (sciv if curva else 0) - (1 if litsu and o.traguardo else 0)
			var scelta = null
			for g in agg:
				for j in (jack if curva else [0]):
					if scelta == null and base + int(g.v) + j == d:
						scelta = {"ni": int(g.ni), "jk": j, "piu": int(g.v)}
			if scelta == null:
				continue
			o.extra = scelta
			var peso: float = _costo(a, o) + (1.0 if scelta.jk != 0 else 0.0) + (0.01 if scelta.ni > 0 else 0.0) + 0.001 * scelta.piu
			if not pesi.has(cid) or peso < pesi[cid]:
				pesi[cid] = peso
				reach[cid] = o
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
		if int(o.get("extra", {}).get("jk", 0)) != 0:
			e.usura["gomme"] = int(e.usura.get("gomme", 0)) + 1
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
			var dx := chi(x.a, "diane")
			if dx != chi(y.a, "diane"):
				return dx
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
	if _prepara():
		return
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

## Prima del via: chi deve ancora scegliere assetto e gomme. Il computer sceglie da solo.
func _prepara() -> bool:
	if s.fase != "gara" or s.attesa != null:
		return s.attesa != null
	for i in s.ordine:
		var a: Dictionary = s.auto[i]
		if a.get("pronto", true):
			continue
		if a.tipo == "ia":
			_assetto(a, assetto_ia(a))
			continue
		s.attesa = {"tipo": "assetto", "auto": a.i, "box": false, "rapida": 0}
		return true
	return false

## Gomme ammesse per questa auto.
func gomme_ammesse(_a: Dictionary) -> Array:
	if not s.get("meteo_on", false) or s.get("strada", false):
		return ["dure"]
	return Dati.GOMME.duplicate()

## Assetto e gomme scelti dal computer.
func assetto_ia(a: Dictionary, solo_gomme := false) -> Dictionary:
	var g := "dure"
	if s.get("meteo_on", false) and not s.get("strada", false):
		if pioggia():
			g = "pioggia"
		elif int(s.meteo) == 0 and a.giro <= 1:
			g = "morbide"
	var az := {"t": "assetto", "g": g}
	if s.get("libero", false) and not solo_gomme and not a.get("pronto", true):
		az["pf"] = Dati.ASSETTO_IA.duplicate()
	return az

func _assetto_valido(a: Dictionary, az: Dictionary) -> bool:
	if az.has("g") and not gomme_ammesse(a).has(str(az.g)):
		return false
	var al_box: bool = s.attesa != null and s.attesa.get("box", false)
	if az.has("pf"):
		if not s.get("libero", false) or al_box:
			return false
		var tot := 0
		for z in Dati.zone(s.regole):
			var n := int(az.pf.get(z.id, -1))
			if n < Dati.ASSETTO_MIN or n > int(z.max):
				return false
			tot += n
		if tot != Dati.ASSETTO_TOTALE:
			return false
	elif s.get("libero", false) and not a.get("pronto", true):
		return false
	return true

func _assetto(a: Dictionary, az: Dictionary) -> void:
	var parti := []
	if az.has("pf"):
		for z in Dati.zone(s.regole):
			a.pf[z.id] = int(az.pf[z.id])
		a.pf0 = a.pf.duplicate()
		parti.append(Dati.testo_usura(s.regole, a.pf))
	if s.get("meteo_on", false):
		var g := str(az.get("g", a.get("gomme_tipo", "dure")))
		if g != a.get("gomme_tipo", "") or not a.get("pronto", true):
			parti.append("gomme %s" % Dati.NOMI_GOMME[g].to_lower())
		a.gomme_tipo = g
		a.eta = 0
	a.pronto = true
	if not parti.is_empty():
		_msg("%s: %s" % [a.nome, ", ".join(parti)], "info", a.i)
	eventi.append({"t": "assetto", "auto": a.i, "pf": a.pf.duplicate(), "g": a.gomme_tipo})

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
	if s.attesa.tipo == "assetto" and az.get("t") == "assetto":
		if not _assetto_valido(a, az):
			return false
		var at: Dictionary = s.attesa
		s.attesa = null
		_assetto(a, az)
		if at.get("box", false):
			var rapida := int(at.get("rapida", 0))
			if rapida > 0 and in_gara(a):
				a.marcia = 4
				a.max_marcia = 0
				a.dado = rapida
				_apri_mossa(a, rapida)
			else:
				_fine_mossa(a)
		avanza()
		return true
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
	var da_c: String = a.c
	var ex: Dictionary = o.get("extra", {})
	if int(ex.get("ni", 0)) > 0:
		a.nitro = a.giro
		_msg("%s usa il Nitro: +%d caselle" % [a.nome, int(ex.ni)], "avviso", a.i)
		eventi.append({"t": "nitro", "auto": a.i, "v": int(ex.ni)})
	if int(ex.get("jk", 0)) != 0:
		_msg("%s derapa in curva (%s1 casella, 1 Gomme)" % [a.nome, "+" if ex.jk > 0 else "-"], "info", a.i)
	# Temana Matahi lascia detriti dove parte, se ha qualcuno dietro
	if chi(a, "temana") and int(a.get("scarto", -99)) != a.giro and not _in_pit(a) and da_c != "":
		for b in s.auto:
			if b.i != a.i and in_gara(b) and b.c != "" and pista.lungo.has(b.c):
				var dietro := _chiave(a) - _chiave(b)
				if dietro > 0.0 and dietro < 8.0 * pista.cella:
					a.scarto = a.giro
					_msg("%s lascia cadere dei rottami in pista" % a.nome, "avviso", a.i)
					_metti_segnalino(da_c)
					break
	a.c = cid
	a.ferm = o.fermate
	eventi.append({"t": "muovi", "auto": a.i, "percorso": o.percorso, "scia": int(o.get("scia", 0))})
	_storia({"a": a.i, "p": o.percorso.duplicate()})
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
				a.eta = int(a.get("eta", 0)) + 1
				if s.get("strada", false):
					_controllo(a)
		var motivi := []
		if o.freno > 0 and not e.usura.is_empty():
			motivi.append("frenata di %d" % o.freno)
		if o.oltre > 0:
			motivi.append("lungo di %d alla curva %d" % [o.oltre, o.curva])
		if int(o.get("scia_curve", 0)) > 0:
			motivi.append("scia fin dentro la curva")
		if int(o.get("extra", {}).get("jk", 0)) != 0:
			motivi.append("derapata")
		_usura(a, e.usura, ", ".join(motivi) if not motivi.is_empty() else "mossa", false)
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
		var soglia_d := 2 if chi(a, "temana") else (5 if pioggia() else 4)
		for pid in e.pericoli:
			if not in_gara(a):
				break
			var v := _nero()
			if v <= soglia_d:
				_nero_evento(a, v, "detriti", "l'auto prende un colpo", true)
				_usura(a, {"tenuta": 1}, "detriti in pista")
			else:
				_nero_evento(a, v, "detriti", "passa indenne", false)
	if in_gara(a) and chi(a, "stanley") and not a.get("radio", false):
		_radio(a)
	if s.sforzo:
		s.sforzo = false
		_msg("Motore sotto sforzo! Tutte le auto in 5a e 6a tirano il dado nero", "avviso", a.i)
		for b in s.auto:
			if in_gara(b) and (b.marcia == 5 or b.marcia == 6) and not _in_pit(b):
				var v := _nero()
				var soglia_m := (3 if pioggia() else 4) - (1 if chi(b, "dimitri") else 0)
				if v <= soglia_m:
					_nero_evento(b, v, "motore", "il motore soffre", true)
					_usura(b, {"motore": 1} if avanzate() else {"ps": 1}, "motore sotto sforzo")
				else:
					_nero_evento(b, v, "motore", "il motore tiene", false)
		if int(s.get("meteo", -1)) == 1 or int(s.get("meteo", -1)) == 2:
			_cambia_meteo()
	if e.box and in_gara(a) and s.get("meteo_on", false) and not s.get("strada", false) and a.tipo != "ia":
		# al box si scelgono le gomme nuove
		_in_movimento = -1
		s.attesa = {"tipo": "assetto", "auto": a.i, "box": true, "rapida": rapida}
		return
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
	# chi collide con Derek Manson tira due volte
	for k in (2 if chi(b, "derek") else 1):
		if not in_gara(a):
			return
		var v := _nero()
		var colpo := v <= (2 if pioggia() else 1) if avanzate() else v <= 4
		eventi.append({"t": "urto", "auto": a.i, "contro": b.i, "colpo": colpo})
		if colpo:
			_nero_evento(a, v, "contatto con %s" % b.nome, "collisione!", true)
			_usura(a, {"carrozzeria": 1} if avanzate() else {"ps": 1}, "collisione con %s" % b.nome)
		else:
			_nero_evento(a, v, "contatto con %s" % b.nome, "nessun danno", false)

## Autoradio di Stanley Washington, una volta per gara, contro un'auto accanto.
func _radio(a: Dictionary) -> void:
	var acc: Array = pista.vicini.get(a.c, [])
	for b in s.auto:
		if b.i != a.i and in_gara(b) and b.c != "" and acc.has(b.c) and not _in_pit(b):
			a.radio = true
			var v := _nero()
			var zona := "tenuta"
			for r in Dati.RADIO:
				if v <= int(r[0]):
					zona = r[1]
					break
			_nero_evento(b, v, "autoradio di Stanley", "colpita la zona %s" % Dati.nome_zona(s.regole, zona), true)
			_usura(b, {zona: 1}, "autoradio di Stanley")
			return

## Punto di controllo al traguardo nelle gare su strada.
func _controllo(a: Dictionary) -> void:
	if not avanzate():
		var prima: int = a.pf.ps
		a.pf.ps = min(18, a.pf.ps + 10)
		if a.pf.ps > prima:
			_msg("%s passa il controllo: +%d PS" % [a.nome, a.pf.ps - prima], "info", a.i)
		eventi.append({"t": "box", "auto": a.i, "pf": a.pf.duplicate()})
		return
	a.pf.gomme = max(a.pf.gomme, _inizio(a, "gomme"))
	var extra := 4 if chi(a, "jenny") else 2
	var dati := []
	for k in extra:
		var meglio := ""
		var manca := 0
		for z in Dati.zone_ids():
			if z == "gomme":
				continue
			var m: int = _inizio(a, z) - int(a.pf[z])
			if m > manca:
				manca = m
				meglio = z
		if meglio == "":
			break
		a.pf[meglio] += 1
		dati.append(Dati.nome_zona(s.regole, meglio))
	_msg("%s passa il controllo: gomme nuove%s" % [a.nome, "" if dati.is_empty() else ", +1 " + ", +1 ".join(dati)], "info", a.i)
	eventi.append({"t": "box", "auto": a.i, "pf": a.pf.duplicate()})

## Sosta nel proprio box. Ritorna le caselle della ripartenza immediata (sosta rapida), o 0.
func _sosta(a: Dictionary) -> int:
	for z in Dati.zone(s.regole):
		if not avanzate() or z.id == "gomme":
			a.pf[z.id] = _inizio(a, z.id)
	a.eta = 0
	if s.get("meteo_on", false) and a.tipo == "ia":
		_assetto(a, assetto_ia(a, true))
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

## Le fermate nella curva in cui si trova l'auto: [fatte, obbligatorie], vuoto se non è in curva.
func _fermate_ora(a: Dictionary) -> Array:
	var c = pista.per_id.get(a.c)
	if c == null or int(c.c) <= 0 or a.fuori:
		return []
	return [max(1, int(a.ferm)), int(pista.fermate.get(int(c.c), 1))]

func _storia(voce: Dictionary) -> void:
	if not s.has("storia"):
		return
	voce["tr"] = int(s.turno)
	s.storia.mosse.append(voce)

func _arriva(a: Dictionary) -> void:
	s.arrivi.append(a.i)
	a.posto_arrivo = s.arrivi.size()
	a.dove = a.c
	a.c = ""
	eventi.append({"t": "arrivo", "auto": a.i, "posto": a.posto_arrivo})
	_storia({"a": a.i, "x": "arrivo"})
	if a.posto_arrivo == 1:
		_msg("%s vince la gara!" % a.nome, "arrivo", a.i)
	else:
		_msg("%s taglia il traguardo: %d° posto" % [a.nome, a.posto_arrivo], "arrivo", a.i)

# ------------------------------------------------------------------ per i telefoni e gli ospiti

## Lo stato in forma compatta, da mandare a telefoni e ospiti.
func vista() -> Dictionary:
	var v := {"regole": s.regole, "pista": s.pista, "giri": s.giri, "fase": s.fase, "turno": s.turno, "ordine": s.ordine,
		"cl": classifica(), "danni": [], "auto": [], "att": null, "mt": int(s.get("meteo", -1)),
		"str": s.get("strada", false), "lib": s.get("libero", false), "mon": s.get("meteo_on", false)}
	for d in s.danni:
		v.danni.append(d.c)
	for a in s.auto:
		v.auto.append({"n": a.nome, "p": a.pilota, "u": a.uid, "tp": a.tipo, "c": a.c, "m": a.marcia, "pf": a.pf, "g": a.giro,
			"f": a.fuori, "pa": a.posto_arrivo, "t": a.testa, "d": a.dado, "mo": a.mosso == s.turno, "w": a.perche,
			"dv": a.get("dove", ""), "gt": a.get("gomme_tipo", "dure"), "et": int(a.get("eta", 0)),
			"ni": s.get("strada", false) and int(a.get("nitro", -99)) != a.giro, "pf0": a.get("pf0", {}), "fs": _fermate_ora(a)})
	if s.attesa != null:
		var a: Dictionary = s.auto[s.attesa.auto]
		var att := {"tipo": s.attesa.tipo, "auto": a.i, "uid": a.uid}
		if s.attesa.tipo == "assetto":
			att.box = s.attesa.get("box", false)
			att.libero = s.get("libero", false) and not att.box and not a.get("pronto", true)
			att.gomme = gomme_ammesse(a)
			att.g = a.get("gomme_tipo", "dure")
			att.pf = a.pf
			att.meteo = int(s.get("meteo", -1))
			if a.tipo == "ia":
				att.consiglio = assetto_ia(a, att.box)
		elif s.attesa.tipo == "marcia":
			att.marce = marce(a)
			att.da = a.c
			if a.tipo != "ia":
				for o in att.marce:
					o["pv"] = anteprima(a, o)
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
					"fr": o.freno, "ol": o.oltre, "ni": int(o.get("extra", {}).get("ni", 0)), "jk": int(o.get("extra", {}).get("jk", 0)),
					"pi": int(o.get("extra", {}).get("piu", 0)), "r": snappedf(float(pista.per_id[cid].r), 0.1)})
			att.opz = l
		v.att = att
	if s.fase == "fine" and s.has("storia"):
		v["storia"] = s.storia
	v["cel"] = [snappedf(pista.cella, 0.1), snappedf(pista.largo_cella, 0.1)]
	return v
