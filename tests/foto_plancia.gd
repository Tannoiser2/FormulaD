extends SceneTree
## La scelta della marcia sulla plancia: marce illuminate, passaggio sopra (anteprima), clic (innesta e tira).
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
	main.menu.regole = str(a[3]) if a.size() > 3 else "avanzate"
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
		if att.tipo == "marcia":
			volte += 1
			if volte < 3:
				main._decisione(IA.decidi(m, 1))
				continue
			await create_timer(1.0).timeout
			await _foto(dir, "1_marce")
			var pl: Plancia = main.hud.plancia
			var scelta_m := int(pl.marce[pl.marce.size() - 1].m)
			var ev := InputEventMouseMotion.new()
			ev.position = pl.centro_marcia(scelta_m)
			pl._gui_input(ev)
			await create_timer(1.5).timeout
			await _foto(dir, "2_sopra")
			var cl := InputEventMouseButton.new()
			cl.button_index = MOUSE_BUTTON_LEFT
			cl.pressed = true
			cl.position = pl.centro_marcia(scelta_m)
			pl._gui_input(cl)
			await create_timer(2.0).timeout
			await _foto(dir, "3_mossa")
			quit()
			return
		main._decisione(IA.decidi(m, 1))
	quit()
