extends SceneTree
## Controllo dei dadi 3D: ogni dado con alcune facce, accanto al valore atteso; più un'auto vista da vicino.
func _init() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dir)
	UI.prepara()
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.25)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var g := GridContainer.new()
	g.columns = 9
	root.add_child(g)
	for marcia in range(1, 7):
		var n: int = Dati.DADI[marcia].size()
		for k in 9:
			var f: int = int(k * n / 9.0)
			var vb := VBoxContainer.new()
			var d := Dado3D.new(150)
			vb.add_child(d)
			d.mostra(marcia, f, 0.0)
			vb.add_child(UI.testo("m%d atteso %d" % [marcia, Dati.DADI[marcia][f][0]], 22))
			g.add_child(vb)
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/dadi.png")
	print("foto dadi")
	quit()
