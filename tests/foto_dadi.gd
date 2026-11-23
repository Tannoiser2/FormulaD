extends SceneTree
## Il box dei dadi durante una gara vera: una foto ogni 0.12 s ritagliata sul box.
func _init():
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	if a.size() >= 3: root.size = Vector2i(int(a[1]), int(a[2]))
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	main.menu._voce("locale")
	main.menu._via()
	await create_timer(1.0).timeout
	for k in 40:
		await create_timer(0.12).timeout
		var im: Image = root.get_viewport().get_texture().get_image()
		var r: Rect2 = main.hud.p_dado.get_global_rect()
		var sc: float = im.get_width() / main.hud.get_viewport_rect().size.x
		im.get_region(Rect2i(r.position * sc, r.size * sc)).save_png("%s/b_%02d.png" % [dir, k])
	quit()
