class_name Plancia
extends Control
## La plancia originale del pilota (cruscotto): i perni segnano i punti rimasti in ogni zona e la leva la marcia.

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

func _ready() -> void:
	tex_base = load("res://assets/img/plancia_base.webp")
	tex_av = load("res://assets/img/plancia_avanzata.webp")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func imposta(r: String, punti: Dictionary, m: int) -> void:
	regole = r
	pf = punti
	marcia = m
	queue_redraw()

func _punto(x: float, z: float) -> Vector2:
	if regole == "avanzate":
		return Vector2((5.0 - x) * PX, (z + 3.03) * PX)
	return Vector2((5.0 - x) * PX, (3.03 - z) * PX)

func _perno(p: Vector2, s: float, col: Color) -> void:
	var c := p * s
	draw_circle(c + Vector2(1.5, 2.5) * s, 17 * s, Color(0, 0, 0, 0.45))
	draw_circle(c, 17 * s, Color(0.12, 0.12, 0.14))
	draw_circle(c, 14 * s, col)
	draw_circle(c - Vector2(4, 4) * s, 5 * s, Color(1, 1, 1, 0.55))

func _draw() -> void:
	var s: float = min(size.x / DIM.x, size.y / DIM.y)
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
			_perno(_punto(g[0], g[1]), s * 1.25, Color(0.9, 0.1, 0.1))
	else:
		var n: int = clamp(int(pf.get("ps", 0)), 0, 18)
		if n > 0:
			_perno(_punto(COL_X[(n - 1) % 3], ROW_Z[6 - (n - 1) / 3]), s, Color(0.9, 0.1, 0.1))
		if marcia >= 1:
			var g: Array = LEVA[6 - marcia]
			_perno(_punto(g[0], g[1]), s * 1.25, Color(0.15, 0.15, 0.18))
