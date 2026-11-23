extends SceneTree
## Il menu a riquadri e l'editor delle piste: scelta di una casella, spostamento, rotazione, nuova casella, annulla.
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
	await create_timer(1.0).timeout
	await _foto(dir, "1_menu")
	main.menu._voce("editor")
	await create_timer(1.0).timeout
	await _foto(dir, "2_editor")
	var ed = main.editor
	var p: Pista = ed.pista
	var c0 = p.caselle[40]
	ed._tocco(p.pos(c0.id), c0.id)
	var n0: String = c0.n[0]
	ed._tocco(p.pos(n0), n0)
	main.mondo.inquadra([c0.id, n0], 1.5, true)
	await create_timer(1.2).timeout
	await _foto(dir, "3_due_scelte")
	ed._tocco(p.pos(c0.id), c0.id)
	var prima: Vector2 = p.pos(c0.id)
	ed._premi("r15")
	ed._premi("av")
	ed._premi("av")
	print("foto mossa ", prima, " -> ", p.pos(c0.id), " r ", p.per_id[c0.id].r)
	ed._premi("nuova")
	ed._tocco(prima + Vector2(0, 60), "")
	print("foto nuova ", ed.sel, " celle ", Modifiche.celle(main.rete, ed.pid))
	await create_timer(0.6).timeout
	await _foto(dir, "4_modifiche")
	for k in 4: ed._premi("annulla")
	print("foto dopo annulla ", Modifiche.quante(main.rete, ed.pid), " pos ", ed.pista.pos(c0.id))
	ed._premi("esci")
	await create_timer(0.5).timeout
	await _foto(dir, "5_menu_ritorno")
	quit()
