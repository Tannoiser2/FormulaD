class_name Campionato
extends RefCounted
## Il campionato (dal regolamento di Gianluca Lari): più Gran Premi di fila, qualifiche a settori prima di ognuno,
## punti 8-6-4-2-1 ai primi cinque arrivati, classifica piloti, scuderie (i due piloti dello stesso colore) e premio
## Gilles Villeneuve (posizioni guadagnate dalla griglia all'arrivo; chi non arriva conta ultimo).
## Punti Pilota: 1 fisso per gara, più 1 «provvisorio» ai primi tre di ogni GP, fino a 4 in tutto; servono a ritirare
## il dado della marcia e si spendono prima i provvisori. Solo dati: si salva così com'è.

const PUNTI := [8, 6, 4, 2, 1]
const PP_MAX := 4

## conf: come quella di una gara, più "campionato": {piste: [...]}.
static func nuovo(conf: Dictionary) -> Dictionary:
	var c := {"piste": conf.campionato.piste.duplicate(), "gp": 0, "regole": conf.regole, "giri": int(conf.giri),
		"livello": int(conf.get("livello", 1)), "opzioni": conf.get("opzioni", {}).duplicate(), "auto": conf.auto.duplicate(true),
		"punti": {}, "vill": {}, "prov": {}, "vittorie": {}, "gare": [], "finito": false}
	c.opzioni["qualifiche"] = true
	c.opzioni["strada"] = false
	for a in c.auto:
		var k := str(a.pilota)
		c.punti[k] = 0
		c.vill[k] = 0
		c.prov[k] = 0
		c.vittorie[k] = 0
	return c

## La conf della gara del GP corrente.
static func conf_gp(c: Dictionary) -> Dictionary:
	var lista := []
	for a in c.auto:
		var d: Dictionary = a.duplicate()
		d["pp"] = min(PP_MAX, 1 + int(c.prov.get(str(a.pilota), 0)))
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
	for a in arrivi:
		var k := str(a.pilota)
		var pos := int(a.posto_arrivo)
		var punti := 0
		if pos >= 1 and pos <= PUNTI.size():
			punti = PUNTI[pos - 1]
		var dal := griglia.find(int(a.i)) + 1
		if dal <= 0:
			dal = n
		var al := pos if pos > 0 else n
		var vill := dal - al
		c.punti[k] = int(c.punti.get(k, 0)) + punti
		c.vill[k] = int(c.vill.get(k, 0)) + vill
		if pos == 1:
			c.vittorie[k] = int(c.vittorie.get(k, 0)) + 1
		# Punti Pilota: si spendono prima i provvisori; ai primi tre uno in più per il prossimo GP
		var avuti: int = min(PP_MAX, 1 + int(c.prov.get(k, 0)))
		var usati: int = max(0, avuti - int(a.get("pp", avuti)))
		var prov: int = max(0, int(c.prov.get(k, 0)) - usati)
		if pos >= 1 and pos <= 3:
			prov = min(PP_MAX - 1, prov + 1)
		c.prov[k] = prov
		riepilogo.append({"p": int(a.pilota), "n": str(a.nome), "pos": pos, "punti": punti, "dal": dal, "vill": vill,
			"perche": str(a.get("perche", ""))})
	c.gare.append({"pista": c.piste[int(c.gp)], "arrivo": riepilogo})
	c.gp = int(c.gp) + 1
	c.finito = int(c.gp) >= c.piste.size()
	return riepilogo

## Classifiche: [{chiave, nome, valore, ...}] ordinate.
static func piloti(c: Dictionary) -> Array:
	var l := []
	for a in c.auto:
		var k := str(a.pilota)
		l.append({"p": int(a.pilota), "n": str(a.nome), "punti": int(c.punti.get(k, 0)), "vit": int(c.vittorie.get(k, 0)),
			"pp": min(PP_MAX, 1 + int(c.prov.get(k, 0))), "vill": int(c.vill.get(k, 0))})
	l.sort_custom(func(x, y):
		if x.punti != y.punti:
			return x.punti > y.punti
		return x.vit > y.vit)
	return l

static func scuderie(c: Dictionary) -> Array:
	var tot := {}
	var nomi := {}
	for a in c.auto:
		var sc: String = Dati.PILOTI[int(a.pilota)].scuderia
		tot[sc] = int(tot.get(sc, 0)) + int(c.punti.get(str(a.pilota), 0))
		if not nomi.has(sc):
			nomi[sc] = []
		nomi[sc].append(Dati.corto(str(a.nome)))
	var l := []
	for sc in tot:
		l.append({"s": sc, "punti": tot[sc], "piloti": " e ".join(PackedStringArray(nomi[sc]))})
	l.sort_custom(func(x, y): return x.punti > y.punti)
	return l

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
