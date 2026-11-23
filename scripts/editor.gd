class_name EditorPiste
extends Control
## L'editor delle piste: una schermata a parte. Si sceglie il circuito, la mappatura mostra un pallino per casella
## (colore della corsia, punta nel verso della casella) e si correggono traiettorie, posizione, rotazione e corsia
## delle caselle, se ne aggiungono o tolgono. Tutto resta salvato su questo dispositivo e si esporta in JSON.

signal esci

var rete: Rete
var mondo: Mondo
var pista: Pista
var pid := "FDMonaco"
var sel := ""            # la casella scelta (anello giallo)
var dest := ""           # la seconda casella, per le traiettorie (anello azzurro)
var attesa := ""         # "" | "sposta" | "nuova": il prossimo tocco sul tabellone è un punto
var _conferma := ""      # comando che aspetta il secondo tocco per conferma
var _storia: Array = []  # per annullare: le modifiche salvate prima di ogni passo

var pannello: PanelContainer
var l_pista: Label
var l_conta: Label
var l_sel: Label
var l_aiuto: Label
var b_agg: Button
var b_eli: Button
var b_annulla: Button
var b_togli: Button
var b_azzera: Button
var _di_casella: Array = []   # bottoni che servono una casella scelta

const NOMI_CORSIA := ["box", "destra", "centro", "sinistra"]

func _ready() -> void:
	UI.prepara()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pannello = UI.pannello(UI.FONDO, UI.ROSSO, 0, 0, 14)
	pannello.anchor_left = 1.0
	pannello.anchor_right = 1.0
	pannello.anchor_bottom = 1.0
	pannello.offset_left = -470
	add_child(pannello)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pannello.add_child(sc)
	var vb := UI.colonna(8)
	vb.custom_minimum_size.x = 430
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)

	var t := UI.testo("EDITOR PISTE", 36, UI.ROSSO, true)
	vb.add_child(t)
	var rp := UI.riga(8)
	vb.add_child(rp)
	var bp := UI.bottone("<", 26, UI.FONDO2, 52, 46)
	bp.pressed.connect(func(): _cambia_pista(-1))
	rp.add_child(bp)
	l_pista = UI.testo("", 24, UI.GIALLO, true)
	l_pista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_pista.custom_minimum_size.x = 300
	l_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_pista.clip_text = true
	rp.add_child(l_pista)
	var bn := UI.bottone(">", 26, UI.FONDO2, 52, 46)
	bn.pressed.connect(func(): _cambia_pista(1))
	rp.add_child(bn)
	l_conta = UI.testo("", 18, UI.GRIGIO, false, 430)
	vb.add_child(l_conta)

	l_sel = UI.testo("", 20, UI.CHIARO, false, 430)
	l_sel.custom_minimum_size.y = 64
	vb.add_child(l_sel)

	vb.add_child(_titoletto("Traiettorie"))
	var rt := UI.riga(8)
	vb.add_child(rt)
	b_agg = _bottone(rt, "Aggiungi", "agg", Color(0.15, 0.5, 0.2))
	b_eli = _bottone(rt, "Elimina", "eli", Color(0.6, 0.15, 0.15))

	vb.add_child(_titoletto("Posizione"))
	var rs := UI.riga(6)
	vb.add_child(rs)
	_di_casella.append(_bottone(rs, "Sposta qui...", "sposta", UI.FONDO2, 180))
	for x in [["Avanti", "av"], ["Indietro", "in"]]:
		_di_casella.append(_bottone(rs, x[0], x[1], UI.FONDO2))
	var rs2 := UI.riga(6)
	vb.add_child(rs2)
	for x in [["A sinistra", "sx"], ["A destra", "dx"]]:
		_di_casella.append(_bottone(rs2, x[0], x[1], UI.FONDO2))

	vb.add_child(_titoletto("Rotazione"))
	var rr := UI.riga(5)
	vb.add_child(rr)
	for g in [-15, -5, -1, 1, 5, 15]:
		_di_casella.append(_bottone(rr, ("%+d" % g), "r%d" % g, UI.FONDO2, 0, 22))
	var rr2 := UI.riga(6)
	vb.add_child(rr2)
	_di_casella.append(_bottone(rr2, "Allinea alla traiettoria", "allinea", UI.FONDO2))

	vb.add_child(_titoletto("Corsia"))
	var rc := UI.riga(5)
	vb.add_child(rc)
	for k in [1, 2, 3, 0]:
		var col: Color = Mondo.COL_CORSIA[k].darkened(0.35)
		_di_casella.append(_bottone(rc, NOMI_CORSIA[k].capitalize(), "l%d" % k, col, 0, 20))

	vb.add_child(_titoletto("Caselle"))
	var rn := UI.riga(6)
	vb.add_child(rn)
	_bottone(rn, "Nuova casella...", "nuova", Color(0.15, 0.4, 0.55), 200)
	b_togli = _bottone(rn, "Togli casella", "togli", Color(0.6, 0.15, 0.15))
	_di_casella.append(b_togli)

	l_aiuto = UI.testo("", 19, UI.GIALLO, false, 430)
	l_aiuto.custom_minimum_size.y = 80
	vb.add_child(l_aiuto)

	vb.add_child(UI.spazio(0, 4))
	var rf := UI.riga(6)
	vb.add_child(rf)
	b_annulla = _bottone(rf, "Annulla", "annulla", UI.FONDO2)
	_bottone(rf, "Esporta JSON", "esporta", Color(0.15, 0.35, 0.6))
	var rf2 := UI.riga(6)
	vb.add_child(rf2)
	b_azzera = _bottone(rf2, "Rifai la pista originale", "azzera", Color(0.45, 0.2, 0.1))
	var rf3 := UI.riga(6)
	vb.add_child(rf3)
	_bottone(rf3, "Vista intera", "vista", UI.FONDO2)
	_bottone(rf3, "Torna al menu", "esci", UI.ROSSO)

func _titoletto(t: String) -> Label:
	var l := UI.testo(t.to_upper(), 18, UI.GRIGIO, true)
	return l

func _bottone(dove: HBoxContainer, t: String, cosa: String, col: Color, larg := 0.0, dim := 20) -> Button:
	var b := UI.bottone(t, dim, col, larg, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): _premi(cosa))
	dove.add_child(b)
	return b

## Il tocco cade sul pannello? (allora la telecamera non si muove)
func sopra(p: Vector2) -> bool:
	return pannello.get_global_rect().has_point(p)

# ------------------------------------------------------------------ apertura e chiusura

func apri(quale: String) -> void:
	visible = true
	pid = quale if Dati.PISTE.has(quale) else Dati.PISTE[0]
	if not mondo.tocco_mappa.is_connected(_tocco):
		mondo.tocco_mappa.connect(_tocco)
	mondo.editor_attivo = true
	_storia.clear()
	_carica()

func chiudi() -> void:
	visible = false
	mondo.editor_attivo = false
	mondo.segna_scelte([])
	mondo.anteprima_mappa("")
	mondo.mostra_mappa(false)
	attesa = ""

func _carica(inquadra := true) -> void:
	pista = Pista.ricarica(pid)
	Modifiche.applica(rete, pista)
	mondo.carica_pista(pista)
	mondo.mostra_mappa(true)
	if inquadra:
		mondo.vista_dall_alto(470.0)
	if not pista.per_id.has(sel):
		sel = ""
	if not pista.per_id.has(dest):
		dest = ""
	_aggiorna()

func _cambia_pista(d: int) -> void:
	var i := Dati.PISTE.find(pid)
	pid = Dati.PISTE[posmod(i + d, Dati.PISTE.size())]
	sel = ""
	dest = ""
	attesa = ""
	_storia.clear()
	_carica()

# ------------------------------------------------------------------ tocchi sul tabellone

func _tocco(p: Vector2, cid: String) -> void:
	if not visible:
		return
	_conferma = ""
	if attesa == "sposta" and sel != "":
		_ricorda()
		pista.sposta_casella(sel, p)
		Modifiche.segna_cella(rete, pid, sel, {"p": pista.per_id[sel].p})
		attesa = ""
		_ridisegna()
		return
	if attesa == "nuova":
		_ricorda()
		var nid := _nuovo_id()
		var ref = pista.per_id.get(sel) if sel != "" else null
		var r := float(ref.r) if ref else 0.0
		var l := int(ref.l) if ref else 2
		var cu := int(ref.c) if ref else 0
		pista.nuova_casella(nid, p, r, l, cu)
		Modifiche.segna_cella(rete, pid, nid, {"nuova": true, "p": pista.per_id[nid].p, "r": r, "l": l, "c": cu})
		attesa = ""
		sel = nid
		dest = ""
		_ridisegna()
		return
	if cid == "":
		return
	if sel == "" or dest != "" or cid == sel:
		sel = cid
		dest = ""
	else:
		dest = cid
	_aggiorna()

func _nuovo_id() -> String:
	var k := 1
	while pista.per_id.has("e.%d" % k):
		k += 1
	return "e.%d" % k

# ------------------------------------------------------------------ comandi

func _premi(cosa: String) -> void:
	var conferma := _conferma == cosa
	_conferma = ""
	match cosa:
		"esci":
			chiudi()
			esci.emit()
			return
		"vista":
			mondo.vista_dall_alto(470.0)
			return
		"esporta":
			_esporta()
			return
		"annulla":
			_annulla()
			return
		"azzera":
			if not conferma:
				_conferma = cosa
				_aggiorna("Premi di nuovo «Rifai la pista originale» per cancellare tutte le correzioni di %s." % pista.nome)
				return
			_ricorda()
			Modifiche.azzera(rete, pid)
			_carica(false)
			return
		"nuova":
			attesa = "" if attesa == "nuova" else "nuova"
			_aggiorna()
			return
	if cosa in ["agg", "eli"]:
		if sel == "" or dest == "":
			return
		_ricorda()
		var ok: bool = Modifiche.aggiungi_traiettoria(rete, pista, sel, dest) if cosa == "agg" else Modifiche.elimina_traiettoria(rete, pista, sel, dest)
		if not ok:
			_storia.pop_back()
		sel = dest
		dest = ""
		_ridisegna()
		return
	if sel == "":
		return
	var c: Dictionary = pista.per_id[sel]
	var a := deg_to_rad(float(c.r))
	var av := Vector2(cos(a), sin(a))
	var passo: float = pista.cella * 0.08
	match cosa:
		"sposta":
			attesa = "" if attesa == "sposta" else "sposta"
			_aggiorna()
			return
		"av", "in", "sx", "dx":
			var d: Vector2 = {"av": av, "in": -av, "sx": Vector2(av.y, -av.x), "dx": Vector2(-av.y, av.x)}[cosa]
			_ricorda()
			pista.sposta_casella(sel, pista.pos(sel) + d * passo)
			Modifiche.segna_cella(rete, pid, sel, {"p": pista.per_id[sel].p})
		"allinea":
			var r := _verso_naturale(sel)
			if is_nan(r):
				_aggiorna("Questa casella non ha caselle prima e dopo nella sua corsia: girala a mano.")
				return
			_ricorda()
			pista.ruota_casella(sel, r)
			Modifiche.segna_cella(rete, pid, sel, {"r": pista.per_id[sel].r})
		"togli":
			if not conferma:
				_conferma = cosa
				_aggiorna("Premi di nuovo «Togli casella» per togliere %s con tutte le sue traiettorie." % sel)
				return
			_ricorda()
			var nuova: bool = Modifiche.celle(rete, pid).get(sel, {}).get("nuova", false)
			pista.togli_casella(sel)
			Modifiche.segna_cella(rete, pid, sel, {"tolta": true, "nuova": nuova})
			sel = ""
			dest = ""
		_:
			if cosa.begins_with("r"):
				_ricorda()
				pista.ruota_casella(sel, float(c.r) + float(cosa.substr(1)))
				Modifiche.segna_cella(rete, pid, sel, {"r": pista.per_id[sel].r})
			elif cosa.begins_with("l"):
				_ricorda()
				pista.corsia_casella(sel, int(cosa.substr(1)))
				Modifiche.segna_cella(rete, pid, sel, {"l": int(cosa.substr(1))})
	_ridisegna()

## Il verso dalla casella che arriva qui a quella dopo (nella stessa corsia se c'è).
func _verso_naturale(cid: String) -> float:
	var c: Dictionary = pista.per_id[cid]
	var dopo := ""
	for n in c.get("n", []):
		if pista.per_id.has(n) and (dopo == "" or int(pista.per_id[n].l) == int(c.l)):
			dopo = n
	var prima := ""
	for o in pista.caselle:
		if Array(o.get("n", [])).has(cid) and (prima == "" or int(o.l) == int(c.l)):
			prima = o.id
	var da := pista.pos(prima) if prima != "" else pista.pos(cid)
	var a := pista.pos(dopo) if dopo != "" else pista.pos(cid)
	if da.distance_to(a) < 1.0:
		return NAN
	return rad_to_deg((a - da).angle())

# ------------------------------------------------------------------ annulla, esporta

func _istantanea() -> Dictionary:
	var d := {}
	for k in ["fd_traiettorie_%s", "fd_traiettorie_rimosse_%s", "fd_celle_%s"]:
		d[k % pid] = rete.carica(k % pid)
	return d

func _ricorda() -> void:
	_storia.append(_istantanea())
	if _storia.size() > 60:
		_storia.pop_front()

func _annulla() -> void:
	if _storia.is_empty():
		return
	var d: Dictionary = _storia.pop_back()
	for k in d:
		rete.salva(k, d[k])
	_carica(false)

func _esporta() -> void:
	var dati := Modifiche.pacchetto(rete)
	if dati.is_empty():
		_aggiorna("Non ci sono ancora correzioni da esportare.")
		return
	var nome := "FormulaD-piste-%s.json" % Time.get_date_string_from_system()
	var dove := rete.scarica(nome, JSON.stringify(dati, "  "))
	_aggiorna("Esportate le correzioni di %d piste%s. Mandami il file per inserirle nel gioco per tutti." % [dati.piste.size(), " in " + dove if dove != "" else ""])

# ------------------------------------------------------------------ disegno e testi

func _ridisegna() -> void:
	mondo.mostra_mappa(true)
	_aggiorna()

func _aggiorna(avviso := "") -> void:
	if pista == null:
		return
	l_pista.text = Campionato.nome_pista(pid)
	var n := Modifiche.quante(rete, pid)
	l_conta.text = "Nessuna correzione su questo circuito." if n == 0 else "Correzioni salvate su questo dispositivo: %d" % n
	var scelte := []
	if sel != "":
		scelte.append(sel)
	if dest != "":
		scelte.append(dest)
	mondo.segna_scelte(scelte)
	if sel != "" and dest != "":
		mondo.anteprima_mappa(sel, dest)
	elif sel != "":
		mondo.anteprima_mappa(sel)
	else:
		mondo.anteprima_mappa("")
	var esiste := sel != "" and dest != "" and Array(pista.per_id[sel].get("n", [])).has(dest)
	b_agg.disabled = sel == "" or dest == "" or esiste
	b_eli.disabled = not esiste
	for b in _di_casella:
		b.disabled = sel == ""
	b_annulla.disabled = _storia.is_empty()
	b_azzera.disabled = n == 0
	b_azzera.text = "Conferma: rifai originale" if _conferma == "azzera" else "Rifai la pista originale"
	b_togli.text = "Conferma: togli" if _conferma == "togli" else "Togli casella"
	if sel == "":
		l_sel.text = "Tocca un pallino sul tabellone per sceglierlo."
	else:
		var c: Dictionary = pista.per_id[sel]
		var testo := "Casella %s: corsia %s, %s, verso %d gradi" % [sel, NOMI_CORSIA[int(c.l)] if int(c.l) <= 3 else str(c.l),
			("curva %d" % int(c.c)) if int(c.c) > 0 else "rettilineo", int(round(float(c.r)))]
		if dest != "":
			testo += "\nPoi %s: %s" % [dest, "c'è già la traiettoria" if esiste else "nessuna traiettoria"]
		l_sel.text = testo
	if avviso != "":
		l_aiuto.text = avviso
	elif attesa == "sposta":
		l_aiuto.text = "Tocca sul tabellone il punto dove mettere il centro di %s." % sel
	elif attesa == "nuova":
		l_aiuto.text = "Tocca sul tabellone il punto della nuova casella. Prende corsia, curva e verso della casella scelta; poi aggiungi le traiettorie verso e da lei."
	elif sel != "" and dest == "":
		l_aiuto.text = "Tocca un secondo pallino per aggiungere o togliere la traiettoria fra i due (bianca nella corsia, rossa se cambia corsia)."
	else:
		l_aiuto.text = "Trascina per spostare la vista, rotella o due dita per lo zoom."
