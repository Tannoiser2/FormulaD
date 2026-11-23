extends SceneTree
## Un campionato di 2 GP da un giro: foto del menu, delle qualifiche, della fine gara e delle classifiche.
func _foto(dir, nome):
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nome])
	print("foto ", nome)
func _gioca(main, dir, prefisso) -> void:
	var foto_q := false
	var foto_r := false
	var foto_pp := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await create_timer(0.1).timeout
		var m = main.motore
		if m == null: continue
		if m.s.fase == "fine": break
		var att = m.s.attesa
		if att == null or m.s.auto[int(att.auto)].tipo != "umano": continue
		if att.tipo == "qualifica" and not foto_q:
			foto_q = true
			await create_timer(0.6).timeout
			await _foto(dir, prefisso + "_qualifica")
		if att.tipo == "qritira" and not foto_r:
			foto_r = true
			await create_timer(0.6).timeout
			await _foto(dir, prefisso + "_riprova")
		if att.tipo == "mossa" and not foto_pp:
			foto_pp = true
			await create_timer(0.6).timeout
			await _foto(dir, prefisso + "_mossa_pp")
		main._decisione(IA.decidi(m, 1))
func _init():
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	if a.size() >= 3: root.size = Vector2i(int(a[1]), int(a[2]))
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	main.rete.salva("fd_campionato", "")
	main._carica_campionato()
	main.menu.principale()
	await create_timer(0.3).timeout
	await _foto(dir, "0_menu")
	main.menu._voce("campionato")
	main.menu.camp_piste = ["FDe08a", "FDe10"]
	main.menu.giri = 1
	for i in 10:
		main.menu.posti[i].tipo = "umano" if i == 0 else ("ia" if i < 8 else "chiuso")
	main.menu.preparazione()
	await create_timer(0.4).timeout
	await _foto(dir, "1_preparazione")
	main.mondo.velocita = 12.0
	main.menu._via()
	await _gioca(main, dir, "2")
	await create_timer(2.0).timeout
	await _foto(dir, "3_fine_gp1")
	main.hud.mostra_campionato()
	await create_timer(0.4).timeout
	await _foto(dir, "4_classifica_gp1")
	main._comando("camp_prossimo")
	await _gioca(main, dir, "5")
	await create_timer(2.0).timeout
	main.hud.mostra_campionato()
	await create_timer(0.4).timeout
	await _foto(dir, "6_classifica_finale")
	print("foto campionato finito: ", main.camp.finito, " gp ", main.camp.gp, " punti ", main.camp.punti, " prov ", main.camp.prov)
	main._al_menu()
	await create_timer(0.3).timeout
	await _foto(dir, "7_menu_dopo")
	quit()
