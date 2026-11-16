extends SceneTree
## Il riquadro della mossa: prima del clic, dopo il primo clic su una casella, poi il secondo clic conferma.
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
	main.mondo.velocita = 8.0
	main.menu._via()
	var volte := 0
	for k in 600:
		await create_timer(0.2).timeout
		var m = main.motore
		if m == null or m.s.fase != "gara": continue
		var att = m.s.get("attesa")
		if att == null or m.s.auto[int(att.auto)].tipo != "umano": continue
		if att.tipo == "mossa":
			volte += 1
			if volte < 3:
				main._decisione(IA.decidi(m, 1))
				continue
			await create_timer(1.0).timeout
			await _foto(dir, "1_mossa")
			var cs: Array = main.mondo.opzioni.keys()
			var scelta: String = cs[cs.size() - 1]
			for c in cs:
				if not main.mondo.opzioni[c].get("u", {}).is_empty(): scelta = c
			main._casella(scelta)
			await create_timer(0.5).timeout
			await _foto(dir, "2_primo_clic")
			var prima = m.s.auto[int(att.auto)].c
			main._casella(scelta)
			print("foto secondo clic fatto")
			await create_timer(0.5).timeout
			print("foto casella prima ", prima, " ora ", m.s.auto[int(att.auto)].c, " scelta ", scelta)
			print("foto dopo: ", m.s.attesa.tipo if m.s.attesa else "nessuna", " auto ", m.s.attesa.auto if m.s.attesa else -1)
			quit()
			return
		main._decisione(IA.decidi(m, 1))
	quit()
