extends SceneTree
## La mappatura delle caselle (pulsante Caselle) sull'incrocio di Suzuka, con una casella toccata.
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
	main.menu.pista_n = Dati.PISTE.find(str(a[3]) if a.size() > 3 else "FDe19")
	main.menu.preparazione()
	main.menu._via()
	await create_timer(2.0).timeout
	main.mondo.segui = false
	main._comando("mappa")
	main.mondo.vista_generale()
	await create_timer(1.5).timeout
	await _foto(dir, "1_tutta")
	var c: String = str(a[4]) if a.size() > 4 else "3204"
	main.mondo._bersaglio_t = main.mondo.pos_casella(c).lerp(main.mondo.pos_casella("693"), 0.5)
	main.mondo._distanza_t = 6.0
	await create_timer(1.5).timeout
	main.mondo.segna_mappa(c)
	main.mondo.casella_mappa.emit(c)
	await create_timer(0.5).timeout
	await _foto(dir, "2_incrocio")
	quit()
