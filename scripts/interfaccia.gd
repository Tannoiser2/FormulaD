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
var plancia_info: Label
var plancia: Plancia
var plancia_nome: Label
var p_dado: PanelContainer
var dadi_area: Control          # la striscia dove il dado entra da destra e rotola fino a sinistra
var dadi_neri: HBoxContainer    # i dadi neri, piccoli, accanto al dado della marcia
var dadi_testo: Label           # sotto i dadi: che cosa è uscito
var _dado3: Dado3D
var p_sx: PanelContainer
var col_dx: VBoxContainer
var b_mappa: Button
var b_suoni: Button
var b_cronaca: Button
var b_scritte: Button
var titolo_ordine: Label
var campionato: Dictionary = {}     # il campionato in corso (vuoto se è una gara singola)
var riepilogo_gp: Array = []
var p_ass: PanelContainer
var ass_box: VBoxContainer
var scritte_icone := func() -> bool: return true   # chiede al tabellone come sono scritte le caselle
var finestra: Control
const LARG_DX := 540.0
const MIN_AZIONE := 190.0   # spazio sempre riservato alle scelte
const ALTA_PLANCIA := (LARG_DX - 20) * 498.0 / 823.0   # la plancia intera, in proporzione
var p_cron: PanelContainer
var barra: PanelContainer
var velo: Control
var opz_scelta: Dictionary = {}
var auto_plancia := -1
var _pannelli: Array = []
var b_segui: Button
var marcia_vista := 0         # la marcia toccata una volta: si vedono le caselle, il secondo tocco conferma
var _ass_pf: Dictionary = {}   # assetto in preparazione
var _ass_g := ""
var _ass_chi := -1

## Il pulsante dice se la telecamera insegue le mosse oppure resta dove la si mette.
func segna_segui(si: bool) -> void:
	b_segui.text = "Telecamera: segue" if si else "Telecamera: ferma"
	b_segui.modulate = Color.WHITE if si else Color(1.0, 0.85, 0.3)

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
	for b in [["Telecamera: segue", "segui"], ["Vista intera", "vista"], ["Caselle", "mappa"], ["Scritte: icone", "scritte"], ["Suoni: sì", "suoni"], ["Regole", "regole"], ["Menu", "menu"]]:
		var bt := UI.bottone(b[0], 22, UI.FONDO2, 96, 44)
		bt.pressed.connect(func(): comando.emit(b[1]))
		hb.add_child(bt)
		if b[1] == "mappa":
			b_mappa = bt
		if b[1] == "scritte":
			b_scritte = bt
		if b[1] == "suoni":
			b_suoni = bt
		if b[1] == "segui":
			b_segui = bt
			bt.custom_minimum_size.x = 190
	hb.add_child(UI.spazio(6))
	# colonna a destra: ordine di gioco, cronaca, plancia
	col_dx = UI.colonna(8)
	col_dx.anchor_left = 1
	col_dx.anchor_right = 1
	col_dx.anchor_top = 0
	col_dx.anchor_bottom = 1
	col_dx.offset_left = -LARG_DX - 10
	col_dx.offset_right = -10
	col_dx.offset_top = 74
	col_dx.offset_bottom = -10
	col_dx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col_dx)
	p_sx = UI.pannello()
	col_dx.add_child(p_sx)
	var vs := UI.colonna(4)
	p_sx.add_child(vs)
	titolo_ordine = UI.testo("ORDINE DI GIOCO", 24, UI.GIALLO, true)
	vs.add_child(titolo_ordine)
	lista = UI.colonna(3)
	vs.add_child(lista)
	# cronaca: finestra richiudibile in alto a sinistra
	p_cron = UI.pannello(UI.FONDO, UI.FONDO2)
	p_cron.offset_left = 10
	p_cron.offset_top = 74
	p_cron.custom_minimum_size.x = LARG_DX
	add_child(p_cron)
	var vc := UI.colonna(4)
	p_cron.add_child(vc)
	b_cronaca = UI.bottone("Cronaca: nascondi", 20, UI.FONDO2, 200, 36)
	b_cronaca.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b_cronaca.pressed.connect(func():
		finestra.visible = not finestra.visible
		b_cronaca.text = "Cronaca: nascondi" if finestra.visible else "Cronaca: mostra"
		if finestra.visible:
			_taglia_cronaca.call_deferred())
	vc.add_child(b_cronaca)
	finestra = Control.new()
	finestra.clip_contents = true
	finestra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finestra.custom_minimum_size = Vector2(LARG_DX - 20, 230)
	vc.add_child(finestra)
	cronaca_box = UI.colonna(2)
	cronaca_box.anchor_left = 0
	cronaca_box.anchor_right = 1
	cronaca_box.anchor_top = 1
	cronaca_box.anchor_bottom = 1
	cronaca_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	finestra.add_child(cronaca_box)
	# dadi sotto l'ordine di gioco
	p_dado = UI.pannello(UI.FONDO, UI.FONDO2)
	col_dx.add_child(p_dado)
	p_dado.custom_minimum_size.y = 166
	var vdad := UI.colonna(8)
	p_dado.add_child(vdad)
	dadi_area = Control.new()
	dadi_area.clip_contents = true
	dadi_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dadi_area.custom_minimum_size = Vector2(LARG_DX - 40, 96)
	vdad.add_child(dadi_area)
	dadi_neri = UI.riga(8)
	dadi_neri.position = Vector2(0, 25)
	dadi_area.add_child(dadi_neri)
	dadi_testo = UI.testo("", 18, UI.CHIARO, false, LARG_DX - 40)
	dadi_testo.max_lines_visible = 2
	dadi_testo.custom_minimum_size = Vector2(LARG_DX - 40, 44)
	vdad.add_child(dadi_testo)
	# le scelte sotto i dadi
	p_azione = UI.pannello()
	p_azione.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_dx.add_child(p_azione)
	var scorri := ScrollContainer.new()
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p_azione.add_child(scorri)
	azione = UI.colonna(8)
	azione.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorri.add_child(azione)
	# plancia in fondo alla colonna
	p_plancia = UI.pannello(UI.FONDO, UI.FONDO2, 14, 2, 8)
	col_dx.add_child(p_plancia)
	var vp := UI.colonna(4)
	p_plancia.add_child(vp)
	plancia_nome = UI.testo("", 22, UI.CHIARO)
	plancia_nome.clip_text = true
	vp.add_child(plancia_nome)
	plancia = Plancia.new()
	# la plancia prende lo spazio che resta in fondo alla colonna (al massimo tutta la larghezza)
	plancia.custom_minimum_size = Vector2(LARG_DX - 20, ALTA_PLANCIA)
	vp.add_child(plancia)
	plancia.sopra.connect(func(m: int):
		marcia_vista = m
		_info_marcia()
		comando.emit("anteprima"))
	plancia.scelta.connect(func(m: int):
		plancia.offri([], 0)
		decisione.emit({"t": "marcia", "m": m}))
	# finestra della preparazione dell'auto (assetto e gomme), al centro del tabellone
	p_ass = UI.pannello()
	p_ass.anchor_left = 0.5
	p_ass.anchor_right = 0.5
	p_ass.anchor_top = 0.5
	p_ass.anchor_bottom = 0.5
	p_ass.offset_left = -(LARG_DX + 10) / 2.0
	p_ass.offset_right = -(LARG_DX + 10) / 2.0
	p_ass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p_ass.grow_vertical = Control.GROW_DIRECTION_BOTH
	p_ass.custom_minimum_size.x = 660
	p_ass.visible = false
	add_child(p_ass)
	ass_box = UI.colonna(8)
	p_ass.add_child(ass_box)
	_pannelli = [barra, p_ass, p_sx, p_cron, p_azione, p_plancia, p_dado]

## Vero se il punto è sopra un pannello: lì i tocchi non devono muovere il tabellone.
## Il QR code della stanza TV + telefoni in basso a sinistra, per rientrare se un telefono perde la gara.
var p_qr: PanelContainer
var _qr_img: TextureRect
func mostra_qr(tex: Texture2D, codice: String) -> void:
	if p_qr == null:
		p_qr = UI.pannello(UI.FONDO, UI.FONDO2, 10, 2, 8)
		p_qr.anchor_top = 1
		p_qr.anchor_bottom = 1
		p_qr.offset_left = 10
		p_qr.grow_vertical = Control.GROW_DIRECTION_BEGIN
		p_qr.offset_bottom = -10
		add_child(p_qr)
		_pannelli.append(p_qr)
		var vb := UI.colonna(4)
		p_qr.add_child(vb)
		_qr_img = TextureRect.new()
		_qr_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_qr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_qr_img.custom_minimum_size = Vector2(150, 150)
		_qr_img.mouse_filter = Control.MOUSE_FILTER_STOP
		_qr_img.gui_input.connect(func(e):
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				var grande := _qr_img.custom_minimum_size.x < 200
				_qr_img.custom_minimum_size = Vector2(420, 420) if grande else Vector2(150, 150)
				_posa_qr())
		vb.add_child(_qr_img)
		var l := UI.testo("", 18, UI.GRIGIO, false, 150)
		l.name = "testo"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	_qr_img.texture = tex
	(p_qr.find_child("testo", true, false) as Label).text = "Stanza %s\nper rientrare" % codice
	p_qr.visible = tex != null
	_posa_qr()

func _posa_qr() -> void:
	p_qr.reset_size()
	var alto := p_qr.get_combined_minimum_size().y
	p_qr.offset_top = -alto - 10
	p_qr.offset_bottom = -10

func nascondi_qr() -> void:
	if p_qr != null:
		p_qr.visible = false

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
	marcia_vista = 0
	var p := Pista.carica(v.pista)
	# «Formula Dé 19: Suzuka» -> «SUZUKA»: nella barra basta il nome del circuito
	var nome: String = p.nome
	if nome.contains(": "):
		nome = nome.get_slice(": ", 1)
	barra_titolo.text = nome.to_upper()
	var giro_max := 0
	for a in v.auto:
		giro_max = max(giro_max, int(a.g))
	var info := "%s%s  -  Turno %d  -  Giro %d di %d" % [("Regolamento Lari" if v.get("lari", false) else Dati.NOMI_REGOLE[v.regole]), "  -  Su strada" if v.get("str", false) else "",
		int(v.turno), clamp(giro_max, 1, int(v.giri)), int(v.giri)]
	if str(v.fase) == "qualifiche" and v.has("q"):
		var q: Dictionary = v.q
		info = "%s  -  settori %d / %d / %d" % [Qualifiche.nome_sessione(q), int(q.limiti[0]), int(q.limiti[1]), int(q.limiti[2])]
	if not campionato.is_empty() and v.has("camp"):
		info = "GP %d di %d  -  " % [int(v.camp) + 1, campionato.piste.size()] + info
	barra_info.text = info
	if str(v.fase) == "qualifiche":
		_classifica_qualifiche()
	else:
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
	var extra := ""
	if v.get("mon", false):
		extra += "  -  gomme %s" % Dati.NOMI_GOMME[str(a.get("gt", "dure"))].to_lower()
	if v.get("str", false):
		extra += "  -  Nitro %s" % ("pronto" if a.get("ni", false) else "usato")
	extra += Interfaccia.testo_curva(a)
	extra += Interfaccia.testo_danni(v, a)
	plancia_nome.text = "%s  -  %s%s%s" % [a.n, Dati.NOMI_MARCE[int(a.m)] if int(a.m) > 0 else "in griglia",
		"  -  tiro %d" % int(a.d) if int(a.d) > 0 else "", extra]
	plancia_nome.clip_text = true
	plancia_nome.custom_minimum_size.x = LARG_DX - 20
	plancia_nome.add_theme_color_override("font_color", Dati.colore_auto(int(a.p)).lightened(0.3))
	plancia.imposta(v.regole, a.pf, int(a.m))
	# le marce si scelgono sulla plancia di chi deve decidere
	if v.att != null and str(v.att.tipo) == "marcia" and int(v.att.auto) == i and _mio(i):
		plancia.offri(v.att.marce, marcia_vista)
		_info_marcia()
	else:
		plancia.offri([], 0)

func _classifica() -> void:
	for c in lista.get_children():
		c.queue_free()
	titolo_ordine.text = "ORDINE DI GIOCO"
	var in_ordine: Array = []
	for i in v.ordine:
		in_ordine.append(int(i))
	var di_turno := int(v.att.auto) if v.att != null else -1
	var riga_n := 0
	for i in in_ordine:
		var a: Dictionary = v.auto[i]
		riga_n += 1
		var sf := UI.FONDO2 if i != di_turno else Color(0.45, 0.08, 0.1)
		var pr := UI.pannello(sf, UI.GIALLO if i == di_turno else sf, 8, 2, 2)
		var h := UI.riga(8)
		pr.add_child(h)
		var col := Dati.colore_auto(int(a.p))
		h.add_child(UI.chip(col, Vector2(12, 26)))
		var stato := ""
		if int(a.pa) > 0:
			stato = "%d° ARRIVATO" % int(a.pa)
		elif a.f:
			stato = "RITIRATO"
		var nome := UI.testo(str(a.n), 22, UI.CHIARO if stato == "" or int(a.pa) > 0 else UI.GRIGIO)
		h.add_child(nome)
		# pallini delle fermate nella curva in cui si trova: pieni quelli fatti, vuoti quelli che mancano
		var pall := Pallini.new()
		pall.fermate = a.get("fs", [])
		pall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(pall)
		if stato != "":
			var ls := UI.testo(stato, 22, UI.GIALLO if int(a.pa) > 0 else UI.ROSSO)
			h.add_child(ls)
		else:
			var m := int(a.m)
			var pm := UI.pannello(Dati.COLORI_MARCE[m], Color.BLACK, 6, 1, 2)
			pm.custom_minimum_size = Vector2(40, 26)
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
			# colonna «ok» sempre presente (vuota se non ha ancora mosso): le colonne restano allineate
			var lo := UI.testo("ok" if a.mo else "", 20, UI.GRIGIO)
			lo.custom_minimum_size.x = 22
			h.add_child(lo)
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
	if int(v.get("mt", -1)) >= 0:
		titolo_ordine.text = "ORDINE DI GIOCO  -  %s" % Dati.NOMI_METEO[int(v.mt)].to_upper()

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
	var l := UI.testo(t, 20, col, false, LARG_DX - 30)
	cronaca_box.add_child(l)
	while cronaca_box.get_child_count() > 14:
		var c := cronaca_box.get_child(0)
		cronaca_box.remove_child(c)
		c.queue_free()
	_taglia_cronaca.call_deferred()

## Toglie le righe più vecchie che non entrano tutte intere nella cronaca.
func _taglia_cronaca() -> void:
	await get_tree().process_frame
	while cronaca_box.get_child_count() > 1 and cronaca_box.get_combined_minimum_size().y > finestra.size.y:
		var c := cronaca_box.get_child(0)
		cronaca_box.remove_child(c)
		c.queue_free()

# ------------------------------------------------------------------ dadi

## Il dado della marcia entra nel riquadro da destra e rotola fino a sinistra, fermandosi sul numero uscito.
func mostra_dado(marcia: int, valore: int, faccia: int, nome: String, durata := 0.6) -> void:
	# i dadi neri dello stesso turno (la partenza) restano, spostati a destra del dado della marcia
	if is_instance_valid(_dado3):
		_dado3.queue_free()
	dadi_neri.position.x = 108.0
	_dado3 = Dado3D.new(96)
	dadi_area.add_child(_dado3)
	var largo: float = max(dadi_area.size.x, LARG_DX - 40)
	dadi_testo.text = "%s in %s: %d" % [Dati.corto(nome), Dati.NOMI_MARCE[marcia], valore]
	dadi_testo.add_theme_color_override("font_color", UI.CHIARO)
	if durata <= 0.0:
		_dado3.position = Vector2.ZERO
		await _dado3.mostra(marcia, faccia, 0.0)
		return
	var t := durata * 1.6
	_dado3.position = Vector2(largo, 0)
	var tw := create_tween()
	tw.tween_property(_dado3, "position", Vector2.ZERO, t).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await _dado3.mostra(marcia, faccia, t, true)
	if tw.is_valid() and tw.is_running():
		await tw.finished

## Un dado nero: un quadratino accanto al dado della marcia; sotto, che cosa ha deciso.
func mostra_nero(valore: int, motivo: String, male: bool, testo := "", nome := "") -> void:
	dadi_neri.position.x = 108.0 if is_instance_valid(_dado3) and _dado3 != null else 0.0
	while dadi_neri.get_child_count() >= 6:
		var vecchio := dadi_neri.get_child(0)
		dadi_neri.remove_child(vecchio)
		vecchio.queue_free()
	var p := UI.pannello(Color(0.05, 0.05, 0.06), UI.ROSSO if male else Color(0.8, 0.8, 0.85), 8, 3 if male else 2, 2)
	p.custom_minimum_size = Vector2(46, 46)
	var l := UI.testo(str(valore), 28, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	dadi_neri.add_child(p)
	var chi := (Dati.corto(nome) + ", ") if nome != "" else ""
	dadi_testo.text = "Dado nero %d - %s%s: %s" % [valore, chi, motivo, testo] if testo != "" else "Dado nero %d - %s%s" % [valore, chi, motivo]
	dadi_testo.add_theme_color_override("font_color", Color(1, 0.55, 0.5) if male else UI.CHIARO)

func pulisci_dadi() -> void:
	if is_instance_valid(_dado3):
		_dado3.queue_free()
	_dado3 = null
	for c in dadi_neri.get_children():
		dadi_neri.remove_child(c)
		c.queue_free()
	dadi_testo.text = ""

# ------------------------------------------------------------------ decisioni

func _svuota_azione() -> void:
	for c in azione.get_children():
		azione.remove_child(c)
		c.queue_free()
	opz_scelta = {}

## Mostra che cosa si aspetta: la scelta (se tocca a un'auto di questo schermo) o chi deve giocare.
func chiedi() -> void:
	_svuota_azione()
	p_ass.visible = false
	for c in ass_box.get_children():
		ass_box.remove_child(c)
		c.queue_free()
	plancia.offri([], 0)
	if v.is_empty() or v.att == null:
		return
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
	if v.att.tipo == "assetto":
		_chiedi_assetto(i, a, col)
		return
	if v.att.tipo == "qualifica" or v.att.tipo == "qritira":
		_chiedi_qualifica(a, col)
		return
	if v.att.tipo == "marcia":
		# le marce si scelgono sulla plancia; qui solo il titolo e il riassunto della marcia sotto il puntatore
		azione.add_child(UI.testo("%s: scegli la marcia" % a.n, 32, col, true))
		plancia_info = UI.testo("", 22, UI.GIALLO, false, LARG_DX - 40)
		azione.add_child(plancia_info)
		mostra_plancia(i)
		return
	if v.att.tipo == "mossa":
		azione.add_child(UI.testo("%s: tiro %d in %s" % [a.n, int(v.att.tiro), Dati.NOMI_MARCE[int(a.m)]], 32, col, true))
		azione.add_child(UI.testo("Clicca una casella per vedere quanto avanzi e quanto costa, riclicca per confermare.", 22, UI.CHIARO, false, LARG_DX - 40))
		if int(v.att.get("pp", 0)) > 0:
			var bpp := UI.bottone("Ritira il dado (Punti Pilota: %d)" % int(v.att.pp), 20, Color(0.45, 0.1, 0.38), 330, 40)
			bpp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bpp.pressed.connect(func(): decisione.emit({"t": "ritira"}))
			azione.add_child(bpp)

## La riga sotto la plancia mentre si sceglie la marcia.
func _info_marcia() -> void:
	if plancia_info == null or not is_instance_valid(plancia_info):
		return
	if marcia_vista <= 0:
		plancia_info.text = "Le marce possibili sono illuminate sulla plancia. Passaci sopra (o toccale) per vedere dove arrivi, poi clic (o secondo tocco) per innestarla e tirare il dado."
		return
	for o in v.att.marce:
		if int(o.m) != marcia_vista:
			continue
		var t := "%s, dado %s" % [Dati.NOMI_MARCE[marcia_vista], Dati.INTERVALLI[marcia_vista]]
		var costo := Dati.testo_usura(v.regole, o.costo)
		if o.fuori:
			t += "  -  RITIRO!"
		elif costo != "":
			t += "  -  scalare costa " + costo
		var peggio := 0
		for e in o.get("pv", {}).get("t", []):
			peggio = max(peggio, int(e[1]))
		t += ["  -  ogni tiro ha una casella libera", "  -  qualche tiro costa punti", "  -  qualche tiro porta al testacoda",
			"  -  qualche tiro porta al ritiro"][peggio] if o.has("pv") else ""
		plancia_info.text = t + ".  Clic (o secondo tocco) per innestarla e tirare."

## Prima del via (assetto libero e gomme) o al box (gomme nuove).
func _chiedi_assetto(i: int, a: Dictionary, col: Color) -> void:
	var att: Dictionary = v.att
	# una finestra al centro: la colonna di destra non cambia
	p_ass.visible = true
	azione.add_child(UI.testo("%s: prepara l'auto nella finestra al centro." % a.n, 24, col, false, LARG_DX - 40))
	if _ass_chi != i or _ass_pf.is_empty():
		_ass_chi = i
		_ass_pf = {}
		for k in att.pf:
			_ass_pf[k] = int(att.pf[k])
		_ass_g = str(att.g)
		if att.box and att.gomme.has("pioggia") and int(v.get("mt", -1)) >= 2:
			_ass_g = "pioggia"
	var titolo := "%s: gomme nuove al box" % a.n if att.box else "%s: prepara l'auto" % a.n
	ass_box.add_child(UI.testo(titolo, 32, col, true))
	if int(v.get("mt", -1)) >= 0:
		ass_box.add_child(UI.testo("Meteo: %s" % Dati.NOMI_METEO[int(v.mt)], 24, UI.GIALLO))
	var tot := 0
	for k in _ass_pf:
		tot += int(_ass_pf[k])
	if att.libero:
		ass_box.add_child(UI.testo("Ripartisci %d punti fra le zone (Gomme 1-14, le altre 1-7)." % Dati.ASSETTO_TOTALE, 20, UI.GRIGIO, false, 600))
		var g := GridContainer.new()
		g.columns = 6
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 4)
		ass_box.add_child(g)
		for z in Dati.zone(v.regole):
			var zid: String = z.id
			var ln := UI.testo(z.nome, 22, Dati.COLORI_ZONE[zid].lightened(0.35))
			ln.custom_minimum_size.x = 190
			g.add_child(ln)
			var bm := UI.bottone("-", 26, UI.FONDO2, 48, 40)
			bm.disabled = int(_ass_pf[zid]) <= Dati.ASSETTO_MIN
			bm.pressed.connect(func():
				_ass_pf[zid] = int(_ass_pf[zid]) - 1
				chiedi())
			g.add_child(bm)
			var lv := UI.testo(str(_ass_pf[zid]), 26, UI.CHIARO, true)
			lv.custom_minimum_size.x = 44
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			g.add_child(lv)
			var bp := UI.bottone("+", 26, UI.FONDO2, 48, 40)
			bp.disabled = int(_ass_pf[zid]) >= int(z.max) or tot >= Dati.ASSETTO_TOTALE
			bp.pressed.connect(func():
				_ass_pf[zid] = int(_ass_pf[zid]) + 1
				chiedi())
			g.add_child(bp)
			var lm := UI.testo("max %d" % int(z.max), 18, UI.GRIGIO)
			lm.custom_minimum_size.x = 70
			g.add_child(lm)
			g.add_child(UI.spazio(4))
		var resta := Dati.ASSETTO_TOTALE - tot
		var tr := "Tutti i %d punti ripartiti" % Dati.ASSETTO_TOTALE
		if resta > 0:
			tr = "Punti da ripartire: %d" % resta
		elif resta < 0:
			tr = "Punti di troppo: %d (togline qualcuno)" % -resta
		var lr := UI.testo(tr,
			22, UI.GIALLO if resta != 0 else Color(0.5, 0.9, 0.5))
		ass_box.add_child(lr)
	if att.gomme.size() > 1:
		var h := UI.riga(8)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		ass_box.add_child(h)
		for gt in att.gomme:
			var nome_g: String = gt
			var b := UI.bottone(Dati.NOMI_GOMME[gt], 22, UI.ROSSO if _ass_g == gt else UI.FONDO2, 150, 48)
			b.pressed.connect(func():
				_ass_g = nome_g
				chiedi())
			h.add_child(b)
		ass_box.add_child(UI.testo(Dati.DESCR_GOMME.get(_ass_g, ""), 20, UI.CHIARO, false, 600))
	var ok := UI.bottone("CONFERMA", 32, Color(0.1, 0.6, 0.2), 300, 58)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.disabled = att.libero and tot != Dati.ASSETTO_TOTALE
	ok.pressed.connect(func():
		var az := {"t": "assetto", "g": _ass_g}
		if att.libero:
			az["pf"] = _ass_pf.duplicate()
		_ass_chi = -1
		decisione.emit(az))
	ass_box.add_child(ok)

const COL_ESITO := [Mondo.COL_LIBERA, Mondo.COL_COSTO, Mondo.COL_TESTA, Mondo.COL_FUORI]

## Un tiro possibile e che cosa costa nel caso migliore.
func _esito(tiro: int, liv: int, persi: int) -> Control:
	var col: Color = COL_ESITO[liv]
	var p := UI.pannello(col.darkened(0.25), col, 8, 2, 4)
	p.custom_minimum_size = Vector2(64, 0)
	var vb := UI.colonna(0)
	p.add_child(vb)
	var chiaro := liv == 3
	var su := UI.testo(str(tiro), 26, UI.CHIARO if chiaro else Color(0.05, 0.05, 0.05), true)
	su.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(su)
	var giu := UI.testo(["libera", "perde %d" % persi, "testacoda", "ritiro"][liv], 16, UI.CHIARO if chiaro else Color(0.05, 0.05, 0.05))
	giu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(giu)
	return p

## Quante caselle mancano alla prossima curva.
static func testo_curva(a: Dictionary) -> String:
	var pc: Array = a.get("pc", [])
	if pc.size() < 3:
		return ""
	return "  -  curva %d (%d fermat%s) tra %d casell%s" % [int(pc[1]), int(pc[2]), "a" if int(pc[2]) == 1 else "e",
		int(pc[0]), "a" if int(pc[0]) == 1 else "e"]

## KERS, meccanici e danni gravi di un'auto, per la riga sopra la plancia.
static func testo_danni(v: Dictionary, a: Dictionary) -> String:
	var t := ""
	if v.get("kers", false):
		t += "  -  KERS %d" % int(a.get("pk", 0))
	if v.get("lari", false):
		t += "  -  meccanici %d" % int(a.get("pm", 0))
		var nomi := {"musetto": "senza musetto (max 3a)", "potenza": "motore senza potenza", "affidabile": "motore da controllare",
			"sospensioni": "sospensioni rotte", "testacoda": ""}
		for z in a.get("dz", {}):
			var n: String = nomi.get(str(a.dz[z]), "")
			if n != "":
				t += "  -  " + n
	return t

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
	if int(o.get("ni", 0)) > 0:
		parti.append("con il Nitro (+%d)" % int(o.ni))
	if int(o.get("jk", 0)) != 0:
		parti.append("derapata")
	if int(o.get("fg", 0)) > 0:
		parti.append("con il motore fuori giri (+%d, 1 Motore)" % int(o.fg))
	if int(o.get("pk", 0)) > 0:
		parti.append("con il KERS (+%d)" % int(o.pi))
	if int(o.get("co", 0)) != 0:
		parti.append("sul cordolo %s" % ("interno (+1)" if int(o.co) > 0 else "esterno (-2)"))
	if o.get("tp", false):
		parti.append("TAMPONA l'auto davanti")
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
	# il testo nel colore della casella: quanto si avanza e quanto costa
	azione.add_child(UI.testo(testo_opzione(v.regole, o), 26, Mondo.colore_opzione(o).lightened(0.25), false, LARG_DX - 40))

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

var _regole_capitolo := 0
var _regole_testo: RichTextLabel
var _regole_indice: Array = []
var _regole_prima: Button
var _regole_dopo: Button
func mostra_regole(capitolo := -1) -> void:
	if capitolo >= 0:
		_regole_capitolo = capitolo
	var vb := _apri_velo("REGOLE", 1500)
	var h := UI.riga(18)
	vb.add_child(h)
	# indice dei capitoli
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(330, 730)
	h.add_child(sc)
	var ind := UI.colonna(4)
	ind.custom_minimum_size.x = 310
	sc.add_child(ind)
	_regole_indice = []
	for k in Regolamento.CAPITOLI.size():
		var b := UI.bottone(Regolamento.CAPITOLI[k][0], 21, UI.FONDO2, 310, 38)
		var kk := k
		b.pressed.connect(func(): _capitolo(kk))
		ind.add_child(b)
		_regole_indice.append(b)
	_regole_testo = RichTextLabel.new()
	_regole_testo.bbcode_enabled = true
	_regole_testo.custom_minimum_size = Vector2(1100, 730)
	_regole_testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_regole_testo.add_theme_font_override("normal_font", UI.f_medio)
	_regole_testo.add_theme_font_override("bold_font", UI.f_testo)
	_regole_testo.add_theme_font_size_override("normal_font_size", 25)
	_regole_testo.add_theme_font_size_override("bold_font_size", 26)
	_regole_testo.add_theme_color_override("default_color", UI.CHIARO)
	h.add_child(_regole_testo)
	var hb := UI.riga(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	_regole_prima = UI.bottone("< Capitolo prima", 24, UI.FONDO2, 260, 54)
	_regole_prima.pressed.connect(func(): _capitolo(_regole_capitolo - 1))
	hb.add_child(_regole_prima)
	var b := UI.bottone("Chiudi", 28, UI.ROSSO, 240, 54)
	b.pressed.connect(chiudi_velo)
	hb.add_child(b)
	_regole_dopo = UI.bottone("Capitolo dopo >", 24, UI.FONDO2, 260, 54)
	_regole_dopo.pressed.connect(func(): _capitolo(_regole_capitolo + 1))
	hb.add_child(_regole_dopo)
	_capitolo(_regole_capitolo)

## Cambia capitolo senza riaprire la finestra.
func _capitolo(k: int) -> void:
	_regole_capitolo = clampi(k, 0, Regolamento.CAPITOLI.size() - 1)
	_regole_testo.text = "[font_size=34][b]%s[/b][/font_size]\n\n%s" % Regolamento.CAPITOLI[_regole_capitolo]
	_regole_testo.scroll_to_line(0)
	for i in _regole_indice.size():
		UI.colora_bottone(_regole_indice[i], UI.ROSSO if i == _regole_capitolo else UI.FONDO2)
	_regole_prima.disabled = _regole_capitolo == 0
	_regole_dopo.disabled = _regole_capitolo >= Regolamento.CAPITOLI.size() - 1

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
		h.add_child(UI.immagine("res://assets/piloti/%s%s.webp" % [Dati.PILOTI[int(a.p)].id, "_strada" if v.get("abil", false) else ""], Vector2(44, 62)))
		h.add_child(UI.chip(Dati.colore_auto(int(a.p)), Vector2(16, 44)))
		var ln := UI.testo(str(a.n), 32, UI.CHIARO if int(a.pa) > 0 else UI.GRIGIO)
		ln.custom_minimum_size.x = 320
		h.add_child(ln)
		if a.f:
			h.add_child(UI.testo(str(a.w), 22, UI.GRIGIO, false, 320))
		vb.add_child(h)
	var hb := UI.riga(20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	if not ospite and not campionato.is_empty():
		var bc := UI.bottone("Classifica del campionato", 30, Color(0.1, 0.6, 0.2), 380, 60)
		bc.pressed.connect(mostra_campionato)
		hb.add_child(bc)
	elif not ospite:
		var b1 := UI.bottone("Nuova gara", 30, Color(0.1, 0.6, 0.2), 260, 60)
		b1.pressed.connect(func(): comando.emit("rivincita"))
		hb.add_child(b1)
	if v.has("storia"):
		var br := UI.bottone("Rivedi la gara", 30, Color(0.15, 0.4, 0.75), 270, 60)
		br.pressed.connect(func(): comando.emit("replay"))
		hb.add_child(br)
	var b2 := UI.bottone("Guarda il tabellone", 30, UI.FONDO2, 300, 60)
	b2.pressed.connect(chiudi_velo)
	hb.add_child(b2)
	var b3 := UI.bottone("Menu principale", 30, UI.ROSSO, 280, 60)
	b3.pressed.connect(func(): comando.emit("esci"))
	hb.add_child(b3)
	vb.add_child(hb)

# ------------------------------------------------------------------ replay

var _rep_mondo: Node
var _rep_testo: Label
var _rep_ultimo := 1

func mostra_replay(m: Node, ultimo: int) -> void:
	_rep_mondo = m
	_rep_ultimo = ultimo
	_svuota_azione()
	p_azione.visible = true
	_rep_testo = UI.testo("Replay: turno 1 di %d" % ultimo, 22, UI.GIALLO, false, LARG_DX - 40)
	_rep_testo.max_lines_visible = 2
	azione.add_child(_rep_testo)
	var h := UI.riga(8)
	azione.add_child(h)
	for b in [["Più lento", "replay_lento", UI.FONDO2], ["Più veloce", "replay_veloce", UI.FONDO2], ["Fine replay", "replay_fine", UI.ROSSO]]:
		var bt := UI.bottone(b[0], 21, b[2], 0, 46)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cosa: String = b[1]
		bt.pressed.connect(func(): comando.emit(cosa))
		h.add_child(bt)
	# la visuale: dall'alto o dalla cabina di un'auto
	var h2 := UI.riga(8)
	azione.add_child(h2)
	for b in [["Dall'alto", "replay_alto"], ["< Auto", "replay_bordo_prima"], ["In cabina", "replay_bordo"], ["Auto >", "replay_bordo_dopo"]]:
		var bt := UI.bottone(b[0], 21, UI.FONDO2, 0, 46)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cosa: String = b[1]
		bt.pressed.connect(func(): comando.emit(cosa))
		h2.add_child(bt)

## La plancia prende lo spazio che resta in fondo alla colonna, al massimo la sua misura intera.
func _adatta_plancia() -> void:
	if col_dx == null or not col_dx.visible:
		return
	var altri := 0.0
	var n := 0
	for c in col_dx.get_children():
		n += 1
		if c == p_azione:
			altri += MIN_AZIONE
		elif c != p_plancia:
			altri += c.get_combined_minimum_size().y
	var resto := p_plancia.get_combined_minimum_size().y - plancia.custom_minimum_size.y
	var libero: float = col_dx.size.y - altri - resto - 8.0 * max(0, n - 1)
	var h: float = clamp(libero, 150.0, ALTA_PLANCIA)
	if absf(h - plancia.custom_minimum_size.y) > 1.0:
		plancia.custom_minimum_size.y = h

func _process(_d: float) -> void:
	_adatta_plancia()
	if _rep_mondo != null and _rep_mondo.replay_attivo and _rep_testo != null and is_instance_valid(_rep_testo):
		var b: int = _rep_mondo.bordo
		var dove := "vista dall'alto" if b < 0 or not v.has("auto") or b >= v.auto.size() else "in cabina con %s" % str(v.auto[b].n)
		_rep_testo.text = "Replay: turno %d di %d, %s, %s" % [_rep_mondo.replay_turno, _rep_ultimo,
			"velocità normale" if is_equal_approx(_rep_mondo.replay_tempo, 1.0) else ("un turno ogni %.1f s" % _rep_mondo.replay_tempo).replace(".", ","), dove]


## I pallini delle fermate in curva accanto al nome nell'ordine di gioco.
class Pallini extends Control:
	var fermate: Array = []
	func _ready() -> void:
		custom_minimum_size = Vector2(30, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if fermate.size() < 2:
			return
		var fatte := int(fermate[0])
		var servono: int = max(int(fermate[1]), fatte)
		for k in servono:
			var c := Vector2(7 + k * 14, size.y * 0.5)
			if k < fatte:
				draw_circle(c, 5.5, Color(1, 0.85, 0.15) if k < int(fermate[1]) else Color(0.6, 0.9, 0.6))
			else:
				draw_arc(c, 5.0, 0, TAU, 20, Color(1, 0.85, 0.15), 1.6, true)

# ------------------------------------------------------------------ qualifiche

func _chiedi_qualifica(a: Dictionary, col: Color) -> void:
	var att: Dictionary = v.att
	var sett := int(att.sett) + 1
	if att.tipo == "qritira":
		azione.add_child(UI.testo("%s: settore %d, %d punti" % [a.n, sett, int(att.punti)], 30, col, true))
		azione.add_child(UI.testo("Hai tirato %d in %s (limite %d). Vuoi riprovare il settore? Costa %s." % [int(att.tiro),
			Dati.NOMI_MARCE[int(att.m)], int(att.limite), att.costo], 22, UI.CHIARO, false, LARG_DX - 40))
		var h := UI.riga(10)
		azione.add_child(h)
		var b1 := UI.bottone("Tengo %d punti" % int(att.punti), 22, Color(0.1, 0.6, 0.2), 220, 50)
		b1.pressed.connect(func(): decisione.emit({"t": "qritira", "si": false}))
		h.add_child(b1)
		var b2 := UI.bottone("Riprovo", 22, UI.ROSSO, 180, 50)
		b2.pressed.connect(func(): decisione.emit({"t": "qritira", "si": true}))
		h.add_child(b2)
		return
	azione.add_child(UI.testo("%s  -  %s: settore %d" % [str(att.sessione), a.n, sett], 26, col, true))
	var t := "Limite %d  -  finora %d punti%s" % [int(att.limite), int(att.fatto), ", il migliore %d" % int(att.meglio) if int(att.meglio) > 0 else ""]
	azione.add_child(UI.testo(t, 20, UI.CHIARO, false, LARG_DX - 40))
	var g := UI.riga(6)
	azione.add_child(g)
	for o in att.marce:
		var m := int(o.m)
		var testo_b := "%s  %d-%d\nmedia %s%s" % [Dati.NOMI_MARCE[m], int(o.min), int(o.max), str(o.media).replace(".", ","),
			"\ntestacoda %d%%" % int(o.tc) if int(o.tc) > 0 else ""]
		var b := UI.bottone(testo_b, 17, Dati.COLORI_MARCE[m].darkened(0.35), (LARG_DX - 58) / 4.0, 78)
		b.pressed.connect(func(): decisione.emit({"t": "qualifica", "m": m}))
		g.add_child(b)

## Durante le qualifiche, al posto dell'ordine di gioco: i tempi della sessione e chi è già fuori.
func _classifica_qualifiche() -> void:
	for c in lista.get_children():
		c.queue_free()
	var q: Dictionary = v.q
	titolo_ordine.text = "%s  -  TEMPI" % Qualifiche.nome_sessione(q).to_upper()
	var di_turno := int(v.att.auto) if v.att != null else -1
	var righe := []
	for k in q.coda.size():
		var i := int(q.coda[k])
		var g: Dictionary = q.giri[str(i)]
		righe.append({"i": i, "tot": int(g.tot), "p": g.p, "fatto": k < int(q.pos), "ora": k == int(q.pos)})
	righe.sort_custom(func(x, y):
		if x.fatto != y.fatto:
			return x.fatto
		if x.fatto:
			return x.tot > y.tot
		return false)
	var passa: int = int(q.dim[int(q.sess) + 1]) if int(q.sess) + 1 < q.dim.size() else 1
	var n := 0
	for r in righe:
		n += 1
		var a: Dictionary = v.auto[int(r.i)]
		var sf := UI.FONDO2 if int(r.i) != di_turno else Color(0.45, 0.08, 0.1)
		var pr := UI.pannello(sf, UI.GIALLO if int(r.i) == di_turno else sf, 8, 2, 2)
		var h := UI.riga(8)
		pr.add_child(h)
		h.add_child(UI.chip(Dati.colore_auto(int(a.p)), Vector2(12, 26)))
		var nome := UI.testo(str(a.n), 22, UI.CHIARO)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nome)
		var sett := []
		for x in r.p:
			sett.append(str(x))
		var ls := UI.testo(" + ".join(PackedStringArray(sett)) if not sett.is_empty() else ("in pista" if r.ora else "-"), 20, UI.GRIGIO)
		ls.custom_minimum_size.x = 120
		h.add_child(ls)
		var lt := UI.testo(str(r.tot) if r.fatto or r.ora else "", 22, UI.GIALLO if r.fatto and n <= passa and q.dim.size() > int(q.sess) + 1 else UI.CHIARO, true)
		lt.custom_minimum_size.x = 40
		lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(lt)
		lista.add_child(pr)
	if not q.griglia.is_empty():
		var fuori := []
		var base: int = v.auto.size() - q.griglia.size()
		for k in q.griglia.size():
			fuori.append("%d. %s" % [base + k + 1, Dati.corto(str(v.auto[int(q.griglia[k])].n))])
		lista.add_child(UI.testo("Già in griglia: " + ", ".join(PackedStringArray(fuori)), 18, UI.GRIGIO, false, LARG_DX - 30))

# ------------------------------------------------------------------ campionato

func mostra_campionato() -> void:
	var c := campionato
	var finito: bool = c.get("finito", false)
	var vb := _apri_velo("CAMPIONATO FINITO" if finito else "CAMPIONATO  -  DOPO %d GP DI %d" % [int(c.gp), c.piste.size()], 1500)
	if str(c.get("codice", "")) != "":
		var lcod := UI.testo("Codice del campionato: %s  -  con il codice lo riprendi da qualsiasi dispositivo («Continua un campionato» nel menu)" % c.codice, 22, UI.CHIARO)
		lcod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lcod)
	if finito:
		var cl := Campionato.piloti(c)
		var sc := Campionato.scuderie(c)
		var lc := UI.testo("Campione del mondo: %s (%d punti)   -   Scuderia campione: %s" % [cl[0].n, int(cl[0].punti), str(sc[0].s).capitalize()], 28, UI.GIALLO, true)
		lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lc)
	var h := UI.riga(24)
	vb.add_child(h)
	# la gara appena corsa
	if not riepilogo_gp.is_empty():
		var vg := _tabella(h, "QUESTO GRAN PREMIO", 430)
		for r in riepilogo_gp:
			var pos := "%d°" % int(r.pos) if int(r.pos) > 0 else "rit."
			_riga_tab(vg, int(r.p), pos, str(r.n), "+%d" % int(r.punti) if int(r.punti) > 0 else "",
				"%+d" % int(r.vill) if int(r.vill) != 0 else "")
	var vp := _tabella(h, "PILOTI  (punti, Punti Pilota)", 470)
	var k := 0
	for r in Campionato.piloti(c):
		k += 1
		_riga_tab(vp, int(r.p), "%d." % k, str(r.n), str(r.punti), "PP %d" % int(r.pp))
	var v2 := UI.colonna(18)
	h.add_child(v2)
	var vs := _tabella(v2, "SCUDERIE", 470)
	k = 0
	for r in Campionato.scuderie(c):
		k += 1
		var hs := UI.riga(8)
		hs.add_child(UI.testo("%d." % k, 22, UI.GRIGIO))
		var ln := UI.testo("%s  (%s)" % [str(r.s).capitalize(), r.piloti], 22, UI.CHIARO)
		ln.custom_minimum_size.x = 360
		ln.clip_text = true
		hs.add_child(ln)
		hs.add_child(UI.testo(str(r.punti), 22, UI.GIALLO, true))
		vs.add_child(hs)
	var vv := _tabella(v2, "PREMIO GILLES VILLENEUVE", 470)
	k = 0
	for r in Campionato.villeneuve(c):
		k += 1
		if k > 5:
			break
		_riga_tab(vv, int(r.p), "%d." % k, str(r.n), "%+d" % int(r.vill) if int(r.vill) != 0 else "0", "")
	var hb := UI.riga(20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	if not finito:
		var bn := UI.bottone("Prossimo GP: %s" % Campionato.nome_pista(c.piste[int(c.gp)]), 30, Color(0.1, 0.6, 0.2), 460, 60)
		bn.pressed.connect(func(): comando.emit("camp_prossimo"))
		hb.add_child(bn)
	var b2 := UI.bottone("Guarda il tabellone", 26, UI.FONDO2, 280, 60)
	b2.pressed.connect(chiudi_velo)
	hb.add_child(b2)
	var b3 := UI.bottone("Menu principale", 26, UI.ROSSO, 260, 60)
	b3.pressed.connect(func(): comando.emit("esci"))
	hb.add_child(b3)

func _tabella(dove: Control, titolo: String, larg: float) -> VBoxContainer:
	var p := UI.pannello(UI.FONDO2, UI.FONDO2, 10, 1, 10)
	p.custom_minimum_size.x = larg
	dove.add_child(p)
	var vb := UI.colonna(4)
	p.add_child(vb)
	vb.add_child(UI.testo(titolo, 22, UI.GIALLO, true))
	return vb

func _riga_tab(vb: VBoxContainer, pilota: int, pos: String, nome: String, a: String, b: String) -> void:
	var h := UI.riga(8)
	var lp := UI.testo(pos, 22, UI.GRIGIO)
	lp.custom_minimum_size.x = 44
	h.add_child(lp)
	h.add_child(UI.chip(Dati.colore_auto(pilota), Vector2(10, 24)))
	var ln := UI.testo(nome, 22, UI.CHIARO)
	ln.custom_minimum_size.x = 220
	ln.clip_text = true
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ln)
	var la := UI.testo(a, 22, UI.GIALLO, true)
	la.custom_minimum_size.x = 50
	la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(la)
	var lb := UI.testo(b, 20, UI.GRIGIO)
	lb.custom_minimum_size.x = 56
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(lb)
	vb.add_child(h)
