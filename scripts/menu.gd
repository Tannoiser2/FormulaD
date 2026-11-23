class_name Menu
extends Control
## Menu principale e preparazione della gara (circuito, giri, regole, piloti); per chi ospita anche la
## sala d'attesa con il QR code per i telefoni.

signal via(conf: Dictionary)
signal comando(cosa: String)

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
var campionato := false
var camp_piste: Array = []      # i circuiti scelti per il campionato, nell'ordine in cui si corrono
var camp_salvato := ""          # riassunto del campionato in corso (vuoto se non ce n'è)
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
	_titolo(vb, "Motori, marce e dadi: la corsa da tavolo in versione digitale")
	vb.add_child(UI.spazio(0, 10))
	var voci := [
		["GARA SU QUESTO SCHERMO", "Da soli contro il computer, o in più a turno sullo stesso schermo", "locale", UI.ROSSO],
		["TV + TELEFONI", "Il tabellone su questo schermo, ogni pilota sceglie dal suo telefono (QR code)", "stanza_tv", Color(0.75, 0.42, 0.05)],
		["GARA ONLINE", "Ognuno gioca dal suo computer e vede la stessa gara: apri la gara e dai il codice", "stanza_online", Color(0.15, 0.35, 0.6)],
		["ENTRA IN UNA GARA ONLINE", "Gioca da questo computer in una gara online aperta da un altro", "entra", Color(0.12, 0.45, 0.5)],
	]
	voci.insert(1, ["CAMPIONATO", "Più Gran Premi di fila con qualifiche, punti, scuderie e Punti Pilota", "campionato", Color(0.55, 0.12, 0.45)])
	if camp_salvato != "":
		voci.insert(2, ["CONTINUA IL CAMPIONATO", camp_salvato, "camp_continua", Color(0.45, 0.1, 0.38)])
	if ha_salvataggio:
		voci.append(["RIPRENDI LA GARA SALVATA", "Continua dall'ultimo turno", "riprendi", Color(0.1, 0.55, 0.2)])
	voci.append(["REGOLE", "Il regolamento in breve, in italiano", "regole", UI.FONDO2])
	for vo in voci:
		var voce := UI.colonna(2)
		vb.add_child(voce)
		var b := UI.bottone(vo[0], 32, vo[3], 760, 54)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cosa: String = vo[2]
		b.pressed.connect(func(): _voce(cosa))
		voce.add_child(b)
		var d := UI.testo(vo[1], 20, UI.GRIGIO)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		voce.add_child(d)
	if avviso != "":
		var a := UI.testo(avviso, 24, UI.GIALLO, false, 900)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(a)

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
			_posti_iniziali()
			preparazione()
		"camp_continua":
			comando.emit("camp_continua")
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
	vs.add_child(_scelta("Regole", [["Base", "base"], ["Avanzate", "avanzate"]], regole, func(x):
		regole = x
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
	vs.add_child(_scelta("Computer", [["Prudente", 0], ["Normale", 1], ["Esperto", 2]], livello, func(x):
		livello = x
		preparazione()))
	var nota0 := "Base: 18 Punti Struttura per tutto. Avanzate: gomme, freni, cambio, carrozzeria, motore, tenuta di strada, scie e detriti."
	var nota := nota0
	if campionato:
		nota = "Prima di ogni GP le qualifiche a settori. Punti 8-6-4-2-1, classifica scuderie e premio Villeneuve. Ogni pilota ha 1 Punto Pilota per ritirare il dado, +1 per i primi tre di ogni GP."
	elif qualifiche and not strada:
		nota = "Qualifiche a settori: 3 tiri a giro, Q1-Q2-Q3 con 8 auto o più. " + nota0
	elif strada:
		nota = "Su strada: niente box, Nitro una volta per giro, controllo al traguardo." + (" Ogni pilota ha la sua auto e un'abilità." if regole == "avanzate" else "")
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
				vq.add_child(UI.testo("Gli altri aprono il gioco sul loro computer, scelgono «Entra in una gara online» e scrivono il codice, oppure aprono il link.", 20, UI.CHIARO, false, 480))
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

func _carta_pilota(i: int) -> Control:
	var pl: Dictionary = Dati.PILOTI[i]
	var posto: Dictionary = posti[i]
	var attivo: bool = posto.tipo != "chiuso"
	var col := Dati.colore_auto(i)
	var p := UI.pannello(UI.FONDO2, col if attivo else UI.FONDO2, 10, 3, 6)
	var vb := UI.colonna(4)
	p.add_child(vb)
	var im := UI.immagine("res://assets/piloti/%s.webp" % pl.id, Vector2(170, 196))
	im.modulate = Color.WHITE if attivo else Color(0.35, 0.35, 0.38)
	vb.add_child(im)
	var nome: String = pl.nome
	if posto.tipo == "remoto":
		nome = str(posto.nome) if posto.uid != "" else "in attesa..."
	var l := UI.testo(nome, 22, UI.CHIARO if attivo else UI.GRIGIO)
	l.custom_minimum_size.x = 170
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
		var pl: Dictionary = Dati.PILOTI[i]
		if pz.tipo == "ia" or pz.tipo == "umano":
			lista.append({"nome": pl.nome, "pilota": i, "tipo": pz.tipo, "uid": ""})
		elif pz.tipo == "remoto" and pz.uid != "":
			lista.append({"nome": str(pz.nome).left(16), "pilota": i, "tipo": "remoto", "uid": pz.uid})
	if lista.is_empty():
		return
	var av := regole == "avanzate"
	var conf := {"regole": regole, "pista": Dati.PISTE[pista_n], "giri": giri, "auto": lista, "livello": livello, "stanza": stanza,
		"opzioni": {"strada": strada, "meteo": av and meteo, "libero": av and libero and not strada, "qualifiche": qualifiche and not strada}}
	if campionato:
		conf.pista = camp_piste[0]
		conf["campionato"] = {"piste": camp_piste.duplicate()}
	via.emit(conf)

## Per i telefoni in sala d'attesa.
func vista_attesa() -> Dictionary:
	var l := []
	for i in posti.size():
		l.append({"p": i, "tp": posti[i].tipo, "u": posti[i].uid, "n": posti[i].nome})
	return {"fase": "attesa", "sk": tipo_stanza, "pista": Dati.PISTE[pista_n], "giri": giri, "regole": regole, "posti": l, "str": strada,
		"mon": regole == "avanzate" and meteo, "lib": regole == "avanzate" and libero and not strada}
