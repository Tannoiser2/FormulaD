class_name Qualifiche
extends RefCounted
## Qualifiche a settori (Q1, Q2, Q3), proposta di un amico di Stefano.
## Il giro è diviso in 3 settori; ognuno ha un limite = 32 - 3 x fermate delle sue curve (fra 12 e 26).
## In ogni settore si sceglie una marcia (3a-6a) e si tira: entro il limite si fanno i punti del tiro, oltre di 1-4
## si fa il limite meno 2 per ogni casella in più, oltre di 5 o più testacoda (0). Il tempo del giro è la somma.
## Funzioni pure: lo stato sta nel motore (s.q).

const MARCE := [3, 4, 5, 6]

static func limiti(p: Pista) -> Array:
	var ids: Array = p.fermate.keys()
	ids.sort()
	var n := ids.size()
	var out := []
	for k in 3:
		var tot := 0
		for j in range(int(floor(k * n / 3.0)), int(floor((k + 1) * n / 3.0))):
			tot += int(p.fermate[ids[j]])
		out.append(clamp(32 - 3 * tot, 12, 26))
	return out

## Punti di un tiro nel settore con quel limite; -1 = testacoda (vale 0).
static func punti(tiro: int, limite: int) -> int:
	if tiro <= limite:
		return tiro
	var oltre := tiro - limite
	if oltre <= 4:
		return max(0, limite - 2 * oltre)
	return -1

## Per ogni marcia: punti medi, deviazione e probabilità di testacoda.
static func valuta(limite: int) -> Array:
	var out := []
	for m in MARCE:
		var vals: Array = Dati.valori_dado(m)
		var tot := 0.0
		var tot2 := 0.0
		var tc := 0
		for v in vals:
			var p := punti(int(v), limite)
			if p < 0:
				tc += 1
				p = 0
			tot += p
			tot2 += p * p
		var med := tot / vals.size()
		# come testo: i decimali si salvano e si ricaricano identici
		out.append({"m": m, "media": "%.1f" % med, "sd": "%.1f" % sqrt(max(0.0, tot2 / vals.size() - med * med)),
			"tc": int(round(100.0 * tc / vals.size())), "min": vals.min(), "max": vals.max()})
	return out

## Quante auto corrono ogni sessione: con più di 7 auto Q1, Q2 (7), Q3 (4); con 6-7 Q2 e Q3; con 5 o meno una sola.
static func sessioni(n: int) -> Array:
	if n <= 5:
		return [n]
	if n <= 7:
		return [n, 4]
	return [n, 7, 4]

static func nome_sessione(q: Dictionary) -> String:
	var tot: int = q.dim.size()
	if tot == 1:
		return "Qualifiche"
	return "Q%d" % (int(q.sess) + 1 + (3 - tot))
