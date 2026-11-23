extends SceneTree
## Controllo dei dadi: in molte gare, quante volte esce ogni faccia di ogni marcia, separando
## le auto del computer da quelle «umane» (qui guidate anch'esse dall'IA, ma il motore non lo sa).
## Se il motore favorisse qualcuno, le frequenze sarebbero diverse.
func _init() -> void:
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 40
	var conta := {"ia": {}, "umano": {}}
	var tot := {"ia": 0, "umano": 0}
	var somma := {"ia": 0.0, "umano": 0.0}
	for g in n:
		var lista := []
		for i in 6:
			lista.append({"nome": "P%d" % i, "pilota": i, "tipo": "umano" if i % 2 == 0 else "ia"})
		var m := Motore.nuova({"regole": ["base", "avanzate"][g % 2], "pista": Dati.PISTE[g % Dati.PISTE.size()], "giri": 1, "auto": lista})
		m.avanza()
		var passi := 0
		while m.s.fase == "gara" and passi < 5000:
			passi += 1
			var i := int(m.s.attesa.auto)
			if not m.applica(IA.decidi(m, 2)):
				break
			for e in m.preleva_eventi():
				if e.t == "dado":
					var chi: String = m.s.auto[int(e.auto)].tipo
					var k := "%d:%d" % [int(e.marcia), int(e.faccia)]
					conta[chi][k] = int(conta[chi].get(k, 0)) + 1
					tot[chi] += 1
					# posizione del valore nell'intervallo della marcia (0 = minimo, 1 = massimo)
					var facce: Array = Dati.DADI[int(e.marcia)]
					var lo := 99
					var hi := 0
					for f in facce:
						lo = min(lo, int(f[0]))
						hi = max(hi, int(f[0]))
					somma[chi] += float(int(e.valore) - lo) / max(1, hi - lo)
	for chi in ["ia", "umano"]:
		print("%s: %d tiri, valore medio nell'intervallo %.3f (0,5 = dado onesto)" % [chi, tot[chi], somma[chi] / max(1, tot[chi])])
	# chi quadro per marcia, tutti i tiri insieme
	for marcia in range(1, 7):
		var f: int = Dati.DADI[marcia].size()
		var oss := []
		var t := 0
		for k in f:
			var c: int = int(conta.ia.get("%d:%d" % [marcia, k], 0)) + int(conta.umano.get("%d:%d" % [marcia, k], 0))
			oss.append(c)
			t += c
		var chi2 := 0.0
		for c in oss:
			var att: float = float(t) / f
			chi2 += (c - att) * (c - att) / max(att, 0.001)
		print("marcia %d: %d tiri, facce %s, chi quadro %.1f con %d gradi di libertà" % [marcia, t, str(oss), chi2, f - 1])
	quit()
