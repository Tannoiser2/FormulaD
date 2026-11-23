extends SceneTree
## Campionato con il regolamento Lari: collaudatore, punti scuderia, esperienza.
func _init():
	var lista := []
	for i in 6:
		lista.append({"nome": Dati.PILOTI[i].nome, "pilota": i, "tipo": "ia"})
	var conf := {"regole": "avanzate", "pista": "FDMonaco", "giri": 1, "auto": lista, "livello": 1,
		"opzioni": {"lari": true, "kers": true}, "campionato": {"piste": ["FDMonaco", "FDSebring", "FDValencia"]}}
	var c := Campionato.nuovo(conf, {"piloti": {"Jack Owens": 1}, "scuderie": {"rossa": 1}})
	print("perm Jack ", c.perm["1"], " pmec rossa ", c.pmec["0"], " libero ", c.opzioni.libero)
	for gp in 3:
		var cg := Campionato.conf_gp(c)
		cg["seme"] = 40 + gp
		var m := Motore.nuova(cg)
		m.avanza()
		var n := 0
		while m.s.fase != "fine" and n < 9000:
			n += 1
			if m.s.attesa == null:
				print("ERRORE ferma")
				break
			if not m.applica(IA.decidi(m, 1)):
				print("ERRORE azione ", m.s.attesa)
				break
			m.preleva_eventi()
		if gp == 0:
			m.s.auto[2]["rischio"] = "frattura"
			m.s.auto[3]["rischio"] = "rip"
		Campionato.registra(c, m.s)
		var nomi := []
		for a in m.s.auto:
			nomi.append("%s %d pp%d" % [a.nome, a.posto_arrivo, a.pp])
		print("GP ", gp, ": ", ", ".join(nomi))
		print("  assenti ", c.assenti, " scuderie ", Campionato.scuderie(c).map(func(x): return "%s %d" % [x.s, x.punti]))
	print(Campionato.esperienza_finale(c, {}))
	quit()
