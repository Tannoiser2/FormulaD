extends Node
## Formula D: mette insieme motore, tavolo 3D, interfaccia, menu e rete.
## Modi: gara su questo schermo, stanza (TV + telefoni / online) e ospite in una stanza altrui.

var rete: Rete
var mondo: Mondo
var hud: Interfaccia
var menu: Menu
var motore: Motore
var modo := "menu"            # menu | locale | stanza | ospite
var livello := 1
var _gira := false
var _seq := 0
var _log: Array = []
var _coda_ospite: Array = []
var _ospite_gira := false
var _ultimo_n := -1
var _vista: Dictionary = {}
var _ultima_conf: Dictionary = {}
var _nome_ospite := "Pilota"
var _stanza_chiesta := false
var auto_prova := false       # prove: la gara va avanti da sola
var _via_con := 0             # prove: la stanza parte da sola quando sono entrati tanti giocatori
var _coda_azioni: Array = []
var _autoguida := false       # prove: l'ospite sceglie da solo

func _ready() -> void:
	rete = Rete.new()
	add_child(rete)
	rete.evento.connect(_evento_rete)
	mondo = Mondo.new()
	add_child(mondo)
	var strato := CanvasLayer.new()
	add_child(strato)
	hud = Interfaccia.new()
	strato.add_child(hud)
	hud.visible = false
	hud.decisione.connect(_decisione)
	hud.comando.connect(_comando)
	menu = Menu.new()
	strato.add_child(menu)
	menu.via.connect(_via)
	menu.comando.connect(_comando)
	menu.in_rete = rete.web
	mondo.sopra_ui = func(p): return menu.visible or hud.sopra(p)
	mondo.casella_toccata.connect(_casella)
	mondo.carica_pista(Pista.carica("FDMonaco"))
	menu.ha_salvataggio = rete.carica("fd_gara") != ""
	menu.principale()
	if rete.web and not menu.ha_salvataggio:
		rete.chiedi_remoto()
	var par := rete.parametri()
	if par.has("veloce"):
		mondo.velocita = max(0.5, float(par.veloce))
	if par.has("stanza"):
		_via_con = int(par.stanza)
		menu.pista_n = int(par.get("pista_n", 0))
		menu.regole = str(par.get("regole", "avanzate"))
		menu.giri = int(par.get("giri", 1))
		menu._voce("stanza")
	elif par.has("s"):
		# aperto con il codice di una stanza: entra come ospite
		_autoguida = par.has("autoguida")
		_entra(str(par.s), str(par.get("nome", "")))
	elif par.has("auto"):
		auto_prova = true
		var lista := []
		for i in int(par.get("bot", 6)):
			lista.append({"nome": Dati.PILOTI[i].nome, "pilota": i, "tipo": "ia", "uid": ""})
		_via({"regole": str(par.get("regole", "avanzate")), "pista": str(par.get("pista", "FDMonaco")), "giri": int(par.get("giri", 1)),
			"auto": lista, "livello": 1, "stanza": false})

# ------------------------------------------------------------------ comandi

func _comando(cosa: String) -> void:
	if cosa.begins_with("guarda:"):
		var i := int(cosa.split(":")[1])
		var c: String = mondo.auto_casella.get(i, "")
		if c != "":
			mondo.inquadra([c], 3.0)
		return
	match cosa:
		"regole":
			hud.visible = true
			hud.mostra_regole()
			if modo == "menu":
				_solo_velo()
		"vista":
			mondo.vista_generale()
		"gira_sx":
			mondo.gira(-PI / 6.0)
		"gira_dx":
			mondo.gira(PI / 6.0)
		"inclina":
			mondo.inclina()
		"menu":
			var voci := [["Torna alla gara", "chiudi"], ["Schermo intero", "schermo"]]
			if modo == "stanza":
				voci.append(["Mostra il codice della stanza", "codice"])
			voci.append(["Animazioni: %s" % ("veloci" if mondo.velocita > 1.5 else "normali"), "velocita"])
			voci.append(["Abbandona e torna al menu", "esci"])
			hud.mostra_menu(voci)
		"schermo":
			rete.schermo_intero()
			if not rete.web:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		"velocita":
			mondo.velocita = 1.0 if mondo.velocita > 1.5 else 2.5
		"codice":
			hud.cronaca("Stanza %s  -  %s" % [rete.codice, rete.url], "ordine")
		"decidi":
			if motore != null and motore.s.attesa != null and not _gira:
				var az := IA.decidi(motore, livello)
				if motore.applica(az):
					mondo.togli_opzioni()
					_ciclo()
		"rivincita":
			hud.chiudi_velo()
			if not _ultima_conf.is_empty():
				_via(_ultima_conf)
		"esci":
			_al_menu()
		"apri_stanza":
			_stanza_chiesta = true
			rete.avvia()
		"chiudi_stanza":
			_stanza_chiesta = false
			rete.chiudi()
		"posti":
			_pubblica_attesa()
		"entra":
			_chiedi_codice()
		"riprendi":
			_riprendi()

func _solo_velo() -> void:
	# le regole viste dal menu: si vede solo la finestra
	for c in hud._pannelli:
		c.visible = false
	menu.visible = false
	await hud.velo.tree_exited
	if modo == "menu":
		hud.visible = false
		menu.visible = true
		for c in hud._pannelli:
			c.visible = c != hud.p_dado

func _al_menu() -> void:
	if modo == "stanza" or modo == "ospite":
		rete.chiudi()
	modo = "menu"
	motore = null
	_gira = false
	_coda_ospite.clear()
	hud.chiudi_velo()
	hud.visible = false
	mondo.togli_opzioni()
	mondo.vista_generale()
	menu.visible = true
	menu.ha_salvataggio = rete.carica("fd_gara") != ""
	menu.principale()

# ------------------------------------------------------------------ gara (chi ospita o in locale)

func _via(conf: Dictionary) -> void:
	_ultima_conf = conf
	livello = int(conf.get("livello", 1))
	modo = "stanza" if conf.get("stanza", false) else "locale"
	motore = Motore.nuova(conf)
	_apri_gara()
	motore.avanza()
	_ciclo()

func _apri_gara() -> void:
	menu.visible = false
	hud.visible = true
	hud.ospite = false
	hud.chiudi_velo()
	hud.pulisci_dadi()
	for c in hud.cronaca_box.get_children():
		c.queue_free()
	_log.clear()
	mondo.carica_pista(motore.pista)
	for a in motore.s.auto:
		mondo.metti_auto(a.i, a.pilota, a.nome, a.c)
	var danni := []
	for d in motore.s.danni:
		danni.append(d.c)
	mondo.sincronizza_danni(danni)

func _miei() -> Array:
	var l := []
	if motore == null:
		return l
	for a in motore.s.auto:
		if a.tipo == "umano":
			l.append(a.i)
	return l

func _ciclo() -> void:
	if _gira or motore == null:
		return
	_gira = true
	while motore != null:
		var m := motore
		var ev := m.preleva_eventi()
		var vista := m.vista()
		_pubblica(vista, ev)
		await _mostra(ev)
		if motore != m:
			break
		_allinea(vista)
		hud.aggiorna(vista, _miei())
		if m.s.fase == "fine":
			mondo.togli_opzioni()
			hud.chiedi()
			rete.salva("fd_gara", "")
			if not auto_prova:
				hud.mostra_fine()
			break
		var a: Dictionary = m.s.auto[m.s.attesa.auto]
		if m.s.attesa.tipo == "mossa" and (a.tipo != "ia" or mondo.velocita < 3.0):
			mondo.mostra_opzioni(vista.att.opz, a.c)
		else:
			mondo.togli_opzioni()
			if a.c != "":
				mondo.inquadra([a.c], 3.5)
		mondo.evidenzia_auto(a.i)
		hud.chiedi()
		if a.tipo == "ia" or auto_prova:
			await get_tree().create_timer(0.35 / mondo.velocita).timeout
			if motore != m:
				break
			var az := IA.decidi(m, livello)
			if not m.applica(az):
				push_error("IA: azione rifiutata %s" % az)
				break
			mondo.togli_opzioni()
			continue
		_salva()
		break
	_gira = false
	_prova_azioni()

## Le mosse arrivate dai telefoni e dagli ospiti: possono arrivare mentre lo schermo sta ancora mostrando
## i movimenti, quindi aspettano in coda. Ognuna dice a quale stato risponde: quelle vecchie si scartano.
func _prova_azioni() -> void:
	if motore == null or _gira or motore.s.attesa == null:
		return
	var a: Dictionary = motore.s.auto[motore.s.attesa.auto]
	var coda := _coda_azioni
	_coda_azioni = []
	for e in coda:
		var az = JSON.parse_string(str(e.p))
		if not (az is Dictionary) or int(az.get("n", -1)) != _seq:
			continue
		if a.tipo == "remoto" and a.uid == str(e.uid) and motore.applica(az):
			mondo.togli_opzioni()
			_ciclo()
			return

func _decisione(az: Dictionary) -> void:
	if modo == "ospite":
		var con_n := az.duplicate()
		con_n["n"] = _ultimo_n
		rete.azione("az", con_n)
		mondo.togli_opzioni()
		hud.p_azione.visible = false
		return
	if motore == null or _gira or motore.s.attesa == null:
		return
	var a: Dictionary = motore.s.auto[motore.s.attesa.auto]
	if a.tipo != "umano":
		return
	if motore.applica(az):
		mondo.togli_opzioni()
		_ciclo()

func _casella(cid: String) -> void:
	if not mondo.opzioni.has(cid):
		return
	mondo.segna_scelta(cid)
	hud.scegli_opzione(mondo.opzioni[cid])

## Mostra uno alla volta gli eventi del motore.
func _mostra(ev: Array) -> void:
	for e in ev:
		match e.t:
			"msg":
				hud.cronaca(e.testo, e.tipo)
				_log.append(e.testo)
				if _log.size() > 8:
					_log.pop_front()
			"tocca":
				mondo.evidenzia_auto(int(e.auto))
				hud.pulisci_dadi()
			"dado":
				var nome := _nome_auto(int(e.auto))
				rete.suono("dado")
				await hud.mostra_dado(int(e.marcia), int(e.valore), int(e.faccia), nome, 0.6 / mondo.velocita)
			"nero":
				hud.mostra_nero(int(e.valore), str(e.motivo), bool(e.male))
				rete.suono("botto" if e.male else "nero")
				await get_tree().create_timer(0.55 / mondo.velocita).timeout
			"muovi":
				mondo.togli_opzioni()
				mondo.inquadra(e.percorso, 2.5)
				rete.suono("motore")
				await mondo.muovi_auto(int(e.auto), e.percorso)
			"testacoda":
				rete.suono("gomme")
				await mondo.testacoda(int(e.auto))
			"fuori":
				rete.suono("botto")
				await mondo.elimina_auto(int(e.auto))
			"arrivo":
				rete.suono("arrivo")
				await mondo.arriva_auto(int(e.auto))
			"segnalino":
				mondo.metti_danno(str(e.c))

func _nome_auto(i: int) -> String:
	if motore != null:
		return motore.s.auto[i].nome
	if not _vista.is_empty():
		return str(_vista.auto[i].n)
	return ""

## Dopo le animazioni: le auto e i segnalini stanno dove dice lo stato.
func _allinea(vista: Dictionary) -> void:
	for i in vista.auto.size():
		var a: Dictionary = vista.auto[i]
		if str(mondo.auto_casella.get(i, "?")) != str(a.c):
			mondo.metti_auto(i, int(a.p), str(a.n), str(a.c))
	mondo.sincronizza_danni(vista.danni)

func _salva() -> void:
	if motore == null or auto_prova:
		return
	var testo := var_to_str({"s": motore.s, "livello": livello, "stanza": modo == "stanza"})
	rete.salva("fd_gara", testo)
	rete.salva_remoto(testo)

func _riprendi() -> void:
	var d = str_to_var(rete.carica("fd_gara"))
	if not (d is Dictionary) or not d.has("s"):
		menu.avviso = "Non trovo una gara salvata."
		menu.ha_salvataggio = false
		menu.principale()
		return
	var m := Motore.da_salvataggio(var_to_str(d.s))
	if m == null:
		menu.avviso = "La gara salvata non si può più aprire."
		menu.principale()
		return
	motore = m
	livello = int(d.get("livello", 1))
	modo = "stanza" if d.get("stanza", false) else "locale"
	_apri_gara()
	if modo == "stanza":
		# i piloti da telefono rientrano con il nuovo codice
		_stanza_chiesta = true
		rete.avvia()
	hud.cronaca("Gara ripresa dal turno %d" % motore.s.turno, "ordine")
	_ciclo()

# ------------------------------------------------------------------ rete: stanza

func _pubblica(vista: Dictionary, ev: Array) -> void:
	if modo != "stanza" or rete.codice == "":
		return
	_seq += 1
	var d := vista.duplicate()
	var leggeri := []
	var testi := _log.duplicate()
	for e in ev:
		if e.t == "msg":
			testi.append(e.testo)
		elif e.t != "usura" and e.t != "box" and e.t != "turno" and e.t != "giro":
			leggeri.append(e)
	d["ev"] = leggeri
	d["n"] = _seq
	d["log"] = testi.slice(max(0, testi.size() - 6))
	d["vel"] = mondo.velocita
	d["iw"] = int(motore.pista.img.x)
	# dove stanno le auto, in pixel del tabellone (per la mappa sui telefoni)
	var caselle := {}
	for a in motore.s.auto:
		if a.c != "":
			var p := motore.pista.pos(a.c)
			caselle[a.c] = [int(p.x), int(p.y)]
	d["caselle"] = caselle
	rete.stato(d)

func _pubblica_attesa() -> void:
	if rete.codice != "" and modo == "menu" and menu.stanza:
		rete.stato(menu.vista_attesa())

func _qr(testo: String) -> Texture2D:
	var s := rete.qr(testo)
	var n := int(round(sqrt(s.length())))
	if n < 10:
		return null
	var im := Image.create(n + 4, n + 4, false, Image.FORMAT_RGB8)
	im.fill(Color.WHITE)
	for y in n:
		for x in n:
			if s[y * n + x] == "1":
				im.set_pixel(x + 2, y + 2, Color.BLACK)
	return ImageTexture.create_from_image(im)

func _evento_rete(e: Dictionary) -> void:
	match e.get("e"):
		"stanza":
			menu.imposta_stanza(rete.codice, rete.url, _qr(rete.url))
			if modo == "stanza" and motore != null:
				hud.cronaca("Stanza aperta: codice %s" % rete.codice, "ordine")
				_pubblica(motore.vista(), [])
			else:
				_pubblica_attesa()
		"entra":
			var uid := str(e.uid)
			var nome := str(e.get("nome", "Pilota")).left(16)
			if modo == "menu" and menu.stanza:
				menu.entra_giocatore(uid, nome)
				menu.preparazione()
				_pubblica_attesa()
				if _via_con > 0:
					var dentro := 0
					for pz in menu.posti:
						if pz.uid != "":
							dentro += 1
					if dentro >= _via_con:
						_via_con = 0
						await get_tree().create_timer(2.0).timeout
						menu._via()
			elif motore != null:
				for a in motore.s.auto:
					if a.uid == uid:
						hud.cronaca("%s è di nuovo collegato" % a.nome, "info")
				_pubblica(motore.vista(), [])
		"esce":
			if modo == "menu" and menu.stanza:
				menu.esce_giocatore(str(e.uid))
				menu.preparazione()
				_pubblica_attesa()
		"azione":
			if str(e.get("k")) == "az":
				_coda_azioni.append(e)
				_prova_azioni()
		"dentro":
			modo = "ospite"
			menu.visible = false
			hud.visible = true
			hud.ospite = true
			hud.cronaca("Sei nella stanza %s: aspetta il via" % rete.codice, "ordine")
			hud.p_azione.visible = false
		"stato":
			var d = JSON.parse_string(str(e.j))
			if d is Dictionary:
				_coda_ospite.append(d)
				_ciclo_ospite()
		"salvataggio":
			if str(e.get("j", "")) != "" and rete.carica("fd_gara") == "":
				rete.salva("fd_gara", str(e.j))
				menu.ha_salvataggio = true
				if modo == "menu" and not menu.stanza:
					menu.principale()
		"errore":
			if modo == "ospite" or modo == "menu":
				menu.avviso = "Rete: %s" % str(e.get("msg", "errore"))
				if modo == "ospite":
					_al_menu()
				elif not menu.stanza:
					menu.principale()

# ------------------------------------------------------------------ rete: ospite

func _chiedi_codice() -> void:
	if not rete.web:
		menu.avviso = "Per entrare in una stanza apri la versione web del gioco."
		menu.principale()
		return
	var c = rete.fr.chiedi("Codice della stanza (4 lettere):", "")
	if c == null or str(c).strip_edges().length() != 4:
		return
	_entra(str(c).strip_edges().to_upper())

func _entra(c: String, gia := "") -> void:
	var n = gia
	if n == "":
		n = rete.fr.chiedi("Il tuo nome:", rete.carica("fd_nome")) if rete.web else "Pilota"
	if n == null or str(n).strip_edges() == "":
		n = "Pilota"
	_nome_ospite = str(n).strip_edges().left(16)
	rete.salva("fd_nome", _nome_ospite)
	_ultimo_n = -1
	rete.entra(c, _nome_ospite)

func _ciclo_ospite() -> void:
	if _ospite_gira:
		return
	_ospite_gira = true
	while not _coda_ospite.is_empty() and modo == "ospite":
		var d: Dictionary = _coda_ospite.pop_front()
		if str(d.get("fase")) == "attesa":
			hud.barra_info.text = "Stanza %s: in attesa del via" % rete.codice
			continue
		var nuova: bool = _vista.is_empty() or str(_vista.get("pista")) != str(d.pista) or mondo.pista == null \
			or mondo.pista.id != str(d.pista) or mondo.auto.size() != d.auto.size()
		if nuova:
			mondo.carica_pista(Pista.carica(str(d.pista)))
			for i in d.auto.size():
				mondo.metti_auto(i, int(d.auto[i].p), str(d.auto[i].n), "")
			hud.chiudi_velo()
		_vista = d
		var n := int(d.get("n", 0))
		if d.has("vel"):
			mondo.velocita = float(d.vel)
		if n == _ultimo_n + 1 or _ultimo_n < 0:
			if _ultimo_n < 0:
				_allinea_prima(d)
			await _mostra(d.get("ev", []))
		for t in d.get("log", []):
			if not _log.has(t):
				_log.append(t)
				hud.cronaca(str(t))
		while _log.size() > 12:
			_log.pop_front()
		_ultimo_n = n
		if modo != "ospite":
			break
		_allinea(d)
		var mie := []
		for i in d.auto.size():
			if str(d.auto[i].u) == rete.uid:
				mie.append(i)
		hud.aggiorna(d, mie)
		if str(d.fase) == "fine":
			mondo.togli_opzioni()
			hud.chiedi()
			hud.mostra_fine()
			continue
		if d.att != null and str(d.att.tipo) == "mossa":
			mondo.mostra_opzioni(d.att.opz, str(d.att.da))
		else:
			mondo.togli_opzioni()
		if d.att != null:
			mondo.evidenzia_auto(int(d.att.auto))
		hud.chiedi()
		if _autoguida and d.att != null and mie.has(int(d.att.auto)):
			_guida_da_solo(d.att)
	_ospite_gira = false

## Prove: l'ospite sceglie la marcia più alta che non costa (fino alla 4a) e la casella meno cara e più lontana.
func _guida_da_solo(att: Dictionary) -> void:
	if str(att.tipo) == "marcia":
		var m := int(att.marce[0].m)
		for o in att.marce:
			if o.costo.is_empty() and not o.fuori and int(o.m) <= 4:
				m = int(o.m)
		_decisione({"t": "marcia", "m": m})
		return
	var best := ""
	var bv := INF
	for o in att.opz:
		var c := -float(o.mo)
		for k in o.u:
			c += 10.0 * float(o.u[k])
		if str(o.fu) != "":
			c += 1000.0
		if o.te:
			c += 50.0
		if c < bv:
			bv = c
			best = str(o.c)
	if best != "":
		_decisione({"t": "mossa", "c": best})

## Appena entrati: le auto dove erano prima degli eventi in arrivo (il percorso dice da dove partono).
func _allinea_prima(d: Dictionary) -> void:
	var prima := {}
	for e in d.get("ev", []):
		if str(e.t) == "muovi" and not prima.has(int(e.auto)):
			prima[int(e.auto)] = str(e.percorso[0])
	for i in d.auto.size():
		var c := str(prima.get(i, d.auto[i].c))
		mondo.metti_auto(i, int(d.auto[i].p), str(d.auto[i].n), c)
