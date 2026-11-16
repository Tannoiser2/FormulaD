class_name Mondo
extends Node3D
## Il tavolo in 3D: il tabellone originale, le auto del modulo, i dadi delle marce, i segnalini.
## La visuale si sposta, si avvicina e ruota con il mouse e con le dita (iPad).

signal casella_toccata(cid: String)
signal casella_mappa(cid: String)   # con la mappatura accesa: la casella toccata, per vederne i collegamenti

const SCALA := 0.01          # 1 pixel del tabellone = 1 cm
const COL_LIBERA := Color(0.15, 0.95, 0.3)
const COL_COSTO := Color(1.0, 0.85, 0.1)
const COL_TESTA := Color(1.0, 0.5, 0.05)
const COL_FUORI := Color(0.95, 0.1, 0.1)
const COL_BOX := Color(0.2, 0.7, 1.0)
const COL_ARRIVO := Color(1, 1, 1)

var pista: Pista
var tabellone: MeshInstance3D
var auto := {}               # indice -> Node3D
var auto_casella := {}       # indice -> casella mostrata
var segni := {}              # casella -> MeshInstance3D (opzioni di mossa)
var opzioni := {}            # casella -> opzione (dalla vista)
var scelta := ""
var danni := {}              # casella -> Array di nodi
var velocita := 1.0
var font: Font

# visuale
var cam: Camera3D
var bersaglio := Vector3.ZERO
var distanza := 20.0
var imbardata := 0.0
var inclinazione := 1.05
var _bersaglio_t := Vector3.ZERO
var _distanza_t := 20.0
var _tocchi := {}
var _mosso := false
var _tasto := 0
var _premuto_in := Vector2.ZERO
var _mat_segno := {}
var _prec_due: Array = []
## Detto dall'interfaccia: vero se il punto è sopra un pannello (il tocco non deve arrivare al tabellone).
var sopra_ui: Callable

## false: la telecamera resta dove l'ha messa il giocatore e non insegue le mosse
var segui := true
var pannelli: Control   # l'interfaccia: la sua colonna a destra copre il tabellone, il centro della vista si sposta a sinistra

func _ready() -> void:
	font = load("res://assets/font/BarlowCondensed-Bold.ttf")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, 35, 0)
	sole.light_energy = 0.9
	add_child(sole)
	cam = Camera3D.new()
	cam.fov = 45
	cam.near = 0.1
	cam.far = 200
	add_child(cam)
	var tavolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 70)
	tavolo.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.09, 0.1, 0.13)
	mt.roughness = 1.0
	tavolo.material_override = mt
	tavolo.position.y = -0.05
	add_child(tavolo)
	tabellone = MeshInstance3D.new()
	add_child(tabellone)

# ------------------------------------------------------------------ circuito

func mondo_da(p: Vector2) -> Vector3:
	return Vector3((p.x - pista.img.x * 0.5) * SCALA, 0, (p.y - pista.img.y * 0.5) * SCALA)

func pos_casella(cid: String) -> Vector3:
	return mondo_da(pista.pos(cid))

func carica_pista(p: Pista) -> void:
	if mappa != null:
		mostra_mappa(false)
	pista = p
	for k in auto:
		auto[k].queue_free()
	auto.clear()
	auto_casella.clear()
	togli_opzioni()
	for k in danni:
		for n in danni[k]:
			n.queue_free()
	danni.clear()
	var pm := PlaneMesh.new()
	pm.size = p.img * SCALA
	tabellone.mesh = pm
	var m := StandardMaterial3D.new()
	var bytes := FileAccess.get_file_as_bytes("res://assets/piste/%s.jpg" % p.id)
	var im := Image.new()
	if bytes.size() > 0 and im.load_jpg_from_buffer(bytes) == OK:
		im.generate_mipmaps()
		m.albedo_texture = ImageTexture.create_from_image(im)
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	tabellone.material_override = m
	vista_generale(true)

func vista_generale(subito := false) -> void:
	_bersaglio_t = Vector3(0, 0, 0.4)
	_distanza_t = max(pista.img.x * SCALA * 0.95, pista.img.y * SCALA * 1.45)
	if subito:
		bersaglio = _bersaglio_t
		distanza = _distanza_t
		imbardata = 0.0
		inclinazione = 1.05

## Inquadra un gruppo di caselle (l'auto che muove e dove può arrivare).
func inquadra(caselle: Array, margine := 2.2, comunque := false) -> void:
	if caselle.is_empty() or (not segui and not comunque):
		return
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for cid in caselle:
		var p := pos_casella(cid)
		lo.x = min(lo.x, p.x)
		lo.z = min(lo.z, p.z)
		hi.x = max(hi.x, p.x)
		hi.z = max(hi.z, p.z)
	_bersaglio_t = (lo + hi) * 0.5
	var ampiezza: float = max(hi.x - lo.x, (hi.z - lo.z) * 1.5)
	_distanza_t = clamp(ampiezza * 1.25 + margine * 2.0, 5.0, 26.0)

# ------------------------------------------------------------------ auto

func _angolo(cid: String) -> float:
	var c = pista.per_id.get(cid)
	return deg_to_rad(90.0 - (c.r if c else 0.0))

func metti_auto(i: int, pilota: int, nome: String, cid: String) -> void:
	if not auto.has(i):
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = load("res://assets/modelli/Formula1Solid.obj")
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/modelli/Formula1Solid.jpg")
		m.albedo_color = Dati.colore_auto(pilota).lightened(0.25)
		m.roughness = 0.45
		m.metallic = 0.2
		mi.material_override = m
		mi.scale = Vector3.ONE * 0.52
		mi.position.y = 0.05
		mi.name = "modello"
		n.add_child(mi)
		var l := Label3D.new()
		l.text = nome.split(" ")[0]
		l.font = font
		l.font_size = 40
		l.pixel_size = 0.0035
		l.outline_size = 14
		l.modulate = Dati.colore_auto(pilota).lightened(0.35)
		l.outline_modulate = Color(0, 0, 0, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.position.y = 0.42
		l.name = "nome"
		n.add_child(l)
		add_child(n)
		auto[i] = n
	var n: Node3D = auto[i]
	if cid == "":
		n.visible = false
	else:
		n.visible = true
		n.position = pos_casella(cid)
		n.rotation = Vector3(0, _angolo(cid), 0)
		n.scale = Vector3.ONE
	auto_casella[i] = cid

func muovi_auto(i: int, percorso: Array) -> void:
	if not auto.has(i) or percorso.size() < 2:
		return
	var n: Node3D = auto[i]
	n.visible = true
	var passo: float = clamp(1.4 / percorso.size(), 0.05, 0.16) / velocita
	var tw := create_tween()
	# il muso va dove va l'auto: la direzione è quella del tratto percorso, non quella scritta sulla casella
	# (così nessuna giravolta), e girando si prende sempre il verso più corto
	var ang_ora: float = n.rotation.y
	for k in range(1, percorso.size()):
		var p := pos_casella(percorso[k])
		var ang := _verso(pos_casella(percorso[k - 1]), p, _angolo(percorso[k]))
		ang = ang_ora + wrapf(ang - ang_ora, -PI, PI)
		ang_ora = ang
		tw.tween_property(n, "position", p, passo)
		tw.parallel().tween_property(n, "rotation:y", ang, passo)
	# all'arrivo si allinea alla casella, se non è troppo diversa dal verso di marcia
	var fine := _angolo(percorso[-1])
	if absf(wrapf(fine - ang_ora, -PI, PI)) < PI * 0.5:
		tw.tween_property(n, "rotation:y", ang_ora + wrapf(fine - ang_ora, -PI, PI), passo)
	auto_casella[i] = percorso[-1]
	await tw.finished

## L'angolo del tratto da a a b (se le due caselle coincidono, quello di riserva).
func _verso(a: Vector3, b: Vector3, riserva: float) -> float:
	var d := b - a
	if Vector2(d.x, d.z).length() < 0.01:
		return riserva
	return atan2(d.x, d.z)

func testacoda(i: int) -> void:
	if not auto.has(i):
		return
	var n: Node3D = auto[i]
	var tw := create_tween()
	# due giri interi: l'auto finisce con il muso in avanti
	tw.tween_property(n, "rotation:y", n.rotation.y + TAU * 2.0, 0.8 / velocita).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

func elimina_auto(i: int) -> void:
	if not auto.has(i):
		return
	var n: Node3D = auto[i]
	var tw := create_tween()
	tw.tween_property(n, "rotation:y", n.rotation.y + PI * 2.5, 0.6 / velocita)
	tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.05, 0.6 / velocita).set_delay(0.3 / velocita)
	await tw.finished
	n.visible = false
	auto_casella[i] = ""

func arriva_auto(i: int) -> void:
	if not auto.has(i):
		return
	var n: Node3D = auto[i]
	var tw := create_tween()
	tw.tween_property(n, "position:y", 0.8, 0.35 / velocita)
	tw.tween_property(n, "scale", Vector3.ONE * 0.05, 0.25 / velocita)
	await tw.finished
	n.visible = false
	auto_casella[i] = ""

func evidenzia_auto(i: int) -> void:
	for k in auto:
		var l: Label3D = auto[k].get_node("nome")
		l.font_size = 46 if k == i else 40
		l.outline_modulate = Color(0.9, 0.05, 0.05, 1) if k == i else Color(0, 0, 0, 0.9)

# ------------------------------------------------------------------ segnalini e dadi

func metti_danno(cid: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://assets/modelli/DamageMarker.obj")
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/modelli/DamageMarker.jpg")
	mi.material_override = m
	mi.scale = Vector3.ONE * 0.2
	var n: int = danni.get(cid, []).size()
	mi.position = pos_casella(cid) + Vector3(0, 0.02 + 0.03 * n, 0)
	mi.rotation.y = _angolo(cid) + PI * 0.5 + n * 0.5
	add_child(mi)
	if not danni.has(cid):
		danni[cid] = []
	danni[cid].append(mi)

func sincronizza_danni(lista: Array) -> void:
	var conta := {}
	for cid in lista:
		conta[cid] = int(conta.get(cid, 0)) + 1
	for cid in danni.keys():
		while danni[cid].size() > int(conta.get(cid, 0)):
			danni[cid].pop_back().queue_free()
	for cid in conta:
		while danni.get(cid, []).size() < conta[cid]:
			metti_danno(cid)

# ------------------------------------------------------------------ opzioni di mossa

func _materiale(col: Color, alfa := 0.82) -> StandardMaterial3D:
	var chiave := Color(col.r, col.g, col.b, alfa)
	if not _mat_segno.has(chiave):
		var m := StandardMaterial3D.new()
		m.albedo_color = chiave
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.render_priority = 2
		_mat_segno[chiave] = m
	return _mat_segno[chiave]

static func colore_opzione(o: Dictionary) -> Color:
	if str(o.get("fu", "")) != "":
		return COL_FUORI
	if o.get("fi", false):
		return COL_ARRIVO
	if o.get("bx", false):
		return COL_BOX
	if o.get("te", false):
		return COL_TESTA
	if not o.get("u", {}).is_empty():
		return COL_COSTO
	return COL_LIBERA

const COL_EXTRA := Color(0.25, 0.9, 1.0)   # bordo delle caselle in più facoltative (scia, Nitro, gomme morbide)
const NOMI_CORTI := {"ps": "PS", "gomme": "Gomme", "freni": "Freni", "cambio": "Cambio", "carrozzeria": "Carrozz.",
	"motore": "Motore", "tenuta": "Tenuta"}

## Le scritte su una casella: che cosa costa e se usa caselle in più. Ogni riga [testo, colore].
static func righe_opzione(o: Dictionary) -> Array:
	var r := []
	var ni := int(o.get("ni", 0))
	var pi := int(o.get("pi", 0)) - ni
	if ni > 0:
		r.append(["NITRO +%d" % ni, COL_EXTRA])
	if pi > 0:
		r.append(["MORBIDE +%d" % pi, COL_EXTRA])
	if int(o.get("sc", 0)) > 0:
		r.append(["SCIA" if int(o.sc) == 1 else "SCIA x%d" % int(o.sc), COL_EXTRA])
	if int(o.get("jk", 0)) != 0:
		r.append(["DERAPATA", COL_EXTRA])
	if str(o.get("fu", "")) != "":
		r.append(["RITIRO", Color(1, 0.35, 0.3)])
	elif o.get("te", false):
		r.append(["TESTACODA", Color(1, 0.65, 0.2)])
	if o.get("bx", false):
		r.append(["BOX", Color(0.45, 0.8, 1)])
	if o.get("fi", false):
		r.append(["ARRIVO", Color.WHITE])
	if str(o.get("fu", "")) == "":
		for k in Dati.zone_ids() + ["ps"]:
			var n := int(o.get("u", {}).get(k, 0))
			if n > 0:
				r.append(["%s -%d" % [NOMI_CORTI[k], n], Dati.COLORI_ZONE[k].lerp(Color.WHITE, 0.45)])
	return r

static func opzione_extra(o: Dictionary) -> bool:
	return int(o.get("pi", 0)) > 0 or int(o.get("sc", 0)) > 0 or int(o.get("jk", 0)) != 0

## lista: le opzioni come nella vista ({c, x, y, u, fu, te, bx, fi, ...}): ogni casella raggiungibile si colora
## per intero, con scritto sopra che cosa costa; un bordo azzurro segna le caselle in più facoltative.
func mostra_opzioni(lista: Array, da: String, inquadrale := true) -> void:
	togli_opzioni()
	_ultime = [lista, da]
	var lungo: float = pista.cella * SCALA * 0.92
	var largo: float = pista.largo_cella * SCALA * 0.9
	var punti := [da] if da != "" else []
	for o in lista:
		var cid: String = o.c
		opzioni[cid] = o
		var radice := Node3D.new()
		radice.position = pos_casella(cid) + Vector3(0, 0.03, 0)
		var c = pista.per_id.get(cid)
		radice.rotation.y = -deg_to_rad(c.r if c else 0.0)
		add_child(radice)
		var extra := opzione_extra(o)
		# riempimento tenue e bordo sottile (azzurro e più spesso per le caselle in più)
		var dentro := MeshInstance3D.new()
		var pd := PlaneMesh.new()
		pd.size = Vector2(lungo, largo)
		dentro.mesh = pd
		dentro.material_override = _materiale(colore_opzione(o), 0.4)
		radice.add_child(dentro)
		radice.add_child(_cornice(lungo, largo, 0.03 if extra else 0.012, _col_bordo(o)))
		if cid == da:
			radice.scale = Vector3(0.6, 1, 0.6)
		segni[cid] = radice
		if cid != da:
			var nodi := _scritte_icone(o) if scritte_icone else _scritte_testo(o)
			for n in nodi:
				n.position = radice.position + Vector3(0, 0.01, 0)
				add_child(n)
			radice.set_meta("righe", nodi)
		punti.append(cid)
	if not lista.is_empty() and inquadrale:
		inquadra(punti)

var _ultime: Array = []

## Passa dalle icone alle parole (o viceversa) e ridisegna le caselle già mostrate.
func cambia_scritte() -> void:
	scritte_icone = not scritte_icone
	if _ultime.is_empty() or segni.is_empty():
		return
	var sel := scelta
	mostra_opzioni(_ultime[0], _ultime[1], false)
	if sel != "":
		segna_scelta(sel)

var scritte_icone := true      # sulle caselle: icone delle zone con il numero, oppure le parole
var _icone := {}

static func _col_bordo(o: Dictionary) -> Color:
	return COL_EXTRA if opzione_extra(o) else Color(0.05, 0.05, 0.08)

## Il bordo di una casella: quattro listelli sottili.
func _cornice(L: float, W: float, w: float, col: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "bordo"
	for k in 4:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var lungo_x := k < 2
		pm.size = Vector2(L, w) if lungo_x else Vector2(w, W)
		mi.mesh = pm
		mi.position = Vector3(0, 0.003, (W - w) * 0.5 * (1 if k == 0 else -1)) if lungo_x else Vector3((L - w) * 0.5 * (1 if k == 2 else -1), 0.003, 0)
		mi.material_override = _materiale(col, 0.75 if col != COL_EXTRA else 0.95)
		n.add_child(mi)
	return n

func _etichetta(t: String, col: Color, fs := 40) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = font
	l.font_size = fs
	l.pixel_size = 0.002
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 4
	l.outline_render_priority = 3
	return l

func _scritte_testo(o: Dictionary) -> Array:
	var righe := righe_opzione(o)
	var out := []
	for k in righe.size():
		var l := _etichetta(righe[k][0], righe[k][1])
		l.offset = Vector2(0, (righe.size() - 1) * 21.0 - k * 42.0)
		out.append(l)
	return out

## Icone delle zone con il numero dei punti persi, in fila; sopra, in piccolo, le caselle in più e gli esiti.
func _scritte_icone(o: Dictionary) -> Array:
	var out := []
	var testi := []
	var costi := []
	for r in righe_opzione(o):
		testi.append(r)
	# separa i costi delle zone (ultime righe) dagli altri testi
	if str(o.get("fu", "")) == "":
		for k in Dati.zone_ids() + ["ps"]:
			var n := int(o.get("u", {}).get(k, 0))
			if n > 0:
				costi.append([k, n])
				testi.pop_back()
	const PX_ICONA := 0.0013
	const LARGO_ICONA := 96 * 0.0013
	const PASSO := 0.19
	var x0 := -(costi.size() - 1) * PASSO * 0.5
	for j in costi.size():
		var k: String = costi[j][0]
		if not _icone.has(k):
			_icone[k] = load("res://assets/img/zone/%s.png" % k)
		var sp := Sprite3D.new()
		sp.texture = _icone[k]
		sp.pixel_size = PX_ICONA
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.render_priority = 4
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sp.offset = Vector2((x0 + j * PASSO - 0.03) / PX_ICONA, 0)
		out.append(sp)
		var l := _etichetta(str(costi[j][1]), Color.WHITE, 44)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.offset = Vector2((x0 + j * PASSO - 0.03 + LARGO_ICONA * 0.5 + 0.006) / 0.002, 0)
		out.append(l)
	for k in testi.size():
		var l := _etichetta(str(testi[k][0]), testi[k][1], 32)
		l.offset = Vector2(0, (LARGO_ICONA * 0.5 + 0.02) / 0.002 + k * 34.0 if not costi.is_empty() else (testi.size() - 1) * 17.0 - k * 34.0)
		out.append(l)
	return out

func togli_opzioni() -> void:
	for k in segni:
		for l in segni[k].get_meta("righe", []):
			l.queue_free()
		segni[k].queue_free()
	segni.clear()
	opzioni.clear()
	scelta = ""

func segna_scelta(cid: String) -> void:
	if scelta != "" and segni.has(scelta):
		segni[scelta].scale = Vector3.ONE
		var col0 := _col_bordo(opzioni.get(scelta, {}))
		for mi in segni[scelta].get_node("bordo").get_children():
			mi.material_override = _materiale(col0, 0.75 if col0 != COL_EXTRA else 0.95)
			mi.scale = Vector3.ONE
	scelta = cid
	if segni.has(cid):
		segni[cid].scale = Vector3(1.08, 1, 1.08)
		for mi in segni[cid].get_node("bordo").get_children():
			mi.material_override = _materiale(Color.WHITE, 1.0)
			mi.scale = Vector3(1, 1, 2.5) if mi.mesh.size.y < mi.mesh.size.x else Vector3(2.5, 1, 1)

# ------------------------------------------------------------------ visuale: mouse e dita

func _process(d: float) -> void:
	_due_dita()
	var k: float = min(1.0, d * 5.0)
	bersaglio = bersaglio.lerp(_bersaglio_t, k)
	distanza = lerp(distanza, _distanza_t, k)
	var dir := Vector3(sin(imbardata) * cos(inclinazione), sin(inclinazione), cos(imbardata) * cos(inclinazione))
	cam.position = bersaglio + dir * distanza
	cam.look_at(bersaglio, Vector3.UP)
	var vis := get_viewport().get_visible_rect().size
	var largo: float = 2.0 * distanza * tan(deg_to_rad(cam.fov) * 0.5) * vis.x / max(vis.y, 1.0)
	var margine := 0.0
	if pannelli != null and pannelli.visible and pannelli.col_dx != null:
		margine = Interfaccia.LARG_DX + 20.0
	cam.h_offset = largo * margine / max(vis.x, 1.0) * 0.5
	# le scritte sulle caselle solo quando le caselle sono abbastanza grandi da leggerle
	if pista != null and not segni.is_empty():
		var px_cella: float = pista.cella * SCALA * vis.y / (2.0 * distanza * tan(deg_to_rad(cam.fov) * 0.5))
		var mostra := px_cella >= (40.0 if scritte_icone else 55.0)
		for cid in segni:
			for l in segni[cid].get_meta("righe", []):
				l.visible = mostra or cid == scelta

## Gesti con due dita (iPad): pizzico = avvicina/allontana, dita che girano = ruota il tabellone,
## dita che scorrono insieme in verticale = inclina, in orizzontale = ruota.
func _due_dita() -> void:
	if _tocchi.size() < 2:
		return
	var ids := _tocchi.keys()
	var a1: Vector2 = _tocchi[ids[0]]
	var b1: Vector2 = _tocchi[ids[1]]
	if _prec_due.size() == 2:
		var a0: Vector2 = _prec_due[0]
		var b0: Vector2 = _prec_due[1]
		var d0 := a0.distance_to(b0)
		var d1 := a1.distance_to(b1)
		var centro := (a1 + b1) * 0.5 - (a0 + b0) * 0.5
		var ang := wrapf((a1 - b1).angle() - (a0 - b0).angle(), -PI, PI)
		if d0 > 20 and d1 > 20:
			_zoom(d0 / d1)
			_ruota(-ang, 0.0)
		# le due dita che si spostano insieme
		if centro.length() > 0.5 and abs(d1 - d0) < centro.length() * 0.7 and abs(ang) < 0.02:
			if abs(centro.y) > abs(centro.x):
				_ruota(0.0, centro.y * 0.005)
			else:
				_ruota(-centro.x * 0.005, 0.0)
	_prec_due = [a1, b1]

func _sposta(rel: Vector2) -> void:
	var alt: float = get_viewport().get_visible_rect().size.y
	var f := distanza * 0.85 / alt
	var destra := Vector3(cos(imbardata), 0, -sin(imbardata))
	var avanti := Vector3(sin(imbardata), 0, cos(imbardata))
	_bersaglio_t += (-destra * rel.x - avanti * rel.y) * f / max(0.45, sin(inclinazione))
	var lim := Vector2(pista.img.x, pista.img.y) * SCALA * 0.6 if pista else Vector2(15, 10)
	_bersaglio_t.x = clamp(_bersaglio_t.x, -lim.x, lim.x)
	_bersaglio_t.z = clamp(_bersaglio_t.z, -lim.y, lim.y)
	bersaglio = _bersaglio_t

func _zoom(fattore: float) -> void:
	_distanza_t = clamp(_distanza_t * fattore, 2.5, 45.0)

func _ruota(dy: float, dp: float) -> void:
	imbardata += dy
	inclinazione = clamp(inclinazione + dp, 0.35, 1.55)

func gira(angolo: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "imbardata", imbardata + angolo, 0.3)

## Passa tra vista dall'alto, inclinata e radente.
func inclina() -> void:
	var prossima := 1.5
	if inclinazione > 1.3:
		prossima = 1.05
	elif inclinazione > 0.8:
		prossima = 0.6
	var tw := create_tween()
	tw.tween_property(self, "inclinazione", prossima, 0.3)

func _tocco(p: Vector2) -> void:
	if cam == null or (opzioni.is_empty() and mappa == null):
		return
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if abs(d.y) < 0.0001:
		return
	var t := -o.y / d.y
	if t < 0:
		return
	var q := o + d * t
	var best := ""
	var bd := 0.3
	for cid in opzioni:
		var dd := pos_casella(cid).distance_to(q)
		if dd < bd:
			bd = dd
			best = cid
	if best != "":
		casella_toccata.emit(best)
		return
	if mappa != null:
		for c in pista.caselle:
			var dd := pos_casella(c.id).distance_to(q)
			if dd < bd:
				bd = dd
				best = c.id
		if best != "":
			segna_mappa(best)
			casella_mappa.emit(best)

func _unhandled_input(ev: InputEvent) -> void:
	if pista == null:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if sopra_ui.is_valid() and sopra_ui.call(ev.position):
				return
			_tocchi[ev.index] = ev.position
			if _tocchi.size() == 1:
				_mosso = false
				_premuto_in = ev.position
			else:
				_mosso = true
				_prec_due = []
		else:
			if _tocchi.size() == 1 and not _mosso and _tocchi.has(ev.index):
				_tocco(ev.position)
			_tocchi.erase(ev.index)
			_prec_due = []
	elif ev is InputEventScreenDrag:
		if not _tocchi.has(ev.index):
			return
		if _tocchi.size() == 1:
			if ev.position.distance_to(_premuto_in) > 14:
				_mosso = true
			if _mosso:
				_sposta(ev.relative)
			_tocchi[ev.index] = ev.position
		else:
			# due dita: se ne occupa _due_dita() a ogni fotogramma, guardando tutte e due insieme
			_tocchi[ev.index] = ev.position
	elif ev is InputEventMouseButton:
		if ev.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)
		elif ev.pressed:
			if sopra_ui.is_valid() and sopra_ui.call(ev.position):
				return
			_tasto = ev.button_index
			_mosso = false
			_premuto_in = ev.position
		else:
			if ev.button_index == MOUSE_BUTTON_LEFT and not _mosso and _tasto == MOUSE_BUTTON_LEFT:
				_tocco(ev.position)
			_tasto = 0
	elif ev is InputEventMouseMotion:
		if ev.device == InputEvent.DEVICE_ID_EMULATION or _tasto == 0:
			return
		if ev.position.distance_to(_premuto_in) > 6:
			_mosso = true
		if not _mosso:
			return
		if _tasto == MOUSE_BUTTON_LEFT:
			_sposta(ev.relative)
		else:
			_ruota(-ev.relative.x * 0.006, ev.relative.y * 0.005)
	elif ev is InputEventMagnifyGesture:
		_zoom(1.0 / ev.factor)
	elif ev is InputEventPanGesture:
		_sposta(-ev.delta * 12.0)

# ------------------------------------------------------------------ replay

var replay_attivo := false
var replay_tempo := 1.0       # secondi per turno
var replay_turno := 0
var _replay_stop := false

## Rivede tutta la gara: in ogni turno tutte le auto si muovono insieme, ognuna alla sua velocità
## (chi fa più caselle va più svelta), e un turno scorre nell'altro senza fermarsi.
## `auto` è la lista delle auto [{i, p, n}].
func replay(storia: Dictionary, lista: Array) -> void:
	replay_attivo = true
	_replay_stop = false
	togli_opzioni()
	# per ogni auto: in ogni turno il percorso fatto (le caselle) e il turno in cui lascia la pista
	var turni := {}
	var esce := {}
	var ultimo := 1
	for v in storia.mosse:
		var i := int(v.a)
		var tr := int(v.tr)
		ultimo = max(ultimo, tr)
		if v.has("x"):
			esce[i] = tr
			continue
		if not turni.has(i):
			turni[i] = {}
		var p: Array = turni[i].get(tr, [])
		for cid in v.p:
			if p.is_empty() or p[-1] != cid:
				p.append(cid)
		turni[i][tr] = p
	for a in lista:
		var i := int(a.i)
		metti_auto(i, int(a.p), str(a.n), str(storia.via.get(str(i), "")))
	var fatto := {}          # caselle percorse da ogni auto (per sapere chi è in testa)
	var t := 1.0
	while t < ultimo + 1.0 and not _replay_stop:
		var d := get_process_delta_time()
		t += d / replay_tempo
		replay_turno = min(int(t), ultimo)
		var k := int(t)
		var f := t - k
		var testa := -1
		var testa_n := -1.0
		for a in lista:
			var i := int(a.i)
			if not auto.has(i):
				continue
			var n: Node3D = auto[i]
			if esce.has(i) and k > int(esce[i]):
				n.visible = false
				continue
			# il percorso del turno in corso, oppure resta dov'è
			var p: Array = turni.get(i, {}).get(k, [])
			var prima := 0
			for kk in turni.get(i, {}):
				if int(kk) < k:
					prima += turni[i][kk].size() - 1
			if p.size() >= 2:
				var x: float = f * (p.size() - 1)
				var j: int = min(int(x), p.size() - 2)
				var u: float = x - j
				var a0 := pos_casella(p[j])
				var a1 := pos_casella(p[j + 1])
				n.position = a0.lerp(a1, u)
				n.rotation.y = lerp_angle(n.rotation.y, _verso(a0, a1, _angolo(p[j + 1])), clamp(d * 12.0, 0.0, 1.0))
				fatto[i] = prima + x
			else:
				# fermo: l'ultima casella raggiunta
				var cid := str(storia.via.get(str(i), ""))
				var ul := -1
				for kk in turni.get(i, {}):
					if int(kk) < k and int(kk) > ul:
						ul = int(kk)
				if ul >= 0:
					cid = turni[i][ul][-1]
				if cid != "":
					n.position = pos_casella(cid)
					n.rotation.y = _angolo(cid)
				fatto[i] = prima
			n.visible = true
			n.scale = Vector3.ONE
			if float(fatto[i]) > testa_n:
				testa_n = fatto[i]
				testa = i
		if segui and testa >= 0:
			_bersaglio_t = auto[testa].position
			_distanza_t = 11.0
		await get_tree().process_frame
	replay_attivo = false

func ferma_replay() -> void:
	_replay_stop = true

# ------------------------------------------------------------------ mappatura delle caselle

var mappa: MeshInstance3D            # tutte le caselle con i loro collegamenti (per controllare i circuiti)
var _mappa_sigle: Array = []
const COL_CORSIA := {1: Color(0.2, 0.55, 1.0), 2: Color(0.15, 0.85, 0.3), 3: Color(1.0, 0.55, 0.1), 0: Color(0.85, 0.3, 0.9)}

## Accende o spegne la mappatura: ogni casella con il bordo del colore della sua corsia (blu a destra, verde al centro,
## arancio a sinistra, viola i box), linee bianche verso la casella davanti, rosse verso le corsie accanto.
func mostra_mappa(si: bool) -> void:
	if mappa != null:
		mappa.queue_free()
		mappa = null
	_togli_sigle()
	if not si or pista == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lungo: float = pista.cella * SCALA * 0.92
	var largo: float = pista.largo_cella * SCALA * 0.9
	var h := 0.035
	for c in pista.caselle:
		var p := pos_casella(c.id) + Vector3(0, h, 0)
		var a := -deg_to_rad(float(c.r))
		var ax := Vector3(cos(a), 0, -sin(a)) * lungo * 0.5
		var az := Vector3(sin(a), 0, cos(a)) * largo * 0.5
		var col: Color = COL_CORSIA.get(int(c.l), Color.WHITE)
		var k := [p - ax - az, p + ax - az, p + ax + az, p - ax + az]
		for j in 4:
			_segmento(st, k[j], k[(j + 1) % 4], 0.012, col)
		# freccette verso le caselle collegate
		for nid in c.get("n", []):
			var q := pos_casella(nid) + Vector3(0, h + 0.003, 0)
			var stessa: bool = pista.per_id[nid].l == c.l
			var cl := Color(1, 1, 1, 0.9) if stessa else Color(1, 0.2, 0.2, 0.95)
			var fine := p.lerp(q, 0.82)
			_segmento(st, p, fine, 0.008 if stessa else 0.01, cl)
			var dir := (q - p).normalized()
			var lat := dir.cross(Vector3.UP) * 0.035
			_triangolo(st, fine + dir * 0.06, fine + lat, fine - lat, cl)
		_quadratino(st, p, 0.035, col)
	mappa = MeshInstance3D.new()
	mappa.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	mappa.material_override = m
	add_child(mappa)

func _segmento(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var lat := (b - a).cross(Vector3.UP).normalized() * w
	_triangolo(st, a - lat, b - lat, b + lat, col)
	_triangolo(st, a - lat, b + lat, a + lat, col)

func _triangolo(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)

func _quadratino(st: SurfaceTool, p: Vector3, r: float, col: Color) -> void:
	_triangolo(st, p + Vector3(-r, 0, -r), p + Vector3(r, 0, -r), p + Vector3(r, 0, r), col)
	_triangolo(st, p + Vector3(-r, 0, -r), p + Vector3(r, 0, r), p + Vector3(-r, 0, r), col)

func _togli_sigle() -> void:
	for l in _mappa_sigle:
		l.queue_free()
	_mappa_sigle.clear()

## Scrive la sigla della casella toccata e di quelle dove porta.
func segna_mappa(cid: String) -> void:
	_togli_sigle()
	var lista: Array = [cid] + Array(pista.per_id[cid].get("n", []))
	for k in lista.size():
		var l := Label3D.new()
		l.text = str(lista[k])
		l.font = font
		l.font_size = 40
		l.pixel_size = 0.003
		l.modulate = Color(1, 1, 0.3) if k == 0 else Color.WHITE
		l.outline_size = 12
		l.outline_modulate = Color.BLACK
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 5
		l.outline_render_priority = 4
		l.position = pos_casella(lista[k]) + Vector3(0, 0.08, 0)
		add_child(l)
		_mappa_sigle.append(l)

# ------------------------------------------------------------------ effetti: polvere, urti, esplosioni

var _mat_fx := {}

func _mat_particelle(col: Color, emette := false) -> StandardMaterial3D:
	var k := str(col) + str(emette)
	if not _mat_fx.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_color = col
		if emette:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# una macchiolina tonda e sfumata
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.8))
		gt.gradient = g
		m.albedo_texture = gt
		_mat_fx[k] = m
	return _mat_fx[k]

## Una nuvoletta di particelle che parte da p e si spegne da sola.
func _nuvola(p: Vector3, quante: int, col_a: Color, col_b: Color, raggio: float, vel: float, durata: float,
		dir := Vector3.UP, apertura := 60.0, grande := 0.08, fuoco := false) -> void:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.explosiveness = 0.9
	cp.amount = quante
	cp.lifetime = durata
	cp.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(grande, grande)
	cp.mesh = q
	cp.material_override = _mat_particelle(Color.WHITE, fuoco)
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = raggio
	cp.direction = dir
	cp.spread = apertura
	cp.gravity = Vector3(0, -0.6, 0)
	cp.initial_velocity_min = vel * 0.5
	cp.initial_velocity_max = vel
	cp.damping_min = vel * 1.2
	cp.damping_max = vel * 2.0
	cp.scale_amount_min = 0.6
	cp.scale_amount_max = 1.6
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.5))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1, 1.6))
	cp.scale_amount_curve = curva
	var g := Gradient.new()
	g.set_color(0, col_a)
	g.set_color(1, Color(col_b.r, col_b.g, col_b.b, 0.0))
	cp.color_ramp = g
	cp.position = p
	add_child(cp)
	cp.emitting = true
	get_tree().create_timer(durata + 0.3).timeout.connect(cp.queue_free)

## Sbuffo di polvere dietro l'auto che ha consumato gomme, freni o altro.
func sbuffo(i: int) -> void:
	if not auto.has(i) or not auto[i].visible:
		return
	var n: Node3D = auto[i]
	var dietro := -Vector3(sin(n.rotation.y), 0, cos(n.rotation.y))
	_nuvola(n.position + dietro * 0.3 + Vector3(0, 0.08, 0), 24, Color(0.92, 0.88, 0.8, 0.95), Color(0.7, 0.65, 0.6),
		0.06, 1.0, 1.0 / velocita, dietro + Vector3(0, 0.5, 0), 40.0, 0.2)

## Due auto si toccano: si avvicinano di colpo, rimbalzano, scintille in mezzo.
func urto(i: int, j: int, colpo: bool) -> void:
	if not auto.has(i) or not auto.has(j):
		return
	var a: Node3D = auto[i]
	var b: Node3D = auto[j]
	var pa := a.position
	var pb := b.position
	var verso := (pb - pa)
	verso.y = 0
	var d := verso.length()
	verso = verso.normalized() if d > 0.001 else Vector3.RIGHT
	var spinta: float = min(d * 0.3, 0.12)
	var t := 0.12 / velocita
	var tw := create_tween()
	tw.tween_property(a, "position", pa + verso * spinta, t).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "position", pb - verso * spinta * 0.5, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var mezzo := (a.position + b.position) * 0.5 + Vector3(0, 0.1, 0)
		_nuvola(mezzo, 30 if colpo else 16, Color(1, 1, 0.7, 1), Color(1, 0.45, 0.05), 0.03, 2.2, 0.5 / velocita,
			Vector3.UP, 100.0, 0.1, true))
	tw.tween_property(a, "position", pa - verso * spinta * 0.3, t * 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "position", pb + verso * spinta * 0.3, t * 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(a, "position", pa, t)
	tw.parallel().tween_property(b, "position", pb, t)
	if colpo:
		tw.parallel().tween_property(a, "rotation:z", 0.25, t * 0.5)
		tw.tween_property(a, "rotation:z", 0.0, t)
	await tw.finished

## Esplosione sulla casella del ritiro: lampo, fuoco e fumo.
func esplosione(cid: String) -> void:
	if cid == "" or pista == null or not pista.per_id.has(cid):
		return
	var p := pos_casella(cid) + Vector3(0, 0.08, 0)
	var luce := OmniLight3D.new()
	luce.light_color = Color(1, 0.6, 0.2)
	luce.light_energy = 6.0
	luce.omni_range = 2.5
	luce.position = p + Vector3(0, 0.4, 0)
	add_child(luce)
	var tw := create_tween()
	tw.tween_property(luce, "light_energy", 0.0, 0.7 / velocita)
	tw.tween_callback(luce.queue_free)
	_nuvola(p, 45, Color(1, 0.95, 0.6, 1), Color(1, 0.3, 0.05), 0.05, 2.2, 0.6 / velocita, Vector3.UP, 180.0, 0.18, true)
	_nuvola(p + Vector3(0, 0.12, 0), 14, Color(0.35, 0.32, 0.3, 0.6), Color(0.2, 0.2, 0.2), 0.08, 0.9, 1.6 / velocita,
		Vector3.UP, 20.0, 0.22)
