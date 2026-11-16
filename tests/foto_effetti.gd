extends SceneTree
## Fotografa gli effetti: polvere, urto, esplosione; poi una gara veloce che controlla che le auto non facciano giravolte.
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
	main.mondo.velocita = 1.0
	main.menu._via()
	await create_timer(2.0).timeout
	var mo = main.mondo
	mo.segui = false
	var c0: String = mo.auto_casella[0]
	mo._bersaglio_t = mo.auto[0].position
	mo._distanza_t = 4.0
	await create_timer(1.2).timeout
	mo.sbuffo(0)
	await create_timer(0.25).timeout
	await _foto(dir, "1_polvere")
	mo.urto(0, 1, true)
	await create_timer(0.17).timeout
	await _foto(dir, "2_urto")
	await create_timer(0.6).timeout
	mo.esplosione(mo.auto_casella[0])
	await create_timer(0.2).timeout
	await _foto(dir, "3_esplosione")
	await create_timer(0.5).timeout
	await _foto(dir, "4_fumo")
	quit()
