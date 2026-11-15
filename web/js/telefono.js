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
let stato = null;
let scelta = null;       // opzione di mossa toccata
let inviata = -1;        // numero dello stato a cui ho già risposto
let toccavaAMe = false;
let errore = '';
const immagini = {};

function colore(p) {
  const [, sc, variante] = PILOTI[p];
  const c = SCUDERIE[sc].map((x) => Math.round(variante ? x * 0.72 : x));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}
function esc(s) { return String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function usura(regole, u) {
  return ZONE[regole].filter(([id]) => (u?.[id] || 0) > 0).map(([id, n]) => `${u[id]} ${n}`).join(', ');
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
      const j = unisci(v);
      if (!j) return;
      try { stato = JSON.parse(j); } catch (e) { return; }
      disegna();
    });
    try { if ('wakeLock' in navigator) await navigator.wakeLock.request('screen'); } catch (e) { /* ok */ }
    if (!stato) app.innerHTML = `<h1>FORMULA D</h1><div class="box"><p class="grande">Stanza ${esc(codice)}</p><p class="sotto">Sei dentro, ${esc(nome)}. Aspetta il via sullo schermo grande.</p></div>`;
  } catch (e) {
    console.error(e);
    errore = 'Non riesco a collegarmi: ' + (e?.message || e);
    ingresso();
  }
}

function manda(az) {
  inviata = stato?.n ?? 0;
  scelta = null;
  rete.push(`${RADICE}/${codice}/acts`, { s: uid, k: 'az', v: JSON.stringify({ ...az, n: stato?.n ?? 0 }) });
  disegna();
}

// ------------------------------------------------------------------ schermate
function disegna() {
  if (!stato) return;
  if (stato.fase === 'attesa') { attesa(); return; }
  const io = stato.auto.findIndex((a) => a.u === uid);
  const att = stato.att;
  const tocca = !!att && att.uid === uid && inviata !== stato.n && stato.fase === 'gara';
  if (tocca && !toccavaAMe) {
    suona('tocca');
    try { navigator.vibrate?.(250); } catch (e) { /* ok */ }
  }
  toccavaAMe = tocca;
  let h = '';
  if (io >= 0) h += testata(stato.auto[io], tocca);
  else h += `<div class="box"><h2>Spettatore</h2><p class="sotto">La gara è già partita senza un posto per te: puoi seguirla da qui.</p></div>`;
  if (stato.fase === 'fine') {
    const a = io >= 0 ? stato.auto[io] : null;
    h += `<div class="box mio"><p class="grande">BANDIERA A SCACCHI</p>${a ? `<p class="grande" style="color:#ffd21a">${a.pa > 0 ? a.pa + '° posto' : 'Ritirato'}</p>` : ''}</div>`;
  } else if (tocca && att.tipo === 'marcia') {
    h += `<div class="box tocca lampo"><h2>Scegli la marcia</h2><div class="marce">` + att.marce.map((o) =>
      `<button class="marcia" data-m="${o.m}" style="background:${COL_MARCE[o.m]};color:${o.m === 1 ? '#111' : '#fff'}">${MARCE[o.m]}<small>${INTERVALLI[o.m]}</small>` +
      `${usura(stato.regole, o.costo) ? `<small>-${esc(usura(stato.regole, o.costo))}</small>` : ''}${o.fuori ? '<small>RITIRO!</small>' : ''}</button>`).join('') +
      `</div><p class="sotto" style="margin-top:8px">Si sale di una marcia alla volta. Scalare più di una marcia rovina l'auto.</p></div>`;
  } else if (tocca && att.tipo === 'mossa') {
    h += `<div class="box tocca"><h2>Tiro <span class="dado" style="background:${COL_MARCE[stato.auto[io].m]};color:${stato.auto[io].m === 1 ? '#111' : '#fff'}">${att.tiro}</span> in ${MARCE[stato.auto[io].m]}: dove vai?</h2>
      <div class="mappa"><canvas id="mappa"></canvas></div>
      <div class="legenda"><span><i style="background:${COL.libera}"></i>libera</span><span><i style="background:${COL.costo}"></i>costa punti</span>
      <span><i style="background:${COL.testa}"></i>testacoda</span><span><i style="background:${COL.fuori}"></i>ritiro</span>
      <span><i style="background:${COL.box}"></i>box</span><span><i style="background:${COL.arrivo}"></i>traguardo</span></div>
      <div id="det" class="dettaglio">Tocca una casella colorata.</div>
      <button id="ok" class="verde" disabled>CONFERMA</button></div>`;
  } else if (att) {
    const a = stato.auto[att.auto];
    h += `<div class="box"><p class="grande" style="color:${colore(a.p)}">${att.uid === uid ? 'Mossa inviata...' : 'Tocca a ' + esc(a.n)}</p></div>`;
  }
  h += classifica(io);
  h += `<div class="box log">${(stato.log || []).slice(-5).map((t) => `<div>${esc(t)}</div>`).join('')}</div>`;
  app.innerHTML = h;
  app.querySelectorAll('.marcia').forEach((b) => { b.onclick = () => manda({ t: 'marcia', m: Number(b.dataset.m) }); });
  if (tocca && att.tipo === 'mossa') mappa(att);
}

function attesa() {
  const mio = (stato.posti || []).find((p) => p.u === uid);
  let h = `<h1>FORMULA D</h1><div class="box mio"><p class="grande">Stanza ${esc(codice)}</p>`;
  if (mio) {
    h += `<div class="testa"><img src="img/${PILOTI[mio.p][0]}.webp" alt="" style="border-color:${colore(mio.p)}"><div class="chi"><div class="nome">${esc(nome)}</div>
      <div class="dati">Guidi l'auto di ${esc(NOMI_PILOTI[mio.p])}, scuderia ${PILOTI[mio.p][1]}. Aspetta il via!</div></div></div>`;
  } else {
    h += `<p class="sotto">Sei dentro, ma non c'è ancora un posto libero per te: chiedi a chi organizza di aprirne uno («Telefono / online»).</p>`;
  }
  h += `</div><div class="box"><h2>In griglia</h2>`;
  for (const p of stato.posti || []) {
    if (p.tp === 'chiuso') continue;
    const chi = p.tp === 'ia' ? 'computer' : p.tp === 'umano' ? 'schermo grande' : (p.u ? esc(p.n) : 'posto libero');
    h += `<div class="riga ${p.u === uid ? 'io' : ''}"><span class="col" style="background:${colore(p.p)}"></span><span class="n">${esc(NOMI_PILOTI[p.p])}</span><span class="p">${chi}</span></div>`;
  }
  h += `</div>`;
  app.innerHTML = h;
}

function testata(a, tocca) {
  const zone = ZONE[stato.regole].map(([id, n, c]) =>
    `<div class="zona ${a.pf[id] <= 1 ? 'poco' : ''}" style="border-left-color:${c}"><span>${n}</span><b>${Math.max(0, a.pf[id])}</b></div>`).join('');
  let st = `${a.m > 0 ? MARCE[a.m] : 'in griglia'} - giro ${Math.max(1, Math.min(a.g, stato.giri))} di ${stato.giri}${a.d ? ' - ultimo tiro ' + a.d : ''}`;
  if (a.pa > 0) st = `ARRIVATO: ${a.pa}° posto`;
  else if (a.f) st = `RITIRATO: ${esc(a.w)}`;
  return `<div class="box mio ${tocca ? 'tocca' : ''}"><div class="testa"><img src="img/${PILOTI[a.p][0]}.webp" alt="" style="border-color:${colore(a.p)}">
    <div class="chi"><div class="nome" style="color:${colore(a.p)}">${esc(a.n)}</div><div class="dati">${st}</div></div></div><div class="zone">${zone}</div></div>`;
}

function classifica(io) {
  const att = stato.att;
  let h = `<div class="box"><h2>Ordine di gioco - turno ${stato.turno}</h2>`;
  for (const i of stato.ordine) {
    const a = stato.auto[i];
    const st = a.pa > 0 ? `${a.pa}° arrivato` : a.f ? 'ritirato' : ZONE[stato.regole].map(([id]) => Math.max(0, a.pf[id])).join(' ');
    h += `<div class="riga ${att && att.auto === i ? 'turno' : ''} ${i === io ? 'io' : ''}"><span class="col" style="background:${colore(a.p)}"></span>
      <span class="n">${esc(a.n)}</span><span class="m" style="background:${COL_MARCE[a.m]};color:${a.m === 1 ? '#111' : '#fff'}">${a.m > 0 ? MARCE[a.m] : '-'}</span><span class="p">${st}</span></div>`;
  }
  return h + '</div>';
}

// ------------------------------------------------------------------ mappa delle caselle
function immagine(pista) {
  if (!immagini[pista]) {
    const im = new Image();
    im.onload = () => { if (stato?.att?.tipo === 'mossa') disegna(); };
    im.src = `img/piste/${pista}.webp`;
    immagini[pista] = im;
  }
  return immagini[pista];
}

function mappa(att) {
  const cv = document.getElementById('mappa');
  const det = document.getElementById('det');
  const ok = document.getElementById('ok');
  const im = immagine(stato.pista);
  const io = stato.auto[att.auto];
  // riquadro del tabellone che contiene tutte le caselle possibili
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const o of att.opz) { x0 = Math.min(x0, o.x); y0 = Math.min(y0, o.y); x1 = Math.max(x1, o.x); y1 = Math.max(y1, o.y); }
  const m = 70;
  x0 -= m; y0 -= m; x1 += m; y1 += m;
  const larg = cv.clientWidth || 320;
  const altMax = Math.max(260, Math.min(window.innerHeight * 0.52, 560));
  let w = Math.max(x1 - x0, 360), hh = Math.max(y1 - y0, 300);
  // stesse proporzioni del riquadro sullo schermo
  const prop = Math.min(Math.max(hh / w, 0.55), altMax / larg);
  if (hh / w > prop) w = hh / prop; else hh = w * prop;
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  x0 = cx - w / 2; y0 = cy - hh / 2;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  cv.width = Math.round(larg * dpr);
  cv.height = Math.round(larg * prop * dpr);
  cv.style.height = Math.round(larg * prop) + 'px';
  const k = cv.width / w;            // pixel dello schermo per pixel del tabellone
  const g = cv.getContext('2d');
  const px = (x) => (x - x0) * k, py = (y) => (y - y0) * k;
  const r = Math.max(9 * dpr, 17 * k);

  function dipingi() {
    g.fillStyle = '#20242c';
    g.fillRect(0, 0, cv.width, cv.height);
    if (im.complete && im.naturalWidth) {
      const s = im.naturalWidth / (stato.iw || 2474);
      g.drawImage(im, x0 * s, y0 * s, w * s, hh * s, 0, 0, cv.width, cv.height);
    }
    for (const o of att.opz) {
      g.beginPath();
      g.arc(px(o.x), py(o.y), scelta && scelta.c === o.c ? r * 1.45 : r, 0, 6.2832);
      g.fillStyle = coloreOpz(o);
      g.globalAlpha = 0.88;
      g.fill();
      g.globalAlpha = 1;
      g.lineWidth = scelta && scelta.c === o.c ? 4 * dpr : 1.5 * dpr;
      g.strokeStyle = scelta && scelta.c === o.c ? '#fff' : '#000';
      g.stroke();
      const tot = Object.values(o.u || {}).reduce((a, b) => a + b, 0);
      if (tot > 0 && !o.fu && !o.fi) {
        g.fillStyle = '#201000';
        g.font = `700 ${Math.round(r * 1.1)}px Barlow, sans-serif`;
        g.textAlign = 'center';
        g.textBaseline = 'middle';
        g.fillText('-' + tot, px(o.x), py(o.y) + 1);
      }
    }
    // le altre auto e la mia
    for (const a of stato.auto) {
      const c = stato.caselle?.[a.c];
      if (!c) continue;
      g.beginPath();
      g.rect(px(c[0]) - r * 0.8, py(c[1]) - r * 0.8, r * 1.6, r * 1.6);
      g.fillStyle = colore(a.p);
      g.fill();
      g.lineWidth = (a === io ? 4 : 2) * dpr;
      g.strokeStyle = a === io ? '#fff' : '#000';
      g.stroke();
    }
  }
  if (scelta) scelta = att.opz.find((o) => o.c === scelta.c) || null;
  function mostraScelta() {
    if (!scelta) return;
    det.textContent = testoOpz(stato.regole, scelta);
    det.className = 'dettaglio' + (scelta.fu || scelta.te ? ' male' : '');
    ok.disabled = false;
    ok.className = scelta.fu || scelta.te ? '' : 'verde';
  }
  mostraScelta();
  dipingi();
  cv.onpointerdown = (ev) => {
    const b = cv.getBoundingClientRect();
    const x = (ev.clientX - b.left) * (cv.width / b.width), y = (ev.clientY - b.top) * (cv.height / b.height);
    let best = null, bd = r * 2.2;
    for (const o of att.opz) {
      const d = Math.hypot(px(o.x) - x, py(o.y) - y);
      if (d < bd) { bd = d; best = o; }
    }
    if (!best) return;
    scelta = best;
    mostraScelta();
    dipingi();
  };
  ok.onclick = () => { if (scelta) manda({ t: 'mossa', c: scelta.c }); };
}

// per le prove automatiche
window.FDprova = { stato: () => stato, uid: () => uid, manda, tocca: () => !!stato?.att && stato.att.uid === uid && inviata !== stato.n };

ingresso();
if (codice.length === 4 && nome && q.has('subito')) entra();
