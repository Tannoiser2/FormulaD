class_name Mondo
extends Node3D
## Il tavolo in 3D: il tabellone originale, le auto del modulo, i dadi delle marce, i segnalini.
## La visuale si sposta, si avvicina e ruota con il mouse e con le dita (iPad).

signal casella_toccata(cid: String)

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
func inquadra(caselle: Array, margine := 2.2) -> void:
	if caselle.is_empty():
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
	for k in range(1, percorso.size()):
		var p := pos_casella(percorso[k])
		var ang := _angolo(percorso[k])
		var da := n.rotation.y if k == 1 else _angolo(percorso[k - 1])
		ang = da + wrapf(ang - da, -PI, PI)
		tw.tween_property(n, "position", p, passo)
		tw.parallel().tween_property(n, "rotation:y", ang, passo)
	auto_casella[i] = percorso[-1]
	await tw.finished

func testacoda(i: int) -> void:
	if not auto.has(i):
		return
	var n: Node3D = auto[i]
	var tw := create_tween()
	tw.tween_property(n, "rotation:y", n.rotation.y + PI * 3.0, 0.7 / velocita).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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

func _materiale(col: Color) -> StandardMaterial3D:
	if not _mat_segno.has(col):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, 0.82)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.render_priority = 2
		_mat_segno[col] = m
	return _mat_segno[col]

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

## lista: le opzioni come nella vista ({c, x, y, u, fu, te, bx, fi, ...}); toccabili: se si possono scegliere
func mostra_opzioni(lista: Array, da: String) -> void:
	togli_opzioni()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.15
	disco.bottom_radius = 0.15
	disco.height = 0.02
	disco.radial_segments = 20
	var punti := [da] if da != "" else []
	for o in lista:
		var cid: String = o.c
		opzioni[cid] = o
		var mi := MeshInstance3D.new()
		mi.mesh = disco
		mi.material_override = _materiale(colore_opzione(o))
		mi.position = pos_casella(cid) + Vector3(0, 0.03, 0)
		if cid == da:
			mi.scale = Vector3(0.7, 1, 0.7)
		add_child(mi)
		segni[cid] = mi
		var tot := 0
		for k in o.get("u", {}):
			tot += int(o.u[k])
		if tot > 0 and str(o.get("fu", "")) == "" and not o.get("fi", false):
			var l := Label3D.new()
			l.text = "-%d" % tot
			l.font = font
			l.font_size = 36
			l.pixel_size = 0.004
			l.modulate = Color(0.1, 0.05, 0)
			l.outline_size = 0
			l.rotation.x = -PI * 0.5
			l.position.y = 0.02
			l.no_depth_test = true
			l.render_priority = 3
			mi.add_child(l)
		punti.append(cid)
	if not lista.is_empty():
		inquadra(punti)

func togli_opzioni() -> void:
	for k in segni:
		segni[k].queue_free()
	segni.clear()
	opzioni.clear()
	scelta = ""

func segna_scelta(cid: String) -> void:
	if scelta != "" and segni.has(scelta):
		segni[scelta].scale = Vector3.ONE
	scelta = cid
	if segni.has(cid):
		segni[cid].scale = Vector3(1.6, 1, 1.6)

# ------------------------------------------------------------------ visuale: mouse e dita

func _process(d: float) -> void:
	_due_dita()
	var k: float = min(1.0, d * 5.0)
	bersaglio = bersaglio.lerp(_bersaglio_t, k)
	distanza = lerp(distanza, _distanza_t, k)
	var dir := Vector3(sin(imbardata) * cos(inclinazione), sin(inclinazione), cos(imbardata) * cos(inclinazione))
	cam.position = bersaglio + dir * distanza
	cam.look_at(bersaglio, Vector3.UP)

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
	if opzioni.is_empty() or cam == null:
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
