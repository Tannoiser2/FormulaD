extends SceneTree
## Gare automatiche tra piloti IA: controlla che le regole non si inceppino.
## Uso: godot --headless --path . -s tests/sim.gd -- 20 [regole] [pista]

func _init() -> void:
	var arg := OS.get_cmdline_user_args()
	var n := int(arg[0]) if arg.size() > 0 else 10
	var solo_regole := arg[1] if arg.size() > 1 else ""
	var solo_pista := arg[2] if arg.size() > 2 else ""
	var varianti := arg[3] if arg.size() > 3 else ""
	var t0 := Time.get_ticks_msec()
	var errori := 0
	var stat := {"arrivi": 0, "fuori": 0, "turni": 0, "decisioni": 0, "box": 0, "scie": 0, "testacoda": 0, "nitro": 0,
		"meteo": 0, "assetti": 0}
	for g in n:
		var regole: String = solo_regole if solo_regole != "" else ["base", "avanzate"][g % 2]
		var pid: String = solo_pista if solo_pista != "" else Dati.PISTE[g % Dati.PISTE.size()]
		var lista := []
		var quante := 2 + (g * 3) % 9
		for i in quante:
			lista.append({"nome": Dati.PILOTI[i].nome, "pilota": i, "tipo": "umano" if (i == 0 and g % 2 == 1) else "ia"})
		var opzioni := {}
		if varianti != "":
			opzioni = [{"qualifiche": true}, {"meteo": true, "libero": true, "qualifiche": true}, {"strada": true}, {"strada": true, "meteo": true}, {"nitro": true, "abilita": true, "meteo": true}, {"lari": true, "kers": true, "meteo": true, "libero": true}, {"lari": true, "qualifiche": true}][g % 7]
		var m := Motore.nuova({"regole": regole, "pista": pid, "giri": 1 + g % 2 + (1 if varianti != "" and g % 3 == 0 else 0),
			"auto": lista, "seme": 1000 + g, "opzioni": opzioni})
		m.avanza()
		var passi := 0
		while (m.s.fase == "gara" or m.s.fase == "qualifiche") and passi < 6000:
			passi += 1
			if m.s.attesa == null:
				print("ERRORE: gara ferma senza attesa (gara %d)" % g)
				errori += 1
				break
			if m.s.attesa.tipo == "mossa" and m.opzioni.is_empty():
				print("ERRORE: nessuna opzione (gara %d)" % g)
				errori += 1
				break
			var az := IA.decidi(m, g % 3)
			if not m.applica(az):
				print("ERRORE: azione rifiutata %s (gara %d)" % [az, g])
				errori += 1
				break
			# salvataggio e ripresa a metà
			if passi % 37 == 0:
				var m2 := Motore.da_salvataggio(m.salva())
				if m2 == null or m2.salva() != m.salva():
					print("ERRORE: il salvataggio non torna uguale (gara %d)" % g)
					errori += 1
			for e in m.preleva_eventi():
				if e.t == "box":
					stat.box += 1
				elif e.t == "testacoda":
					stat.testacoda += 1
				elif e.t == "muovi" and e.scia > 0:
					stat.scie += 1
				elif e.t == "nitro":
					stat.nitro += 1
				elif e.t == "meteo":
					stat.meteo += 1
				elif e.t == "assetto":
					stat.assetti += 1
		if m.s.fase != "fine":
			print("ERRORE: gara %d non finita dopo %d decisioni (turno %d)" % [g, passi, m.s.turno])
			errori += 1
		# controlli
		var caselle := {}
		for a in m.s.auto:
			if a.c != "":
				if caselle.has(a.c):
					print("ERRORE: due auto sulla stessa casella")
					errori += 1
				caselle[a.c] = true
			if a.posto_arrivo > 0:
				stat.arrivi += 1
			if a.fuori:
				stat.fuori += 1
		stat.turni += m.s.turno
		stat.decisioni += passi
		var cl := m.classifica()
		print("gara %2d %-9s %-12s %d giri, %2d auto: %d turni, arrivate %d, vince %s" % [g, regole, pid, m.s.giri, quante, m.s.turno,
			m.s.arrivi.size(), m.s.auto[cl[0]].nome if not m.s.arrivi.is_empty() else "nessuno"])
	print("fatto in %.1f s: %s - errori %d" % [(Time.get_ticks_msec() - t0) / 1000.0, stat, errori])
	quit(1 if errori > 0 else 0)
