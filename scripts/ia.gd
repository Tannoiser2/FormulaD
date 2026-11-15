class_name IA
extends RefCounted
## I piloti guidati dal computer: scelgono la marcia pesando ogni faccia del dado e, per ogni tiro,
## la casella migliore (strada fatta, punti persi, rischi) guardando anche la curva che viene dopo.

static var rng := RandomNumberGenerator.new()

## livello: 0 prudente e impreciso, 1 normale, 2 esperto
static func decidi(m: Motore, livello := 1) -> Dictionary:
	var att = m.s.attesa
	if att == null:
		return {}
	var a: Dictionary = m.s.auto[att.auto]
	var rumore: float = [3.0, 0.8, 0.0][clamp(livello, 0, 2)]
	if att.tipo == "mossa":
		return {"t": "mossa", "c": _migliore(m, a, m.opzioni, a.marcia, a.pf, rumore)[0]}
	var best_m := 1
	var best := -INF
	var lista := m.marce(a)
	for opz in lista:
		if opz.fuori and lista.size() > 1:
			continue
		var pf: Dictionary = a.pf.duplicate()
		var costo := 0.0
		for k in opz.costo:
			pf[k] -= opz.costo[k]
			costo += opz.costo[k] * _peso(m, k, pf[k])
		var conta := {}
		for v in Dati.valori_dado(opz.m):
			conta[v] = int(conta.get(v, 0)) + 1
		var tot := 0.0
		var n := 0
		var peggio := INF
		for v in conta:
			var r := m.prova(a, opz, v)
			var p: float = _migliore(m, a, r, opz.m, pf, 0.0)[1]
			# motore sotto sforzo
			if int(Dati.SFORZO.get(opz.m, 0)) == v:
				p -= 0.2 * _peso(m, "motore" if m.avanzate() else "ps", pf.get("motore", pf.get("ps", 3)))
			tot += p * conta[v]
			n += conta[v]
			peggio = min(peggio, p)
		var atteso: float = tot / max(1, n)
		# un po' di prudenza: conta anche il caso peggiore
		var voto: float = atteso * 0.8 + peggio * 0.2 - costo + rng.randf_range(-rumore, rumore)
		if voto > best:
			best = voto
			best_m = opz.m
	return {"t": "marcia", "m": best_m}

static func _migliore(m: Motore, a: Dictionary, opzioni: Dictionary, marcia: int, pf: Dictionary, rumore: float) -> Array:
	var best_c := ""
	var best := -INF
	for cid in opzioni:
		var p := valuta(m, a, opzioni[cid], marcia, pf)
		if rumore > 0:
			p += rng.randf_range(-rumore, rumore)
		if p > best:
			best = p
			best_c = cid
	return [best_c, best]

static func _peso(m: Motore, zona: String, resta: int) -> float:
	match zona:
		"ps":
			return 1.3 + 10.0 / max(1, resta)
		"gomme":
			return 1.5 + 8.0 / max(1, resta + 1)
		"freni":
			return 1.2 + 4.0 / max(1, resta + 1)
		"cambio":
			return 1.0 + 3.0 / max(1, resta + 1)
	return 2.5 + 12.0 / max(1, resta)

static func _serve_box(m: Motore, a: Dictionary, pf: Dictionary) -> bool:
	if not m._puo_pit(a):
		return false
	if m.avanzate():
		return pf.gomme <= 2
	return pf.ps <= 8

static func valuta(m: Motore, a: Dictionary, o: Dictionary, marcia: int, pf: Dictionary) -> float:
	var e: Dictionary = o.eff
	if e.finisce:
		return 10000.0 + o.mosse
	if e.fuori != "":
		return -5000.0 + o.mosse
	var pista := m.pista
	var p := pista.progresso(a.c, o.casella)
	if o.casella != a.c and p <= 0.0 and o.mosse > 0:
		p = float(o.mosse) * 0.8
	var dopo := pf.duplicate()
	for z in e.usura:
		var n: int = e.usura[z]
		dopo[z] -= n
		p -= n * _peso(m, z, dopo[z])
	if e.testa:
		p -= 9.0
	if not e.tocca.is_empty():
		var zc := "carrozzeria" if m.avanzate() else "ps"
		p -= e.tocca.size() * (0.05 if m.avanzate() else 0.2) * _peso(m, zc, dopo[zc])
	if not e.pericoli.is_empty():
		p -= e.pericoli.size() * 0.2 * _peso(m, "tenuta", dopo.get("tenuta", 2))
	var c = pista.per_id[o.casella]
	var da = pista.per_id[a.c]
	var serve := _serve_box(m, a, pf)
	if e.box:
		p += 25.0 if (serve or da.pit) else -5.0
		return p + 4.0
	if c.pit:
		if not da.pit:
			p += 10.0 if serve else -30.0
		return p + 3.0
	p += 0.6 * _prospettiva(m, o.casella, marcia, o.fermate, dopo, e.testa)
	return p

## Quanto promette il turno dopo, partendo da lì con quella marcia.
static func _prospettiva(m: Motore, cid: String, marcia: int, ferm: int, pf: Dictionary, testa: bool) -> float:
	var av := Mosse.avanti(m.pista, cid, ferm)
	var marce := []
	if testa or marcia == 0:
		marce = [1]
	else:
		for g in range(max(1, marcia - 4), min(6, marcia + 1) + 1):
			marce.append(g)
	var best := -INF
	for g in marce:
		var costo := 0.0
		var saltate: int = marcia - g - 1
		if saltate > 0:
			if m.avanzate():
				if pf.cambio <= 0:
					continue
				costo = saltate * 2.5 + (3.0 if saltate >= 3 else 0.0)
				if saltate >= 3 and pf.motore <= 1:
					continue
			else:
				if saltate >= pf.ps:
					continue
				costo = saltate * _peso(m, "ps", pf.ps - saltate)
		var vv := Dati.valori_dado(g)
		var tot := 0.0
		for v in vv:
			tot += _guadagno(m, v, av, pf)
		best = max(best, tot / vv.size() - costo)
	return best if best > -INF else -40.0

static func _guadagno(m: Motore, v: int, av: Dictionary, pf: Dictionary) -> float:
	if av.is_empty():
		return v
	var mancano: int = av.servono - av.fatte
	if mancano <= 0 or v < av.entrata:
		return v
	if v <= av.uscita:
		return v + 2.0
	var oltre: int = v - av.uscita
	if mancano >= 2:
		# resta solo la frenata
		return _frenata(m, oltre, av, pf)
	var lungo := -60.0
	if m.avanzate():
		if oltre < pf.gomme:
			lungo = v - oltre * _peso(m, "gomme", pf.gomme - oltre)
		elif oltre == pf.gomme or (pf.gomme <= 0 and oltre == 1):
			lungo = v - oltre * 3.0 - 9.0
	elif oltre < pf.ps:
		lungo = v - oltre * _peso(m, "ps", pf.ps - oltre)
	return max(lungo, _frenata(m, oltre, av, pf))

static func _frenata(m: Motore, n: int, av: Dictionary, pf: Dictionary) -> float:
	if m.avanzate():
		if n > 6:
			return -60.0
		var freni: int = min(n, 3)
		var gomme: int = max(0, n - 3)
		if freni > pf.freni:
			gomme += freni - max(0, pf.freni)
			freni = max(0, pf.freni)
		if gomme > pf.gomme:
			return -60.0
		return av.uscita + 2.0 - freni * _peso(m, "freni", pf.freni - freni) - gomme * _peso(m, "gomme", pf.gomme - gomme)
	if n >= pf.ps:
		return -60.0
	return av.uscita + 2.0 - n * _peso(m, "ps", pf.ps - n)
