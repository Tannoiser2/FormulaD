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
var _cr: Array = []            # la cronaca intera della gara (ultime righe), per la scheda sui telefoni
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
var editor: EditorPiste

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
	mondo.pannelli = hud
	hud.decisione.connect(_decisione)
	hud.comando.connect(_comando)
	menu = Menu.new()
	strato.add_child(menu)
	menu.via.connect(_via)
	menu.comando.connect(_comando)
	menu.in_rete = rete.web
	var nomi = JSON.parse_string(rete.carica("fd_nomi")) if rete.carica("fd_nomi") != "" else null
	if nomi is Array:
		menu.nomi = nomi
	menu.nome_ospite = rete.carica("fd_nome")
	menu.suoni = rete.suoni_attivi()
	hud.b_suoni.text = "Suoni: " + ("sì" if menu.suoni else "no")
	hud.b_suoni.visible = rete.web
	menu.camp_scegli.connect(_continua_camp)
	menu.camp_togli.connect(_togli_camp)
	menu.entra_gara.connect(func(c: String, n: String):
		if not rete.web:
			menu.avviso = "Per entrare in una gara online apri la versione web del gioco."
			menu.online()
			return
		_entra(c, n))
	editor = EditorPiste.new()
	editor.visible = false
	strato.add_child(editor)
	editor.rete = rete
	editor.mondo = mondo
	editor.esci.connect(_al_menu)
	mondo.sopra_ui = func(p): return menu.visible or hud.sopra(p) or (editor.visible and editor.sopra(p))
	mondo.casella_toccata.connect(_casella)
	mondo.casella_mappa.connect(_casella_mappa)
	var prima := Pista.carica("FDMonaco")
	Modifiche.applica(rete, prima)
	mondo.carica_pista(prima)
	menu.ha_salvataggio = rete.carica("fd_gara") != ""
	_carica_campionato()
	mondo.segui = rete.carica("fd_segui") != "0"
	mondo.scritte_icone = rete.carica("fd_scritte") != "parole"
	hud.scritte_icone = func() -> bool: return mondo.scritte_icone
	hud.b_scritte.text = "Scritte: icone" if mondo.scritte_icone else "Scritte: parole"
	hud.segna_segui(mondo.segui)
	menu.principale()
	if rete.web and not menu.ha_salvataggio:
		rete.chiedi_remoto()
	var par := rete.parametri()
	if par.has("campionato") and str(par.campionato).length() == 6:
		# link diretto a un campionato: ...index.html?campionato=ABCDEF
		_continua_camp.call_deferred(str(par.campionato))
	if par.has("veloce"):
		mondo.velocita = max(0.5, float(par.veloce))
	if par.has("stanza"):
		_via_con = int(par.stanza)
		menu.pista_n = int(par.get("pista_n", 0))
		menu.regole = str(par.get("regole", "avanzate"))
		menu.giri = int(par.get("giri", 1))
		menu.strada = par.has("strada")
		menu.meteo = par.has("meteo")
		menu.libero = par.has("libero")
		menu.qualifiche = par.has("qualifiche")
		menu.lari = par.has("lari")
		menu.kers = par.has("kers")
		menu._voce("stanza_online" if par.has("online") else "stanza_tv")
		if par.has("online"):
			menu.posti[0].tipo = "ia"   # nelle prove nessuno guida da questo computer
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
			"auto": lista, "livello": 1, "stanza": false,
			"opzioni": {"strada": par.has("strada"), "meteo": par.has("meteo"), "libero": par.has("libero"), "qualifiche": par.has("qualifiche"),
				"lari": par.has("lari"), "kers": par.has("kers")}})

# ------------------------------------------------------------------ comandi

## Nel replay, l'auto da cui guardare: quella di chi gioca qui (la prima di un giocatore, se ce ne sono), se no la vincitrice.
func _auto_mia() -> int:
	var v: Dictionary = hud.v
	for i in v.auto.size():
		if str(v.auto[i].tp) == "umano" or (str(v.auto[i].u) != "" and str(v.auto[i].u) == str(rete.uid)):
			return i
	var arr: Array = v.get("arrivi", [])
	return int(arr[0]) if not arr.is_empty() else 0

## Passa all'auto prima o dopo (salta quelle già fuori dalla pista nel replay).
func _bordo_cambia(d: int) -> void:
	var n: int = hud.v.auto.size()
	var i: int = mondo.bordo if mondo.bordo >= 0 else _auto_mia() - d
	for k in n:
		i = posmod(i + d, n)
		if mondo.auto.has(i) and mondo.auto[i].visible:
			break
	mondo.a_bordo(i)

## Il replay di tutta la gara, poi di nuovo la classifica finale.
func _replay() -> void:
	var v: Dictionary = hud.v
	if not v.has("storia") or mondo.replay_attivo:
		return
	hud.chiudi_velo()
	hud.pulisci_dadi()
	var lista := []
	var ultimo := 1
	for i in v.auto.size():
		lista.append({"i": i, "p": int(v.auto[i].p), "n": str(v.auto[i].n)})
	for m in v.storia.mosse:
		ultimo = max(ultimo, int(m.tr))
	hud.mostra_replay(mondo, ultimo)
	await mondo.replay(v.storia, lista)
	hud.chiedi()
	if hud.v.fase == "fine":
		hud.mostra_fine()

func _comando(cosa: String) -> void:
	if cosa.begins_with("guarda:"):
		var i := int(cosa.split(":")[1])
		var c: String = mondo.auto_casella.get(i, "")
		if c != "":
			mondo.inquadra([c], 3.0, true)
		return
	match cosa:
		"regole":
			hud.visible = true
			hud.mostra_regole()
			if modo == "menu":
				_solo_velo()
		"vista":
			mondo.vista_generale()
		"scritte":
			mondo.cambia_scritte()
			rete.salva("fd_scritte", "icone" if mondo.scritte_icone else "parole")
			hud.b_scritte.text = "Scritte: icone" if mondo.scritte_icone else "Scritte: parole"
		"mappa":
			var acceso: bool = mondo.mappa == null
			mondo.mostra_mappa(acceso)
			hud.b_mappa.text = "Caselle: sì" if acceso else "Caselle"
			if acceso:
				hud.cronaca("Mappatura delle caselle: pallino blu corsia di destra, verde centro, arancio sinistra, viola box; la punta indica il verso. Linee bianche avanti, rosse cambio corsia. Tocca una casella per vederne la sigla e dove porta.", "info")
		"editor":
			_apri_editor()
		"gira_sx":
			mondo.gira(-PI / 6.0)
		"gira_dx":
			mondo.gira(PI / 6.0)
		"inclina":
			mondo.inclina()
		"segui":
			mondo.segui = not mondo.segui
			rete.salva("fd_segui", "1" if mondo.segui else "0")
			hud.segna_segui(mondo.segui)
		"anteprima":
			_anteprima()
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
			if menu.tipo_stanza == "online":
				hud.cronaca("Gara online %s  -  %s" % [rete.codice, menu.link_gara()], "ordine")
			else:
				hud.cronaca("Stanza %s  -  %s" % [rete.codice, rete.url], "ordine")
		"decidi":
			if motore != null and motore.s.attesa != null and not _gira:
				var az := IA.decidi(motore, livello)
				if motore.applica(az):
					mondo.togli_opzioni()
					_ciclo()
		"replay":
			_replay()
		"replay_lento":
			mondo.replay_tempo = min(mondo.replay_tempo * 1.5, 3.0)
		"replay_veloce":
			mondo.replay_tempo = max(mondo.replay_tempo / 1.5, 0.2)
		"replay_alto":
			mondo.a_bordo(-1)
		"replay_bordo":
			if mondo.bordo < 0:
				mondo.a_bordo(_auto_mia())
		"replay_bordo_prima", "replay_bordo_dopo":
			_bordo_cambia(1 if cosa == "replay_bordo_dopo" else -1)
		"replay_fine":
			mondo.ferma_replay()
		"rivincita":
			mondo.ferma_replay()
			hud.chiudi_velo()
			if not _ultima_conf.is_empty():
				_via(_ultima_conf)
		"esci":
			_al_menu()
		"suoni":
			menu.suoni = not rete.suoni_attivi()
			rete.attiva_suoni(menu.suoni)
			hud.b_suoni.text = "Suoni: " + ("sì" if menu.suoni else "no")
			if menu.suoni:
				rete.suono("tocca")
		"camp_lista":
			_menu_campionati()
			menu.campionati_schermo()
		"camp_prossimo":
			hud.chiudi_velo()
			_gp()
		"camp_via":
			var sala := {}
			for i in menu.posti.size():
				sala[i] = menu.posti[i]
			menu.camp_gp = {}
			var conf := _conf_gp_rete(sala)
			_salva_campionato()
			_via(conf)
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
		"nomi":
			rete.salva("fd_nomi", JSON.stringify(menu.nomi))
		"riprendi":
			_riprendi()

func _solo_velo() -> void:
	# le regole viste dal menu: si vede solo la finestra
	for c in hud._pannelli:
		c.visible = false
	menu.visible = false
	await hud.velo.tree_exited
	for c in hud._pannelli:
		c.visible = c != hud.p_dado and c != hud.p_qr and c != hud.p_ass and c != hud.p_barra
	hud.imposta_tavolo(hud.tavolo)
	if modo == "menu":
		hud.visible = false
		menu.visible = true
	else:
		_qr_in_gara()

func _al_menu() -> void:
	hud.nascondi_qr()
	menu.camp_gp = {}
	_connessi.clear()
	if editor.visible:
		editor.chiudi()
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
	_carica_campionato()
	menu.principale()

# ------------------------------------------------------------------ campionato

var camp: Dictionary = {}

# ------------------------------------------------------------------ campionati salvati
# Ogni campionato ha un codice di 6 lettere. Si salva qui (fd_camp_<codice>, elenco in fd_campionati) e online
# (formulad/campagne/<codice>): con il codice lo si riprende da qualsiasi dispositivo.

var _camp_attesa := ""   # il codice chiesto online, in attesa di risposta

func _camp_codici() -> Array:
	var t: String = rete.carica("fd_campionati")
	var x = JSON.parse_string(t) if t != "" else null
	return x if x is Array else []

func _camp_locale(cod: String) -> Dictionary:
	var d = _leggi_campionato(rete.carica("fd_camp_" + cod))
	return d

## Legge un campionato salvato (anche quello scaricato da internet): solo dati, niente oggetti.
func _leggi_campionato(t: String) -> Dictionary:
	if t == "" or t.contains("Object(") or t.contains("Resource("):
		return {}
	var d = str_to_var(t)
	return d if d is Dictionary and d.has("piste") and d.has("gp") else {}

static func nuovo_codice_camp() -> String:
	const L := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	var c := ""
	for k in 6:
		c += L[randi() % L.length()]
	return c

## All'avvio: sposta il vecchio campionato unico nell'elenco e prepara l'elenco per il menu.
func _carica_campionato() -> void:
	var vecchio := _leggi_campionato(rete.carica("fd_campionato"))
	if not vecchio.is_empty():
		camp = vecchio
		_salva_campionato()
		rete.salva("fd_campionato", "")
	_menu_campionati()

func _menu_campionati() -> void:
	var l := []
	for cod in _camp_codici():
		var c := _camp_locale(str(cod))
		if c.is_empty():
			continue
		var t := ""
		if c.finito:
			var cl := Campionato.piloti(c)
			t = "Finito: campione %s" % (str(cl[0].n) if not cl.is_empty() else "")
		else:
			t = "Gran Premio %d di %d: %s" % [int(c.gp) + 1, c.piste.size(), Campionato.nome_pista(c.piste[int(c.gp)])]
		var chi := []
		for a in c.auto:
			if str(a.get("tipo", "")) != "ia":
				chi.append(Dati.corto(str(a.nome)))
		l.append({"codice": str(cod), "testo": t, "finito": bool(c.finito), "chi": ", ".join(PackedStringArray(chi)),
			"quando": float(c.get("salvato", 0))})
	menu.campionati = l

func _salva_campionato() -> void:
	if not camp.has("codice"):
		camp["codice"] = nuovo_codice_camp()
	camp["salvato"] = Time.get_unix_time_from_system()
	var cod: String = camp.codice
	var testo := var_to_str(camp)
	rete.salva("fd_camp_" + cod, testo)
	var l := _camp_codici()
	l.erase(cod)
	l.push_front(cod)
	rete.salva("fd_campionati", JSON.stringify(l))
	rete.salva_campionato(cod, testo)
	_menu_campionati()

## Continua un campionato: prima guarda online se c'è una versione più nuova (giocata da un altro dispositivo).
func _continua_camp(cod: String) -> void:
	cod = cod.strip_edges().to_upper()
	if not rete.web:
		_camp_pronto(cod, "")
		return
	_camp_attesa = cod
	menu.avviso = "Cerco il campionato %s..." % cod
	menu.campionati_schermo()
	rete.chiedi_campionato(cod)
	await get_tree().create_timer(6.0).timeout
	if _camp_attesa == cod:
		_camp_pronto(cod, "")

func _camp_pronto(cod: String, online: String) -> void:
	_camp_attesa = ""
	var loc := _camp_locale(cod)
	var onl := _leggi_campionato(online)
	var c := loc
	if not onl.is_empty() and (loc.is_empty() or float(onl.get("salvato", 0)) > float(loc.get("salvato", 0))):
		c = onl
	if c.is_empty():
		menu.avviso = "Non trovo il campionato %s: controlla il codice." % cod
		menu.campionati_schermo()
		return
	camp = c
	camp["codice"] = cod
	print("campionato ripreso %s, gran premio %d (%s)" % [cod, int(camp.gp) + 1, "online" if c == onl else "da questo dispositivo"])
	_salva_campionato()
	menu.avviso = ""
	if camp.finito:
		menu.avviso = "Il campionato %s è finito." % cod
		menu.campionati_schermo()
		return
	_gp()

func _togli_camp(cod: String) -> void:
	var l := _camp_codici()
	l.erase(cod)
	rete.salva("fd_campionati", JSON.stringify(l))
	rete.salva("fd_camp_" + cod, "")
	_menu_campionati()
	menu.campionati_schermo()

## Il Gran Premio corrente del campionato.
func _gp() -> void:
	if camp.is_empty() or camp.finito:
		_al_menu()
		return
	var remoti: Array = camp.auto.filter(func(a): return str(a.get("tipo", "")) == "remoto")
	if not remoti.is_empty():
		# con i telefoni (o online): si parte subito se sono tutti collegati, se no la sala d'attesa del GP
		var tutti := rete.codice != ""
		for a in remoti:
			if not _connessi.has(str(a.uid)):
				tutti = false
		if not tutti:
			_sala_gp()
			return
		_via(_conf_gp_rete({}))
	else:
		_via(Campionato.conf_gp(camp))
	hud.cronaca("Campionato: Gran Premio %d di %d, %s" % [int(camp.gp) + 1, camp.piste.size(), Campionato.nome_pista(camp.piste[int(camp.gp)])], "giro")

var _connessi := {}   # uid dei telefoni / ospiti collegati adesso alla stanza

## La configurazione del GP con i giocatori collegati: posti è la sala (vuoto: tutti come nel campionato).
## Chi non è collegato lascia l'auto al computer per questo GP.
func _conf_gp_rete(posti: Dictionary) -> Dictionary:
	var conf := Campionato.conf_gp(camp)
	conf.stanza = true
	for d in conf.auto:
		var k := int(d.pilota)
		if posti.has(k):
			var pz: Dictionary = posti[k]
			d.tipo = str(pz.tipo)
			d.uid = str(pz.uid) if pz.tipo == "remoto" else ""
			# il telefono nuovo resta legato al pilota anche per i prossimi GP
			for a in camp.auto:
				if int(a.pilota) == k and str(a.get("tipo", "")) == "remoto" and pz.tipo == "remoto" and str(pz.uid) != "":
					a.uid = str(pz.uid)
		if str(d.tipo) == "remoto" and not _connessi.has(str(d.uid)):
			d.tipo = "ia"
			d.uid = ""
	camp["stanza_cod"] = rete.codice
	return conf

## La sala d'attesa di un GP del campionato: si riapre la stanza (con lo stesso codice, se si può) e si
## aspettano i telefoni.
func _sala_gp() -> void:
	hud.nascondi_qr()
	hud.chiudi_velo()
	hud.visible = false
	motore = null
	modo = "menu"
	menu.visible = true
	menu.campionato = false
	menu.stanza = true
	menu.tipo_stanza = str(camp.get("tipo_stanza", "tv"))
	menu.posti = []
	for i in Dati.PILOTI.size():
		menu.posti.append({"tipo": "chiuso", "uid": "", "nome": ""})
	for a in camp.auto:
		var t := str(a.get("tipo", "ia"))
		menu.posti[int(a.pilota)] = {"tipo": t, "uid": str(a.get("uid", "")), "nome": str(a.nome), "pilota_n": str(a.nome),
			"orig": t, "dentro": t == "remoto" and _connessi.has(str(a.get("uid", "")))}
	menu.camp_gp = {"gp": int(camp.gp), "n": camp.piste.size(), "pista": Campionato.nome_pista(camp.piste[int(camp.gp)])}
	if rete.codice == "":
		menu.codice = ""
		_stanza_chiesta = true
		rete.avvia(str(camp.get("stanza_cod", "")))
	else:
		menu.imposta_stanza(rete.codice, rete.url, _qr(rete.url))
	menu.preparazione()
	_pubblica_attesa()

## A gara finita: se è un GP del campionato si aggiornano le classifiche (una volta sola).
func _esperienza() -> Dictionary:
	var t: String = rete.carica("fd_esperienza")
	var x = JSON.parse_string(t) if t != "" else null
	return x if x is Dictionary else {}

func _fine_gp() -> void:
	if motore == null or not motore.s.has("camp") or camp.is_empty():
		return
	if int(motore.s.camp) != int(camp.gp):
		return
	var rie := Campionato.registra(camp, motore.s)
	if camp.finito:
		var x := Campionato.esperienza_finale(camp, _esperienza())
		rete.salva("fd_esperienza", JSON.stringify(x[0]))
		if str(x[1]) != "":
			hud.cronaca("Premi di esperienza per il prossimo campionato: " + str(x[1]), "arrivo")
	_salva_campionato()
	hud.riepilogo_gp = rie

# ------------------------------------------------------------------ gara (chi ospita o in locale)

func _via(conf: Dictionary) -> void:
	if conf.has("campionato"):
		camp = Campionato.nuovo(conf, _esperienza())
		_salva_campionato()
		hud.cronaca("Codice del campionato: %s. Con questo codice lo riprendi da qualsiasi dispositivo (Continua un campionato)." % camp.codice, "ordine")
		_gp()
		return
	_ultima_conf = conf
	hud.campionato = {}
	if conf.has("camp"):
		hud.campionato = camp
	livello = int(conf.get("livello", 1))
	modo = "stanza" if conf.get("stanza", false) else "locale"
	Modifiche.applica(rete, Pista.carica(str(conf.pista)))
	motore = Motore.nuova(conf)
	_apri_gara()
	motore.avanza()
	_ciclo()

func _apri_gara() -> void:
	hud.imposta_tavolo(modo == "stanza" and menu.tipo_stanza == "tv" and _miei().is_empty())
	menu.visible = false
	hud.visible = true
	_qr_in_gara()
	hud.ospite = false
	hud.chiudi_velo()
	hud.pulisci_dadi()
	for c in hud.cronaca_box.get_children():
		c.queue_free()
	_log.clear()
	_cr.clear()
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
			_fine_gp()
			rete.salva("fd_gara", "")
			if not auto_prova:
				hud.mostra_fine()
			break
		var a: Dictionary = m.s.auto[m.s.attesa.auto]
		var curva := _casella_curva(m, a)
		if m.s.attesa.tipo == "mossa" and (a.tipo != "ia" or mondo.velocita < 3.0):
			mondo.mostra_opzioni(vista.att.opz, a.c, true, curva)
		else:
			mondo.togli_opzioni()
			if a.c != "":
				mondo.inquadra([a.c] + curva, 3.5)
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

## Tocca a un giocatore: oltre alla sua casella la telecamera inquadra, se non è troppo lontana, la prossima curva.
func _casella_curva(m: Motore, a: Dictionary) -> Array:
	if a.tipo == "ia" or a.c == "" or not m.pista.per_id.has(a.c) or bool(a.get("fuori", false)):
		return []
	var pc := m.pista.prossima_curva(str(a.c))
	if int(pc[0]) < 0 or int(pc[0]) > 14:
		return []
	return [str(pc[2])]

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
		hud._svuota_azione()
		return
	if motore == null or _gira or motore.s.attesa == null:
		return
	var a: Dictionary = motore.s.auto[motore.s.attesa.auto]
	if a.tipo != "umano":
		return
	if motore.applica(az):
		mondo.togli_opzioni()
		_ciclo()

## È stata toccata una marcia: sul tabellone compaiono le caselle dove può portare.
func _anteprima() -> void:
	mondo.togli_opzioni()
	var v: Dictionary = hud.v
	if v.is_empty() or v.att == null or str(v.att.tipo) != "marcia":
		return
	for o in v.att.marce:
		if int(o.m) == hud.marcia_vista and o.has("pv"):
			mondo.mostra_opzioni(o.pv.c, str(v.att.get("da", "")))

func _casella(cid: String) -> void:
	if not mondo.opzioni.has(cid):
		return
	mondo.segna_scelta(cid)
	hud.scegli_opzione(mondo.opzioni[cid])

func _casella_mappa(cid: String) -> void:
	if editor.visible:
		return
	var c = mondo.pista.per_id[cid]
	hud.cronaca("Casella %s (corsia %s): porta a %s" % [cid, ["box", "destra", "centro", "sinistra"][int(c.l)] if int(c.l) <= 3 else str(c.l),
		", ".join(PackedStringArray(c.get("n", [])))], "info")

## L'editor delle piste, una schermata a parte.
func _apri_editor() -> void:
	modo = "editor"
	menu.visible = false
	hud.visible = false
	hud.chiudi_velo()
	mondo.togli_opzioni()
	editor.apri(mondo.pista.id if mondo.pista != null else "FDMonaco")

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
				if int(e.marcia) >= 5 and int(e.valore) == int(Dati.SFORZO.get(int(e.marcia), -1)):
					rete.suono("ritorno")
				await hud.mostra_dado(int(e.marcia), int(e.valore), int(e.faccia), nome, 0.6 / mondo.velocita)
			"nero":
				hud.mostra_nero(int(e.valore), str(e.motivo), bool(e.male), str(e.get("testo", "")), _nome_auto(int(e.auto)) if int(e.auto) >= 0 else "")
				rete.suono("nero")
				await get_tree().create_timer(0.55 / mondo.velocita).timeout
			"muovi":
				mondo.togli_opzioni()
				mondo.inquadra(e.percorso, 2.5)
				rete.suono("motore", {"m": int(e.get("m", 3)), "d": mondo.durata_mossa(e.percorso), "fr": int(e.get("fr", 0)),
					"ol": int(e.get("ol", 0)), "ni": bool(e.get("ni", false))})
				await mondo.muovi_auto(int(e.auto), e.percorso)
			"testacoda":
				rete.suono("gomme")
				await mondo.testacoda(int(e.auto))
			"fuori":
				rete.suono("esplosione")
				mondo.esplosione(str(mondo.auto_casella.get(int(e.auto), e.get("c", ""))))
				await mondo.elimina_auto(int(e.auto))
			"usura":
				mondo.sbuffo(int(e.auto))
				var mot := str(e.get("motivo", ""))
				if mot.contains("detriti") or mot.contains("cordolo"):
					rete.suono("ghiaia")
			"urto":
				rete.suono("scontro", {"forte": bool(e.colpo)})
				await mondo.urto(int(e.auto), int(e.contro), bool(e.colpo))
			"arrivo":
				rete.suono("arrivo")
				await mondo.arriva_auto(int(e.auto))
			"segnalino":
				mondo.metti_danno(str(e.c))
			"box":
				rete.suono("box")

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
	var testo := var_to_str({"s": motore.s, "livello": livello, "stanza": modo == "stanza", "sk": menu.tipo_stanza, "codice": rete.codice, "seq": _seq})
	rete.salva("fd_gara", testo)
	if modo == "stanza":
		rete.salva_stanza(testo)
	else:
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
	_carica_campionato()
	hud.campionato = camp if m.s.has("camp") else {}
	modo = "stanza" if d.get("stanza", false) else "locale"
	menu.tipo_stanza = str(d.get("sk", "tv"))
	_apri_gara()
	if modo == "stanza":
		# si riapre la stessa stanza (stesso codice e QR): i piloti da telefono rientrano da soli
		_seq = int(d.get("seq", 0)) + 1
		_stanza_chiesta = true
		rete.avvia(str(d.get("codice", "")))
	hud.cronaca("Gara ripresa dal turno %d" % motore.s.turno, "ordine")
	_ciclo()

# ------------------------------------------------------------------ rete: stanza

func _pubblica(vista: Dictionary, ev: Array) -> void:
	if modo != "stanza" or rete.codice == "":
		return
	_seq += 1
	var d := vista.duplicate()
	d["sk"] = menu.tipo_stanza
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
	var cr := _cr.duplicate()
	for e in ev:
		if e.t == "msg":
			cr.append(e.testo)
	d["cr"] = cr.slice(max(0, cr.size() - 30))
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

## Con i telefoni il QR resta in un angolo per tutta la gara: chi perde la connessione lo inquadra e rientra.
func _qr_in_gara() -> void:
	if modo == "stanza" and menu.tipo_stanza == "tv" and rete.codice != "" and rete.url != "":
		hud.mostra_qr(_qr(rete.url), rete.codice)
	else:
		hud.nascondi_qr()

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
				_qr_in_gara()
				_pubblica(motore.vista(), [])
			else:
				_pubblica_attesa()
		"entra":
			var uid := str(e.uid)
			var nome := str(e.get("nome", "Pilota")).left(16)
			_connessi[uid] = true
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
			_connessi.erase(str(e.uid))
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
			hud.cronaca("Sei nella gara online %s: aspetta il via" % rete.codice, "ordine")
			hud._svuota_azione()
		"stato":
			var d = JSON.parse_string(str(e.j))
			if d is Dictionary:
				_coda_ospite.append(d)
				_ciclo_ospite()
		"campionato":
			if str(e.get("codice", "")) == _camp_attesa and _camp_attesa != "":
				_camp_pronto(_camp_attesa, str(e.get("dati", "")))
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
				else:
					menu.preparazione()

# ------------------------------------------------------------------ rete: ospite

func _chiedi_codice() -> void:
	if not rete.web:
		menu.avviso = "Per entrare in una stanza apri la versione web del gioco."
		menu.principale()
		return
	var c = rete.fr.chiedi("Codice della gara online (4 lettere):", "")
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
		if str(d.get("sk", "online")) == "tv":
			# una stanza TV + telefoni: dal computer non si entra, si usa il telefono
			var c := rete.codice
			_al_menu()
			menu.avviso = "La stanza %s è una gara TV + telefoni: per giocare inquadra il QR con il telefono." % c
			menu.principale()
			break
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
	if str(att.tipo) == "qualifica":
		_decisione({"t": "qualifica", "m": 4})
		return
	if str(att.tipo) == "qritira":
		_decisione({"t": "qritira", "si": false})
		return
	if str(att.tipo) == "assetto":
		var az := {"t": "assetto", "g": str(att.gomme[att.gomme.size() - 1])}
		if att.libero:
			az["pf"] = Dati.ASSETTO_IA.duplicate()
		_decisione(az)
		return
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
