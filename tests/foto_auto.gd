extends SceneTree
func _init() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.menu._voce("locale")
	main.menu.regole = "base"
	main.menu._via()
	await create_timer(1.0).timeout
	var m = main.mondo
	m._bersaglio_t = m.pos_casella(main.motore.pista.griglia[1])
	m._distanza_t = 3.0
	m.inclinazione = 1.1
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/auto.png")
	print("foto auto")
	quit()
