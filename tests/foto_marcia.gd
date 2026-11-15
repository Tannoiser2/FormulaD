extends SceneTree
func _foto(dir, nome):
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nome])
	print("foto ", nome)
func _init():
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	if a.size() >= 3: root.size = Vector2i(int(a[1]), int(a[2]))
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	main.menu._voce("locale")
	main.menu.regole = "avanzate"
	main.menu.preparazione()
	main.mondo.velocita = 4.0
	main.menu._via()
	var fatte := 0
	var t0 := Time.get_ticks_msec()
	while fatte < 9 and Time.get_ticks_msec() - t0 < 200000:
		await create_timer(0.3).timeout
		var m = main.motore
		if m == null or main._gira or m.s.attesa == null: continue
		if m.s.auto[m.s.attesa.auto].tipo != "umano": continue
		await create_timer(1.0).timeout
		if m.s.attesa.tipo == "marcia" and fatte >= 6:
			var az = IA.decidi(m, 2)
			main.hud.marcia_vista = int(az.m)
			main.hud.chiedi()
			main._comando("anteprima")
			await create_timer(1.5).timeout
			await _foto(dir, "anteprima_%d" % fatte)
			if fatte == 8:
				main._comando("segui")
				await _foto(dir, "ferma")
		main._decisione(IA.decidi(m, 2))
		fatte += 1
	quit()
