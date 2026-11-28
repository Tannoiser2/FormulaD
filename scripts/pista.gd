class_name Pista
extends RefCounted
## Un circuito: le caselle con i collegamenti (dal modulo TTS), le curve, la griglia, i box
## e la posizione di ogni casella lungo il giro (per l'ordine di gioco).

var id := ""
var nome := ""
var giri := 2
## Soglie del dado nero: fino alla prima pioggia, fino alla seconda variabile, poi sole.
var meteo: Array = [7, 12]
var img := Vector2(2474, 1616)
var caselle: Array = []
var per_id: Dictionary = {}
var fermate: Dictionary = {}   # curva -> fermate obbligatorie
var griglia: Array = []
var traguardo: Dictionary = {} # id -> true: la prima casella oltre la linea, in ogni corsia
var pit: Dictionary = {}
var vicini: Dictionary = {}
var dadi := Vector2.ZERO
var dimensione_curva: Dictionary = {}

# posizione lungo il giro
var lungo: Dictionary = {}     # id -> distanza dalla linea, in pixel, lungo la corsia centrale
var lato: Dictionary = {}      # id -> quanto sta a destra di quella linea
var curva_di: Dictionary = {}  # id -> la curva in cui è, o la prossima
var verso: Dictionary = {}     # curva -> 1 se l'interno è a destra, -1 a sinistra
var lunghezza := 1.0
var cella := 45.0
var largo_cella := 40.0        # larghezza di una casella (distanza fra due corsie), in pixel
var _cache_avanti: Dictionary = {}

static var _caricate: Dictionary = {}

static func carica(pid: String) -> Pista:
	if _caricate.has(pid):
		return _caricate[pid]
	var f := FileAccess.open("res://assets/piste/%s.json" % pid, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	var p := Pista.new()
	p.id = pid
	p.nome = d.nome
	p.giri = int(d.giri)
	var tabella_meteo = d.get("meteo", [7, 12])
	if tabella_meteo is Array and tabella_meteo.size() == 2:
		p.meteo = [int(tabella_meteo[0]), int(tabella_meteo[1])]
	p.img = Vector2(d.img[0], d.img[1])
	p.caselle = d.caselle
	for c in p.caselle:
		c.l = int(c.l)
		c.c = int(c.get("c", 0))
		c.pit = bool(c.get("pit", false))
		c.box = str(c.get("box", ""))
		p.per_id[c.id] = c
		if c.c > 0:
			p.dimensione_curva[c.c] = int(p.dimensione_curva.get(c.c, 0)) + 1
	for c in d.curve:
		p.fermate[int(c.id)] = int(c.stops)
	p.griglia = d.griglia
	for t in d.traguardo:
		p.traguardo[t] = true
	p.pit = d.pit if d.pit is Dictionary else {}
	p.vicini = d.vicini
	if d.get("dadi") is Array:
		p.dadi = Vector2(d.dadi[0], d.dadi[1])
	else:
		p.dadi = p.img * 0.5
	p._posizioni()
	# larghezza delle caselle: distanza dalla casella più vicina di un'altra corsia
	var lati := []
	var norm := []
	for c in p.caselle:
		if not c.pit:
			norm.append(c)
	for k in range(0, norm.size(), 3):
		var c = norm[k]
		var pc := p.pos(c.id)
		var dir := Vector2.from_angle(deg_to_rad(float(c.r)))
		var meglio := 1e9
		var di := 1e9
		for n in norm:
			if n.l != c.l:
				var dd := pc.distance_to(p.pos(n.id))
				if dd < di:
					di = dd
					meglio = absf(dir.cross(p.pos(n.id) - pc))
		if meglio < 1e8:
			lati.append(meglio)
	if lati.size() > 10:
		lati.sort()
		p.largo_cella = clamp(lati[lati.size() / 2], p.cella * 0.4, p.cella * 1.2)
	_caricate[pid] = p
	return p

func pos(cid: String) -> Vector2:
	var c = per_id.get(cid)
	return Vector2(c.p[0], c.p[1]) if c else Vector2.ZERO

## Rilegge il circuito dal file, senza le modifiche fatte con l'editor.
static func ricarica(pid: String) -> Pista:
	_caricate.erase(pid)
	return carica(pid)

# ------------------------------------------------------------------ modifiche dell'editor

func sposta_casella(cid: String, p: Vector2) -> void:
	if per_id.has(cid):
		per_id[cid].p = [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]
		_ricalcola()

func ruota_casella(cid: String, r: float) -> void:
	if per_id.has(cid):
		per_id[cid].r = snappedf(fposmod(r, 360.0), 0.1)

func corsia_casella(cid: String, l: int) -> void:
	if per_id.has(cid):
		per_id[cid].l = l
		per_id[cid].pit = l == 0
		_ricalcola()

## Una casella nuova (senza collegamenti: si aggiungono con l'editor).
func nuova_casella(cid: String, p: Vector2, r: float, l: int, curva: int) -> bool:
	if per_id.has(cid):
		return false
	var c := {"id": cid, "p": [snappedf(p.x, 0.1), snappedf(p.y, 0.1)], "r": snappedf(fposmod(r, 360.0), 0.1), "l": l,
		"s": "x", "n": [], "c": curva, "pit": l == 0, "box": ""}
	caselle.append(c)
	per_id[cid] = c
	# accanto: le caselle vicine delle altre corsie (per contatti e sorpassi)
	var acc: Array = []
	for o in caselle:
		if o.id != cid and o.pit == c.pit and pos(o.id).distance_to(p) < max(cella, largo_cella) * 1.5:
			acc.append(o.id)
			if not vicini.has(o.id):
				vicini[o.id] = []
			if not vicini[o.id].has(cid):
				vicini[o.id].append(cid)
	vicini[cid] = acc
	_ricalcola()
	return true

## Toglie una casella con tutti i collegamenti verso di lei.
func togli_casella(cid: String) -> bool:
	if not per_id.has(cid):
		return false
	caselle.erase(per_id[cid])
	per_id.erase(cid)
	for c in caselle:
		if c.n.has(cid):
			c.n.erase(cid)
	vicini.erase(cid)
	for k in vicini:
		if vicini[k].has(cid):
			vicini[k].erase(cid)
	_ricalcola()
	return true

var _cache_curva := {}

## Quante caselle mancano alla prossima curva (la prima casella di una curva diversa da quella in cui si è),
## seguendo la strada più corta: [caselle, numero della curva, id della casella]. [-1, 0, ""] se non ce n'è.
func prossima_curva(cid: String) -> Array:
	if _cache_curva.has(cid):
		return _cache_curva[cid]
	var out := [-1, 0, ""]
	var da = per_id.get(cid)
	if da != null:
		var qui := int(da.c)
		var visti := {cid: true}
		var giro := [cid]
		var passi := 0
		while not giro.is_empty() and passi < 200 and out[0] < 0:
			passi += 1
			var dopo := []
			for x in giro:
				for n in per_id[x].get("n", []):
					if visti.has(n) or not per_id.has(n):
						continue
					visti[n] = true
					var c = per_id[n]
					if int(c.c) > 0 and int(c.c) != qui:
						out = [passi, int(c.c), str(n)]
						break
					dopo.append(n)
				if out[0] >= 0:
					break
			giro = dopo
	_cache_curva[cid] = out
	return out

func _ricalcola() -> void:
	_cache_curva.clear()
	_cache_avanti.clear()
	dimensione_curva.clear()
	for c in caselle:
		if int(c.c) > 0:
			dimensione_curva[int(c.c)] = int(dimensione_curva.get(int(c.c), 0)) + 1
	_posizioni()

## Aggiunge una traiettoria all'edizione locale della pista. Ritorna false se non è valida o esiste già.
func aggiungi_collegamento(da: String, a: String) -> bool:
	if da == a or not per_id.has(da) or not per_id.has(a):
		return false
	var c: Dictionary = per_id[da]
	var prossime: Array = c.get("n", [])
	if prossime.has(a):
		return false
	prossime.append(a)
	c.n = prossime
	_cache_avanti.clear()
	return true

## Elimina una traiettoria esistente dall'edizione locale della pista.
func elimina_collegamento(da: String, a: String) -> bool:
	if not per_id.has(da) or not per_id.has(a):
		return false
	var c: Dictionary = per_id[da]
	var prossime: Array = c.get("n", [])
	var indice := prossime.find(a)
	if indice < 0:
		return false
	prossime.remove_at(indice)
	c.n = prossime
	_cache_avanti.clear()
	return true

static func _avvolgi(g: float) -> float:
	g = fposmod(g, 360.0)
	return g - 360.0 if g > 180.0 else g

## La corsia centrale, dalla linea del traguardo per tutto il giro.
func _catena() -> Array:
	var lo := 99
	var hi := -99
	for c in caselle:
		if not c.pit:
			lo = min(lo, c.l)
			hi = max(hi, c.l)
	var mid := int(floor((lo + hi) / 2.0 + 0.5))
	var primo = null
	for tid in traguardo:
		var c = per_id.get(tid)
		if c and not c.pit and (primo == null or abs(c.l - mid) < abs(primo.l - mid)):
			primo = c
	if primo == null:
		return []
	var out := [primo]
	var visti := {primo.id: true}
	var qui = primo
	while true:
		var meglio = null
		for nid in qui.n:
			var t = per_id.get(nid)
			if t and not t.pit and (meglio == null or abs(t.l - mid) < abs(meglio.l - mid)):
				meglio = t
		if meglio == null or traguardo.has(meglio.id) or visti.has(meglio.id):
			break
		out.append(meglio)
		visti[meglio.id] = true
		qui = meglio
	return out

func _posizioni() -> void:
	var pts := _catena()
	if pts.size() < 3:
		return
	var settore_n := {}
	var settori := []
	for p in pts:
		if p.s != "" and not settore_n.has(p.s):
			settori.append(p.s)
			settore_n[p.s] = settori.size()
	var segs := []
	var cum := 0.0
	var salti := []
	for i in pts.size():
		var a = pts[i]
		var b = pts[(i + 1) % pts.size()]
		var d := Vector2(b.p[0] - a.p[0], b.p[1] - a.p[1])
		var ln := d.length()
		segs.append({"a": a, "d": d, "len": ln, "da": cum, "set": {a.s: true, b.s: true}})
		cum += ln
		salti.append(ln)
	salti.sort()
	lunghezza = cum
	cella = salti[int(ceil(salti.size() / 2.0)) - 1]
	var primo_settore: String = pts[0].s
	var ultimo: int = segs.size() - 1
	for s in caselle:
		var suo: String = s.s if settore_n.has(s.s) else ""
		var best := -1
		var best_d := INF
		var best_t := 0.0
		for i in segs.size():
			var g = segs[i]
			if g.len > 0 and (suo == "" or g.set.has(suo)) and not (i == ultimo and suo == primo_settore):
				var px: float = s.p[0] - g.a.p[0]
				var py: float = s.p[1] - g.a.p[1]
				var t: float = (px * g.d.x + py * g.d.y) / (g.len * g.len)
				var tc: float = clamp(t, 0.0, 1.0)
				if i == 0 and t < 0:
					tc = t
				var ex: float = px - tc * g.d.x
				var ey: float = py - tc * g.d.y
				var dd := ex * ex + ey * ey
				if dd < best_d:
					best = i
					best_d = dd
					best_t = tc
		if best >= 0:
			var g = segs[best]
			var px: float = s.p[0] - g.a.p[0]
			var py: float = s.p[1] - g.a.p[1]
			lungo[s.id] = g.da + best_t * g.len
			lato[s.id] = (px * -g.d.y + py * g.d.x) / g.len
	# da che parte gira ogni curva: l'interno è la corsia con meno caselle
	var corsie := {}
	for s in caselle:
		if s.c > 0 and lato.has(s.id):
			if not corsie.has(s.c):
				corsie[s.c] = {}
			var c: Dictionary = corsie[s.c]
			if not c.has(s.l):
				c[s.l] = {"n": 0, "lato": 0.0}
			c[s.l].n += 1
			c[s.l].lato += lato[s.id]
	var direzione := {}
	for i in range(1, pts.size()):
		var p = pts[i]
		if p.c > 0:
			direzione[p.c] = float(direzione.get(p.c, 0.0)) + _avvolgi(p.r - pts[i - 1].r)
	for cid in corsie:
		var c: Dictionary = corsie[cid]
		var lo := 99
		var hi := -99
		for l in c:
			lo = min(lo, l)
			hi = max(hi, l)
		var a: Dictionary = c[lo]
		var b: Dictionary = c[hi]
		if a.n != b.n:
			var corta := a
			var lunga := b
			if b.n < a.n:
				corta = b
				lunga = a
			verso[cid] = 1 if corta.lato / corta.n > lunga.lato / lunga.n else -1
		else:
			verso[cid] = 1 if float(direzione.get(cid, 0.0)) >= 0 else -1
	# la curva in cui si è o a cui si va incontro
	var curva_settore := {}
	for p in pts:
		if p.c > 0 and p.s != "":
			curva_settore[p.s] = p.c
	var avanti := {}
	for i in settori.size():
		for j in settori.size():
			var c = curva_settore.get(settori[(i + j) % settori.size()])
			if c != null:
				avanti[settori[i]] = c
				break
	for s in caselle:
		curva_di[s.id] = s.c if s.c > 0 else int(avanti.get(s.s, 0))

## Quanto la casella è verso l'interno della curva in cui è o che ha davanti.
func interno(cid: String) -> float:
	var c := int(curva_di.get(cid, 0))
	if c == 0 or not verso.has(c) or not lato.has(cid):
		return 0.0
	return verso[c] * lato[cid]

## Avanzamento in celle da una casella a un'altra (nel verso di marcia, anche oltre il traguardo).
func progresso(da: String, a: String) -> float:
	if da == a or not lungo.has(da) or not lungo.has(a):
		return 0.0
	var d: float = lungo[a] - lungo[da]
	if d < -lunghezza * 0.5:
		d += lunghezza
	elif d > lunghezza * 0.5:
		d -= lunghezza
	return d / cella
