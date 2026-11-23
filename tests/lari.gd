extends SceneTree
## Gare con il regolamento Lari: conta quante volte scattano le regole nuove.
func _init():
	var conta := {}
	var chiavi := ["fuori giri", "KERS: +", "carica il KERS", "cordolo", "tampona", "danni:", "meccanici", "stesso turno", "Punto Pilota", "rischio pilota", "affidabilità", "non cambia più"]
	for g in 4:
		var lista := []
		for i in 8:
			lista.append({"nome": Dati.PILOTI[i].nome, "pilota": i, "tipo": "ia"})
		var m := Motore.nuova({"regole": "avanzate", "pista": Dati.PISTE[g * 2], "giri": 2, "auto": lista, "seme": 500 + g,
			"opzioni": {"lari": true, "kers": true, "meteo": true}})
		m.avanza()
		var passi := 0
		while m.s.fase == "gara" and passi < 8000:
			passi += 1
			if not m.applica(IA.decidi(m, 1)):
				print("ERRORE azione")
				break
			for e in m.preleva_eventi():
				if e.t == "msg":
					for k in chiavi:
						if str(e.testo).contains(k):
							conta[k] = int(conta.get(k, 0)) + 1
							if int(conta[k]) <= 2:
								print("  ", e.testo)
		print("gara ", g, " ", m.s.fase, " arrivi ", m.s.arrivi.size())
	print(conta)
	quit()
