extends SceneTree
## Fotografie dell'interfaccia: xvfb-run godot --path . -s tests/foto.gd -- cartella [larghezza altezza] [regole]
func _foto(dir: String, nome: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nome])
	print("foto ", nome)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := a[0] if a.size() else "/tmp/foto"
	if a.size() >= 3:
		root.size = Vector2i(int(a[1]), int(a[2]))
	var regole := a[3] if a.size() >= 4 else "avanzate"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	await _foto(dir, "0_menu")
	main.menu._voce("locale")
	main.menu.regole = regole
	main.menu.preparazione()
	await create_timer(0.3).timeout
	await _foto(dir, "1_prepara")
	main.mondo.velocita = 4.0
	main.menu._via()
	# aspetta la prima decisione del giocatore
	var n := 0
	var fatte := 0
	var t0 := Time.get_ticks_msec()
	while fatte < 14 and Time.get_ticks_msec() - t0 < 240000:
		await create_timer(0.3).timeout
		var m = main.motore
		if m == null or main._gira or m.s.attesa == null:
			continue
		var au = m.s.auto[m.s.attesa.auto]
		if au.tipo != "umano":
			continue
		await create_timer(1.2).timeout
		if m.s.attesa.tipo == "marcia":
			if fatte in [0, 4, 9]:
				await _foto(dir, "%d_marcia" % (2 + fatte))
			main._decisione(IA.decidi(m, 2))
		else:
			if fatte in [1, 2, 5, 8, 11]:
				await _foto(dir, "%d_mossa" % (2 + fatte))
				var az = IA.decidi(m, 2)
				main._casella(az.c)
				await create_timer(0.2).timeout
				await _foto(dir, "%d_scelta" % (2 + fatte))
			main._decisione(IA.decidi(m, 2))
		fatte += 1
	main._comando("vista")
	await create_timer(1.5).timeout
	await _foto(dir, "8_vista")
	# torna al menu e riprende la gara salvata
	var turno_prima: int = main.motore.s.turno
	main._al_menu()
	await create_timer(0.5).timeout
	await _foto(dir, "8_menu_con_salvataggio")
	main._comando("regole")
	await create_timer(0.3).timeout
	await _foto(dir, "8_regole_dal_menu")
	main.hud.chiudi_velo()
	await create_timer(0.3).timeout
	main._comando("riprendi")
	await create_timer(2.0).timeout
	print("ripresa: turno prima ", turno_prima, " dopo ", main.motore.s.turno if main.motore else -1, " attesa ", main.motore.s.attesa if main.motore else null)
	main._comando("inclina")
	main._comando("gira_dx")
	await create_timer(1.0).timeout
	await _foto(dir, "8_ripresa")
	main._comando("menu")
	await _foto(dir, "8_pausa")
	main.hud.chiudi_velo()
	main.hud.mostra_regole()
	await _foto(dir, "9_regole")
	main.hud.chiudi_velo()
	main.hud.mostra_fine()
	await _foto(dir, "9_fine")
	quit()
