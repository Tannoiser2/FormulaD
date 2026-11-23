class_name Campionato
extends RefCounted
## Il campionato (dal regolamento di Gianluca Lari): più Gran Premi di fila, qualifiche a settori prima di ognuno,
## punti 8-6-4-2-1 ai primi cinque arrivati, classifica piloti, scuderie (i due piloti dello stesso colore) e premio
## Gilles Villeneuve (posizioni guadagnate dalla griglia all'arrivo; chi non arriva conta ultimo).
## Punti Pilota: 1 fisso per gara, più 1 «provvisorio» ai primi tre di ogni GP, fino a 4 in tutto; servono a ritirare
## il dado della marcia e si spendono prima i provvisori. Solo dati: si salva così com'è.

const PUNTI := [8, 6, 4, 2, 1]
const PP_MAX := 4
const PP_PERM_MAX := 3

## conf: come quella di una gara, più "campionato": {piste: [...]}.
## esp: i premi di esperienza dei campionati precedenti {piloti: {nome: PP in più}, scuderie: {colore: meccanici in più}}.
static func nuovo(conf: Dictionary, esp := {}) -> Dictionary:
	var c := {"piste": conf.campionato.piste.duplicate(), "gp": 0, "regole": conf.regole, "giri": int(conf.giri),
		"livello": int(conf.get("livello", 1)), "opzioni": conf.get("opzioni", {}).duplicate(), "auto": conf.auto.duplicate(true),
		"punti": {}, "vill": {}, "prov": {}, "vittorie": {}, "gare": [], "finito": false,
		"perm": {}, "pmec": {}, "assenti": {}, "punti_sc": {}}
	c.opzioni["qualifiche"] = true
	c.opzioni["strada"] = false
	if c.opzioni.get("lari", false):
		# regolamento Lari: l'assetto si prepara a ogni Gran Premio
		c.opzioni["libero"] = true
	for a in c.auto:
		var k := str(a.pilota)
		c.punti[k] = 0
		c.vill[k] = 0
		c.prov[k] = 0
		c.vittorie[k] = 0
		c.perm[k] = min(PP_PERM_MAX, 1 + int(esp.get("piloti", {}).get(str(a.nome), 0)))
		var sc: String = Dati.PILOTI[int(a.pilota)].scuderia
		c.pmec[k] = 2 + min(2, int(esp.get("scuderie", {}).get(sc, 0)))
	return c

## Punti Pilota permanenti del pilota (1, più i premi di esperienza).
static func _perm(c: Dictionary, k: String) -> int:
	return int(c.get("perm", {}).get(k, 1))

## La conf della gara del GP corrente.
static func conf_gp(c: Dictionary) -> Dictionary:
	var lista := []
	for a in c.auto:
		var d: Dictionary = a.duplicate()
		var k := str(a.pilota)
		d["pp"] = min(PP_MAX, _perm(c, k) + int(c.prov.get(k, 0)))
		d["pmec"] = int(c.get("pmec", {}).get(k, 2))
		if int(c.get("assenti", {}).get(k, 0)) > 0:
			# il pilota è fermo (rischio pilota): guida il collaudatore, che porta punti solo alla scuderia
			d["nome"] = "Collaudatore " + str(Dati.SCUDERIE[Dati.PILOTI[int(a.pilota)].scuderia].nome)
			d["coll"] = true
			d["pp"] = 0
		lista.append(d)
	return {"regole": c.regole, "pista": c.piste[int(c.gp)], "giri": c.giri, "auto": lista, "livello": c.livello,
		"stanza": false, "opzioni": c.opzioni.duplicate(), "camp": int(c.gp)}

## A gara finita: punti, Villeneuve, Punti Pilota. Ritorna il riepilogo della gara.
static func registra(c: Dictionary, s: Dictionary) -> Array:
	var n: int = s.auto.size()
	var griglia: Array = s.get("griglia_via", [])
	var arrivi := []
	for a in s.auto:
		arrivi.append(a)
	arrivi.sort_custom(func(x, y):
		var px := int(x.posto_arrivo) if int(x.posto_arrivo) > 0 else 99
		var py := int(y.posto_arrivo) if int(y.posto_arrivo) > 0 else 99
		return px < py)
	var riepilogo := []
	if not c.has("assenti"):
		c["assenti"] = {}
	if not c.has("punti_sc"):
		c["punti_sc"] = {}
	for a in arrivi:
		var k := str(a.pilota)
		var sc: String = Dati.PILOTI[int(a.pilota)].scuderia
		var pos := int(a.posto_arrivo)
		var punti := 0
		if pos >= 1 and pos <= PUNTI.size():
			punti = PUNTI[pos - 1]
		var dal := griglia.find(int(a.i)) + 1
		if dal <= 0:
			dal = n
		var al := pos if pos > 0 else n
		var vill := dal - al
		c.punti_sc[sc] = int(c.punti_sc.get(sc, 0)) + punti
		var coll := bool(a.get("coll", false))
		if coll:
			# il collaudatore: punti solo alla scuderia; il pilota salta una gara in meno
			if int(c.assenti.get(k, 0)) < 900:
				c.assenti[k] = int(c.assenti.get(k, 0)) - 1
		else:
			c.punti[k] = int(c.punti.get(k, 0)) + punti
			c.vill[k] = int(c.vill.get(k, 0)) + vill
			if pos == 1:
				c.vittorie[k] = int(c.vittorie.get(k, 0)) + 1
			# Punti Pilota: si spendono prima i provvisori; ai primi tre uno in più per il prossimo GP
			var avuti: int = min(PP_MAX, _perm(c, k) + int(c.prov.get(k, 0)))
			var usati: int = max(0, avuti - int(a.get("pp", avuti)))
			var prov: int = max(0, int(c.prov.get(k, 0)) - usati)
			if pos >= 1 and pos <= 3:
				prov = min(PP_MAX - _perm(c, k), prov + 1)
			c.prov[k] = prov
			# rischio pilota
			match str(a.get("rischio", "")):
				"rip":
					c.assenti[k] = 999
				"frattura":
					c.assenti[k] = 1
		riepilogo.append({"p": int(a.pilota), "n": str(a.nome), "pos": pos, "punti": punti if not coll else 0, "dal": dal,
			"vill": vill if not coll else 0, "perche": str(a.get("perche", "")) + (" (punti alla scuderia: %d)" % punti if coll and punti > 0 else "")})
	c.gare.append({"pista": c.piste[int(c.gp)], "arrivo": riepilogo})
	c.gp = int(c.gp) + 1
	c.finito = int(c.gp) >= c.piste.size()
	return riepilogo

## Classifiche: [{chiave, nome, valore, ...}] ordinate.
static func piloti(c: Dictionary) -> Array:
	var l := []
	for a in c.auto:
		var k := str(a.pilota)
		var nome := str(a.nome)
		var ass := int(c.get("assenti", {}).get(k, 0))
		if ass >= 900:
			nome += " (ritirato)"
		elif ass > 0:
			nome += " (infortunato)"
		l.append({"p": int(a.pilota), "n": nome, "punti": int(c.punti.get(k, 0)), "vit": int(c.vittorie.get(k, 0)),
			"pp": min(PP_MAX, _perm(c, k) + int(c.prov.get(k, 0))), "vill": int(c.vill.get(k, 0))})
	l.sort_custom(func(x, y):
		if x.punti != y.punti:
			return x.punti > y.punti
		return x.vit > y.vit)
	return l

static func scuderie(c: Dictionary) -> Array:
	var tot := {}
	var nomi := {}
	var con_sc: bool = c.has("punti_sc") and not c.punti_sc.is_empty()
	for a in c.auto:
		var sc: String = Dati.PILOTI[int(a.pilota)].scuderia
		tot[sc] = int(c.punti_sc.get(sc, 0)) if con_sc else int(tot.get(sc, 0)) + int(c.punti.get(str(a.pilota), 0))
		if not nomi.has(sc):
			nomi[sc] = []
		nomi[sc].append(Dati.corto(str(a.nome)))
	var l := []
	for sc in tot:
		l.append({"s": sc, "punti": tot[sc], "piloti": " e ".join(PackedStringArray(nomi[sc]))})
	l.sort_custom(func(x, y): return x.punti > y.punti)
	return l

## A campionato finito: ai primi tre piloti 1 Punto Pilota permanente in più per i campionati seguenti (al massimo 3
## in tutto), alla scuderia campione 1 punto meccanico in più (al massimo 2). Ritorna esp aggiornato e il testo.
static func esperienza_finale(c: Dictionary, esp: Dictionary) -> Array:
	var e := esp.duplicate(true)
	if not e.has("piloti"):
		e["piloti"] = {}
	if not e.has("scuderie"):
		e["scuderie"] = {}
	var testo := []
	var cl := piloti(c)
	for k in min(3, cl.size()):
		var a: Dictionary = c.auto[0]
		for x in c.auto:
			if int(x.pilota) == int(cl[k].p):
				a = x
		var nome := str(a.nome)
		var ora := int(e.piloti.get(nome, 0))
		if ora < PP_PERM_MAX - 1:
			e.piloti[nome] = ora + 1
			testo.append("%s +1 Punto Pilota permanente" % nome)
	var sc := scuderie(c)
	if not sc.is_empty():
		var s0: String = sc[0].s
		var ora := int(e.scuderie.get(s0, 0))
		if ora < 2:
			e.scuderie[s0] = ora + 1
			testo.append("scuderia %s +1 meccanico" % Dati.SCUDERIE[s0].nome)
	return [e, ", ".join(PackedStringArray(testo))]

static func villeneuve(c: Dictionary) -> Array:
	var l := piloti(c)
	l.sort_custom(func(x, y): return x.vill > y.vill)
	return l

## Il nome corto del circuito; i tabelloni di Formula Dé con lo stesso nome di uno più nuovo hanno «(Dé)».
static func nome_pista(pid: String) -> String:
	var n := _corto(pid)
	if pid.begins_with("FDe"):
		for altra in Dati.PISTE:
			if altra != pid and not altra.begins_with("FDe") and _corto(altra) == n:
				return n + " (Dé)"
	return n

static func _corto(pid: String) -> String:
	var n: String = Pista.carica(pid).nome
	return n.get_slice(": ", 1) if n.contains(": ") else n
