class_name Plancia
extends Control
## La plancia originale del pilota (cruscotto): i perni segnano i punti rimasti in ogni zona e la leva la marcia.
## Quando tocca a un giocatore, le marce che può innestare si illuminano: passandoci sopra si vedono le caselle
## sul tabellone, un clic innesta la marcia (con il dito: primo tocco anteprima, secondo conferma).

signal sopra(m: int)
signal scelta(m: int)

const COL_X := [0.96, 0.10, -0.77, -1.63, -2.49, -3.35, -4.21]
const ROW_Z := [-2.31, -1.55, -0.78, 0.00, 0.77, 1.55, 2.33]
const LEVA := [[2.48, -2.03], [4.23, -1.22], [2.47, -0.40], [4.20, 0.34], [2.45, 1.16], [4.20, 1.94]]
const PX := 82.3
const DIM := Vector2(823, 498)
const RIGHE := {"freni": 2, "cambio": 3, "carrozzeria": 4, "motore": 5, "tenuta": 6}

var regole := "base"
var pf := {}
var marcia := 0
var tex_base: Texture2D
var tex_av: Texture2D
var font: Font
var marce: Array = []      # le marce che si possono innestare: [{m, costo, fuori}]
var evidenziata := 0       # la marcia sotto il puntatore (o toccata una volta)

func _ready() -> void:
	tex_base = load("res://assets/img/plancia_base.webp")
	tex_av = load("res://assets/img/plancia_avanzata.webp")
	font = load("res://assets/font/BarlowCondensed-Bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Le marce da offrire (vuoto = nessuna scelta). `vista` è quella già evidenziata.
func offri(lista: Array, vista: int) -> void:
	marce = lista
	evidenziata = vista
	mouse_filter = Control.MOUSE_FILTER_STOP if not lista.is_empty() else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not lista.is_empty() else Control.CURSOR_ARROW
	queue_redraw()

func _scala() -> float:
	return min(size.x / DIM.x, size.y / DIM.y)

## Il centro dello slot della marcia m sulla plancia (in pixel del controllo).
func centro_marcia(m: int) -> Vector2:
	var g: Array = LEVA[m - 1] if regole == "avanzate" else LEVA[6 - m]
	return _punto(g[0], g[1]) * _scala()

func _marcia_in(p: Vector2) -> int:
	p -= _origine()
	var meglio := 0
	var d_m := 60.0 * _scala()
	for o in marce:
		var d := p.distance_to(centro_marcia(int(o.m)))
		if d < d_m:
			d_m = d
			meglio = int(o.m)
	return meglio

func _gui_input(e: InputEvent) -> void:
	if marce.is_empty():
		return
	if e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION:
		var m := _marcia_in(e.position)
		if m > 0 and m != evidenziata:
			evidenziata = m
			queue_redraw()
			sopra.emit(m)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var m := _marcia_in(e.position)
		if m <= 0:
			return
		accept_event()
		# con il dito il primo tocco mostra le caselle, il secondo sulla stessa marcia la innesta
		if e.device == InputEvent.DEVICE_ID_EMULATION and m != evidenziata:
			evidenziata = m
			queue_redraw()
			sopra.emit(m)
			return
		scelta.emit(m)

func imposta(r: String, punti: Dictionary, m: int) -> void:
	regole = r
	pf = punti
	marcia = m
	queue_redraw()

func _punto(x: float, z: float) -> Vector2:
	if regole == "avanzate":
		return Vector2((5.0 - x) * PX, (z + 3.03) * PX)
	return Vector2((5.0 - x) * PX, (3.03 - z) * PX)

## Un perno: `s` è la scala della plancia, `r` quanto è grande rispetto a un foro (la leva del cambio è più grossa).
func _perno(p: Vector2, s: float, col: Color, r := 1.0) -> void:
	var c := p * s
	var k := s * r
	draw_circle(c + Vector2(1.5, 2.5) * k, 21 * k, Color(0, 0, 0, 0.45))
	draw_circle(c, 21 * k, Color(0.12, 0.12, 0.14))
	draw_circle(c, 17.5 * k, col)
	draw_circle(c - Vector2(5, 5) * k, 6 * k, Color(1, 1, 1, 0.55))

## Dove comincia il disegno: la plancia sta centrata in orizzontale nello spazio che ha.
func _origine() -> Vector2:
	return Vector2(max(0.0, (size.x - DIM.x * _scala()) * 0.5), 0)

func _draw() -> void:
	draw_set_transform(_origine())
	var s: float = _scala()
	var tex := tex_av if regole == "avanzate" else tex_base
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(Vector2.ZERO, DIM * s), false)
	if regole == "avanzate":
		for zona in pf:
			var n := int(pf[zona])
			if n <= 0:
				continue
			var col: Color = Dati.COLORI_ZONE.get(zona, Color.WHITE).lightened(0.2)
			if zona == "gomme":
				n = min(n, 14)
				_perno(_punto(COL_X[(n - 1) % 7], ROW_Z[(n - 1) / 7]), s, col)
			elif RIGHE.has(zona):
				n = min(n, 7)
				_perno(_punto(COL_X[n - 1], ROW_Z[RIGHE[zona]]), s, col)
		if marcia >= 1:
			var g: Array = LEVA[marcia - 1]
			_perno(_punto(g[0], g[1]), s, Color(0.9, 0.1, 0.1), 1.45)
	else:
		var n: int = clamp(int(pf.get("ps", 0)), 0, 18)
		if n > 0:
			_perno(_punto(COL_X[(n - 1) % 3], ROW_Z[6 - (n - 1) / 3]), s, Color(0.9, 0.1, 0.1))
		if marcia >= 1:
			var g: Array = LEVA[6 - marcia]
			_perno(_punto(g[0], g[1]), s, Color(0.15, 0.15, 0.18), 1.45)
	# le marce che si possono innestare: anelli luminosi negli slot, più grande quella evidenziata
	for o in marce:
		var m := int(o.m)
		var c := centro_marcia(m)
		var col: Color = Dati.COLORI_MARCE[m].lightened(0.35)
		var su := m == evidenziata
		var r := (40.0 if su else 33.0) * s
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.38 if su else 0.2))
		draw_arc(c, r, 0, TAU, 40, Color.WHITE if su else col, (7.0 if su else 5.0) * s, true)
		# un cartellino sopra lo slot se scalare costa punti (o fa ritirare)
		var tot := 0
		for k in o.get("costo", {}):
			tot += int(o.costo[k])
		var testo := "RITIRO" if o.get("fuori", false) else ("-%d" % tot if tot > 0 else "")
		if testo != "" and font != null:
			var fs := int(30 * s)
			var w := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12 * s
			var box := Rect2(c + Vector2(-w * 0.5, -r - 30 * s), Vector2(w, 30 * s))
			draw_rect(box, Color(0.75, 0.05, 0.05) if o.get("fuori", false) else Color(0.1, 0.1, 0.12))
			draw_rect(box, Color(1, 0.85, 0.1), false, 2.0 * s)
			draw_string(font, box.position + Vector2(6 * s, 24 * s), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.88, 0.2))
