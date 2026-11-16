extends SceneTree
## Foto di una gara su strada: il giocatore umano decide con l'IA finché non può usare il Nitro.
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
	main.menu.strada = true
	main.menu.meteo = true
	main.menu.preparazione()
	main.mondo.velocita = 8.0
	main.menu._via()
	var fatte := 0
	for k in 900:
		await create_timer(0.2).timeout
		var m = main.motore
		if m == null or m.s.fase != "gara": continue
		var att = m.s.get("attesa")
		if att == null: continue
		if m.s.auto[int(att.auto)].tipo != "umano": continue
		if att.tipo == "mossa":
			var con_nitro := false
			for o in m.opzioni.values():
				if int(o.get("extra", {}).get("ni", 0)) > 0: con_nitro = true
			if con_nitro and fatte > 2:
				await create_timer(0.5).timeout
				root.get_viewport().get_texture().get_image().save_png(dir + "/strada.png")
				print("foto strada")
				main._comando("scritte")
				await create_timer(0.5).timeout
				root.get_viewport().get_texture().get_image().save_png(dir + "/strada_parole.png")
				main._comando("scritte")
				quit()
				return
		fatte += 1
		main._decisione(IA.decidi(m, 1))
	print("nessun nitro")
	quit()
