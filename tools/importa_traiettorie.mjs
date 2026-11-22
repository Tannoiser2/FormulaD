#!/usr/bin/env node
// Integra nel JSON delle piste il file prodotto dall'editor, mantenendo minime le differenze testuali.
import fs from 'node:fs';

const ingresso = process.argv[2];
if (!ingresso) throw new Error('Uso: node tools/importa_traiettorie.mjs file.json');
const pacchetto = JSON.parse(fs.readFileSync(ingresso, 'utf8'));
if (pacchetto.formato !== 'FormulaD-traiettorie' || !pacchetto.piste) throw new Error('Formato non riconosciuto');

for (const [pid, operazioni] of Object.entries(pacchetto.piste)) {
  const percorso = `assets/piste/${pid}.json`;
  let testo = fs.readFileSync(percorso, 'utf8');
  const pista = JSON.parse(testo);
  const caselle = new Map(pista.caselle.map(c => [String(c.id), c]));
  const aggiunte = new Set((operazioni.aggiunte || []).map(x => `${x.da}\0${x.a}`));
  const cambiate = new Map();

  for (const [tipo, lista] of [['aggiunta', operazioni.aggiunte || []], ['eliminazione', operazioni.eliminazioni || []]]) {
    for (const op of lista) {
      const da = String(op.da), a = String(op.a), chiave = `${da}\0${a}`;
      if (!caselle.has(da) || !caselle.has(a)) throw new Error(`${pid}: casella inesistente in ${da} -> ${a}`);
      // Se una freccia è stata eliminata e poi riaggiunta, l'aggiunta rappresenta lo stato finale.
      if (tipo === 'eliminazione' && aggiunte.has(chiave)) continue;
      const prossime = cambiate.get(da) || caselle.get(da).n.map(String);
      const indice = prossime.indexOf(a);
      if (tipo === 'aggiunta' && indice < 0) prossime.push(a);
      if (tipo === 'eliminazione' && indice >= 0) prossime.splice(indice, 1);
      cambiate.set(da, prossime);
    }
  }

  for (const [da, prossime] of cambiate) {
    const id = `"id":${JSON.stringify(da)}`;
    const inizioCasella = testo.indexOf(id);
    if (inizioCasella < 0) throw new Error(`${pid}: impossibile trovare ${da} nel testo`);
    const inizioN = testo.indexOf('"n":[', inizioCasella);
    const fineCasella = testo.indexOf('}', inizioCasella);
    if (inizioN < 0 || inizioN > fineCasella) throw new Error(`${pid}: collegamenti non trovati per ${da}`);
    const inizioArray = inizioN + 4;
    const fineArray = testo.indexOf(']', inizioArray) + 1;
    testo = testo.slice(0, inizioArray) + JSON.stringify(prossime) + testo.slice(fineArray);
  }
  fs.writeFileSync(percorso, testo);
  console.log(`${pid}: aggiornate ${cambiate.size} caselle`);
}
