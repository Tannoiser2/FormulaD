extends SceneTree
## Quanto appare grande ogni dado nel riquadro (in pixel), su tutte le facce: per uguagliarne la dimensione.
func _init():
	await process_frame
	for m in range(1, 7):
		var d := Dado3D.new(100)
		root.add_child(d)
		await process_frame
		var tot := 0.0
		var n := 0
		for f in Dati.DADI[m].size():
			await d.mostra(m, f, 0.0)
			await process_frame
			await process_frame
			var im: Image = d.vp.get_texture().get_image()
			var r := im.get_used_rect()
			tot += max(r.size.x, r.size.y)
			n += 1
		print("foto marcia ", m, " lato medio ", snappedf(tot / n, 0.1), " su ", d.vp.size.x)
		d.queue_free()
	quit()
