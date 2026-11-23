#!/usr/bin/env node
// Integra nel JSON delle piste il file prodotto dall'editor delle piste (formato «FormulaD-traiettorie»).
// Versione 2: traiettorie aggiunte ed eliminate. Versione 3: in più, per ogni casella, posizione (p),
// rotazione (r), corsia (l), caselle nuove e tolte. I file delle piste sono JSON compatto su una riga:
// si rilegge, si modifica e si riscrive nello stesso formato.
import fs from 'node:fs';

const ingresso = process.argv[2];
if (!ingresso) throw new Error('Uso: node tools/importa_traiettorie.mjs file.json');
const pacchetto = JSON.parse(fs.readFileSync(ingresso, 'utf8'));
if (pacchetto.formato !== 'FormulaD-traiettorie' || !pacchetto.piste) throw new Error('Formato non riconosciuto');

const arrotonda = x => Math.round(Number(x) * 10) / 10;

for (const [pid, operazioni] of Object.entries(pacchetto.piste)) {
  const percorso = `assets/piste/${pid}.json`;
  const pista = JSON.parse(fs.readFileSync(percorso, 'utf8'));
  const caselle = new Map(pista.caselle.map(c => [String(c.id), c]));
  const celle = operazioni.celle || {};
  if (!(operazioni.aggiunte || []).length && !(operazioni.eliminazioni || []).length && !Object.keys(celle).length) continue;
  let nuove = 0, tolte = 0, cambiate = 0;

  // 1. caselle nuove (prima dei collegamenti, che possono riguardarle)
  for (const [cid, d] of Object.entries(celle)) {
    if (!d.nuova || d.tolta || caselle.has(cid)) continue;
    const c = { id: cid, p: [arrotonda(d.p[0]), arrotonda(d.p[1])], r: arrotonda(d.r || 0), l: Number(d.l ?? 2), s: 'x', n: [], c: Number(d.c || 0) };
    if (c.l === 0) c.pit = true;
    pista.caselle.push(c);
    caselle.set(cid, c);
    // accanto: le caselle vicine delle altre corsie
    const acc = [];
    for (const o of pista.caselle) {
      if (o.id === cid || Boolean(o.pit) !== Boolean(c.pit)) continue;
      if (Math.hypot(o.p[0] - c.p[0], o.p[1] - c.p[1]) < 67) {
        acc.push(o.id);
        (pista.vicini[o.id] ||= []).includes(cid) || pista.vicini[o.id].push(cid);
      }
    }
    pista.vicini[cid] = acc;
    nuove++;
  }

  // 2. posizione, rotazione, corsia
  for (const [cid, d] of Object.entries(celle)) {
    if (d.tolta || d.nuova) continue;
    const c = caselle.get(cid);
    if (!c) throw new Error(`${pid}: casella inesistente ${cid}`);
    if (d.p) c.p = [arrotonda(d.p[0]), arrotonda(d.p[1])];
    if (d.r !== undefined) c.r = arrotonda(d.r);
    if (d.l !== undefined) {
      c.l = Number(d.l);
      if (c.l === 0) c.pit = true; else delete c.pit;
    }
    cambiate++;
  }

  // 3. traiettorie
  const aggiunte = new Set((operazioni.aggiunte || []).map(x => `${x.da}\0${x.a}`));
  for (const [tipo, lista] of [['aggiunta', operazioni.aggiunte || []], ['eliminazione', operazioni.eliminazioni || []]]) {
    for (const op of lista) {
      const da = String(op.da), a = String(op.a);
      if (!caselle.has(da) || !caselle.has(a)) throw new Error(`${pid}: casella inesistente in ${da} -> ${a}`);
      // Se una freccia è stata eliminata e poi riaggiunta, l'aggiunta rappresenta lo stato finale.
      if (tipo === 'eliminazione' && aggiunte.has(`${da}\0${a}`)) continue;
      const prossime = caselle.get(da).n;
      const indice = prossime.indexOf(a);
      if (tipo === 'aggiunta' && indice < 0) prossime.push(a);
      if (tipo === 'eliminazione' && indice >= 0) prossime.splice(indice, 1);
    }
  }

  // 4. caselle tolte, con tutti i riferimenti
  for (const [cid, d] of Object.entries(celle)) {
    if (!d.tolta || !caselle.has(cid)) continue;
    pista.caselle = pista.caselle.filter(c => c.id !== cid);
    caselle.delete(cid);
    for (const c of pista.caselle) c.n = c.n.filter(x => x !== cid);
    delete pista.vicini[cid];
    for (const k of Object.keys(pista.vicini)) pista.vicini[k] = pista.vicini[k].filter(x => x !== cid);
    if (pista.griglia.includes(cid)) console.warn(`${pid}: attenzione, ${cid} era una casella della griglia di partenza`);
    pista.griglia = pista.griglia.filter(x => x !== cid);
    pista.traguardo = pista.traguardo.filter(x => x !== cid);
    tolte++;
  }

  fs.writeFileSync(percorso, JSON.stringify(pista));
  console.log(`${pid}: ${(operazioni.aggiunte || []).length} traiettorie aggiunte, ${(operazioni.eliminazioni || []).length} eliminate, ${cambiate} caselle corrette, ${nuove} nuove, ${tolte} tolte`);
}
