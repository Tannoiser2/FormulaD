class_name Menu
extends Control
## Menu principale e preparazione della gara (circuito, giri, regole, piloti); per chi ospita anche la
## sala d'attesa con il QR code per i telefoni.

signal via(conf: Dictionary)
signal comando(cosa: String)
signal entra_gara(codice: String, nome: String)
signal camp_scegli(codice: String)
signal camp_togli(codice: String)

const TIPI_LOCALE := ["umano", "ia", "chiuso"]
const TIPI_STANZA := ["remoto", "ia", "umano", "chiuso"]
const NOMI_TIPO := {"umano": "Questo schermo", "ia": "Computer", "chiuso": "Non corre", "remoto": "Telefono"}
const COL_TIPO := {"umano": Color(0.1, 0.55, 0.2), "ia": Color(0.2, 0.3, 0.5), "chiuso": Color(0.22, 0.23, 0.26), "remoto": Color(0.7, 0.4, 0.05)}

var sfondo: ColorRect
var corpo: Control
var stanza := false
var tipo_stanza := "tv"     # "tv": tabellone qui e scelte dai telefoni; "online": ognuno gioca dal suo computer
var pista_n := 0
var giri := 2
var regole := "base"
var livello := 1
var strada := false
var meteo := false
var libero := false
var qualifiche := false
var abilita := false     # in circuito: i personaggi con le loro abilità (su strada ci sono sempre, con le regole avanzate)
var nitro := false       # in circuito: il Nitro come su strada
var lari := false        # regolamento del campionato di Gianluca Lari (sopra le regole avanzate)
var kers := false
var nomi: Array = []     # i nomi scelti per i piloti (vuoto: «Pilota N»)
var campionato := false
var camp_piste: Array = []      # i circuiti scelti per il campionato, nell'ordine in cui si corrono
var campionati: Array = []     # i campionati salvati qui: {codice, testo, finito, chi}
var posti: Array = []        # per pilota: {tipo, uid, nome}
var codice := ""
var url := ""
var qr_tex: Texture2D
var ha_salvataggio := false
var avviso := ""
var in_rete := false

func _ready() -> void:
	UI.prepara()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sfondo = ColorRect.new()
	sfondo.color = Color(0.05, 0.06, 0.08, 0.86)
	sfondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sfondo)
	_posti_iniziali()
	principale()

func _posti_iniziali() -> void:
	posti = []
	for i in Dati.PILOTI.size():
		var tipo := "chiuso"
		if stanza and tipo_stanza == "online":
			# chi apre la gara guida la prima auto dal suo computer
			tipo = "umano" if i == 0 else ("remoto" if i < 4 else ("ia" if i < 6 else "chiuso"))
		elif stanza:
			tipo = "remoto" if i < 4 else ("ia" if i < 6 else "chiuso")
		else:
			tipo = "umano" if i == 0 else ("ia" if i < 6 else "chiuso")
		posti.append({"tipo": tipo, "uid": "", "nome": ""})

func _nuovo_corpo() -> VBoxContainer:
	if corpo != null and is_instance_valid(corpo):
		corpo.queue_free()
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	corpo = cc
	var vb := UI.colonna(16)
	cc.add_child(vb)
	return vb

func _titolo(vb: VBoxContainer, sotto: String) -> void:
	var t := UI.testo("FORMULA D", 120, UI.ROSSO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color.WHITE)
	t.add_theme_constant_override("outline_size", 10)
	vb.add_child(t)
	var s := UI.testo(sotto, 30, UI.GIALLO)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)

# ------------------------------------------------------------------ menu principale

func principale() -> void:
	var vb := _nuovo_corpo()
	var t := UI.testo("FORMULA D", 92, UI.ROSSO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color.WHITE)
	t.add_theme_constant_override("outline_size", 8)
	vb.add_child(t)
	var griglia := GridContainer.new()
	griglia.columns = 3
	griglia.add_theme_constant_override("h_separation", 22)
	griglia.add_theme_constant_override("v_separation", 14)
	vb.add_child(griglia)
	var voci := [
		["locale", "Da soli contro il computer, o in più a turno sullo stesso schermo"],
		["campionato", "Più Gran Premi con qualifiche, punti, scuderie e Punti Pilota"],
		["stanza_tv", "Il tabellone qui, ogni pilota sceglie dal suo telefono (QR code)"],
		["online", "Ognuno dal suo computer: apri una gara o entra con il codice"],
		["editor", "Scegli un circuito e correggi caselle e traiettorie"],
		["regole", "Il regolamento in breve, in italiano"],
	]
	for vo in voci:
		griglia.add_child(_riquadro_menu(vo[0], vo[1]))
	var altri := UI.riga(16)
	altri.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(altri)
	var sec := [["CONTINUA UN CAMPIONATO", "camp_lista", Color(0.45, 0.1, 0.38)]]
	if ha_salvataggio:
		sec.append(["RIPRENDI LA GARA SALVATA", "riprendi", Color(0.1, 0.55, 0.2)])
	for x in sec:
		var b := UI.bottone(x[0], 24, x[2], 380, 50)
		var cosa: String = x[1]
		b.pressed.connect(func(): _voce(cosa))
		altri.add_child(b)
	var in_corso := campionati.filter(func(x): return not x.finito)
	if not in_corso.is_empty():
		var c := UI.testo("Campionato in corso: %s (codice %s)" % [in_corso[0].testo, in_corso[0].codice], 20, UI.GRIGIO)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(c)
	if avviso != "":
		var a := UI.testo(avviso, 24, UI.GIALLO, false, 900)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(a)

## Un riquadro del menu: l'immagine (che porta già il titolo) e sotto una riga di spiegazione.
func _riquadro_menu(cosa: String, desc: String) -> Control:
	var col := UI.colonna(4)
	col.custom_minimum_size = Vector2(580, 0)
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/img/menu/%s.webp" % ("stanza_online" if cosa == "online" else cosa))
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(580, 256)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func(): b.modulate = Color(1.15, 1.15, 1.15))
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
	b.button_down.connect(func(): b.modulate = Color(0.8, 0.8, 0.8))
	b.button_up.connect(func(): b.modulate = Color.WHITE)
	b.pressed.connect(func(): _voce(cosa))
	col.add_child(b)
	var d := UI.testo(desc, 20, UI.GRIGIO, false, 580)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(d)
	return col

func _voce(cosa: String) -> void:
	avviso = ""
	match cosa:
		"locale":
			stanza = false
			campionato = false
			_posti_iniziali()
			preparazione()
		"campionato":
			stanza = false
			campionato = true
			if camp_piste.is_empty():
				camp_piste = ["FDMonaco", "FDe04", "FDe19", "FDAustin", "FDe01"]
			giri = 3
			regole = "avanzate"
			lari = true
			_posti_iniziali()
			preparazione()
		"camp_lista":
			comando.emit("camp_lista")
		"online":
			online()
		"stanza", "stanza_tv", "stanza_online":
			campionato = false
			tipo_stanza = "online" if cosa == "stanza_online" else "tv"
			if not in_rete:
				avviso = "Le stanze funzionano dalla versione web del gioco (GitHub Pages)."
				principale()
				return
			stanza = true
			codice = ""
			_posti_iniziali()
			preparazione()
			comando.emit("apri_stanza")
		_:
			comando.emit(cosa)

## I campionati salvati su questo dispositivo, e il recupero con il codice da qualsiasi altro.
func campionati_schermo() -> void:
	var vb := _nuovo_corpo()
	var t := UI.testo("CONTINUA UN CAMPIONATO", 56, UI.ROSSO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var h := UI.riga(30)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(h)
	# elenco
	var pl := UI.pannello(UI.FONDO, Color(0.45, 0.1, 0.38), 16, 3, 18)
	pl.custom_minimum_size = Vector2(900, 520)
	h.add_child(pl)
	var vl := UI.colonna(10)
	pl.add_child(vl)
	vl.add_child(UI.testo("SU QUESTO DISPOSITIVO", 30, UI.GIALLO, true))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(860, 440)
	vl.add_child(sc)
	var lista := UI.colonna(8)
	lista.custom_minimum_size.x = 840
	sc.add_child(lista)
	if campionati.is_empty():
		lista.add_child(UI.testo("Nessun campionato salvato qui. Se ne hai iniziato uno su un altro dispositivo, scrivi a destra il suo codice.", 24, UI.GRIGIO, false, 820))
	for c in campionati:
		var r := UI.riga(10)
		lista.add_child(r)
		var vt := UI.colonna(0)
		vt.custom_minimum_size.x = 520
		vt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(vt)
		vt.add_child(UI.testo("%s  -  codice %s" % [c.testo, c.codice], 24, UI.CHIARO if not c.finito else UI.GRIGIO, true, 520))
		if str(c.chi) != "":
			vt.add_child(UI.testo("Giocatori: " + str(c.chi), 20, UI.GRIGIO, false, 520))
		var cod: String = c.codice
		if not c.finito:
			var bc := UI.bottone("CONTINUA", 24, Color(0.1, 0.55, 0.2), 170, 54)
			bc.pressed.connect(func(): camp_scegli.emit(cod))
			r.add_child(bc)
		var bt := UI.bottone("Togli", 22, UI.FONDO2, 110, 54)
		bt.tooltip_text = "Lo toglie da questo dispositivo; online resta e si recupera con il codice"
		bt.pressed.connect(func(): camp_togli.emit(cod))
		r.add_child(bt)
	# recupero con il codice
	var pr := UI.pannello(UI.FONDO, Color(0.12, 0.45, 0.5), 16, 3, 18)
	pr.custom_minimum_size = Vector2(460, 520)
	h.add_child(pr)
	var vr := UI.colonna(12)
	pr.add_child(vr)
	vr.add_child(UI.testo("CON IL CODICE", 30, UI.GIALLO, true))
	vr.add_child(UI.testo("Ogni campionato si salva anche online. Scrivi il suo codice di 6 lettere (è nella classifica del campionato) e riprendilo da qui, anche se l'hai iniziato su un altro computer o tablet.", 22, UI.CHIARO, false, 420))
	var e := LineEdit.new()
	e.max_length = 6
	e.placeholder_text = "ABCDEF"
	e.custom_minimum_size = Vector2(420, 64)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_size_override("font_size", 40)
	e.text_changed.connect(func(x: String):
		var col := e.caret_column
		e.text = x.to_upper()
		e.caret_column = col)
	vr.add_child(e)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vr.add_child(sp)
	var br := UI.bottone("RECUPERA", 32, Color(0.12, 0.45, 0.5), 420, 64)
	var vai := func():
		var c := e.text.strip_edges().to_upper()
		if c.length() != 6:
			avviso = "Il codice del campionato ha 6 lettere."
			campionati_schermo()
			return
		camp_scegli.emit(c)
	br.pressed.connect(vai)
	e.text_submitted.connect(func(_x): vai.call())
	vr.add_child(br)
	if avviso != "":
		var a := UI.testo(avviso, 24, UI.GIALLO, false, 1300)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(a)
	var bi := UI.bottone("INDIETRO", 32, UI.FONDO2, 260, 64)
	bi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bi.pressed.connect(func():
		avviso = ""
		principale())
	vb.add_child(bi)

## Gara online: aprire una gara nuova o entrare in quella di un altro con il codice.
var nome_ospite := ""
func online() -> void:
	var vb := _nuovo_corpo()
	var t := UI.testo("GARA ONLINE", 64, UI.ROSSO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := UI.testo("Ognuno gioca dal suo computer o tablet e vede la stessa gara.", 26, UI.CHIARO)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var h := UI.riga(30)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(h)
	# apri
	var pa := UI.pannello(UI.FONDO, UI.ROSSO, 16, 3, 22)
	pa.custom_minimum_size = Vector2(560, 360)
	h.add_child(pa)
	var va := UI.colonna(14)
	pa.add_child(va)
	va.add_child(UI.testo("APRI UNA GARA", 40, UI.GIALLO, true))
	va.add_child(UI.testo("Scegli circuito, regole e piloti. Il gioco ti dà un codice di 4 lettere e un link da mandare agli altri: chi entra prende un posto «Online».", 24, UI.CHIARO, false, 510))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	va.add_child(sp)
	var ba := UI.bottone("APRI LA GARA", 34, Color(0.1, 0.6, 0.2), 510, 64)
	ba.pressed.connect(func(): _voce("stanza_online"))
	va.add_child(ba)
	# entra
	var pe := UI.pannello(UI.FONDO, Color(0.12, 0.45, 0.5), 16, 3, 22)
	pe.custom_minimum_size = Vector2(560, 360)
	h.add_child(pe)
	var ve := UI.colonna(12)
	pe.add_child(ve)
	ve.add_child(UI.testo("ENTRA IN UNA GARA", 40, UI.GIALLO, true))
	var e_cod := _campo(ve, "Codice della gara (4 lettere)", "", 4)
	e_cod.add_theme_font_size_override("font_size", 40)
	e_cod.text_changed.connect(func(x: String):
		var c := e_cod.caret_column
		e_cod.text = x.to_upper()
		e_cod.caret_column = c)
	var e_nome := _campo(ve, "Il tuo nome", nome_ospite, 16)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ve.add_child(sp2)
	var be := UI.bottone("ENTRA", 34, Color(0.12, 0.45, 0.5), 510, 64)
	var vai := func():
		var c := e_cod.text.strip_edges().to_upper()
		if c.length() != 4:
			avviso = "Il codice ha 4 lettere."
			online()
			return
		nome_ospite = e_nome.text.strip_edges()
		entra_gara.emit(c, nome_ospite if nome_ospite != "" else "Pilota")
	be.pressed.connect(vai)
	e_cod.text_submitted.connect(func(_x): e_nome.grab_focus())
	e_nome.text_submitted.connect(func(_x): vai.call())
	ve.add_child(be)
	if avviso != "":
		var a := UI.testo(avviso, 24, UI.GIALLO, false, 900)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(a)
	var bi := UI.bottone("INDIETRO", 32, UI.FONDO2, 260, 64)
	bi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bi.pressed.connect(func():
		avviso = ""
		principale())
	vb.add_child(bi)

func _campo(dove: VBoxContainer, etichetta: String, testo: String, lung: int) -> LineEdit:
	dove.add_child(UI.testo(etichetta, 22, UI.GRIGIO))
	var e := LineEdit.new()
	e.text = testo
	e.max_length = lung
	e.custom_minimum_size = Vector2(510, 56)
	e.add_theme_font_size_override("font_size", 28)
	dove.add_child(e)
	return e

# ------------------------------------------------------------------ preparazione

func _scelta(etichetta: String, valori: Array, attuale, quando: Callable) -> HBoxContainer:
	var h := UI.riga(8)
	var l := UI.testo(etichetta, 26, UI.GRIGIO)
	l.custom_minimum_size.x = 130
	h.add_child(l)
	for val in valori:
		var scelto: bool = val[1] == attuale
		var b := UI.bottone(val[0], 24, UI.ROSSO if scelto else UI.FONDO2, 0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var x = val[1]
		b.pressed.connect(func(): quando.call(x))
		h.add_child(b)
	return h

func preparazione() -> void:
	var vb := _nuovo_corpo()
	var t := UI.testo("CAMPIONATO" if campionato else "PREPARA LA GARA" if not stanza else ("TV + TELEFONI" if tipo_stanza == "tv" else "GARA ONLINE"), 60, UI.ROSSO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var h := UI.riga(24)
	vb.add_child(h)
	# colonna di sinistra: circuito e regole
	var ps := UI.pannello()
	ps.custom_minimum_size.x = 560
	h.add_child(ps)
	var vs := UI.colonna(10)
	ps.add_child(vs)
	if campionato:
		_scegli_circuiti(vs)
	else:
		_scegli_pista(vs)
	vs.add_child(_scelta("Giri", [["1", 1], ["2", 2], ["3", 3]], giri, func(x):
		giri = x
		preparazione()))
	vs.add_child(_scelta("Regole", [["Base", "base"], ["Avanzate", "avanzate"], ["Lari", "lari"]], "lari" if lari and regole == "avanzate" else regole, func(x):
		lari = x == "lari"
		regole = "avanzate" if lari else x
		preparazione()))
	if not campionato:
		vs.add_child(_scelta("Gara", [["In circuito", false], ["Su strada", true]], strada, func(x):
			strada = x
			preparazione()))
		vs.add_child(_scelta("Griglia", [["Dado nero", false], ["Qualifiche", true]], qualifiche, func(x):
			qualifiche = x
			preparazione()))
	else:
		strada = false
	if regole == "avanzate":
		vs.add_child(_scelta("Meteo", [["Sereno", false], ["Dado nero", true]], meteo, func(x):
			meteo = x
			preparazione()))
		if not strada:
			vs.add_child(_scelta("Assetto", [["Uguale", false], ["Libero", true]], libero, func(x):
				libero = x
				preparazione()))
	if not strada:
		# extra delle gare su strada, da aggiungere anche in circuito
		var he := UI.riga(8)
		var le := UI.testo("Extra", 26, UI.GRIGIO)
		le.custom_minimum_size.x = 130
		he.add_child(le)
		var bn := UI.bottone("Nitro: " + ("sì" if nitro else "no"), 22, UI.ROSSO if nitro else UI.FONDO2, 0, 46)
		bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bn.pressed.connect(func():
			nitro = not nitro
			preparazione())
		he.add_child(bn)
		var ba := UI.bottone("Personaggi: " + ("sì" if abilita and regole == "avanzate" else "no"), 22,
			UI.ROSSO if abilita and regole == "avanzate" else UI.FONDO2, 0, 46)
		ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ba.disabled = regole != "avanzate"
		ba.tooltip_text = "Solo con le regole avanzate"
		ba.pressed.connect(func():
			abilita = not abilita
			preparazione())
		he.add_child(ba)
		var bk := UI.bottone("KERS: " + ("sì" if kers and regole == "avanzate" else "no"), 22,
			UI.ROSSO if kers and regole == "avanzate" else UI.FONDO2, 0, 46)
		bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bk.disabled = regole != "avanzate"
		bk.pressed.connect(func():
			kers = not kers
			preparazione())
		he.add_child(bk)
		vs.add_child(he)
	vs.add_child(_scelta("Computer", [["Prudente", 0], ["Normale", 1], ["Esperto", 2]], livello, func(x):
		livello = x
		preparazione()))
	var nota0 := "Base: 18 Punti Struttura per tutto. Avanzate: gomme, freni, cambio, carrozzeria, motore, tenuta di strada, scie e detriti."
	var nota := nota0
	if lari and regole == "avanzate" and not campionato:
		nota = "Regolamento Lari: avanzate più cordoli, fuori giri, tabelle dei danni, strada bloccata, meccanici ai box, rischio pilota, Punti Pilota sul dado nero (vedi le Regole)."
	elif campionato:
		nota = "Prima di ogni GP le qualifiche a settori. Punti 8-6-4-2-1, classifica scuderie e premio Villeneuve. Ogni pilota ha 1 Punto Pilota per ritirare il dado, +1 per i primi tre di ogni GP."
	elif qualifiche and not strada:
		nota = "Qualifiche a settori: 3 tiri a giro, Q1-Q2-Q3 con 8 auto o più. " + nota0
	elif strada:
		nota = "Su strada: niente box, Nitro una volta per giro, controllo al traguardo." + (" Ogni pilota ha la sua auto e un'abilità." if regole == "avanzate" else "")
	elif personaggi() or nitro:
		nota = ("Nitro: una volta per giro, dopo il tiro, tante caselle in più quanto la marcia. " if nitro else "") + ("Ogni pilota ha un'abilità (vedi le Regole)." if personaggi() else "")
	elif regole == "avanzate" and (meteo or libero):
		nota = ("Il dado nero decide il tempo e si scelgono le gomme. " if meteo else "") + ("Ognuno ripartisce 20 punti fra le zone." if libero else "")
	vs.add_child(UI.testo(nota, 20, UI.GRIGIO, false, 520))
	if stanza:
		var hq := UI.riga(14)
		vs.add_child(hq)
		if qr_tex != null and codice != "" and tipo_stanza == "tv":
			var q := TextureRect.new()
			q.texture = qr_tex
			q.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			q.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			q.custom_minimum_size = Vector2(190, 190)
			hq.add_child(q)
		var vq := UI.colonna(2)
		hq.add_child(vq)
		if codice == "":
			vq.add_child(UI.testo("Apro la stanza..." if avviso == "" else avviso, 28, UI.GIALLO, false, 480))
		else:
			vq.add_child(UI.testo("CODICE STANZA" if tipo_stanza == "tv" else "CODICE DELLA GARA", 22, UI.GRIGIO))
			vq.add_child(UI.testo(codice, 80, UI.GIALLO, true))
			if tipo_stanza == "tv":
				vq.add_child(UI.testo("Ogni pilota inquadra il QR con il telefono (o apre la pagina del telefono e scrive il codice).", 20, UI.CHIARO, false, 300))
			else:
				vq.add_child(UI.testo("Gli altri aprono il gioco sul loro computer, scelgono «Gara online», «Entra in una gara» e scrivono il codice, oppure aprono il link.", 20, UI.CHIARO, false, 480))
				var bl := UI.bottone("Copia il link della gara", 20, UI.FONDO2, 260, 40)
				bl.pressed.connect(func():
					DisplayServer.clipboard_set(link_gara())
					bl.text = "Link copiato")
				vq.add_child(bl)
	# colonna di destra: i piloti
	var pd := UI.pannello()
	h.add_child(pd)
	var vd := UI.colonna(8)
	pd.add_child(vd)
	vd.add_child(UI.testo("PILOTI E SCUDERIE  -  tocca il pulsante per cambiare chi guida", 26, UI.GIALLO))
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	vd.add_child(g)
	for i in Dati.PILOTI.size():
		g.add_child(_carta_pilota(i))
	# in fondo
	var hb := UI.riga(20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var bi := UI.bottone("INDIETRO", 32, UI.FONDO2, 260, 64)
	bi.pressed.connect(func():
		if stanza:
			comando.emit("chiudi_stanza")
		principale())
	hb.add_child(bi)
	var n := _quante()
	var bv := UI.bottone(("VIA AL CAMPIONATO!  (%d auto)" if campionato else "VIA!  (%d auto)") % n, 40, Color(0.1, 0.6, 0.2), 520 if campionato else 420, 64)
	bv.disabled = n < 1 or (stanza and codice == "") or (campionato and (camp_piste.is_empty() or n < 2))
	bv.pressed.connect(_via)
	hb.add_child(bv)

func _scegli_pista(vs: VBoxContainer) -> void:
	var pid: String = Dati.PISTE[pista_n]
	var p := Pista.carica(pid)
	var hc := UI.riga(8)
	var bp := UI.bottone("<", 34, UI.FONDO2, 54, 54)
	bp.pressed.connect(func():
		pista_n = (pista_n + Dati.PISTE.size() - 1) % Dati.PISTE.size()
		preparazione())
	hc.add_child(bp)
	var ln := UI.testo(p.nome, 34, UI.CHIARO, true)
	# i nomi lunghi si rimpiccioliscono invece di essere tagliati
	var dim_nome := 34
	while dim_nome > 16 and UI.f_titolo.get_string_size(p.nome, HORIZONTAL_ALIGNMENT_LEFT, -1, dim_nome).x > 400.0:
		dim_nome -= 2
	ln.add_theme_font_size_override("font_size", dim_nome)
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ln.clip_text = true
	ln.custom_minimum_size.x = 380
	hc.add_child(ln)
	var bn := UI.bottone(">", 34, UI.FONDO2, 54, 54)
	bn.pressed.connect(func():
		pista_n = (pista_n + 1) % Dati.PISTE.size()
		preparazione())
	hc.add_child(bn)
	vs.add_child(hc)
	var alt := 130.0 if stanza else 210.0
	vs.add_child(UI.immagine("res://assets/piste/mini/%s.webp" % pid, Vector2(530, alt)))
	var curve := 0
	for c in p.fermate:
		curve += 1
	vs.add_child(UI.testo("%d curve  -  circuito %d di %d" % [curve, pista_n + 1, Dati.PISTE.size()], 22, UI.GRIGIO))

## Campionato: i circuiti si accendono e spengono; si corrono nell'ordine in cui sono stati scelti.
func _scegli_circuiti(vs: VBoxContainer) -> void:
	vs.add_child(UI.testo("CIRCUITI  -  %d Gran Premi (si corrono nell'ordine scelto)" % camp_piste.size(), 22, UI.GIALLO, false, 520))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 5)
	vs.add_child(g)
	for pid in Dati.PISTE:
		var k := camp_piste.find(pid)
		var nome := Campionato.nome_pista(pid)
		var etichetta := ("%d. " % (k + 1) if k >= 0 else "") + nome
		var b := UI.bottone(etichetta, 18 if etichetta.length() <= 17 else 15, UI.ROSSO if k >= 0 else UI.FONDO2, 170, 34)
		b.clip_text = true
		var id: String = pid
		b.pressed.connect(func():
			if camp_piste.has(id):
				camp_piste.erase(id)
			else:
				camp_piste.append(id)
			preparazione())
		g.add_child(b)

func _quante() -> int:
	var n := 0
	for i in posti.size():
		var t: String = posti[i].tipo
		if t == "ia" or t == "umano" or (t == "remoto" and posti[i].uid != ""):
			n += 1
	return n

## Ci sono i personaggi con le loro abilità? (su strada sempre, in circuito se scelto; solo con le regole avanzate)
func personaggi() -> bool:
	return regole == "avanzate" and (strada or abilita)

## Il nome del pilota di quell'auto: il personaggio, o il nome scelto, o «Pilota N».
func nome_pilota(i: int) -> String:
	if personaggi():
		return Dati.PILOTI[i].nome
	var n: String = str(nomi[i]).strip_edges() if i < nomi.size() else ""
	return n if n != "" else "Pilota %d" % (i + 1)

func _carta_pilota(i: int) -> Control:
	var pl: Dictionary = Dati.PILOTI[i]
	var posto: Dictionary = posti[i]
	var attivo: bool = posto.tipo != "chiuso"
	var col := Dati.colore_auto(i)
	var p := UI.pannello(UI.FONDO2, col if attivo else UI.FONDO2, 10, 3, 6)
	var vb := UI.colonna(4)
	p.add_child(vb)
	var im := UI.immagine("res://assets/piloti/%s%s.webp" % [pl.id, "_strada" if personaggi() else ""], Vector2(170, 196))
	im.modulate = Color.WHITE if attivo else Color(0.35, 0.35, 0.38)
	vb.add_child(im)
	if attivo and posto.tipo != "remoto" and not personaggi():
		# il nome si può cambiare
		var e := LineEdit.new()
		e.text = nome_pilota(i)
		e.max_length = 16
		e.custom_minimum_size = Vector2(170, 34)
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.add_theme_font_size_override("font_size", 20)
		e.select_all_on_focus = true
		e.text_changed.connect(func(t: String):
			while nomi.size() < Dati.PILOTI.size():
				nomi.append("")
			nomi[i] = t.strip_edges())
		e.text_submitted.connect(func(_t): e.release_focus())
		e.focus_exited.connect(func(): comando.emit("nomi"))
		vb.add_child(e)
	else:
		var nome := nome_pilota(i)
		if posto.tipo == "remoto":
			nome = str(posto.nome) if posto.uid != "" else "in attesa..."
		var l := UI.testo(nome, 22, UI.CHIARO if attivo else UI.GRIGIO)
		l.custom_minimum_size = Vector2(170, 34)
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	var b := UI.bottone(_nome_tipo(posto.tipo), 20, COL_TIPO[posto.tipo], 170, 40)
	b.pressed.connect(func():
		var tipi := TIPI_STANZA if stanza else TIPI_LOCALE
		var k := tipi.find(posto.tipo)
		posto.tipo = tipi[(k + 1) % tipi.size()]
		if posto.tipo != "remoto" and posto.uid != "":
			# il giocatore che era qui cerca un altro posto libero
			var u: String = posto.uid
			var n: String = posto.nome
			posto.uid = ""
			posto.nome = ""
			entra_giocatore(u, n)
		preparazione()
		comando.emit("posti"))
	vb.add_child(b)
	return p

func _nome_tipo(t: String) -> String:
	if stanza and tipo_stanza == "online":
		return {"umano": "Questo computer", "remoto": "Online"}.get(t, NOMI_TIPO[t])
	return NOMI_TIPO[t]

## Il link che apre il gioco ed entra direttamente nella gara online.
func link_gara() -> String:
	var base := url
	var k := base.find("telefono.html")
	if k >= 0:
		base = base.substr(0, k)
	return base + "?s=" + codice

## Un giocatore (telefono o ospite) è entrato: prende il primo posto «Telefono / online» libero.
func entra_giocatore(uid: String, nome: String) -> bool:
	for pz in posti:
		if pz.uid == uid:
			pz.nome = nome
			return true
	for pz in posti:
		if pz.tipo == "remoto" and pz.uid == "":
			pz.uid = uid
			pz.nome = nome
			return true
	return false

func esce_giocatore(uid: String) -> void:
	for pz in posti:
		if pz.uid == uid:
			pz.uid = ""
			pz.nome = ""

func imposta_stanza(c: String, u: String, tex: Texture2D) -> void:
	codice = c
	url = u
	qr_tex = tex
	if stanza:
		preparazione()

func _via() -> void:
	var lista := []
	for i in posti.size():
		var pz: Dictionary = posti[i]
		if pz.tipo == "ia" or pz.tipo == "umano":
			lista.append({"nome": nome_pilota(i), "pilota": i, "tipo": pz.tipo, "uid": ""})
		elif pz.tipo == "remoto" and pz.uid != "":
			lista.append({"nome": str(pz.nome).left(16), "pilota": i, "tipo": "remoto", "uid": pz.uid})
	if lista.is_empty():
		return
	var av := regole == "avanzate"
	var conf := {"regole": regole, "pista": Dati.PISTE[pista_n], "giri": giri, "auto": lista, "livello": livello, "stanza": stanza,
		"opzioni": {"strada": strada, "meteo": av and meteo, "libero": av and libero and not strada, "qualifiche": qualifiche and not strada,
			"abilita": av and (strada or abilita), "nitro": strada or nitro, "lari": av and lari and not strada, "kers": av and kers}}
	if campionato:
		conf.pista = camp_piste[0]
		conf["campionato"] = {"piste": camp_piste.duplicate()}
	via.emit(conf)

## Per i telefoni in sala d'attesa.
func vista_attesa() -> Dictionary:
	var l := []
	for i in posti.size():
		l.append({"p": i, "tp": posti[i].tipo, "u": posti[i].uid, "n": posti[i].nome, "nm": str(posti[i].nome) if posti[i].tipo == "remoto" and not personaggi() else nome_pilota(i)})
	return {"fase": "attesa", "sk": tipo_stanza, "abil": personaggi(), "pista": Dati.PISTE[pista_n], "giri": giri, "regole": regole, "posti": l, "str": strada,
		"mon": regole == "avanzate" and meteo, "lib": regole == "avanzate" and libero and not strada}
