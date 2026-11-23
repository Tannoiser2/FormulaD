class_name UI
extends RefCounted
## Stile dell'interfaccia: carbonio scuro, rosso corsa, titoli in Racing Sans One, testi in Barlow Condensed.

const ROSSO := Color(0.88, 0.1, 0.12)
const GIALLO := Color(1.0, 0.82, 0.1)
const CHIARO := Color(0.94, 0.95, 0.97)
const GRIGIO := Color(0.62, 0.66, 0.72)
const FONDO := Color(0.07, 0.08, 0.11, 0.94)
const FONDO2 := Color(0.13, 0.15, 0.19, 1.0)

static var f_titolo: Font
static var f_testo: Font
static var f_medio: Font

static func prepara() -> void:
	if f_titolo == null:
		f_titolo = load("res://assets/font/RacingSansOne-Regular.ttf")
		f_testo = load("res://assets/font/BarlowCondensed-Bold.ttf")
		f_medio = load("res://assets/font/BarlowCondensed-Medium.ttf")

static func riquadro(col := FONDO, bordo := ROSSO, raggio := 14, spess := 2, margine := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = bordo
	s.set_border_width_all(spess)
	s.set_corner_radius_all(raggio)
	s.set_content_margin_all(margine)
	return s

static func pannello(col := FONDO, bordo := ROSSO, raggio := 14, spess := 2, margine := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", riquadro(col, bordo, raggio, spess, margine))
	return p

## Etichetta. larg > 0: va a capo dentro quella larghezza minima (mai testo in verticale).
static func testo(t: String, dim := 26, col := CHIARO, titolo := false, larg := 0.0) -> Label:
	prepara()
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f_titolo if titolo else f_testo)
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", col)
	if larg > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = larg
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func bottone(t: String, dim := 28, col := ROSSO, larg := 0.0, alt := 0.0) -> Button:
	prepara()
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", f_testo)
	b.add_theme_font_size_override("font_size", dim)
	for stato in ["normal", "hover", "pressed", "disabled"]:
		var c := col
		if stato == "hover":
			c = col.lightened(0.15)
		elif stato == "pressed":
			c = col.darkened(0.25)
		elif stato == "disabled":
			c = Color(0.25, 0.27, 0.3)
		var s := riquadro(c, c.lightened(0.35), 10, 2, 8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		b.add_theme_stylebox_override(stato, s)
	var chiaro := col.get_luminance() > 0.6
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(n, Color(0.08, 0.08, 0.1) if chiaro else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
	b.custom_minimum_size = Vector2(larg, alt)
	return b

## Cambia il colore di un bottone già fatto.
static func colora_bottone(b: Button, col: Color) -> void:
	for stato in ["normal", "hover", "pressed"]:
		var c := col
		if stato == "hover":
			c = col.lightened(0.15)
		elif stato == "pressed":
			c = col.darkened(0.25)
		var s := riquadro(c, c.lightened(0.35), 10, 2, 8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		b.add_theme_stylebox_override(stato, s)

static func riga(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func colonna(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func spazio(w := 0.0, h := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func molla() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func immagine(percorso: String, dim: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(percorso)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = dim
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func chip(col: Color, dim := Vector2(18, 30)) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(4)
	s.border_color = Color(0, 0, 0, 0.6)
	s.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = dim
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
