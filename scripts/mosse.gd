class_name Mosse
extends RefCounted
## Dove può arrivare un'auto con il tiro che ha fatto, e che cosa comporta fermarsi lì.
## (Trasposizione della logica del modulo TTS «Formula D: Scripted».)
##
## Una mossa sono `tiro` passi lungo i collegamenti del circuito, mai attraverso o sopra un'altra auto.
## Fermarsi prima è frenare. In rettilineo si va per la via più breve (niente zigzag per consumare il tiro);
## in curva valgono le frecce. Una curva chiede un certo numero di fermate: uscirne prima è andare lungo,
## e da lì in poi ogni casella è «oltre», restando nella corsia da cui si è usciti.
##
## Un'opzione: {casella, mosse, freno, oltre, mancate, curva, fermate, percorso, traguardo, scia, scia_curve}

static func costo_base(o: Dictionary) -> float:
	if o.mancate >= 2:
		return 1000.0 + o.freno + o.oltre
	return float(o.freno + o.oltre)

static func _esito(st: Dictionary, mosse: int, tiro: int) -> Dictionary:
	var over = st.over
	var o := {
		"casella": st.sp.id, "mosse": mosse, "freno": tiro - mosse,
		"oltre": over.spazi if over else 0,
		"mancate": over.mancate if over else 0,
		"curva": over.curva if over else 0,
		"fermate": 0,
	}
	if st.sp.c > 0 and over == null:
		o.fermate = st.made + 1
	return o

static func _finale(st: Dictionary, mosse: int, tiro: int, linea: Dictionary) -> Dictionary:
	var o := _esito(st, mosse, tiro)
	var percorso := []
	var at = st
	o.traguardo = false
	while at != null:
		percorso.push_front(at.sp.id)
		if at.prev != null and linea.has(at.sp.id) and not linea.has(at.prev.sp.id):
			o.traguardo = true
		at = at.prev
	o.percorso = percorso
	return o

## opz: occupate {id: true}, fermate (già fatte nella curva in cui si è, -1 = da calcolare),
## costo (Callable), pit (può entrare ai box), posto (il box di chi muove)
static func raggiungi(pista: Pista, da_id: String, tiro: int, opz: Dictionary) -> Dictionary:
	var per_id := pista.per_id
	var servono := pista.fermate
	var linea := pista.traguardo
	var da = per_id.get(da_id)
	if da == null:
		return {}
	var occupate: Dictionary = opz.get("occupate", {})
	var costo: Callable = opz.get("costo", Callable(Mosse, "costo_base"))
	var puo_pit: bool = opz.get("pit", false)
	var posto: String = opz.get("posto", "")
	var fatte: int = opz.get("fermate", -1)
	if fatte < 0:
		fatte = 1 if da.c > 0 else 0

	var aperta := func(s, t) -> bool:
		return t != null and not occupate.has(t.id) and (not t.pit or s.pit or puo_pit) and (t.box == "" or t.box == posto)

	var dist := {}
	var dist_da := func(a) -> Dictionary:
		if dist.has(a.id):
			return dist[a.id]
		var d := {a.id: 0}
		var anello := [a]
		for k in range(1, tiro + 1):
			var nxt := []
			for s in anello:
				for nid in s.n:
					var t = per_id.get(nid)
					if aperta.call(s, t) and not d.has(nid):
						d[nid] = k
						nxt.append(t)
			anello = nxt
			if anello.is_empty():
				break
		dist[a.id] = d
		return d

	var inizio := {"sp": da, "made": fatte, "over": null, "prev": null, "run": da, "run_at": 0}
	var risultati := {da.id: _finale(inizio, 0, tiro, linea)}
	var livello := [inizio]
	for mosse in range(1, tiro + 1):
		var meglio := {}
		var ordine := []
		for st in livello:
			var s = st.sp
			for nid in s.n:
				var t = per_id.get(nid)
				var run = st.run
				var run_at: int = st.run_at
				var ok := false
				if aperta.call(s, t):
					if s.c > 0 or t.c > 0:
						run = t
						run_at = mosse
						ok = true
					else:
						ok = int(dist_da.call(run).get(nid, -1)) == mosse - run_at
				if ok:
					var over = st.over
					var t_made: int = st.made
					if over != null:
						over = {"curva": over.curva, "mancate": over.mancate, "spazi": over.spazi + 1}
					elif s.c > 0 and t.c != s.c and servono.has(s.c) and st.made < servono[s.c]:
						over = {"curva": s.c, "mancate": servono[s.c] - st.made, "spazi": 1}
					if t.c != s.c:
						t_made = 0
					# andando lungo si resta nella propria corsia
					if over == null or t.l == s.l:
						var nst := {"sp": t, "made": t_made, "over": over, "prev": st, "run": run, "run_at": run_at}
						var chiave: String = nid + "<" + run.id
						if not meglio.has(chiave):
							ordine.append(chiave)
							meglio[chiave] = nst
						elif costo.call(_esito(nst, mosse, tiro)) < costo.call(_esito(meglio[chiave], mosse, tiro)):
							meglio[chiave] = nst
		livello = []
		for chiave in ordine:
			var st = meglio[chiave]
			var aveva = risultati.get(st.sp.id)
			if aveva == null or costo.call(_esito(st, mosse, tiro)) <= costo.call(aveva):
				risultati[st.sp.id] = _finale(st, mosse, tiro, linea)
			livello.append(st)
		if livello.is_empty():
			break
	return risultati

const MAX_SCIE := 6

## Dove porta la scia a partire dalle opzioni `reach`: chi finisce tutto il tiro esattamente dietro
## un'altra auto (entrambe almeno in `min_marcia`, chi segue con marcia non più bassa) può proseguire
## di `spazi` caselle, girandole attorno. Può frenare parte di quelle caselle e prendere un'altra scia.
## opz: occupate, marce {id: marcia dell'auto lì}, marcia, min_marcia, spazi, costo, posto
static func scia(pista: Pista, reach: Dictionary, opz: Dictionary) -> Dictionary:
	var out := {}
	for k in reach:
		_scia_da(pista, reach[k], 1, opz, out)
	return out

static func _davanti(pista: Pista, o: Dictionary, occupate: Dictionary) -> String:
	var s = pista.per_id.get(o.casella)
	if s == null or s.pit:
		return ""
	for nid in s.n:
		var t = pista.per_id.get(nid)
		if t and t.l == s.l and occupate.has(nid):
			return nid
	return ""

static func _scia_da(pista: Pista, o: Dictionary, prof: int, opz: Dictionary, out: Dictionary) -> void:
	if prof > MAX_SCIE or o.freno > 0 or o.oltre > 0:
		return
	var occupate: Dictionary = opz.occupate
	var id := _davanti(pista, o, occupate)
	if id == "":
		return
	var g := int(opz.marce.get(id, 0))
	if not (g >= opz.min_marcia and opz.marcia >= g):
		return
	var costo: Callable = opz.get("costo", Callable(Mosse, "costo_base"))
	var s = pista.per_id[o.casella]
	var fatte: int = (o.fermate - 1) if (s.c > 0 and o.fermate > 0) else 0
	var altre := raggiungi(pista, o.casella, opz.spazi, {"occupate": occupate, "fermate": fatte, "posto": opz.get("posto", ""), "costo": costo})
	for cid in altre:
		if cid == o.casella:
			continue
		var c: Dictionary = altre[cid]
		var percorso: Array = o.percorso.duplicate()
		var dentro := false
		for k in range(1, c.percorso.size()):
			percorso.append(c.percorso[k])
			var p = pista.per_id[c.percorso[k]]
			dentro = dentro or (p.c > 0 and p.c != s.c)
		var n := {
			"casella": cid, "mosse": o.mosse + c.mosse, "freno": c.freno, "oltre": c.oltre, "mancate": c.mancate,
			"curva": c.curva, "fermate": c.fermate, "percorso": percorso, "traguardo": o.traguardo or c.traguardo,
			"scia": int(o.get("scia", 0)) + 1, "scia_curve": int(o.get("scia_curve", 0)) + (1 if dentro else 0),
		}
		var aveva = out.get(cid)
		if aveva == null or costo.call(n) < costo.call(aveva):
			out[cid] = n
		_scia_da(pista, n, prof + 1, opz, out)

## La curva che conta per un'auto ferma su `da_id`: quella in cui è (se le mancano fermate) o la prossima.
## Ritorna {} oppure {curva, servono, fatte, dentro, entrata, uscita}: entrata = passi minimi per arrivarci,
## uscita = il massimo che si può avanzare restando ancora dentro la curva.
static func avanti(pista: Pista, da_id: String, fermate_fatte: int) -> Dictionary:
	var chiave := "%s/%d" % [da_id, fermate_fatte]
	if pista._cache_avanti.has(chiave):
		return pista._cache_avanti[chiave]
	var da = pista.per_id.get(da_id)
	var out := {}
	if da == null:
		return out
	var fatte := fermate_fatte
	if fatte < 0:
		fatte = 1 if da.c > 0 else 0
	var curva := 0
	var entrata := 0
	if da.c > 0 and fatte < int(pista.fermate.get(da.c, 0)):
		curva = da.c
	else:
		var visti := {da.id: true}
		var anello := [da]
		var k := 0
		while not anello.is_empty() and curva == 0:
			k += 1
			var nxt := []
			for s in anello:
				for nid in s.n:
					var t = pista.per_id.get(nid)
					if t and not visti.has(nid):
						visti[nid] = true
						if t.c > 0 and t.c != da.c and not t.pit:
							curva = t.c
							entrata = k
						nxt.append(t)
			anello = nxt
	if curva > 0:
		var grande := int(pista.dimensione_curva.get(curva, 0))
		var uscita := entrata
		var r := raggiungi(pista, da_id, entrata + grande + 4, {"fermate": fatte})
		for cid in r:
			var o: Dictionary = r[cid]
			if pista.per_id[cid].c == curva and o.oltre == 0 and o.mosse > uscita:
				uscita = o.mosse
		out = {"curva": curva, "servono": int(pista.fermate.get(curva, 0)), "fatte": fatte if curva == da.c else 0,
			"dentro": curva == da.c, "entrata": entrata, "uscita": uscita}
	pista._cache_avanti[chiave] = out
	return out
