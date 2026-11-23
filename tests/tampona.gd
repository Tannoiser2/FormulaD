extends SceneTree
## Strada bloccata con il regolamento Lari: frenata oltre 6 pagata con altri punti, o tamponamento.
func _init():
	var lista := []
	for i in 5:
		lista.append({"nome": "P%d" % i, "pilota": i, "tipo": "ia"})
	var m := Motore.nuova({"regole": "avanzate", "pista": "FDMonaco", "giri": 2, "auto": lista, "seme": 3, "opzioni": {"lari": true}})
	var p := m.pista
	var a: Dictionary = m.s.auto[0]
	a.c = p.griglia[8]
	a.partito = true
	a.marcia = 6
	var muro := []
	for c in p.caselle:
		var d := p.progresso(a.c, c.id)
		if d > 2.2 and d < 3.4 and not c.pit:
			muro.append(c.id)
	print("muro ", muro)
	for k in range(1, 5):
		m.s.auto[k].c = muro[(k - 1) % muro.size()] if k - 1 < muro.size() else ""
		m.s.auto[k].partito = true
	for prova in [[3, 3, 3, 2], [0, 0, 1, 1]]:
		a.pf = {"gomme": 6, "freni": 3, "cambio": prova[0], "carrozzeria": prova[1] + 1, "motore": prova[2] + 1, "tenuta": prova[3] + 1}
		m.s.attesa = {"tipo": "mossa", "auto": 0, "tiro": 25}
		m._calcola_opzioni()
		for cid in m.opzioni:
			var e: Dictionary = m.opzioni[cid].eff
			print("opzione ", cid, " freno ", m.opzioni[cid].freno, " usura ", e.usura, " fuori '", e.fuori, "' crash ", e.get("crash", false), " contro ", e.get("tampona", -1))
		m.applica({"t": "mossa", "c": m.opzioni.keys()[0]})
		for ev in m.preleva_eventi():
			if ev.t == "msg":
				print("   ", ev.testo)
		print("dopo: ", a.pf, " fuori ", a.fuori, " dz ", a.dz)
		a.fuori = false
		a.c = p.griglia[8]
		a.mosso = -1
		a.dz = {}
	quit()
