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
## Regolamento del campionato (Gianluca Lari): le zone che a zero non eliminano, ma fanno tirare la tabella dei danni.
const ZONE_TABELLA := ["carrozzeria", "motore", "tenuta"]
## Sosta ai box con il regolamento Lari: dado nero fino a ... -> caselle della ripartenza (0 = sosta lunga).
const BOX_LARI := [[4, 2], [8, 3], [12, 4], [20, 0]]

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
		"meteo_on": av and bool(op.get("meteo", false)), "meteo": -1,
		"abil": av and bool(op.get("abilita", strada)), "nitro": strada or bool(op.get("nitro", false)),
		"lari": av and bool(op.get("lari", false)), "kers": av and bool(op.get("kers", false)), "meteo_ult": -1}
	# griglia: ognuno tira il dado nero, il più alto parte in pole
	var tiri := []
	for i in conf.auto.size():
		# Diane Montfort vince le parità in griglia
		var diane: bool = m.s.abil and Dati.PILOTI[int(conf.auto[i].pilota)].id == "diane"
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
			"mosso": -1, "partito": false, "dado": 0, "tiro_griglia": tiri[k][0] / 100, "pq": 0,
			"pp": int(c.get("pp", 1 if m.s.lari else 0)), "pmec": int(c.get("pmec", 2)), "pk": 0, "dz": {}, "lim_marcia": 0,
			"coll": bool(c.get("coll", false))}
		if m.s.kers and pf.has("motore"):
			pf.motore = min(int(pf.motore), 2)
			a.pf0 = pf.duplicate()
		m.s.auto.append(a)
		m.s.ordine.append(a.i)
		testo.append("%d. %s (%d)" % [k + 1, a.nome, a.tiro_griglia])
	if bool(op.get("qualifiche", false)) and conf.auto.size() > 1:
		m._q_inizia()
	else:
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
	if not m.s.has("griglia_via"):
		m.s.griglia_via = m.s.ordine.duplicate()
	if conf.has("camp"):
		m.s.camp = int(conf.camp)
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

## Il primo passaggio sulla linea avvia il giro 1: l'età conta soltanto i giri già completati.
static func eta_gomme(giro: int) -> int:
	return max(0, giro - 1)

## Si entra ai box soltanto fra due giri: mai nell'ultimo giro o in una gara di un giro solo.
func _puo_pit(a: Dictionary) -> bool:
	return a.giro >= 1 and a.giro < s.giri and not pista.pit.is_empty() and not s.get("strada", false)

func pioggia() -> bool:
	return int(s.get("meteo", -1)) >= 2

## Le abilità dei piloti valgono nelle gare su strada con le regole avanzate.
func abilita() -> bool:
	return s.get("abil", s.get("strada", false) and avanzate())

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
	var tab: Array = pista.meteo
	if v <= int(tab[0]):
		return 0
	if v <= int(tab[1]):
		return 1
	return 2

func _cambia_meteo() -> void:
	var r := _dado_meteo("cambio del tempo")
	var prima: int = s.meteo
	if lari():
		# il risultato dice il tempo; due volte di fila lo stesso (pioggia o sereno) e non cambia più
		var ult := int(s.get("meteo_ult", -1))
		if r == 0:
			s.meteo = 3 if ult == 0 else 2
		elif r == 2:
			s.meteo = 0 if ult == 2 else 1
		s.meteo_ult = r
		if s.meteo == 0 or s.meteo == 3:
			_msg("Meteo: due volte di fila %s, il tempo non cambia più" % ("pioggia" if s.meteo == 3 else "sereno"), "info")
	elif r == 2:
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
	var k := 2 if str(a.get("dz", {}).get("tenuta", "")) == "sospensioni" else 1
	return k * _molt_gomme(a)

func _molt_gomme(a: Dictionary) -> int:
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
	var gravi := []
	if lari():
		for zid in ZONE_TABELLA:
			if a.pf.has(zid) and int(a.pf[zid]) < 0:
				a.pf[zid] = 0
				gravi.append(zid)
	eventi.append({"t": "usura", "auto": a.i, "usura": perso, "motivo": motivo, "pf": a.pf.duplicate()})
	_msg("%s perde %s (%s)" % [a.nome, Dati.testo_usura(s.regole, perso), motivo], "usura", a.i)
	for zid in gravi:
		_danno_grave(a, zid)
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
		if _esce(a, z, int(a.pf[z.id])):
			_elimina(a, "%s a zero" % z.nome)
			return

## Con quel valore rimasto nella zona l'auto è fuori? Con il regolamento Lari carrozzeria, motore e tenuta a zero
## non eliminano: perdere un punto in più fa tirare la tabella dei danni.
func _esce(a: Dictionary, z: Dictionary, resta: int) -> bool:
	if not z.has("fuori"):
		return false
	if s.get("lari", false) and ZONE_TABELLA.has(z.id):
		return resta < 0 and a.get("dz", {}).has(z.id)
	return resta <= int(z.fuori)

func lari() -> bool:
	return s.get("lari", false)

## Dado nero con i Punti Pilota (regolamento Lari): se il risultato è grave e il pilota ha ancora Punti Pilota,
## ne spende uno e ritira.
func _nero_pp(a: Dictionary, male: Callable, perche: String) -> int:
	var v := _nero()
	if lari() and int(a.get("pp", 0)) > 0 and male.call(v):
		a.pp -= 1
		var v2 := _nero()
		_msg("%s usa un Punto Pilota per ritirare il dado nero (%s): %d invece di %d, ne restano %d" % [a.nome, perche, v2, v, a.pp], "avviso", a.i)
		v = v2
	return v

## Regolamento Lari: una zona fra carrozzeria, motore e tenuta deve perdere un punto che non ha più.
func _danno_grave(a: Dictionary, zid: String) -> void:
	if not in_gara(a):
		return
	var dz: Dictionary = a.get("dz", {})
	if dz.has(zid):
		var t: String = {"carrozzeria": "un altro colpo al telaio: incidente grave", "motore": "il motore prende fuoco",
			"tenuta": "le sospensioni cedono: incidente grave"}[zid]
		_msg("%s: %s" % [a.nome, t], "fuori", a.i)
		_ritiro_grave(a, t)
		return
	var v := _nero_pp(a, func(x): return x <= 2, "danni")
	var nome := Dati.nome_zona(s.regole, zid)
	if v <= 2:
		var t: String = {"carrozzeria": "incidente grave, l'auto è distrutta", "motore": "rottura del motore",
			"tenuta": "danno irrimediabile alle sospensioni"}[zid]
		_nero_evento(a, v, "danni: %s a zero" % nome, t, true)
		if zid == "carrozzeria":
			_ritiro_grave(a, t)
		else:
			_elimina(a, t)
		return
	if v <= 18:
		match zid:
			"carrozzeria":
				dz[zid] = "musetto"
				a.lim_marcia = 3
				_nero_evento(a, v, "danni: telaio a zero", "perde il musetto: al massimo in 3a", true)
			"motore":
				dz[zid] = "potenza"
				_nero_evento(a, v, "danni: motore a zero", "perde potenza: ogni dado dà il numero più basso", true)
			"tenuta":
				dz[zid] = "sospensioni"
				_nero_evento(a, v, "danni: sospensioni a zero", "sospensioni rotte: +3 caselle obbligatorie in curva, lungo costa il doppio", true)
	else:
		if zid == "motore":
			dz[zid] = "affidabile"
			_nero_evento(a, v, "danni: motore a zero", "nessuna conseguenza, ma a ogni turno la prova di affidabilità", false)
		else:
			dz[zid] = "testacoda"
			_nero_evento(a, v, "danni: %s a zero" % nome, "testacoda e 2 punti persi", true)
			a.testa = true
			eventi.append({"t": "testacoda", "auto": a.i})
			_lascia_segnalino(a)
			a.dz = dz
			_perdi_a_scelta(a, 2, zid)
	a.dz = dz

## Perde n punti nelle zone che ne hanno di più (i «PA a scelta» del regolamento).
func _perdi_a_scelta(a: Dictionary, n: int, tranne := "") -> void:
	var w := {}
	for k in n:
		var meglio := ""
		var piu := 0
		for z in Dati.zone_ids():
			if z == tranne:
				continue
			var resta: int = int(a.pf[z]) - int(w.get(z, 0))
			if resta > piu:
				piu = resta
				meglio = z
		if meglio == "":
			break
		w[meglio] = int(w.get(meglio, 0)) + 1
	_usura(a, w, "punti a scelta")

## Ritiro con il «rischio pilota» (regolamento Lari).
func _ritiro_grave(a: Dictionary, perche: String) -> void:
	_elimina(a, perche)
	var v := _nero_pp(a, func(x): return x == 1 or x == 20, "rischio pilota")
	if v == 1:
		a.rischio = "rip"
		_nero_evento(a, v, "rischio pilota", "un incidente terribile: il suo nome resterà negli annali", true)
	elif v == 20:
		a.rischio = "frattura"
		_nero_evento(a, v, "rischio pilota", "frattura: salterà la prossima gara", true)
	else:
		_nero_evento(a, v, "rischio pilota", "esce illeso", false)

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
	var lim := int(a.get("lim_marcia", 0))
	for m in range(1, min(6 if lim <= 0 else lim, da + 1) + 1):
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
			if z.id != "gomme" and _esce(a, z, a.pf[z.id] - int(costo.get(z.id, 0))):
				fuori = true
		out.append({"m": m, "costo": costo, "fuori": fuori})
	if out.is_empty() and lim > 0:
		out.append({"m": lim, "costo": {}, "fuori": false})
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
			if _esce(a, z, resta):
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
				for k in [["ni", "ni"], ["pi", "piu"], ["jk", "jk"], ["fg", "fg"], ["pk", "pk"], ["co", "co"]]:
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
	if morbide and lari() and (int(a.pf.get("carrozzeria", 1)) <= 0 or int(a.pf.get("tenuta", 1)) <= 0):
		morbide = false
	if morbide:
		out.append({"v": 1, "ni": 0})
	# fuori giri (regolamento Lari): dal rettilineo, 1 Motore per tante caselle quanto la marcia
	var da = pista.per_id.get(a.c)
	if lari() and da != null and int(da.c) == 0 and int(a.pf.get("motore", 0)) >= 1 and a.marcia >= 1 and a.partito:
		out.append({"v": int(a.marcia), "ni": 0, "fg": int(a.marcia)})
	# KERS: 1, 2 o 3 punti per 1, 2 o 4 caselle
	if s.get("kers", false) and int(a.get("pk", 0)) > 0:
		var pk := int(a.pk)
		out.append({"v": [0, 1, 2, 4][pk], "ni": 0, "pk": pk})
	if s.get("nitro", s.get("strada", false)) and int(a.get("nitro", -99)) != a.giro and a.marcia >= 1:
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
	var reach := {}
	var pesi := {}
	var fatte := {}
	var cache := {}
	var passo := func(cordoli: Array) -> bool:
		var dist := {}
		for g in agg:
			for j in jack:
				for r in [0, sciv]:
					for l in [0, -1 if litsu else 0]:
						for co in cordoli:
							var d: int = tiro + int(g.v) + j + r + l + co
							if d >= 1 and not fatte.has(d):
								dist[d] = true
		var curve := false
		for d in dist:
			fatte[d] = true
			if not cache.has(d):
				cache[d] = Mosse.raggiungi(pista, a.c, d, {"occupate": occupate, "fermate": a.ferm, "pit": _puo_pit(a),
					"posto": a.posto, "costo": costo})
			var r1: Dictionary = cache[d]
			for cid in r1:
				var o: Dictionary = r1[cid].duplicate()
				if pista.per_id[cid].pit:
					o.freno = 0
				var curva := _tocca_curva(o.percorso)
				curve = curve or curva
				var base: int = tiro + (sciv if curva else 0) - (1 if litsu and o.traguardo else 0)
				var scelta = null
				for g in agg:
					for j in (jack if curva else [0]):
						for co in cordoli:
							if scelta != null or base + int(g.v) + j + co != d:
								continue
							if (int(g.get("fg", 0)) > 0 or co != 0) and int(o.freno) > 0:
								continue
							if co != 0 and (int(g.v) != 0 or j != 0 or not _cordolo_ok(o.percorso, co)):
								continue
							scelta = {"ni": int(g.ni), "jk": j, "piu": int(g.v), "fg": int(g.get("fg", 0)), "pk": int(g.get("pk", 0)), "co": co}
				if scelta == null:
					continue
				o.extra = scelta
				var peso: float = _costo(a, o) + (1.0 if scelta.jk != 0 else 0.0) + (0.01 if scelta.ni > 0 else 0.0) + 0.001 * scelta.piu \
					+ (0.6 if scelta.fg > 0 else 0.0) + (0.3 if scelta.pk > 0 else 0.0) + (0.4 if scelta.co != 0 else 0.0)
				if not pesi.has(cid) or peso < pesi[cid]:
					pesi[cid] = peso
					reach[cid] = o
		return curve
	var con_curve: bool = passo.call([0])
	# i cordoli (regolamento Lari) servono solo se la mossa arriva a una curva
	if lari() and not _in_pit(a) and (con_curve or int(pista.per_id[a.c].c) > 0):
		fatte.clear()
		passo.call([1, -2])
	if avanzate():
		# dopo il fuori giri non si prende la scia
		var per_scia := {}
		for cid in reach:
			if int(reach[cid].get("extra", {}).get("fg", 0)) == 0:
				per_scia[cid] = reach[cid]
		var altre := Mosse.scia(pista, per_scia, {"occupate": occupate, "marce": marce_altre, "marcia": a.marcia,
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
		var finisce: bool = o.traguardo and a.giro + 1 > s.giri
		# tagliando il traguardo non si frena, ma l'ultima curva va comunque controllata:
		# chi ne esce lungo prima della linea paga come sempre (e può anche ritirarsi)
		var oe := o
		if finisce and int(o.freno) > 0:
			oe = o.duplicate()
			oe.freno = 0
		var e := _effetto(a, oe, suo_box)
		var exo: Dictionary = o.get("extra", {})
		if int(exo.get("jk", 0)) != 0:
			e.usura["gomme"] = int(e.usura.get("gomme", 0)) + 1
		if int(exo.get("fg", 0)) > 0:
			e.usura["motore"] = int(e.usura.get("motore", 0)) + 1
		e.cordolo = int(exo.get("co", 0)) != 0
		e.box = suo_box
		e.finisce = finisce and e.fuori == ""
		if e.finisce:
			e.testa = false
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
	if lari():
		_tamponamento(a, reach)
	return reach

## Il cordolo si può usare con quel percorso? +1 (interno): almeno una casella interna di una curva;
## -2 (esterno): finisce sulla terza di almeno tre caselle esterne di fila nella stessa curva.
func _cordolo_ok(percorso: Array, co: int) -> bool:
	if co > 0:
		for k in range(1, percorso.size()):
			if _bordo(percorso[k]) > 0:
				return true
		return false
	var n := percorso.size()
	if n < 4:
		return false
	var curva := int(pista.per_id[percorso[n - 1]].c)
	if curva <= 0:
		return false
	for k in range(n - 3, n):
		var c = pista.per_id[percorso[k]]
		if int(c.c) != curva or _bordo(percorso[k]) >= 0:
			return false
	return true

## In curva: 1 se la casella è nella corsia interna, -1 se nell'esterna, 0 altrimenti.
func _bordo(cid: String) -> int:
	var c = pista.per_id.get(cid)
	if c == null or int(c.c) <= 0 or c.pit:
		return 0
	var mio := pista.interno(cid)
	var piu := true
	var meno := true
	var altri := 0
	for v in pista.vicini.get(cid, []):
		var o = pista.per_id.get(v)
		if o == null or o.pit or int(o.c) != int(c.c) or int(o.l) == int(c.l):
			continue
		altri += 1
		if pista.interno(v) >= mio:
			piu = false
		if pista.interno(v) <= mio:
			meno = false
	if altri == 0:
		return 0
	return 1 if piu else (-1 if meno else 0)

## Strada bloccata (regolamento Lari): se non c'è modo di frenare abbastanza, oltre la sesta casella si pagano
## altri punti a scelta; se non bastano, tamponamento contro l'auto davanti.
func _tamponamento(a: Dictionary, reach: Dictionary) -> void:
	var minimo := 999
	for cid in reach:
		minimo = min(minimo, int(reach[cid].freno))
	if minimo <= FRENATA_MASSIMA or reach.is_empty():
		return
	var tenere := ""
	for cid in reach:
		if int(reach[cid].freno) == minimo and (tenere == "" or reach[cid].eff.fuori == ""):
			tenere = cid
	for cid in reach.keys():
		if cid != tenere:
			reach.erase(cid)
	var o: Dictionary = reach[tenere]
	var oo := o.duplicate()
	oo.freno = FRENATA_MASSIMA
	var e := _effetto(a, oo, false)
	var extra: int = int(o.freno) - FRENATA_MASSIMA
	var base_u: Dictionary = e.usura.duplicate()
	var pf: Dictionary = a.pf.duplicate()
	for k in e.usura:
		pf[k] -= int(e.usura[k])
	var pagati := 0
	while pagati < extra:
		var meglio := ""
		var piu := 0
		for z in ["cambio", "motore", "tenuta", "carrozzeria"]:
			var minimo_z := 1 if ZONE_TABELLA.has(z) else 0
			if int(pf[z]) - minimo_z > piu:
				piu = int(pf[z]) - minimo_z
				meglio = z
		if meglio == "":
			break
		pf[meglio] -= 1
		e.usura[meglio] = int(e.usura.get(meglio, 0)) + 1
		pagati += 1
	e.tampona = -1
	e.crash = pagati < extra
	if e.crash:
		# tanto si sbatte: i punti in più non servono
		e.usura = base_u
		# non basta: si tampona l'auto davanti
		var c = pista.per_id[tenere]
		for b in s.auto:
			if b.i != a.i and in_gara(b) and b.c != "" and (Array(c.n).has(b.c) or pista.vicini.get(tenere, []).has(b.c)):
				e.tampona = b.i
				break
	e.box = o.eff.box
	e.finisce = o.eff.finisce
	e.tocca = o.eff.tocca
	e.pericoli = o.eff.pericoli
	e.cordolo = false
	o.eff = e

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
	if s.fase == "qualifiche":
		_q_avanza()
		if s.fase == "qualifiche":
			return
	if _prepara():
		return
	while s.fase == "gara" and s.attesa == null:
		if _in_corsa() == 0:
			_ordina_arrivi()
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
			_ordina_arrivi()
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
	if not a.get("pronto", true) and int(a.get("pq", 0)) > 0 and a.pf.has("gomme"):
		a.pf.gomme = max(1, int(a.pf.gomme) - int(a.pq))
		parti.append("%d Gomme in meno per le qualifiche" % int(a.pq))
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
	var k := _faccia(a, facce)
	var v := int(facce[k][0])
	var in_pit := _in_pit(a)
	a.marcia = opz.m
	a.max_marcia = 0
	a.testa = false
	a.dado = v
	eventi.append({"t": "dado", "auto": a.i, "marcia": opz.m, "valore": v, "faccia": k})
	_msg("%s innesta la %s e tira %d" % [a.nome, Dati.NOMI_MARCE[opz.m], v], "tiro", a.i)
	s.sforzo = int(Dati.SFORZO.get(opz.m, 0)) == v and not in_pit
	_kers(a, v)
	_apri_mossa(a, v)

## La faccia del dado: con il motore senza potenza sempre la più bassa.
func _faccia(a: Dictionary, facce: Array) -> int:
	if str(a.get("dz", {}).get("motore", "")) == "potenza":
		var k0 := 0
		for k in facce.size():
			if int(facce[k][0]) < int(facce[k0][0]):
				k0 = k
		return k0
	return rng.randi() % facce.size()

## KERS: i due numeri più alti del dado dalla 4a in su danno un punto (al massimo 3).
func _kers(a: Dictionary, v: int) -> void:
	if not s.get("kers", false) or a.marcia < 4:
		return
	var alto := 0
	for f in Dati.DADI[a.marcia]:
		alto = max(alto, int(f[0]))
	if v >= alto - 1 and int(a.get("pk", 0)) < 3:
		a.pk = int(a.get("pk", 0)) + 1
		_msg("%s carica il KERS: %d punt%s" % [a.nome, a.pk, "o" if a.pk == 1 else "i"], "info", a.i)

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
	if s.attesa.tipo == "qualifica" and az.get("t") == "qualifica":
		if not Qualifiche.MARCE.has(int(az.get("m", 0))):
			return false
		_q_tira(a, int(az.m))
		avanza()
		return true
	if s.attesa.tipo == "qritira" and az.get("t") == "qritira":
		_q_ritira(a, bool(az.get("si", false)))
		avanza()
		return true
	if s.attesa.tipo == "mossa" and az.get("t") == "ritira":
		if int(a.get("pp", 0)) <= 0:
			return false
		a.pp -= 1
		_msg("%s usa un Punto Pilota e ritira il dado (ne restano %d)" % [a.nome, a.pp], "avviso", a.i)
		var facce: Array = Dati.DADI[a.marcia]
		var k := _faccia(a, facce)
		var v := int(facce[k][0])
		a.dado = v
		eventi.append({"t": "dado", "auto": a.i, "marcia": a.marcia, "valore": v, "faccia": k})
		_msg("%s ritira e fa %d" % [a.nome, v], "tiro", a.i)
		s.sforzo = int(Dati.SFORZO.get(a.marcia, 0)) == v and not _in_pit(a)
		_kers(a, v)
		_apri_mossa(a, v)
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
	if int(ex.get("pk", 0)) > 0:
		_msg("%s usa il KERS: +%d caselle" % [a.nome, int(ex.piu)], "avviso", a.i)
		a.pk = 0
	if int(ex.get("co", 0)) != 0:
		_msg("%s sfrutta il cordolo %s (%s)" % [a.nome, "interno" if ex.co > 0 else "esterno", "+1" if ex.co > 0 else "-2"], "info", a.i)
	if int(ex.get("fg", 0)) > 0:
		# fuori giri: 1 Motore, senza lasciare detriti
		_msg("%s manda il motore fuori giri: +%d caselle, 1 Motore" % [a.nome, int(ex.fg)], "avviso", a.i)
		e = e.duplicate(true)
		e.usura.motore = int(e.usura.get("motore", 0)) - 1
		if e.usura.motore <= 0:
			e.usura.erase("motore")
		a.pf.motore -= 1
		eventi.append({"t": "usura", "auto": a.i, "usura": {"motore": 1}, "motivo": "fuori giri", "pf": a.pf.duplicate()})
		if int(a.pf.motore) < 0:
			a.pf.motore = 0
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
		if not e.usura.is_empty():
			_usura(a, e.usura, "lungo all'ultima curva", false)
		a.giro += 1
		# caselle oltre la linea: decidono l'ordine fra chi arriva nello stesso turno
		var oltre_l := 0
		for k in range(1, o.percorso.size()):
			if pista.traguardo.has(o.percorso[k]) and not pista.traguardo.has(o.percorso[k - 1]):
				oltre_l = o.percorso.size() - k
		a.arr_turno = s.turno
		a.arr_oltre = oltre_l
		_arriva(a)
	else:
		if o.traguardo:
			a.giro += 1
			eventi.append({"t": "giro", "auto": a.i, "giro": a.giro})
			if a.giro > 1:
				_msg("%s inizia il giro %d di %d%s" % [a.nome, a.giro, s.giri, " - ultimo giro!" if a.giro == s.giri else ""], "giro", a.i)
				a.eta = eta_gomme(a.giro)
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
		if e.get("crash", false) and in_gara(a):
			var b_t := int(e.get("tampona", -1))
			var contro: String = s.auto[b_t].nome if b_t >= 0 else "le auto davanti"
			_msg("%s non riesce a fermarsi e tampona %s!" % [a.nome, contro], "avviso", a.i)
			eventi.append({"t": "urto", "auto": a.i, "contro": max(b_t, a.i), "colpo": true})
			if int(a.pf.carrozzeria) > 0:
				_usura(a, {"carrozzeria": int(a.pf.carrozzeria)}, "tamponamento", false)
			_danno_grave(a, "carrozzeria")
			if b_t >= 0 and in_gara(s.auto[b_t]):
				_usura(s.auto[b_t], {"carrozzeria": 1}, "tamponata da %s" % a.nome)
		if e.get("cordolo", false) and in_gara(a):
			var soglia_c := 5 if pioggia() else 4
			var vc := _nero_pp(a, func(x): return x <= soglia_c and int(a.pf.get("tenuta", 1)) <= 0, "sospensioni")
			if vc <= soglia_c:
				_nero_evento(a, vc, "cordolo", "le sospensioni soffrono", true)
				_usura(a, {"tenuta": 1}, "cordolo")
			else:
				_nero_evento(a, vc, "cordolo", "sospensioni a posto", false)
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
			var v := _nero_pp(a, func(x): return x <= soglia_d and int(a.pf.get("tenuta", 1)) <= 0, "detriti")
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
				var soglia_m := (3 if pioggia() else 4) - (1 if chi(b, "dimitri") else 0)
				var v := _nero_pp(b, func(x): return x <= soglia_m and int(b.pf.get("motore", 1)) <= 0, "motore")
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
	if in_gara(a) and str(a.get("dz", {}).get("motore", "")) == "affidabile":
		var v := _nero_pp(a, func(x): return x <= int(a.marcia), "affidabilità")
		if v <= int(a.marcia):
			_nero_evento(a, v, "prova di affidabilità", "il motore cede", true)
			_elimina(a, "motore ceduto")
		else:
			_nero_evento(a, v, "prova di affidabilità", "il motore regge", false)
	if a.fuori:
		a.c = ""

func _collisione(a: Dictionary, b: Dictionary) -> void:
	# chi collide con Derek Manson tira due volte
	for k in (2 if chi(b, "derek") else 1):
		if not in_gara(a):
			return
		var soglia_u := (2 if pioggia() else 1) if avanzate() else 4
		var v := _nero_pp(a, func(x): return x <= soglia_u and int(a.pf.get("carrozzeria", 1)) <= 0, "collisione")
		var colpo := v <= soglia_u
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
	if lari():
		return _sosta_lari(a)
	var v := _nero()
	if v <= 10:
		var n := int(ceil(v / 2.0))
		_nero_evento(a, v, "sosta ai box", "sosta rapida! Riparte subito in 4a per %d casell%s" % [n, "a" if n == 1 else "e"], false)
		return n
	_nero_evento(a, v, "sosta ai box", "sosta lenta: riparte al prossimo turno, al massimo in 4a", false)
	return 0

## Sosta con il regolamento Lari: i meccanici riparano (1 punto meccanico per punto, prima le zone danneggiate),
## poi il dado nero dice di quanto si riparte subito in 4a (2, 3 o 4 caselle) o se si resta fermi un turno.
func _sosta_lari(a: Dictionary) -> int:
	var fatti := []
	while int(a.get("pmec", 0)) > 0:
		var meglio := ""
		var manca := 0
		for z in ["carrozzeria", "motore", "tenuta", "freni", "cambio"]:
			var m: int = _inizio(a, z) - int(a.pf[z]) + (10 if a.get("dz", {}).has(z) else 0)
			if m > manca and int(a.pf[z]) < _inizio(a, z):
				manca = m
				meglio = z
		if meglio == "":
			break
		a.pf[meglio] += 1
		a.pmec -= 1
		fatti.append(Dati.nome_zona(s.regole, meglio))
		if a.get("dz", {}).has(meglio):
			a.dz.erase(meglio)
			if meglio == "carrozzeria":
				a.lim_marcia = 0
	if not fatti.is_empty():
		_msg("%s: i meccanici riparano +1 %s (restano %d punti meccanici)" % [a.nome, ", +1 ".join(fatti), int(a.pmec)], "info", a.i)
		eventi.append({"t": "box", "auto": a.i, "pf": a.pf.duplicate()})
	var v := _nero()
	for r in BOX_LARI:
		if v <= int(r[0]):
			var n := int(r[1])
			if n > 0:
				_nero_evento(a, v, "sosta ai box", "sosta rapida! Riparte subito in 4a per %d caselle" % n, false)
			else:
				_nero_evento(a, v, "sosta ai box", "problemi ai box: riparte al prossimo turno, al massimo in 4a", false)
			return n
	return 0

## Le fermate nella curva in cui si trova l'auto: [fatte, obbligatorie], vuoto se non è in curva.
func _fermate_ora(a: Dictionary) -> Array:
	var c = pista.per_id.get(a.c)
	if c == null or int(c.c) <= 0 or a.fuori:
		return []
	# -1 = appena arrivata in curva fermandosi (vale una fermata); 0 = entrata andando lungo dalla curva
	# precedente: quella sosta non conta
	var fatte := int(a.ferm)
	if fatte < 0:
		fatte = 1
	return [fatte, int(pista.fermate.get(int(c.c), 1))]

func _storia(voce: Dictionary) -> void:
	if not s.has("storia"):
		return
	voce["tr"] = int(s.turno)
	s.storia.mosse.append(voce)

## Chi arriva nello stesso turno: vince chi va più oltre la linea; a parità chi l'ha tagliata prima.
func _ordina_arrivi() -> void:
	_ordina_arrivi_turno()
	# nell'ordine di gioco le auto arrivate stanno nell'ordine d'arrivo
	var posti := []
	var arrivate := []
	for k in s.ordine.size():
		var a: Dictionary = s.auto[s.ordine[k]]
		if int(a.get("posto_arrivo", 0)) > 0:
			posti.append(k)
			arrivate.append(a)
	arrivate.sort_custom(func(x, y): return int(x.posto_arrivo) < int(y.posto_arrivo))
	for k in posti.size():
		s.ordine[posti[k]] = arrivate[k].i

func _ordina_arrivi_turno() -> void:
	var gruppo := []
	for i in s.arrivi:
		if int(s.auto[i].get("arr_turno", -1)) == int(s.turno):
			gruppo.append(s.auto[i])
	if gruppo.size() < 2:
		return
	var posti := []
	for a in gruppo:
		posti.append(int(a.posto_arrivo))
	posti.sort()
	var ordinati := gruppo.duplicate()
	ordinati.sort_custom(func(x, y):
		if int(x.arr_oltre) != int(y.arr_oltre):
			return int(x.arr_oltre) > int(y.arr_oltre)
		return int(x.posto_arrivo) < int(y.posto_arrivo))
	var cambia := false
	for k in ordinati.size():
		if int(ordinati[k].posto_arrivo) != posti[k]:
			cambia = true
		ordinati[k].posto_arrivo = posti[k]
	for a in gruppo:
		a.arr_turno = -1
	if not cambia:
		return
	var nuovi := []
	for i in s.arrivi:
		nuovi.append(i)
	nuovi.sort_custom(func(x, y): return int(s.auto[x].posto_arrivo) < int(s.auto[y].posto_arrivo))
	s.arrivi = nuovi
	var testo := []
	for a in ordinati:
		testo.append("%d. %s (%d oltre la linea)" % [int(a.posto_arrivo), a.nome, int(a.arr_oltre)])
		eventi.append({"t": "arrivo", "auto": a.i, "posto": a.posto_arrivo})
	_msg("Arrivo nello stesso turno, conta chi va più oltre il traguardo: " + "   ".join(testo), "arrivo")

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
		"str": s.get("strada", false), "abil": abilita(), "lari": lari(), "kers": s.get("kers", false), "lib": s.get("libero", false), "mon": s.get("meteo_on", false)}
	for d in s.danni:
		v.danni.append(d.c)
	for a in s.auto:
		v.auto.append({"n": a.nome, "p": a.pilota, "u": a.uid, "tp": a.tipo, "c": a.c, "m": a.marcia, "pf": a.pf, "g": a.giro,
			"f": a.fuori, "pa": a.posto_arrivo, "t": a.testa, "d": a.dado, "mo": a.mosso == s.turno, "w": a.perche,
			"dv": a.get("dove", ""), "gt": a.get("gomme_tipo", "dure"), "et": int(a.get("eta", 0)),
			"ni": s.get("nitro", s.get("strada", false)) and int(a.get("nitro", -99)) != a.giro, "pf0": a.get("pf0", {}), "fs": _fermate_ora(a),
			"pp": int(a.get("pp", 0)), "pk": int(a.get("pk", 0)), "pm": int(a.get("pmec", 0)), "dz": a.get("dz", {})})
	if s.has("q"):
		v["q"] = s.q
	if s.has("camp"):
		v["camp"] = int(s.camp)
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
		elif s.attesa.tipo == "qualifica" or s.attesa.tipo == "qritira":
			for k in s.attesa:
				att[k] = s.attesa[k]
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
					"pi": int(o.get("extra", {}).get("piu", 0)), "fg": int(o.get("extra", {}).get("fg", 0)),
					"pk": int(o.get("extra", {}).get("pk", 0)), "co": int(o.get("extra", {}).get("co", 0)),
					"tp": e.get("crash", false), "r": snappedf(float(pista.per_id[cid].r), 0.1)})
			att.opz = l
			att.pp = int(a.get("pp", 0))
		v.att = att
	if s.fase == "fine" and s.has("storia"):
		v["storia"] = s.storia
	v["cel"] = [snappedf(pista.cella, 0.1), snappedf(pista.largo_cella, 0.1)]
	return v

# ------------------------------------------------------------------ qualifiche a settori

func _q_inizia() -> void:
	var ordine := []
	for a in s.auto:
		ordine.append(a.i)
	# ordine di uscita della prima sessione: a sorte
	for k in range(ordine.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = ordine[k]
		ordine[k] = ordine[j]
		ordine[j] = t
	s.fase = "qualifiche"
	s.q = {"limiti": Qualifiche.limiti(pista), "dim": Qualifiche.sessioni(ordine.size()), "sess": 0, "coda": ordine,
		"pos": 0, "sett": 0, "giri": {}, "griglia": [], "rit": {}, "rg": {}, "fine": false}
	_q_nuova_sessione()

func _q_nuova_sessione() -> void:
	var q: Dictionary = s.q
	q.pos = 0
	q.sett = 0
	q.giri = {}
	q.rit = {}
	for i in q.coda:
		q.giri[str(i)] = {"p": [], "t": [], "m": [], "tot": 0}
	_msg("%s: %d auto in pista, limiti dei settori %d / %d / %d" % [Qualifiche.nome_sessione(q), q.coda.size(),
		q.limiti[0], q.limiti[1], q.limiti[2]], "giro")

## Puo' ritirare il dado del settore? Base: una volta per sessione. Avanzate: ogni volta 1 Gomme, al massimo 2.
func _q_puo_ritirare(a: Dictionary) -> bool:
	if avanzate():
		return int(s.q.rg.get(str(a.i), 0)) < 2
	return int(s.q.rit.get(str(a.i), 0)) < 1

func _q_avanza() -> void:
	var q: Dictionary = s.q
	while s.attesa == null and s.fase == "qualifiche":
		if q.pos >= q.coda.size():
			_q_fine_sessione()
			continue
		var i: int = q.coda[q.pos]
		var a: Dictionary = s.auto[i]
		if q.sett >= 3:
			var g: Dictionary = q.giri[str(i)]
			_msg("%s: giro da %d punti (%s)" % [a.nome, int(g.tot), " + ".join(PackedStringArray(g.p.map(func(x): return str(x))))], "info", i)
			q.pos += 1
			q.sett = 0
			continue
		s.attesa = {"tipo": "qualifica", "auto": i, "sett": q.sett, "limite": int(q.limiti[q.sett]),
			"sessione": Qualifiche.nome_sessione(q), "marce": Qualifiche.valuta(int(q.limiti[q.sett])),
			"rit": _q_puo_ritirare(a), "fatto": q.giri[str(i)].tot, "meglio": _q_meglio(i)}
		eventi.append({"t": "tocca", "auto": i})

## Il miglior tempo di questa sessione fra le altre auto (0 se nessuno ha ancora girato).
func _q_meglio(escluso: int) -> int:
	var q: Dictionary = s.q
	var b := 0
	for k in q.pos:
		var i: int = q.coda[k]
		if i != escluso:
			b = max(b, int(q.giri[str(i)].tot))
	return b

func _q_tira(a: Dictionary, m: int) -> void:
	var q: Dictionary = s.q
	s.attesa = null
	var facce: Array = Dati.DADI[m]
	var k := rng.randi() % facce.size()
	var v := int(facce[k][0])
	var lim: int = q.limiti[q.sett]
	var p := Qualifiche.punti(v, lim)
	eventi.append({"t": "dado", "auto": a.i, "marcia": m, "valore": v, "faccia": k})
	var testo := "%s, settore %d in %s: tira %d" % [a.nome, q.sett + 1, Dati.NOMI_MARCE[m], v]
	if p < 0:
		testo += " - testacoda, 0 punti"
		if avanzate():
			a.pq = int(a.get("pq", 0)) + 1
			testo += " e 1 Gomme in meno per la gara"
	elif v > lim:
		testo += " - lungo di %d, %d punti" % [v - lim, p]
	else:
		testo += " - %d punti" % p
	_msg(testo, "tiro", a.i)
	q["ultimo"] = {"m": m, "v": v, "p": max(0, p)}
	if _q_puo_ritirare(a) and (p < 0 or v < lim):
		s.attesa = {"tipo": "qritira", "auto": a.i, "sett": q.sett, "m": m, "tiro": v, "punti": max(0, p),
			"limite": lim, "sessione": Qualifiche.nome_sessione(q),
			"costo": "1 punto Gomme per la gara" if avanzate() else "l'unico nuovo tiro di questa sessione",
			"fatto": q.giri[str(a.i)].tot, "meglio": _q_meglio(a.i), "marce": Qualifiche.valuta(lim)}
		return
	_q_segna(a)

func _q_segna(a: Dictionary) -> void:
	var q: Dictionary = s.q
	var g: Dictionary = q.giri[str(a.i)]
	g.p.append(int(q.ultimo.p))
	g.t.append(int(q.ultimo.v))
	g.m.append(int(q.ultimo.m))
	g.tot = int(g.tot) + int(q.ultimo.p)
	q.sett += 1

func _q_ritira(a: Dictionary, si: bool) -> void:
	var q: Dictionary = s.q
	s.attesa = null
	if not si:
		_q_segna(a)
		return
	q.rit[str(a.i)] = int(q.rit.get(str(a.i), 0)) + 1
	if avanzate():
		q.rg[str(a.i)] = int(q.rg.get(str(a.i), 0)) + 1
		a.pq = int(a.get("pq", 0)) + 1
	_msg("%s riprova il settore %d%s" % [a.nome, q.sett + 1, " (1 Gomme in meno per la gara)" if avanzate() else ""], "avviso", a.i)

func _q_fine_sessione() -> void:
	var q: Dictionary = s.q
	var tiri := {}
	for i in q.coda:
		tiri[i] = _nero() * 100 + (99 if chi(s.auto[i], "diane") else rng.randi_range(0, 98))
	var cl: Array = q.coda.duplicate()
	cl.sort_custom(func(x, y):
		var gx: Dictionary = q.giri[str(x)]
		var gy: Dictionary = q.giri[str(y)]
		if int(gx.tot) != int(gy.tot):
			return int(gx.tot) > int(gy.tot)
		var sx := int(gx.p[2]) if gx.p.size() > 2 else 0
		var sy := int(gy.p[2]) if gy.p.size() > 2 else 0
		if sx != sy:
			return sx > sy
		return tiri[x] > tiri[y])
	var nomi := []
	for k in cl.size():
		nomi.append("%d. %s %d" % [k + 1, s.auto[cl[k]].nome, int(q.giri[str(cl[k])].tot)])
	_msg("%s, risultati: %s" % [Qualifiche.nome_sessione(q), "   ".join(nomi)], "ordine")
	var passa: int = int(q.dim[q.sess + 1]) if q.sess + 1 < q.dim.size() else 0
	# chi esce prende i posti in fondo (davanti a quelli già eliminati)
	var fuori := cl.slice(passa)
	q.griglia = fuori + q.griglia
	q.sess += 1
	if passa > 0:
		var avanti := cl.slice(0, passa)
		avanti.reverse()   # si gira dall'ultimo al primo
		q.coda = avanti
		_q_nuova_sessione()
		return
	_q_griglia()

func _q_griglia() -> void:
	var q: Dictionary = s.q
	q.fine = true
	s.griglia_via = q.griglia.duplicate()
	s.ordine = []
	var testo := []
	for k in q.griglia.size():
		var a: Dictionary = s.auto[q.griglia[k]]
		a.c = pista.griglia[k]
		s.storia.via[str(a.i)] = a.c
		s.ordine.append(a.i)
		testo.append("%d. %s" % [k + 1, a.nome])
		# il giro spinto si paga in gomme (le auto da preparare lo pagano dopo l'assetto)
		if int(a.get("pq", 0)) > 0 and a.get("pronto", true) and a.pf.has("gomme"):
			a.pf.gomme = max(1, int(a.pf.gomme) - int(a.pq))
			_msg("%s parte con %d Gomme in meno (qualifiche)" % [a.nome, int(a.pq)], "info", a.i)
	_msg("Griglia di partenza (qualifiche): " + "   ".join(testo), "ordine")
	s.fase = "gara"
	eventi.append({"t": "griglia"})
