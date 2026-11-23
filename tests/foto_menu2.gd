extends SceneTree
## Menu online, preparazione con nomi ed extra, regole a capitoli, QR in gara.
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
	main.menu._voce("online")
	await create_timer(0.3).timeout
	await _foto(dir, "2_online")
	main.menu._voce("locale")
	main.menu.regole = "avanzate"
	main.menu.preparazione()
	await create_timer(0.3).timeout
	await _foto(dir, "3_prepara")
	main.menu.abilita = true
	main.menu.nitro = true
	main.menu.preparazione()
	await create_timer(0.3).timeout
	await _foto(dir, "4_prepara_abilita")
	main._comando("regole")
	await create_timer(0.3).timeout
	await _foto(dir, "5_regole")
	main.hud._capitolo(12)
	await create_timer(0.3).timeout
	await _foto(dir, "6_regole_camp")
	main.hud.chiudi_velo()
	main.menu.abilita = false
	main.menu.preparazione()
	main.menu._via()
	await create_timer(2.0).timeout
	var im := Image.create(29, 29, false, Image.FORMAT_RGB8)
	im.fill(Color.WHITE)
	for y in 25:
		for x in 25:
			if (x * 7 + y * 3) % 5 < 2: im.set_pixel(x + 2, y + 2, Color.BLACK)
	main.hud.mostra_qr(ImageTexture.create_from_image(im), "ABCD")
	await create_timer(0.5).timeout
	await _foto(dir, "7_gara_qr")
	quit()
