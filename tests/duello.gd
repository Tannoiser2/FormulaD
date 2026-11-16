extends SceneTree
## Due versioni dell'IA l'una contro l'altra: metà auto con il profilo A, metà con il B (a turno sulla griglia).
## Uso: godot --headless -s tests/duello.gd -- <gare> '<json profilo A>' '<json profilo B>' [regole]
func _init() -> void:
	var arg := OS.get_cmdline_user_args()
	var n := int(arg[0])
	var pa: Dictionary = JSON.parse_string(arg[1])
	var pb: Dictionary = JSON.parse_string(arg[2])
	var solo := arg[3] if arg.size() > 3 else ""
	var base := int(arg[4]) if arg.size() > 4 else 0
	var punti := {"A": 0.0, "B": 0.0}
	var vinte := {"A": 0, "B": 0}
	var fuori := {"A": 0, "B": 0}
	for g0 in n:
		var g := g0 + base
		var regole: String = solo if solo != "" else ["base", "avanzate"][g % 2]
		var pid: String = Dati.PISTE[(g * 7) % Dati.PISTE.size()]
		var lista := []
		for i in 6:
			lista.append({"nome": Dati.PILOTI[i].nome, "pilota": i, "tipo": "ia"})
		var m := Motore.nuova({"regole": regole, "pista": pid, "giri": 1, "auto": lista, "seme": 5000 + g})
		var chi := func(i: int) -> String: return "A" if (i + g) % 2 == 0 else "B"
		m.avanza()
		var passi := 0
		while m.s.fase == "gara" and passi < 6000:
			passi += 1
			IA.prof = pa if chi.call(int(m.s.attesa.auto)) == "A" else pb
			if not m.applica(IA.decidi(m, 2)):
				break
			m.preleva_eventi()
		var cl := m.classifica()
		for k in cl.size():
			var i := int(cl[k])
			punti[chi.call(i)] += 6 - k
			if k == 0:
				vinte[chi.call(i)] += 1
			if m.s.auto[i].fuori:
				fuori[chi.call(i)] += 1
	print("A punti %.2f a gara, vinte %d, ritirate %d" % [punti.A / n, vinte.A, fuori.A])
	print("B punti %.2f a gara, vinte %d, ritirate %d" % [punti.B / n, vinte.B, fuori.B])
	quit()
