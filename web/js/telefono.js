// Il telefono del pilota: entra nella stanza con il QR code e decide da qui marcia e casella.
// Il tabellone, i dadi e i movimenti restano sullo schermo grande.
import { creaRete, RADICE, unisci } from './rete.js';
import { sbloccaAudio, suona } from './suoni.js';

const q = new URLSearchParams(location.search);
const app = document.getElementById('app');
const PILOTI = [
  ['dimitri', 'rossa', 0], ['jack', 'blu', 0], ['stanley', 'gialla', 0], ['derek', 'verde', 0], ['diane', 'bianca', 0],
  ['jenny', 'rossa', 1], ['montoya', 'blu', 1], ['temana', 'gialla', 1], ['julien', 'verde', 1], ['litsu', 'bianca', 1],
];
const NOMI_PILOTI = ['Dimitri Tzarof', 'Jack Owens', 'Stanley Washington', 'Derek Manson', 'Diane Montfort', 'Jenny Slivers', 'Montoya Cadena',
  'Temana Matahi', 'Julien Marcellin', 'Li Tsu Sin'];
const SCUDERIE = { bianca: [242, 242, 242], gialla: [250, 209, 20], verde: [51, 184, 51], rossa: [219, 26, 26], blu: [38, 140, 242] };
const MARCE = ['folle', '1a', '2a', '3a', '4a', '5a', '6a'];
const INTERVALLI = ['', '1-2', '2-4', '4-8', '7-12', '11-20', '21-30'];
const COL_MARCE = ['#666', '#edd40d', '#f26b0d', '#b82126', '#0d801a', '#5c1a8c', '#0d40a6'];
const ZONE = {
  base: [['ps', 'Punti Struttura', '#f2cc1a']],
  avanzate: [['gomme', 'Gomme', '#4033b3'], ['freni', 'Freni', '#80bf1a'], ['cambio', 'Cambio', '#1a9999'], ['carrozzeria', 'Carrozzeria', '#e6991a'],
    ['motore', 'Motore', '#d9261a'], ['tenuta', 'Tenuta', '#9933b3']],
};
const COL = { libera: '#26f24d', costo: '#ffd91a', testa: '#ff800d', fuori: '#f21a1a', box: '#33b3ff', arrivo: '#ffffff' };

let rete = null;
let uid = '';
let codice = (q.get('s') || '').toUpperCase().slice(0, 4);
let nome = '';
try { nome = localStorage.getItem('fd_nome') || ''; } catch (e) { /* ok */ }
// sulle caselle: icone delle zone con il numero, oppure le parole
let icone = true;
try { icone = localStorage.getItem('fd_scritte') !== 'parole'; } catch (e) { /* ok */ }
const ICONE = {};
for (const k of ['gomme', 'freni', 'cambio', 'carrozzeria', 'motore', 'tenuta', 'ps']) {
  const im = new Image();
  im.onload = () => disegna();
  im.src = `img/zone/${k}.png`;
  ICONE[k] = im;
}
let stato = null;
let scelta = null;       // opzione di mossa toccata
let inviata = -1;        // numero dello stato a cui ho già risposto
let toccavaAMe = false;
let errore = '';
const immagini = {};
let assChiave = '';      // assetto in preparazione sul telefono
let assPf = {};
let assG = '';
const GOMME = { dure: 'Dure', morbide: 'Morbide', pioggia: 'Da pioggia' };
const DESCR_GOMME = {
  dure: 'Sempre affidabili. Pioggia: +3 in curva.',
  morbide: 'Asciutto: +1 casella facoltativa (primo giro), lungo in curva costa il doppio. Pioggia: +3 in curva.',
  pioggia: 'Pioggia: +1 in curva. Asciutto: lungo in curva costa il doppio.',
};
const METEO = ['Bel tempo', 'Variabile', 'Pioggia (variabile)', 'Pioggia'];
const MAX_ZONA = { gomme: 14, freni: 7, cambio: 7, carrozzeria: 7, motore: 7, tenuta: 7 };

function colore(p) {
  const [, sc, variante] = PILOTI[p];
  const c = SCUDERIE[sc].map((x) => Math.round(variante ? x * 0.72 : x));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}
function esc(s) { return String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function usura(regole, u) {
  return ZONE[regole].filter(([id]) => (u?.[id] || 0) > 0).map(([id, n]) => `${u[id]} ${n}`).join(', ');
}
const NOMI_CORTI = { ps: 'PS', gomme: 'Gomme', freni: 'Freni', cambio: 'Cambio', carrozzeria: 'Carrozz.', motore: 'Motore', tenuta: 'Tenuta' };
const CHIARI = { ps: '#f8e48c', gomme: '#9a94db', freni: '#b8d98c', cambio: '#8ccaca', carrozzeria: '#f2c98c', motore: '#ec958c', tenuta: '#c994d9' };
function opzExtra(o) { return (o.pi || 0) > 0 || (o.sc || 0) > 0 || (o.jk || 0) !== 0; }
// le scritte su una casella: le caselle in più e che cosa costa
function righeOpz(o) {
  const r = [];
  const ni = o.ni || 0, pi = (o.pi || 0) - ni;
  if (ni > 0) r.push([`NITRO +${ni}`, '#40e6ff']);
  if (pi > 0) r.push([`MORBIDE +${pi}`, '#40e6ff']);
  if (o.sc > 0) r.push([o.sc === 1 ? 'SCIA' : `SCIA x${o.sc}`, '#40e6ff']);
  if (o.jk) r.push(['DERAPATA', '#40e6ff']);
  if (o.fu) r.push(['RITIRO', '#ff5a4d']);
  else if (o.te) r.push(['TESTACODA', '#ffa633']);
  if (o.bx) r.push(['BOX', '#73ccff']);
  if (o.fi) r.push(['ARRIVO', '#fff']);
  if (!o.fu) for (const k of ['gomme', 'freni', 'cambio', 'carrozzeria', 'motore', 'tenuta', 'ps']) if ((o.u?.[k] || 0) > 0) r.push([`${NOMI_CORTI[k]} -${o.u[k]}`, CHIARI[k]]);
  return r;
}
function coloreOpz(o) {
  if (o.fu) return COL.fuori;
  if (o.fi) return COL.arrivo;
  if (o.bx) return COL.box;
  if (o.te) return COL.testa;
  if (o.u && Object.keys(o.u).length) return COL.costo;
  return COL.libera;
}
function testoOpz(regole, o) {
  const parti = [o.mo === 0 ? 'Resta ferma' : `Avanza di ${o.mo}`];
  if (o.sc > 0) parti.push('in scia');
  if (o.fr > 0) parti.push(`frena ${o.fr}`);
  if (o.ol > 0) parti.push(`lungo di ${o.ol}`);
  if (o.ni > 0) parti.push(`con il Nitro (+${o.ni})`);
  if (o.jk) parti.push('derapata');
  let t = parti.join(', ') + '.';
  if (o.fi) return t + ' TRAGUARDO!';
  const c = usura(regole, o.u);
  if (c) t += ` Perde ${c}.`;
  if (o.bx) t += ' Sosta al box.';
  if (o.te) t += ' TESTACODA: ripartirai in 1a.';
  if (o.fu) t += ` RITIRO: ${o.fu}.`;
  if (o.to > 0) t += ` Rischio collisione (${o.to}).`;
  if (o.pe > 0) t += ' Passi sui detriti.';
  return t;
}

// ------------------------------------------------------------------ ingresso
function ingresso() {
  app.innerHTML = `
    <h1>FORMULA D</h1>
    <p class="sotto">Il tuo volante: il tabellone resta sullo schermo grande</p>
    <div class="box">
      <label for="cod">Codice della stanza</label>
      <input id="cod" class="codice" maxlength="4" autocomplete="off" autocapitalize="characters" value="${esc(codice)}">
      <label for="nom" style="margin-top:10px">Il tuo nome</label>
      <input id="nom" maxlength="14" autocomplete="off" value="${esc(nome)}">
      <div class="errore">${esc(errore)}</div>
      <button id="entra" class="verde">ENTRA IN GARA</button>
    </div>`;
  document.getElementById('entra').onclick = entra;
}

async function entra() {
  sbloccaAudio();
  codice = document.getElementById('cod').value.trim().toUpperCase();
  nome = document.getElementById('nom').value.trim().slice(0, 14);
  if (codice.length !== 4) { errore = 'Il codice ha 4 lettere'; ingresso(); return; }
  if (!nome) { errore = 'Scrivi il tuo nome'; ingresso(); return; }
  try { localStorage.setItem('fd_nome', nome); } catch (e) { /* ok */ }
  app.innerHTML = '<h1>FORMULA D</h1><p class="sotto">Entro nella stanza...</p>';
  try {
    if (!rete) { rete = creaRete(); uid = await rete.init(); }
    const h = await rete.get(`${RADICE}/${codice}/host`);
    if (!h) { errore = `La stanza ${codice} non esiste`; ingresso(); return; }
    await rete.set(`${RADICE}/${codice}/seats/${uid}`, { uid, name: nome });
    rete.on(`${RADICE}/${codice}/game`, (v) => {
      if (!codice) return;
      const j = unisci(v);
      if (!j) return;
      try { stato = JSON.parse(j); } catch (e) { return; }
      if (stato.sk === 'online') {
        // una gara online si gioca dal computer, non dal telefono
        rete.remove(`${RADICE}/${codice}/seats/${uid}`).catch(() => {});
        const c = codice;
        codice = '';
        stato = null;
        app.innerHTML = `<h1>FORMULA D</h1><div class="box"><p class="grande">Gara online ${esc(c)}</p><p class="sotto">Questa gara si gioca dal computer: apri il gioco sul computer e scegli «Gara online» e poi «Entra in una gara». Il telefono serve per le gare TV + telefoni.</p></div>`;
        return;
      }
      disegna();
    });
    if (!codice) return;   // respinto subito (gara online)
    try { if ('wakeLock' in navigator) await navigator.wakeLock.request('screen'); } catch (e) { /* ok */ }
    if (!stato && codice) app.innerHTML = `<h1>FORMULA D</h1><div class="box"><p class="grande">Stanza ${esc(codice)}</p><p class="sotto">Sei dentro, ${esc(nome)}. Aspetta il via sullo schermo grande.</p></div>`;
  } catch (e) {
    console.error(e);
    errore = 'Non riesco a collegarmi: ' + (e?.message || e);
    ingresso();
  }
}

function manda(az) {
  inviata = stato?.n ?? 0;
  scelta = null;
  marciaVista = 0;
  rete.push(`${RADICE}/${codice}/acts`, { s: uid, k: 'az', v: JSON.stringify({ ...az, n: stato?.n ?? 0 }) });
  disegna();
}

// ------------------------------------------------------------------ schermate
// In gara: l'ordine di gioco, la plancia originale (le marce si scelgono lì) e il pezzo di pista che interessa.
// In verticale uno sotto l'altro; in orizzontale plancia a sinistra, pista al centro, ordine a destra.
const PLANCIA = { larg: 823, alt: 498, px: 82.3,
  colX: [0.96, 0.10, -0.77, -1.63, -2.49, -3.35, -4.21], rigaZ: [-2.31, -1.55, -0.78, 0.00, 0.77, 1.55, 2.33],
  leva: [[2.48, -2.03], [4.23, -1.22], [2.47, -0.40], [4.20, 0.34], [2.45, 1.16], [4.20, 1.94]],
  righe: { freni: 2, cambio: 3, carrozzeria: 4, motore: 5, tenuta: 6 } };
const COL_LIV = [COL.libera, COL.costo, COL.testa, COL.fuori];
const TESTI_LIV = ['libera', '', 'testacoda', 'ritiro'];
let marciaVista = 0;     // marcia toccata una volta: si vedono le caselle, il secondo tocco conferma
let nVisto = -1;

function puntoPlancia(x, z) {
  return stato.regole === 'avanzate' ? [(5 - x) * PLANCIA.px, (z + 3.03) * PLANCIA.px] : [(5 - x) * PLANCIA.px, (3.03 - z) * PLANCIA.px];
}
function puntoMarcia(m) {
  const g = stato.regole === 'avanzate' ? PLANCIA.leva[m - 1] : PLANCIA.leva[6 - m];
  return puntoPlancia(g[0], g[1]);
}

function disegna() {
  if (!stato) return;
  document.body.classList.toggle('gara', stato.fase !== 'attesa');
  if (stato.fase === 'attesa') { attesa(); return; }
  if (stato.n !== nVisto) { nVisto = stato.n; marciaVista = 0; scelta = null; }
  const io = stato.auto.findIndex((a) => a.u === uid);
  const att = stato.att;
  const tocca = !!att && att.uid === uid && inviata !== stato.n && (stato.fase === 'gara' || stato.fase === 'qualifiche');
  if (tocca && !toccavaAMe) {
    suona('tocca');
    try { navigator.vibrate?.(250); } catch (e) { /* ok */ }
  }
  toccavaAMe = tocca;
  const mia = io >= 0 ? stato.auto[io] : null;
  if (tocca && att.tipo === 'mossa' && scelta) scelta = att.opz.find((o) => o.c === scelta.c) || null;
  const vistaM = tocca && att.tipo === 'marcia' && marciaVista ? att.marce.find((o) => o.m === marciaVista) : null;

  // ---- che cosa si aspetta
  let az = '';
  if (stato.fase === 'fine') {
    az = `<p class="grande">BANDIERA A SCACCHI</p>${mia ? `<p class="grande" style="color:#ffd21a">${mia.pa > 0 ? mia.pa + '° posto' : 'Ritirato'}</p>` : ''}`;
  } else if (tocca && att.tipo === 'marcia') {
    if (vistaM) {
      const costo = usura(stato.regole, vistaM.costo);
      az = `<h2>${MARCE[vistaM.m]} <small>dado ${INTERVALLI[vistaM.m]}${costo ? ' - perdi ' + esc(costo) : ''}${vistaM.fuori ? ' - RITIRO!' : ''}</small></h2>
        <div class="esiti">${(vistaM.pv?.t || []).map(([t, l, p]) => `<span style="background:${COL_LIV[l]};color:${l === 3 ? '#fff' : '#111'}"><b>${t}</b>${l === 1 ? '-' + p : TESTI_LIV[l]}</span>`).join('')}</div>
        <button id="okm" style="background:${COL_MARCE[vistaM.m]};color:${vistaM.m === 1 ? '#111' : '#fff'}">CONFERMA LA ${MARCE[vistaM.m].toUpperCase()}</button>`;
    } else {
      az = `<h2>Tocca a te: scegli la marcia</h2><p class="sotto">Tocca una marcia cerchiata sulla plancia: vedrai dove puoi arrivare. Toccala ancora per confermare.</p>`;
    }
  } else if (tocca && (att.tipo === 'qualifica' || att.tipo === 'qritira')) {
    az = qualifica(att);
  } else if (tocca && att.tipo === 'assetto') {
    az = assetto(att, mia);
  } else if (tocca && att.tipo === 'mossa') {
    az = `<h2>Tiro <span class="dado" style="background:${COL_MARCE[mia.m]};color:${mia.m === 1 ? '#111' : '#fff'}">${att.tiro}</span> in ${MARCE[mia.m]}</h2>
      <div id="det" class="dettaglio ${scelta && (scelta.fu || scelta.te) ? 'male' : ''}">${scelta ? esc(testoOpz(stato.regole, scelta)) : 'Tocca una casella colorata sulla pista.'}</div>
      <button id="ok" class="${scelta && (scelta.fu || scelta.te) ? '' : 'verde'}" ${scelta ? '' : 'disabled'}>CONFERMA</button>
      ${att.pp > 0 ? `<button id="pp" class="piccolo">Ritira il dado (Punti Pilota: ${att.pp})</button>` : ''}
      <button id="scritte" class="piccolo">Sulle caselle: ${icone ? 'parole' : 'icone'}</button>`;
  } else if (att) {
    const a = stato.auto[att.auto];
    az = `<p class="grande" style="color:${colore(a.p)}">${att.uid === uid ? 'Mossa inviata...' : 'Tocca a ' + esc(a.n)}</p>`;
    const ultimo = (stato.log || []).slice(-1)[0];
    if (ultimo) az += `<p class="sotto">${esc(ultimo)}</p>`;
  }
  if (!mia) az = `<h2>Spettatore</h2><p class="sotto">La gara è partita senza un posto per te: puoi seguirla da qui.</p>` + (stato.fase === 'fine' ? az : '');

  // ---- la mia auto in breve
  let testa = '';
  if (mia) {
    let st = `${mia.m > 0 ? MARCE[mia.m] : 'in griglia'} - giro ${Math.max(1, Math.min(mia.g, stato.giri))} di ${stato.giri}${mia.d ? ' - tiro ' + mia.d : ''}`;
    if (stato.mt >= 0) st += ` - ${METEO[stato.mt]}`;
    if (stato.mon) st += ` - gomme ${(GOMME[mia.gt] || 'dure').toLowerCase()}`;
    if (stato.str) st += ` - Nitro ${mia.ni ? 'pronto' : 'usato'}`;
    if (mia.pa > 0) st = `ARRIVATO: ${mia.pa}° posto`;
    else if (mia.f) st = `RITIRATO: ${esc(mia.w)}`;
    testa = `<div class="chi"><span class="nome" style="color:${colore(mia.p)}">${esc(mia.n)}</span><span class="dati">${st}</span></div>
      <div class="zone">${ZONE[stato.regole].map(([id, n, c]) =>
    `<div class="zona ${mia.pf[id] <= 1 ? 'poco' : ''}" style="border-color:${c}"><span>${n}</span><b>${Math.max(0, mia.pf[id])}</b></div>`).join('')}</div>`;
  }

  const prep = tocca && (att.tipo === 'assetto' || att.tipo === 'qualifica' || att.tipo === 'qritira');
  app.innerHTML = `<div class="gioco ${prep ? 'prep' : ''}">
    <div class="ordine">${ordine(io)}</div>
    <div class="cruscotto ${tocca ? 'tocca' : ''}">${mia && !prep ? '<canvas id="plancia"></canvas>' : ''}${testa}<div class="azione">${az}</div></div>
    <div class="pista"><canvas id="mappa"></canvas></div></div>`;
  app.querySelectorAll('[data-z]').forEach((b) => { b.onclick = () => { assPf[b.dataset.z] += Number(b.dataset.d); disegna(); }; });
  app.querySelectorAll('[data-g]').forEach((b) => { b.onclick = () => { assG = b.dataset.g; disegna(); }; });
  app.querySelectorAll('[data-qm]').forEach((b) => { b.onclick = () => manda({ t: 'qualifica', m: Number(b.dataset.qm) }); });
  app.querySelectorAll('[data-qr]').forEach((b) => { b.onclick = () => manda({ t: 'qritira', si: b.dataset.qr === '1' }); });
  const bpp = document.getElementById('pp');
  if (bpp) bpp.onclick = () => manda({ t: 'ritira' });
  const bsc = document.getElementById('scritte');
  if (bsc) bsc.onclick = () => { icone = !icone; try { localStorage.setItem('fd_scritte', icone ? 'icone' : 'parole'); } catch (e) { /* ok */ } disegna(); };
  const oka = document.getElementById('oka');
  if (oka) oka.onclick = () => { const az = { t: 'assetto', g: assG }; if (att.libero) az.pf = { ...assPf }; assChiave = ''; manda(az); };
  const okm = document.getElementById('okm');
  if (okm) okm.onclick = () => manda({ t: 'marcia', m: marciaVista });
  const ok = document.getElementById('ok');
  if (ok) ok.onclick = () => { if (scelta) manda({ t: 'mossa', c: scelta.c }); };
  if (prep) return;
  if (mia) plancia(mia, tocca && att.tipo === 'marcia' ? att.marce : []);
  mappa(mia, tocca ? att : null, vistaM);
}

// Prima del via (punti liberi e gomme) o al box (gomme nuove).
function assetto(att, mia) {
  const chiave = `${att.auto}-${att.box}-${mia.g}-${stato.turno}`;
  if (chiave !== assChiave) {
    assChiave = chiave;
    assPf = { ...att.pf };
    assG = att.g;
    if (att.box && att.gomme.includes('pioggia') && stato.mt >= 2) assG = 'pioggia';
  }
  let h = `<h2>${att.box ? 'Box: gomme nuove' : "Prepara l'auto"}${stato.mt >= 0 ? ` <small>${METEO[stato.mt]}</small>` : ''}</h2>`;
  let tot = 0;
  for (const k in assPf) tot += assPf[k];
  if (att.libero) {
    h += '<div class="assetto">' + ZONE.avanzate.map(([id, n, c]) => `<span style="color:${c}">${n}</span>
      <button data-z="${id}" data-d="-1" ${assPf[id] <= 1 ? 'disabled' : ''}>-</button><b>${assPf[id]}</b>
      <button data-z="${id}" data-d="1" ${assPf[id] >= MAX_ZONA[id] || tot >= 20 ? 'disabled' : ''}>+</button>`).join('') + '</div>';
    const resta = 20 - tot;
    h += `<p class="sotto" style="color:${resta ? '#ffd21a' : '#7be07b'}">${resta > 0 ? 'Punti da ripartire: ' + resta : resta < 0 ? 'Punti di troppo: ' + -resta : 'Tutti i 20 punti ripartiti'}</p>`;
  }
  if (att.gomme.length > 1) {
    h += '<div class="gomme">' + att.gomme.map((g) => `<button data-g="${g}" class="${g === assG ? 'su' : ''}">${GOMME[g]}</button>`).join('') + '</div>';
    h += `<p class="sotto">${DESCR_GOMME[assG] || ''}</p>`;
  }
  h += `<button id="oka" class="verde" ${att.libero && tot !== 20 ? 'disabled' : ''}>CONFERMA</button>`;
  return h;
}

// Qualifiche: la marcia del settore, poi se si vuole riprovare.
function qualifica(att) {
  if (att.tipo === 'qritira') {
    return `<h2>Settore ${att.sett + 1}: ${att.punti} punti</h2>
      <p class="sotto">Hai tirato ${att.tiro} in ${MARCE[att.m]} (limite ${att.limite}). Riprovare costa ${esc(att.costo)}.</p>
      <div class="gomme"><button data-qr="0" class="su">Tengo ${att.punti} punti</button><button data-qr="1">Riprovo</button></div>`;
  }
  let h = `<h2>${esc(att.sessione)}: settore ${att.sett + 1} <small>limite ${att.limite}</small></h2>
    <p class="sotto">Finora ${att.fatto} punti${att.meglio ? `, il migliore ne ha ${att.meglio}` : ''}. Oltre il limite di 1-4: limite meno 2 a casella; di 5 o più: testacoda.</p><div class="gomme qmarce">`;
  for (const o of att.marce) h += `<button data-qm="${o.m}">${MARCE[o.m]} (${o.min}-${o.max}): media ${String(o.media).replace('.', ',')}${o.tc ? `<br>testacoda ${o.tc}%` : ''}</button>`;
  return h + '</div>';
}

function ordine(io) {
  const att = stato.att;
  return stato.ordine.map((i) => {
    const a = stato.auto[i];
    const fuori = a.pa > 0 || a.f;
    return `<span class="oc ${att && att.auto === i ? 'turno' : ''} ${i === io ? 'io' : ''} ${fuori ? 'via' : ''}"><i style="background:${colore(a.p)}"></i>
      <span class="n">${esc(String(a.n).split(' ')[0])}</span><b style="background:${COL_MARCE[a.m]};color:${a.m === 1 ? '#111' : '#fff'}">${a.pa > 0 ? a.pa + '°' : a.f ? 'rit' : a.m > 0 ? MARCE[a.m] : '-'}</b></span>`;
  }).join('');
}

// La plancia originale: i perni sui punti rimasti, la leva sulla marcia, le marce che si possono innestare cerchiate.
function plancia(a, marce) {
  const cv = document.getElementById('plancia');
  const nome = stato.regole === 'avanzate' ? 'plancia_avanzata' : 'plancia_base';
  const im = immagine('img/' + nome + '.webp');
  const larg = cv.clientWidth || 320;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  cv.width = Math.round(larg * dpr);
  cv.height = Math.round(larg * PLANCIA.alt / PLANCIA.larg * dpr);
  const s = cv.width / PLANCIA.larg;
  const g = cv.getContext('2d');
  g.fillStyle = '#1b2029';
  g.fillRect(0, 0, cv.width, cv.height);
  if (im.complete && im.naturalWidth) g.drawImage(im, 0, 0, cv.width, cv.height);
  const perno = ([x, y], r, col) => {
    g.beginPath(); g.arc(x * s + 1.5 * s, y * s + 2.5 * s, r * s, 0, 6.2832); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
    g.beginPath(); g.arc(x * s, y * s, r * s, 0, 6.2832); g.fillStyle = '#1f1f24'; g.fill();
    g.beginPath(); g.arc(x * s, y * s, r * s * 0.82, 0, 6.2832); g.fillStyle = col; g.fill();
    g.beginPath(); g.arc((x - 4) * s, (y - 4) * s, r * s * 0.3, 0, 6.2832); g.fillStyle = 'rgba(255,255,255,.55)'; g.fill();
  };
  if (stato.regole === 'avanzate') {
    for (const [id, , col] of ZONE.avanzate) {
      let n = a.pf[id];
      if (!(n > 0)) continue;
      if (id === 'gomme') { n = Math.min(n, 14); perno(puntoPlancia(PLANCIA.colX[(n - 1) % 7], PLANCIA.rigaZ[Math.floor((n - 1) / 7)]), 21, col); }
      else { n = Math.min(n, 7); perno(puntoPlancia(PLANCIA.colX[n - 1], PLANCIA.rigaZ[PLANCIA.righe[id]]), 21, col); }
    }
  } else {
    const n = Math.max(0, Math.min(18, a.pf.ps || 0));
    if (n > 0) perno(puntoPlancia(PLANCIA.colX[(n - 1) % 3], PLANCIA.rigaZ[6 - Math.floor((n - 1) / 3)]), 21, '#e61a1a');
  }
  if (a.m >= 1) perno(puntoMarcia(a.m), 30, stato.regole === 'avanzate' ? '#e61a1a' : '#26262e');
  for (const o of marce) {
    const [x, y] = puntoMarcia(o.m);
    const sel = o.m === marciaVista;
    g.beginPath();
    g.arc(x * s, y * s, (sel ? 34 : 29) * s, 0, 6.2832);
    g.lineWidth = (sel ? 9 : 5) * s;
    g.strokeStyle = sel ? '#ffffff' : '#ffd21a';
    g.stroke();
    if (sel) { g.beginPath(); g.arc(x * s, y * s, 40 * s, 0, 6.2832); g.lineWidth = 3 * s; g.strokeStyle = '#000'; g.stroke(); }
  }
  cv.onpointerdown = (ev) => {
    if (!marce.length) return;
    const b = cv.getBoundingClientRect();
    const x = (ev.clientX - b.left) / b.width * PLANCIA.larg, y = (ev.clientY - b.top) / b.height * PLANCIA.alt;
    let best = null, bd = 75;
    for (const o of marce) {
      const [mx, my] = puntoMarcia(o.m);
      const d = Math.hypot(mx - x, my - y);
      if (d < bd) { bd = d; best = o; }
    }
    if (!best) return;
    sbloccaAudio();
    if (marciaVista === best.m) { manda({ t: 'marcia', m: best.m }); return; }
    marciaVista = best.m;
    disegna();
  };
}

function attesa() {
  const mio = (stato.posti || []).find((p) => p.u === uid);
  let h = `<h1>FORMULA D</h1><div class="box mio"><p class="grande">Stanza ${esc(codice)}</p>`;
  if (mio) {
    h += `<div class="testa"><span class="col" style="background:${colore(mio.p)}"></span><div class="chi"><div class="nome">${esc(nome)}</div>
      <div class="dati">${stato.abil ? `Guidi l'auto di ${esc(NOMI_PILOTI[mio.p])}, scuderia` : 'Guidi l\'auto della scuderia'} ${PILOTI[mio.p][1]}. Aspetta il via!</div></div></div>`;
  } else {
    h += `<p class="sotto">Sei dentro, ma non c'è ancora un posto libero per te: chiedi a chi organizza di aprirne uno («Telefono / online»).</p>`;
  }
  h += `</div><div class="box"><h2>In griglia</h2>`;
  for (const p of stato.posti || []) {
    if (p.tp === 'chiuso') continue;
    const chi = p.tp === 'ia' ? 'computer' : p.tp === 'umano' ? 'schermo grande' : (p.u ? esc(p.n) : 'posto libero');
    h += `<div class="riga ${p.u === uid ? 'io' : ''}"><span class="col" style="background:${colore(p.p)}"></span><span class="n">${esc(p.nm || NOMI_PILOTI[p.p])}</span><span class="p">${chi}</span></div>`;
  }
  h += `</div>`;
  app.innerHTML = h;
}

// ------------------------------------------------------------------ il pezzo di pista che interessa
function immagine(src) {
  if (!immagini[src]) {
    const im = new Image();
    im.onload = () => disegna();
    im.src = src;
    immagini[src] = im;
  }
  return immagini[src];
}

// att: la decisione che aspetta me (o null); vistaM: la marcia di cui si guarda l'anteprima
function mappa(mia, att, vistaM) {
  const cv = document.getElementById('mappa');
  const im = immagine(`img/piste/${stato.pista}.webp`);
  const opz = att && att.tipo === 'mossa' ? att.opz : vistaM?.pv?.c || [];
  const toccabili = !!att && att.tipo === 'mossa';
  const iw = stato.iw || 2474;
  const ih = im.naturalWidth ? iw * im.naturalHeight / im.naturalWidth : iw * 0.65;
  const qui = mia ? stato.caselle?.[mia.c] : null;
  // riquadro del tabellone: le caselle possibili e la mia auto; senza caselle, i dintorni della mia auto
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  const dentro = (x, y) => { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); };
  for (const o of opz) dentro(o.x, o.y);
  if (qui) dentro(qui[0], qui[1]);
  if (x0 === Infinity) { x0 = 0; y0 = 0; x1 = iw; y1 = ih; }
  else {
    const m = opz.length ? 80 : 300;
    x0 -= m; y0 -= m; x1 += m; y1 += m;
  }
  const larg = cv.parentElement.clientWidth || 320, alt = Math.max(140, cv.parentElement.clientHeight || 240);
  let w = Math.max(x1 - x0, 380), hh = Math.max(y1 - y0, 260);
  if (hh / w > alt / larg) w = hh * larg / alt; else hh = w * alt / larg;
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  x0 = cx - w / 2; y0 = cy - hh / 2;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  cv.width = Math.round(larg * dpr);
  cv.height = Math.round(alt * dpr);
  cv.style.width = larg + 'px';
  cv.style.height = alt + 'px';
  const k = cv.width / w;            // pixel dello schermo per pixel del tabellone
  const g = cv.getContext('2d');
  const px = (x) => (x - x0) * k, py = (y) => (y - y0) * k;
  const r = Math.max(8 * dpr, 17 * k);

  g.fillStyle = '#20242c';
  g.fillRect(0, 0, cv.width, cv.height);
  if (im.complete && im.naturalWidth) {
    // solo la parte del riquadro che sta dentro l'immagine
    const ax = Math.max(0, x0), ay = Math.max(0, y0), bx = Math.min(iw, x0 + w), by = Math.min(ih, y0 + hh);
    if (bx > ax && by > ay) {
      const s = im.naturalWidth / iw;
      g.drawImage(im, ax * s, ay * s, (bx - ax) * s, (by - ay) * s, px(ax), py(ay), (bx - ax) * k, (by - ay) * k);
    }
  }
  // le caselle raggiungibili, intere e nella loro direzione; bordo azzurro per quelle in più facoltative
  const [cl, cw] = stato.cel || [45, 25];
  for (const o of opz) {
    const sel = scelta && scelta.c === o.c;
    const ex = opzExtra(o);
    const L = cl * 0.92 * k * (sel ? 1.15 : 1), W = cw * 0.9 * k * (sel ? 1.15 : 1);
    g.save();
    g.translate(px(o.x), py(o.y));
    g.rotate(((o.r || 0) * Math.PI) / 180);
    g.globalAlpha = 0.45;
    g.fillStyle = coloreOpz(o);
    g.fillRect(-L / 2, -W / 2, L, W);
    g.globalAlpha = sel || ex ? 1 : 0.7;
    g.lineWidth = (sel ? 3 : ex ? 2.5 : 1) * dpr;
    g.strokeStyle = sel ? '#fff' : ex ? '#40e6ff' : '#000';
    g.strokeRect(-L / 2, -W / 2, L, W);
    g.restore();
  }
  const fs = Math.max(9 * dpr, Math.min(13 * dpr, cl * k * 0.24));
  g.font = `700 ${Math.round(fs)}px Barlow, sans-serif`;
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.lineJoin = 'round';
  const leggibili = cl * k >= (icone ? 40 : 52) * dpr;   // caselle troppo piccole: le scritte solo su quella scelta
  for (const o of opz) {
    if (!leggibili && !(scelta && scelta.c === o.c)) continue;
    let righe = righeOpz(o);
    if (icone && !o.fu) {
      // icone delle zone con il numero, in fila; le altre scritte sopra
      const costi = ['gomme', 'freni', 'cambio', 'carrozzeria', 'motore', 'tenuta', 'ps'].filter((k) => (o.u?.[k] || 0) > 0);
      righe = righe.slice(0, righe.length - costi.length);
      const D = fs * 1.25, passo = D + fs * 0.75;
      let x = px(o.x) - ((costi.length - 1) * passo) / 2 - fs * 0.3;
      for (const k of costi) {
        if (ICONE[k].complete) g.drawImage(ICONE[k], x - D / 2, py(o.y) - D / 2, D, D);
        g.textAlign = 'left';
        g.lineWidth = 4 * dpr;
        g.strokeStyle = '#000';
        g.strokeText(String(o.u[k]), x + D / 2 + 1 * dpr, py(o.y));
        g.fillStyle = '#fff';
        g.fillText(String(o.u[k]), x + D / 2 + 1 * dpr, py(o.y));
        g.textAlign = 'center';
        x += passo;
      }
      righe.forEach(([t, c], i) => {
        const y = py(o.y) - (costi.length ? D * 0.5 + fs * 0.6 : 0) - (righe.length - 1 - i) * fs * 1.05;
        g.lineWidth = 4 * dpr;
        g.strokeStyle = '#000';
        g.strokeText(t, px(o.x), y);
        g.fillStyle = c;
        g.fillText(t, px(o.x), y);
      });
      continue;
    }
    righe.forEach(([t, c], i) => {
      const y = py(o.y) + (i - (righe.length - 1) / 2) * fs * 1.05;
      g.lineWidth = 4 * dpr;
      g.strokeStyle = '#000';
      g.strokeText(t, px(o.x), y);
      g.fillStyle = c;
      g.fillText(t, px(o.x), y);
    });
  }
  // le auto: la mia con il bordo bianco
  for (const a of stato.auto) {
    const c = stato.caselle?.[a.c];
    if (!c || a.f || a.pa > 0) continue;
    g.beginPath();
    g.rect(px(c[0]) - r * 0.8, py(c[1]) - r * 0.8, r * 1.6, r * 1.6);
    g.fillStyle = colore(a.p);
    g.fill();
    g.lineWidth = (a === mia ? 4 : 2) * dpr;
    g.strokeStyle = a === mia ? '#fff' : '#000';
    g.stroke();
  }
  cv.onpointerdown = (ev) => {
    if (!toccabili) return;
    const b = cv.getBoundingClientRect();
    const x = (ev.clientX - b.left) * (cv.width / b.width), y = (ev.clientY - b.top) * (cv.height / b.height);
    let best = null, bd = r * 2.2;
    for (const o of opz) {
      const d = Math.hypot(px(o.x) - x, py(o.y) - y);
      if (d < bd) { bd = d; best = o; }
    }
    if (!best) return;
    if (scelta && scelta.c === best.c) { manda({ t: 'mossa', c: best.c }); return; }
    scelta = best;
    disegna();
  };
}

let _rid = 0;
window.addEventListener('resize', () => { clearTimeout(_rid); _rid = setTimeout(disegna, 120); });

// per le prove automatiche
window.FDprova = { stato: () => stato, uid: () => uid, manda,
  // dove toccare sullo schermo per la marcia m
  marcia: (m) => { const b = document.getElementById('plancia').getBoundingClientRect(); const [x, y] = puntoMarcia(m);
    return { x: b.left + x / PLANCIA.larg * b.width, y: b.top + y / PLANCIA.alt * b.height }; },
  scegli: (c) => { scelta = stato.att.opz.find((o) => o.c === c) || null; disegna(); }, tocca: () => !!stato?.att && stato.att.uid === uid && inviata !== stato.n };

ingresso();
if (codice.length === 4 && nome && q.has('subito')) entra();
