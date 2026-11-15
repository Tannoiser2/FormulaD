class_name Interfaccia
extends Control
## L'interfaccia della gara: classifica e ordine di gioco, cronaca, dadi, scelta della marcia e della
## casella, plancia originale del pilota. Si disegna dalla «vista» del motore, uguale per chi ospita e per gli ospiti.

signal decisione(az: Dictionary)
signal comando(cosa: String)

var v: Dictionary = {}
var miei: Array = []          # indici delle auto guidate da questo schermo
var ospite := false
var barra_titolo: Label
var barra_info: Label
var lista: VBoxContainer
var cronaca_box: VBoxContainer
var azione: VBoxContainer
var p_azione: PanelContainer
var p_plancia: PanelContainer
var plancia: Plancia
var plancia_nome: Label
var p_dado: PanelContainer
var dado_box: HBoxContainer
var p_sx: PanelContainer
var p_cron: PanelContainer
var barra: PanelContainer
var velo: Control
var opz_scelta: Dictionary = {}
var auto_plancia := -1
var _pannelli: Array = []

func _ready() -> void:
	UI.prepara()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# barra in alto
	barra = UI.pannello(UI.FONDO, UI.ROSSO, 0, 0, 8)
	barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	barra.custom_minimum_size.y = 64
	add_child(barra)
	var hb := UI.riga(18)
	barra.add_child(hb)
	hb.add_child(UI.spazio(6))
	var logo := UI.testo("FORMULA D", 40, UI.ROSSO, true)
	hb.add_child(logo)
	barra_titolo = UI.testo("", 30, UI.CHIARO, true)
	hb.add_child(barra_titolo)
	barra_info = UI.testo("", 26, UI.GIALLO)
	barra_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_info.clip_text = true
	hb.add_child(barra_info)
	for b in [["Gira a sinistra", "gira_sx"], ["Gira a destra", "gira_dx"], ["Inclina", "inclina"], ["Vista intera", "vista"],
			["Regole", "regole"], ["Menu", "menu"]]:
		var bt := UI.bottone(b[0], 22, UI.FONDO2, 96, 44)
		bt.pressed.connect(func(): comando.emit(b[1]))
		hb.add_child(bt)
	hb.add_child(UI.spazio(6))
	# classifica a sinistra
	p_sx = UI.pannello()
	p_sx.anchor_left = 0
	p_sx.anchor_top = 0
	p_sx.offset_left = 10
	p_sx.offset_top = 74
	p_sx.custom_minimum_size = Vector2(470, 0)
	add_child(p_sx)
	var vs := UI.colonna(4)
	p_sx.add_child(vs)
	vs.add_child(UI.testo("ORDINE DI GIOCO", 24, UI.GIALLO, true))
	lista = UI.colonna(3)
	vs.add_child(lista)
	# cronaca in basso a sinistra
	p_cron = UI.pannello(UI.FONDO, UI.FONDO2)
	p_cron.anchor_top = 1
	p_cron.anchor_bottom = 1
	p_cron.offset_left = 10
	p_cron.offset_bottom = -10
	p_cron.custom_minimum_size = Vector2(470, 0)
	p_cron.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p_cron)
	cronaca_box = UI.colonna(2)
	p_cron.add_child(cronaca_box)
	# azione in basso al centro
	p_azione = UI.pannello()
	p_azione.anchor_left = 0.5
	p_azione.anchor_right = 0.5
	p_azione.anchor_top = 1
	p_azione.anchor_bottom = 1
	p_azione.offset_bottom = -10
	p_azione.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p_azione.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p_azione.custom_minimum_size = Vector2(640, 0)
	add_child(p_azione)
	azione = UI.colonna(8)
	p_azione.add_child(azione)
	# plancia in basso a destra
	p_plancia = UI.pannello(UI.FONDO, UI.FONDO2, 14, 2, 8)
	p_plancia.anchor_left = 1
	p_plancia.anchor_right = 1
	p_plancia.anchor_top = 1
	p_plancia.anchor_bottom = 1
	p_plancia.offset_right = -10
	p_plancia.offset_bottom = -10
	p_plancia.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p_plancia.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p_plancia)
	var vp := UI.colonna(4)
	p_plancia.add_child(vp)
	plancia_nome = UI.testo("", 24, UI.CHIARO)
	vp.add_child(plancia_nome)
	plancia = Plancia.new()
	plancia.custom_minimum_size = Vector2(430, 260)
	vp.add_child(plancia)
	# dadi in alto a destra
	p_dado = UI.pannello(UI.FONDO, UI.FONDO2)
	p_dado.anchor_left = 1
	p_dado.anchor_right = 1
	p_dado.offset_right = -10
	p_dado.offset_top = 74
	p_dado.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p_dado)
	dado_box = UI.riga(12)
	p_dado.add_child(dado_box)
	p_dado.visible = false
	_pannelli = [barra, p_sx, p_cron, p_azione, p_plancia, p_dado]

## Vero se il punto è sopra un pannello: lì i tocchi non devono muovere il tabellone.
func sopra(p: Vector2) -> bool:
	if velo != null and is_instance_valid(velo):
		return true
	for c in _pannelli:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false

# ------------------------------------------------------------------ stato

func _mio(i: int) -> bool:
	return miei.has(i)

func aggiorna(vista: Dictionary, mie: Array) -> void:
	v = vista
	miei = mie
	var p := Pista.carica(v.pista)
	barra_titolo.text = p.nome.to_upper()
	var giro_max := 0
	for a in v.auto:
		giro_max = max(giro_max, int(a.g))
	barra_info.text = "%s  -  Turno %d  -  Giro %d di %d" % [Dati.NOMI_REGOLE[v.regole], int(v.turno), clamp(giro_max, 1, int(v.giri)), int(v.giri)]
	_classifica()
	# la plancia: quella dell'auto di turno se è mia, altrimenti la mia (o quella di turno)
	var chi := -1
	if v.att != null and _mio(int(v.att.auto)):
		chi = int(v.att.auto)
	elif not miei.is_empty():
		chi = miei[0] if not miei.has(auto_plancia) else auto_plancia
	elif v.att != null:
		chi = int(v.att.auto)
	if chi >= 0:
		mostra_plancia(chi)

func mostra_plancia(i: int) -> void:
	auto_plancia = i
	var a: Dictionary = v.auto[i]
	plancia_nome.text = "%s  -  %s%s" % [a.n, Dati.NOMI_MARCE[int(a.m)] if int(a.m) > 0 else "in griglia",
		"  -  ultimo tiro %d" % int(a.d) if int(a.d) > 0 else ""]
	plancia_nome.add_theme_color_override("font_color", Dati.colore_auto(int(a.p)).lightened(0.3))
	plancia.imposta(v.regole, a.pf, int(a.m))

func _classifica() -> void:
	for c in lista.get_children():
		c.queue_free()
	var in_ordine: Array = []
	for i in v.ordine:
		in_ordine.append(int(i))
	var di_turno := int(v.att.auto) if v.att != null else -1
	var riga_n := 0
	for i in in_ordine:
		var a: Dictionary = v.auto[i]
		riga_n += 1
		var sf := UI.FONDO2 if i != di_turno else Color(0.45, 0.08, 0.1)
		var pr := UI.pannello(sf, UI.GIALLO if i == di_turno else sf, 8, 2 if i == di_turno else 0, 4)
		var h := UI.riga(8)
		pr.add_child(h)
		var col := Dati.colore_auto(int(a.p))
		h.add_child(UI.chip(col, Vector2(14, 34)))
		var stato := ""
		if int(a.pa) > 0:
			stato = "%d° ARRIVATO" % int(a.pa)
		elif a.f:
			stato = "RITIRATO"
		var nome := UI.testo(str(a.n), 24, UI.CHIARO if stato == "" or int(a.pa) > 0 else UI.GRIGIO)
		nome.custom_minimum_size.x = 170
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.clip_text = true
		h.add_child(nome)
		if stato != "":
			var ls := UI.testo(stato, 22, UI.GIALLO if int(a.pa) > 0 else UI.ROSSO)
			h.add_child(ls)
		else:
			var m := int(a.m)
			var pm := UI.pannello(Dati.COLORI_MARCE[m], Color.BLACK, 6, 1, 2)
			pm.custom_minimum_size = Vector2(40, 30)
			var lm := UI.testo(Dati.NOMI_MARCE[m] if m > 0 else "-", 22, Color.WHITE if m != 1 else Color.BLACK)
			lm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pm.add_child(lm)
			h.add_child(pm)
			var lg := UI.testo("G%d" % max(1, int(a.g)), 22, UI.GRIGIO)
			lg.custom_minimum_size.x = 30
			h.add_child(lg)
			for z in Dati.zone(v.regole):
				var n := int(a.pf[z.id])
				var lz := UI.testo(str(max(0, n)), 22, Dati.COLORI_ZONE[z.id].lightened(0.35) if n > 1 else UI.ROSSO.lightened(0.2))
				lz.custom_minimum_size.x = 30 if v.regole == "base" else 17
				lz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				h.add_child(lz)
			if a.mo:
				h.add_child(UI.testo("ok", 20, UI.GRIGIO))
		var i_auto: int = i
		pr.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				mostra_plancia(i_auto)
				comando.emit("guarda:%d" % i_auto))
		lista.add_child(pr)
	if v.regole == "avanzate":
		var leg := UI.testo("Numeri: Gomme, Freni, Cambio, Carrozzeria, Motore, Tenuta", 18, UI.GRIGIO)
		lista.add_child(leg)
	else:
		lista.add_child(UI.testo("Il numero giallo sono i Punti Struttura rimasti", 18, UI.GRIGIO))

func cronaca(t: String, tipo := "info") -> void:
	var col := UI.CHIARO
	match tipo:
		"avviso":
			col = UI.GIALLO
		"usura":
			col = Color(1.0, 0.6, 0.3)
		"fuori":
			col = UI.ROSSO.lightened(0.25)
		"arrivo":
			col = Color(0.4, 1.0, 0.5)
		"ordine", "giro":
			col = Color(0.55, 0.8, 1.0)
	var l := UI.testo(t, 20, col, false, 440)
	cronaca_box.add_child(l)
	while cronaca_box.get_child_count() > 7:
		var c := cronaca_box.get_child(0)
		cronaca_box.remove_child(c)
		c.queue_free()

# ------------------------------------------------------------------ dadi

func _faccia(testo: String, col: Color, chiaro: bool, sotto: String) -> Control:
	var vb := UI.colonna(2)
	var p := UI.pannello(col, Color.WHITE if not chiaro else Color.BLACK, 12, 3, 4)
	p.custom_minimum_size = Vector2(92, 92)
	var l := UI.testo(testo, 58, Color.BLACK if chiaro else Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	vb.add_child(p)
	var s := UI.testo(sotto, 20, UI.GRIGIO)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	return vb

func mostra_dado(marcia: int, valore: int, faccia: int, nome: String, durata := 0.6) -> void:
	for c in dado_box.get_children():
		c.queue_free()
	var d3 := Dado3D.new(118)
	dado_box.add_child(d3)
	p_dado.visible = true
	await d3.mostra(marcia, faccia, durata)
	dado_box.add_child(_faccia(str(valore), Dati.COLORI_MARCE[marcia], marcia == 1, "%s in %s" % [nome.split(" ")[0], Dati.NOMI_MARCE[marcia]]))
	p_dado.visible = true

func mostra_nero(valore: int, motivo: String, male: bool) -> void:
	if dado_box.get_child_count() > 4:
		dado_box.get_child(2).queue_free()
	var c := _faccia(str(valore), Color(0.05, 0.05, 0.06), false, motivo.left(22))
	if male:
		(c.get_child(0) as PanelContainer).add_theme_stylebox_override("panel", UI.riquadro(Color(0.05, 0.05, 0.06), UI.ROSSO, 12, 4, 4))
	dado_box.add_child(c)
	p_dado.visible = true

func pulisci_dadi() -> void:
	for c in dado_box.get_children():
		c.queue_free()
	p_dado.visible = false

# ------------------------------------------------------------------ decisioni

func _svuota_azione() -> void:
	for c in azione.get_children():
		azione.remove_child(c)
		c.queue_free()
	opz_scelta = {}

## Mostra che cosa si aspetta: la scelta (se tocca a un'auto di questo schermo) o chi deve giocare.
func chiedi() -> void:
	_svuota_azione()
	if v.is_empty() or v.att == null:
		p_azione.visible = false
		return
	p_azione.visible = true
	var i := int(v.att.auto)
	var a: Dictionary = v.auto[i]
	var col := Dati.colore_auto(int(a.p)).lightened(0.3)
	if not _mio(i):
		var chi := "il computer" if a.tp == "ia" else "dal suo schermo"
		azione.add_child(UI.testo("Tocca a %s" % a.n, 32, col, true))
		if a.tp == "ia":
			azione.add_child(UI.testo("Guida il computer...", 22, UI.GRIGIO))
		else:
			azione.add_child(UI.testo("Sta decidendo %s" % chi, 22, UI.GRIGIO))
			if not ospite:
				var b := UI.bottone("Decidi tu al suo posto", 22, UI.FONDO2, 260, 44)
				b.pressed.connect(func(): comando.emit("decidi"))
				azione.add_child(b)
		return
	if v.att.tipo == "marcia":
		azione.add_child(UI.testo("%s: scegli la marcia" % a.n, 32, col, true))
		var h := UI.riga(10)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		azione.add_child(h)
		for o in v.att.marce:
			var m := int(o.m)
			var costo := Dati.testo_usura(v.regole, o.costo)
			var t := "%s\n%s" % [Dati.NOMI_MARCE[m], Dati.INTERVALLI[m]]
			if costo != "":
				t += "\n-" + costo
			if o.fuori:
				t += "\nRITIRO!"
			var b := UI.bottone(t, 26, Dati.COLORI_MARCE[m], 118, 110)
			b.pressed.connect(func(): decisione.emit({"t": "marcia", "m": m}))
			h.add_child(b)
		var nota := "Marcia attuale: %s. Si sale di una alla volta; scalare più di una marcia rovina l'auto." % Dati.NOMI_MARCE[int(a.m)]
		azione.add_child(UI.testo(nota, 20, UI.GRIGIO, false, 600))
	else:
		azione.add_child(UI.testo("%s: tiro %d in %s" % [a.n, int(v.att.tiro), Dati.NOMI_MARCE[int(a.m)]], 32, col, true))
		azione.add_child(UI.testo("Tocca sul tabellone una casella colorata, poi conferma.", 22, UI.CHIARO, false, 600))
		var h := UI.riga(10)
		for l in [[Mondo.COL_LIBERA, "libera"], [Mondo.COL_COSTO, "costa punti"], [Mondo.COL_TESTA, "testacoda"], [Mondo.COL_FUORI, "ritiro"],
				[Mondo.COL_BOX, "box"], [Mondo.COL_ARRIVO, "traguardo"]]:
			h.add_child(UI.chip(l[0], Vector2(20, 20)))
			h.add_child(UI.testo(l[1], 18, UI.GRIGIO))
		azione.add_child(h)

static func testo_opzione(regole: String, o: Dictionary) -> String:
	var parti := []
	if int(o.mo) == 0:
		parti.append("Resta ferma")
	else:
		parti.append("Avanza di %d" % int(o.mo))
	if int(o.sc) > 0:
		parti.append("in scia")
	if int(o.fr) > 0:
		parti.append("frena %d" % int(o.fr))
	if int(o.ol) > 0:
		parti.append("lungo di %d" % int(o.ol))
	var t := ", ".join(parti) + "."
	if o.fi:
		return t + " TRAGUARDO!"
	var costo := Dati.testo_usura(regole, o.u)
	if costo != "":
		t += " Perde " + costo + "."
	if o.bx:
		t += " Sosta al box."
	if o.te:
		t += " TESTACODA: ripartirà in 1a."
	if str(o.fu) != "":
		t += " RITIRO: %s." % o.fu
	if int(o.to) > 0:
		t += " Rischio collisione con %d aut%s." % [int(o.to), "o" if int(o.to) == 1 else "o diverse"]
	if int(o.pe) > 0:
		t += " Passa sui detriti."
	return t

## Dal tabellone: è stata toccata una casella possibile.
func scegli_opzione(o: Dictionary) -> void:
	if v.is_empty() or v.att == null or v.att.tipo != "mossa" or not _mio(int(v.att.auto)):
		return
	if not opz_scelta.is_empty() and opz_scelta.c == o.c:
		decisione.emit({"t": "mossa", "c": o.c})
		return
	chiedi()
	opz_scelta = o
	var male: bool = str(o.fu) != "" or o.te
	azione.add_child(UI.testo(testo_opzione(v.regole, o), 26, UI.ROSSO.lightened(0.3) if male else UI.GIALLO, false, 600))
	var b := UI.bottone("CONFERMA", 32, Color(0.1, 0.6, 0.2) if not male else UI.ROSSO, 300, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cid: String = o.c
	b.pressed.connect(func(): decisione.emit({"t": "mossa", "c": cid}))
	azione.add_child(b)

# ------------------------------------------------------------------ finestre

func chiudi_velo() -> void:
	if velo != null and is_instance_valid(velo):
		velo.queue_free()
	velo = null

func _apri_velo(titolo: String, larg := 1100.0) -> VBoxContainer:
	chiudi_velo()
	velo = ColorRect.new()
	(velo as ColorRect).color = Color(0, 0, 0, 0.7)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.add_child(cc)
	var p := UI.pannello(UI.FONDO, UI.ROSSO, 18, 3, 24)
	p.custom_minimum_size.x = larg
	cc.add_child(p)
	var vb := UI.colonna(14)
	p.add_child(vb)
	var t := UI.testo(titolo, 44, UI.ROSSO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	return vb

func mostra_regole() -> void:
	var vb := _apri_velo("REGOLE IN BREVE", 1300)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = Dati.REGOLE_IN_BREVE
	r.custom_minimum_size = Vector2(1250, 700)
	r.add_theme_font_override("normal_font", UI.f_medio)
	r.add_theme_font_override("bold_font", UI.f_testo)
	r.add_theme_font_size_override("normal_font_size", 25)
	r.add_theme_font_size_override("bold_font_size", 26)
	r.add_theme_color_override("default_color", UI.CHIARO)
	vb.add_child(r)
	var b := UI.bottone("Chiudi", 28, UI.ROSSO, 240, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(chiudi_velo)
	vb.add_child(b)

func mostra_menu(testi: Array) -> void:
	var vb := _apri_velo("PAUSA", 620)
	for t in testi:
		var b := UI.bottone(t[0], 30, UI.FONDO2 if t[1] != "chiudi" else UI.ROSSO, 520, 60)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cosa: String = t[1]
		b.pressed.connect(func():
			chiudi_velo()
			if cosa != "chiudi":
				comando.emit(cosa))
		vb.add_child(b)

func mostra_fine() -> void:
	var vb := _apri_velo("BANDIERA A SCACCHI", 900)
	var n := 0
	for i in v.cl:
		var a: Dictionary = v.auto[int(i)]
		n += 1
		var h := UI.riga(14)
		var pos := "%d°" % int(a.pa) if int(a.pa) > 0 else "rit."
		var lp := UI.testo(pos, 34, UI.GIALLO if int(a.pa) == 1 else UI.CHIARO, true)
		lp.custom_minimum_size.x = 80
		h.add_child(lp)
		h.add_child(UI.immagine("res://assets/piloti/%s.webp" % Dati.PILOTI[int(a.p)].id, Vector2(44, 62)))
		h.add_child(UI.chip(Dati.colore_auto(int(a.p)), Vector2(16, 44)))
		var ln := UI.testo(str(a.n), 32, UI.CHIARO if int(a.pa) > 0 else UI.GRIGIO)
		ln.custom_minimum_size.x = 320
		h.add_child(ln)
		if a.f:
			h.add_child(UI.testo(str(a.w), 22, UI.GRIGIO, false, 320))
		vb.add_child(h)
	var hb := UI.riga(20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	if not ospite:
		var b1 := UI.bottone("Nuova gara", 30, Color(0.1, 0.6, 0.2), 260, 60)
		b1.pressed.connect(func(): comando.emit("rivincita"))
		hb.add_child(b1)
	var b2 := UI.bottone("Guarda il tabellone", 30, UI.FONDO2, 300, 60)
	b2.pressed.connect(chiudi_velo)
	hb.add_child(b2)
	var b3 := UI.bottone("Menu principale", 30, UI.ROSSO, 280, 60)
	b3.pressed.connect(func(): comando.emit("esci"))
	hb.add_child(b3)
	vb.add_child(hb)
