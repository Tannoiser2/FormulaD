class_name Modifiche
extends RefCounted
## Le correzioni fatte con l'editor delle piste, salvate su questo dispositivo e riapplicate a ogni caricamento:
## traiettorie aggiunte e tolte, e per ogni casella posizione, rotazione, corsia, caselle nuove e tolte.
## Si esportano in un file JSON (formato «FormulaD-traiettorie», versione 3) da integrare nel gioco con
## tools/importa_traiettorie.mjs.

static func _k_agg(pid: String) -> String:
	return "fd_traiettorie_%s" % pid

static func _k_tolte(pid: String) -> String:
	return "fd_traiettorie_rimosse_%s" % pid

static func _k_celle(pid: String) -> String:
	return "fd_celle_%s" % pid

static func _leggi(rete, k: String):
	var t: String = rete.carica(k)
	return null if t.strip_edges() == "" else JSON.parse_string(t)

static func _lista(rete, k: String) -> Array:
	var x = _leggi(rete, k)
	return x if x is Array else []

static func celle(rete, pid: String) -> Dictionary:
	var x = _leggi(rete, _k_celle(pid))
	return x if x is Dictionary else {}

## Applica alla pista (già caricata) tutte le modifiche salvate. Si può chiamare più volte.
static func applica(rete, p: Pista) -> void:
	if p == null:
		return
	var cc := celle(rete, p.id)
	for cid in cc:
		var d: Dictionary = cc[cid]
		if d.get("nuova", false) and not d.get("tolta", false):
			p.nuova_casella(cid, Vector2(d.p[0], d.p[1]), float(d.get("r", 0)), int(d.get("l", 2)), int(d.get("c", 0)))
	for cid in cc:
		var d: Dictionary = cc[cid]
		if d.get("tolta", false):
			p.togli_casella(cid)
			continue
		if d.has("p"):
			p.sposta_casella(cid, Vector2(d.p[0], d.p[1]))
		if d.has("r"):
			p.ruota_casella(cid, float(d.r))
		if d.has("l"):
			p.corsia_casella(cid, int(d.l))
	for x in _lista(rete, _k_agg(p.id)):
		if x is Array and x.size() == 2:
			p.aggiungi_collegamento(str(x[0]), str(x[1]))
	for x in _lista(rete, _k_tolte(p.id)):
		if x is Array and x.size() == 2:
			p.elimina_collegamento(str(x[0]), str(x[1]))

## Ricorda un cambio di una casella (posizione, rotazione, corsia, nuova, tolta).
static func segna_cella(rete, pid: String, cid: String, dati: Dictionary) -> void:
	var cc := celle(rete, pid)
	var d: Dictionary = cc.get(cid, {})
	for k in dati:
		d[k] = dati[k]
	if d.get("tolta", false) and d.get("nuova", false):
		cc.erase(cid)
	else:
		cc[cid] = d
	rete.salva(_k_celle(pid), JSON.stringify(cc) if not cc.is_empty() else "")

static func aggiungi_traiettoria(rete, p: Pista, da: String, a: String) -> bool:
	if not p.aggiungi_collegamento(da, a):
		return false
	var coppia := [da, a]
	var tolte := _lista(rete, _k_tolte(p.id))
	if tolte.has(coppia):
		tolte.erase(coppia)
		rete.salva(_k_tolte(p.id), JSON.stringify(tolte) if not tolte.is_empty() else "")
	else:
		var agg := _lista(rete, _k_agg(p.id))
		if not agg.has(coppia):
			agg.append(coppia)
		rete.salva(_k_agg(p.id), JSON.stringify(agg))
	return true

static func elimina_traiettoria(rete, p: Pista, da: String, a: String) -> bool:
	if not p.elimina_collegamento(da, a):
		return false
	var coppia := [da, a]
	var agg := _lista(rete, _k_agg(p.id))
	if agg.has(coppia):
		agg.erase(coppia)
		rete.salva(_k_agg(p.id), JSON.stringify(agg) if not agg.is_empty() else "")
	else:
		var tolte := _lista(rete, _k_tolte(p.id))
		if not tolte.has(coppia):
			tolte.append(coppia)
		rete.salva(_k_tolte(p.id), JSON.stringify(tolte))
	return true

## Quante modifiche ci sono per quella pista.
static func quante(rete, pid: String) -> int:
	return _lista(rete, _k_agg(pid)).size() + _lista(rete, _k_tolte(pid)).size() + celle(rete, pid).size()

## Dimentica tutte le modifiche di una pista.
static func azzera(rete, pid: String) -> void:
	for k in [_k_agg(pid), _k_tolte(pid), _k_celle(pid)]:
		rete.salva(k, "")

## Il pacchetto da esportare; vuoto se non c'è niente.
static func pacchetto(rete) -> Dictionary:
	var piste := {}
	for pid in Dati.PISTE:
		var m := {"aggiunte": [], "eliminazioni": [], "celle": celle(rete, pid)}
		for x in _lista(rete, _k_agg(pid)):
			m.aggiunte.append({"da": str(x[0]), "a": str(x[1])})
		for x in _lista(rete, _k_tolte(pid)):
			m.eliminazioni.append({"da": str(x[0]), "a": str(x[1])})
		if m.aggiunte.size() + m.eliminazioni.size() + m.celle.size() > 0:
			piste[pid] = m
	if piste.is_empty():
		return {}
	return {"formato": "FormulaD-traiettorie", "versione": 3, "creato": Time.get_datetime_string_from_system(true), "piste": piste}
