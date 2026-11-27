extends SceneTree
## Campionati salvati: due campionati, l'elenco nel menu, ripresa di uno.
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
	for cod in main._camp_codici():
		main._togli_camp(str(cod))
	for k in 2:
		var lista := []
		for i in 4:
			lista.append({"nome": ["Stefano", "Marco", "Giulia", "Luca"][i] if i < 2 else Dati.PILOTI[i].nome, "pilota": i, "tipo": "umano" if i < 2 else "ia"})
		main.camp = Campionato.nuovo({"regole": "avanzate", "giri": 1, "auto": lista, "opzioni": {"lari": true},
			"campionato": {"piste": ["FDMonaco", "FDe04", "FDSebring"]}})
		main.camp.gp = k
		main._salva_campionato()
	print("foto codici ", main._camp_codici())
	main.menu.principale()
	await _foto(dir, "1_menu")
	main._comando("camp_lista")
	await _foto(dir, "2_elenco")
	main._continua_camp("ZZZZZZ")
	await create_timer(0.3).timeout
	await _foto(dir, "3_codice_sbagliato")
	main._continua_camp(str(main._camp_codici()[1]))
	await create_timer(3.0).timeout
	print("foto in gara: ", main.motore != null, " gp ", main.camp.gp, " codice ", main.camp.codice)
	await _foto(dir, "4_gp")
	quit()
