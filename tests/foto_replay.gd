extends SceneTree
## Corre una gara di un giro (decide l'IA anche per l'umano), poi fotografa la classifica e il replay.
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
	main.menu.giri = 1
	main.menu.preparazione()
	main.mondo.velocita = 12.0
	main.menu._via()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 200000:
		await create_timer(0.1).timeout
		var m = main.motore
		if m == null: continue
		if m.s.fase == "fine": break
		var att = m.s.get("attesa")
		if att == null or m.s.auto[int(att.auto)].tipo != "umano": continue
		main._decisione(IA.decidi(m, 1))
	print("fase ", main.motore.s.fase, " turno ", main.motore.s.turno, " mosse ", main.motore.s.storia.mosse.size())
	await create_timer(2.0).timeout
	await _foto(dir, "1_fine")
	main._comando("replay")
	await create_timer(2.5).timeout
	await _foto(dir, "2_replay")
	main._comando("replay_bordo")
	await create_timer(1.5).timeout
	await _foto(dir, "3_bordo")
	await create_timer(2.0).timeout
	await _foto(dir, "3b_bordo")
	main._comando("replay_bordo_dopo")
	await create_timer(1.5).timeout
	await _foto(dir, "3c_bordo_altra")
	main._comando("replay_veloce")
	main._comando("replay_veloce")
	main._comando("replay_veloce")
	var t1 := Time.get_ticks_msec()
	while main.mondo.replay_attivo and Time.get_ticks_msec() - t1 < 60000:
		await create_timer(0.2).timeout
	print("replay finito in %d ms" % (Time.get_ticks_msec() - t1))
	await create_timer(0.5).timeout
	await _foto(dir, "4_dopo")
	quit()
