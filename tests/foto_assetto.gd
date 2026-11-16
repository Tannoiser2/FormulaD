extends SceneTree
## Foto del menu con le nuove scelte e del pannello dell'assetto (assetto libero, meteo, gomme).
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
	main.menu.meteo = true
	main.menu.libero = true
	main.menu.preparazione()
	await create_timer(0.5).timeout
	await _foto(dir, "1_menu")
	main.menu.strada = true
	main.menu.preparazione()
	await create_timer(0.5).timeout
	await _foto(dir, "2_menu_strada")
	main.menu.strada = false
	main.menu.preparazione()
	main.mondo.velocita = 4.0
	main.menu._via()
	await create_timer(2.5).timeout
	await _foto(dir, "3_assetto")
	# qualche punto spostato a mano
	main.hud._ass_pf["gomme"] = 9
	main.hud._ass_pf["tenuta"] = 1
	main.hud._ass_g = "morbide"
	main.hud.chiedi()
	await create_timer(0.3).timeout
	await _foto(dir, "4_assetto_mosso")
	main.hud._ass_pf["freni"] = 2
	main.hud.chiedi()
	await create_timer(0.3).timeout
	await _foto(dir, "5_assetto_pronto")
	main._decisione({"t": "assetto", "g": "morbide", "pf": main.hud._ass_pf.duplicate()})
	await create_timer(3.0).timeout
	await _foto(dir, "6_gara")
	quit()
