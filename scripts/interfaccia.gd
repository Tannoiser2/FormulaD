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
var dado_box: HBoxContainer
var p_sx: PanelContainer
var col_dx: VBoxContainer
var b_mappa: Button
var b_cronaca: Button
var titolo_ordine: Label
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
	for b in [["Telecamera: segue", "segui"], ["Vista intera", "vista"], ["Caselle", "mappa"], ["Regole", "regole"], ["Menu", "menu"]]:
		var bt := UI.bottone(b[0], 22, UI.FONDO2, 96, 44)
		bt.pressed.connect(func(): comando.emit(b[1]))
		hb.add_child(bt)
		if b[1] == "mappa":
			b_mappa = bt
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
	p_dado.custom_minimum_size.y = 116
	dado_box = UI.riga(12)
	p_dado.add_child(dado_box)
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
	var info := "%s%s  -  Turno %d  -  Giro %d di %d" % [Dati.NOMI_REGOLE[v.regole], "  -  Su strada" if v.get("str", false) else "",
		int(v.turno), clamp(giro_max, 1, int(v.giri)), int(v.giri)]
	barra_info.text = info
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
		var pr := UI.pannello(sf, UI.GIALLO if i == di_turno else sf, 8, 2 if i == di_turno else 0, 2)
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

func _faccia(testo: String, col: Color, chiaro: bool, sotto: String) -> Control:
	var vb := UI.colonna(2)
	var p := UI.pannello(col, Color.WHITE if not chiaro else Color.BLACK, 12, 3, 4)
	p.custom_minimum_size = Vector2(72, 72)
	var l := UI.testo(testo, 46, Color.BLACK if chiaro else Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	vb.add_child(p)
	var s := UI.testo(sotto, 18, UI.GRIGIO)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	return vb

func mostra_dado(marcia: int, valore: int, faccia: int, nome: String, durata := 0.6) -> void:
	for c in dado_box.get_children():
		c.queue_free()
	var d3 := Dado3D.new(90)
	dado_box.add_child(d3)
	await d3.mostra(marcia, faccia, durata)
	dado_box.add_child(_faccia(str(valore), Dati.COLORI_MARCE[marcia], marcia == 1, "%s in %s" % [nome.split(" ")[0], Dati.NOMI_MARCE[marcia]]))

func mostra_nero(valore: int, motivo: String, male: bool) -> void:
	if dado_box.get_child_count() > 4:
		dado_box.get_child(2).queue_free()
	var c := _faccia(str(valore), Color(0.05, 0.05, 0.06), false, motivo.left(22))
	if male:
		(c.get_child(0) as PanelContainer).add_theme_stylebox_override("panel", UI.riquadro(Color(0.05, 0.05, 0.06), UI.ROSSO, 12, 4, 4))
	dado_box.add_child(c)

func pulisci_dadi() -> void:
	for c in dado_box.get_children():
		c.queue_free()

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
	if v.att.tipo == "marcia":
		# le marce si scelgono sulla plancia; qui solo il titolo e il riassunto della marcia sotto il puntatore
		azione.add_child(UI.testo("%s: scegli la marcia" % a.n, 32, col, true))
		plancia_info = UI.testo("", 22, UI.GIALLO, false, LARG_DX - 40)
		azione.add_child(plancia_info)
		mostra_plancia(i)
		return
	if v.att.tipo == "mossa":
		azione.add_child(UI.testo("%s: tiro %d in %s" % [a.n, int(v.att.tiro), Dati.NOMI_MARCE[int(a.m)]], 32, col, true))
		azione.add_child(UI.testo("Tocca sul tabellone una casella colorata, poi conferma.", 22, UI.CHIARO, false, LARG_DX - 40))
		var h := HFlowContainer.new()
		h.add_theme_constant_override("h_separation", 8)
		h.add_theme_constant_override("v_separation", 4)
		h.custom_minimum_size.x = LARG_DX - 40
		for l in [[Mondo.COL_LIBERA, "libera"], [Mondo.COL_COSTO, "costa punti"], [Mondo.COL_TESTA, "testacoda"], [Mondo.COL_FUORI, "ritiro"],
				[Mondo.COL_BOX, "box"], [Mondo.COL_ARRIVO, "traguardo"]]:
			h.add_child(UI.chip(l[0], Vector2(20, 20)))
			h.add_child(UI.testo(l[1], 18, UI.GRIGIO))
		var bs := UI.bottone("Sulle caselle: parole" if scritte_icone.call() else "Sulle caselle: icone", 18, UI.FONDO2, 190, 34)
		bs.pressed.connect(func(): comando.emit("scritte"))
		h.add_child(UI.spazio(6))
		h.add_child(bs)
		azione.add_child(h)
		var con_extra := false
		for o in v.att.opz:
			con_extra = con_extra or Mondo.opzione_extra(o)
		if con_extra:
			var h2 := UI.riga(10)
			h2.add_child(UI.chip(Mondo.COL_EXTRA, Vector2(20, 20)))
			h2.add_child(UI.testo("bordo azzurro: casella in più facoltativa (scia, Nitro, gomme morbide)", 18, UI.GRIGIO, false, LARG_DX - 80))
			azione.add_child(h2)

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
	azione.add_child(UI.testo(testo_opzione(v.regole, o), 26, UI.ROSSO.lightened(0.3) if male else UI.GIALLO, false, LARG_DX - 40))
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
	azione.add_child(UI.testo("Replay della gara", 32, UI.GIALLO, true))
	_rep_testo = UI.testo("Turno 1 di %d" % ultimo, 24, UI.CHIARO)
	azione.add_child(_rep_testo)
	var h := UI.riga(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	azione.add_child(h)
	for b in [["Più lento", "replay_lento", UI.FONDO2], ["Più veloce", "replay_veloce", UI.FONDO2], ["Fine replay", "replay_fine", UI.ROSSO]]:
		var bt := UI.bottone(b[0], 22, b[2], 150, 50)
		var cosa: String = b[1]
		bt.pressed.connect(func(): comando.emit(cosa))
		h.add_child(bt)

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
		_rep_testo.text = "Turno %d di %d  -  %s" % [_rep_mondo.replay_turno, _rep_ultimo,
			"velocità normale" if is_equal_approx(_rep_mondo.replay_tempo, 1.0) else ("un turno ogni %.1f secondi" % _rep_mondo.replay_tempo).replace(".", ",")]
