// Effetti sonori sintetizzati (niente file audio): rombo del motore che sale con la marcia, frenate e gomme
// che stridono, collisioni, esplosioni, box, nitro, arrivo. Si spengono con «Suoni: no» (fd_suoni = 'no').
let ctx = null;
let uscita = null;
let attivi = true;
try { attivi = localStorage.getItem('fd_suoni') !== 'no'; } catch (e) { /* ok */ }

export function sbloccaAudio() {
  try {
    if (!ctx) {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      // un compressore leggero: tanti suoni insieme non saturano
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -18; comp.ratio.value = 4;
      uscita = ctx.createGain();
      uscita.gain.value = attivi ? 0.9 : 0;
      uscita.connect(comp).connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
  } catch (e) { /* ok */ }
}

// Il browser fa partire l'audio solo dopo un gesto: ogni tocco o tasto lo sblocca (o lo riprende se il
// sistema l'ha sospeso, come fa iPad quando si cambia app). Sta qui, nello stesso modulo che suona.
for (const ev of ['pointerdown', 'touchend', 'click', 'keydown']) {
  document.addEventListener(ev, sbloccaAudio, { capture: true, passive: true });
}
let suonati = 0;
export function statoAudio() { return `${ctx ? ctx.state : 'spento'}, suoni fatti ${suonati}`; }

export function attivaSuoni(si) {
  attivi = !!si;
  try { localStorage.setItem('fd_suoni', attivi ? 'si' : 'no'); } catch (e) { /* ok */ }
  if (uscita) uscita.gain.setTargetAtTime(attivi ? 0.9 : 0, ctx.currentTime, 0.05);
}
export function suoniAttivi() { return attivi; }

// ---------------------------------------------------------------- mattoni

function inviluppo(g, t, attacco, tenuta, rilascio, vol) {
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + attacco);
  g.gain.setValueAtTime(vol, t + attacco + tenuta);
  g.gain.exponentialRampToValueAtTime(0.0001, t + attacco + tenuta + rilascio);
}

function nota(freq, dur, tipo = 'sine', vol = 0.15, quando = 0, fine = null) {
  const t = ctx.currentTime + quando;
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = tipo;
  o.frequency.setValueAtTime(freq, t);
  if (fine) o.frequency.exponentialRampToValueAtTime(fine, t + dur);
  inviluppo(g, t, 0.005, 0, dur, vol);
  o.connect(g).connect(uscita);
  o.start(t);
  o.stop(t + dur + 0.05);
}

let bufRumore = null;
function sorgenteRumore(t, dur) {
  if (!bufRumore) {
    const n = ctx.sampleRate * 2;
    bufRumore = ctx.createBuffer(1, n, ctx.sampleRate);
    const d = bufRumore.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
  }
  const s = ctx.createBufferSource();
  s.buffer = bufRumore;
  s.loop = true;
  s.start(t, Math.random() * 1.5);
  s.stop(t + dur + 0.1);
  return s;
}

// rumore filtrato: tipo del filtro, frequenza (o [da, a] per farla scorrere), Q, inviluppo
function rumore(dur, vol, quando = 0, filtro = 'lowpass', freq = 1200, q = 0.7, attacco = 0.005) {
  const t = ctx.currentTime + quando;
  const s = sorgenteRumore(t, dur);
  const f = ctx.createBiquadFilter();
  f.type = filtro;
  f.Q.value = q;
  if (Array.isArray(freq)) {
    f.frequency.setValueAtTime(freq[0], t);
    f.frequency.exponentialRampToValueAtTime(freq[1], t + dur);
  } else f.frequency.value = freq;
  const g = ctx.createGain();
  inviluppo(g, t, attacco, 0, dur, vol);
  s.connect(f).connect(g).connect(uscita);
  return f;
}

let curvaDist = null;
function distorsione() {
  if (!curvaDist) {
    curvaDist = new Float32Array(1024);
    for (let i = 0; i < 1024; i++) { const x = i / 512 - 1; curvaDist[i] = Math.tanh(x * 3); }
  }
  const w = ctx.createWaveShaper();
  w.curve = curvaDist;
  return w;
}

// ---------------------------------------------------------------- effetti

// Il rombo: tre denti di sega un po' stonati, distorti e filtrati, con il «battito» dei cilindri.
// Sale di giri durante la mossa; con la frenata scala alla fine.
function motore(m, dur, o) {
  const t = ctx.currentTime;
  const marcia = Math.max(1, Math.min(6, m || 1));
  const basso = 34 + marcia * 9;
  const alto = basso * (1.55 + marcia * 0.07) * (o.ni ? 1.25 : 1);
  const finale = o.fr > 0 ? basso * 0.75 : alto * 0.92;
  const tot = Math.max(0.35, dur);
  const filt = ctx.createBiquadFilter();
  filt.type = 'lowpass';
  filt.Q.value = 2;
  filt.frequency.setValueAtTime(500, t);
  filt.frequency.linearRampToValueAtTime(900 + marcia * 250, t + tot * 0.7);
  filt.frequency.linearRampToValueAtTime(o.fr > 0 ? 500 : 1100, t + tot);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(0.11, t + 0.08);
  g.gain.setValueAtTime(0.11, t + tot);
  g.gain.exponentialRampToValueAtTime(0.0001, t + tot + 0.45);
  // battito dei cilindri: l'ampiezza oscilla a 1/4 della frequenza
  const trem = ctx.createGain();
  trem.gain.value = 0.6;
  const lfo = ctx.createOscillator();
  lfo.type = 'square';
  const prof = ctx.createGain();
  prof.gain.value = 0.35;
  lfo.connect(prof).connect(trem.gain);
  const dist = distorsione();
  trem.connect(dist).connect(filt).connect(g).connect(uscita);
  const oscs = [lfo];
  for (const [k, det, tipo] of [[1, -6, 'sawtooth'], [1, 7, 'sawtooth'], [0.5, 0, 'square']]) {
    const osc = ctx.createOscillator();
    osc.type = tipo;
    osc.detune.value = det;
    osc.connect(trem);
    oscs.push(osc);
    const f = osc.frequency;
    f.setValueAtTime(basso * k * 0.9, t);
    f.exponentialRampToValueAtTime(alto * k, t + tot * 0.75);
    f.exponentialRampToValueAtTime(finale * k, t + tot + 0.3);
  }
  lfo.frequency.setValueAtTime(basso / 4, t);
  lfo.frequency.exponentialRampToValueAtTime(alto / 4, t + tot * 0.75);
  for (const osc of oscs) { osc.start(t); osc.stop(t + tot + 0.5); }
  if (o.ni) rumore(0.7, 0.18, 0, 'bandpass', [400, 3500], 1.5, 0.15);       // nitro: soffio che sale
  if (o.fr > 0) stridio(Math.min(0.9, 0.25 + o.fr * 0.1), tot * 0.65, 0.12 + Math.min(0.12, o.fr * 0.02));
  if (o.ol > 0) { stridio(0.8, tot * 0.55, 0.16); rumore(0.6, 0.12, tot * 0.7, 'lowpass', 900, 0.5, 0.05); } // lungo: gomme e ghiaia
}

// gomme che stridono: rumore stretto attorno ai 2-3 kHz che ondeggia, più un fischio
function stridio(dur, quando = 0, vol = 0.15) {
  const f = rumore(dur, vol * 4, quando, 'bandpass', 2600, 6, 0.03);
  const t = ctx.currentTime + quando;
  for (let k = 0; k < 6; k++) f.frequency.setValueAtTime(2200 + Math.random() * 900, t + (k * dur) / 6);
  nota(1900 + Math.random() * 300, dur, 'triangle', vol * 0.5, quando, 1500);
}

// scontro: tonfo, lamiera (parziali non armoniche) e frammenti
function scontro(forte) {
  const v = forte ? 0.8 : 0.5;
  rumore(0.35, v, 0, 'lowpass', 1800, 0.8);
  nota(70, 0.35, 'sine', v * 0.8, 0, 35);
  for (const f of [347, 612, 983, 1411, 2093]) nota(f * (0.95 + Math.random() * 0.1), 0.25 + Math.random() * 0.2, 'square', v * 0.05);
  for (let k = 0; k < 4; k++) rumore(0.05, v * 0.4, 0.12 + Math.random() * 0.3, 'highpass', 3000, 1);
}

function esplosione() {
  rumore(1.6, 0.7, 0, 'lowpass', [900, 80], 0.7, 0.01);
  nota(55, 1.2, 'sine', 0.5, 0, 28);
  for (let k = 0; k < 6; k++) rumore(0.06, 0.15, 0.2 + Math.random() * 0.9, 'highpass', 2500, 1);
}

// avvitatore dei meccanici: raffiche di rumore a 60 colpi al secondo
function box() {
  for (const q of [0, 0.45, 0.9, 1.35]) {
    const f = rumore(0.32, 0.9, q, 'bandpass', 1400, 2, 0.01);
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 60;
    const p = ctx.createGain();
    p.gain.value = 700;
    lfo.connect(p).connect(f.frequency);
    lfo.start(ctx.currentTime + q);
    lfo.stop(ctx.currentTime + q + 0.35);
  }
}

// motore sotto sforzo che perde un colpo: due scoppi
function ritorno() {
  for (const q of [0, 0.16]) { rumore(0.09, 0.4, q, 'lowpass', 700, 1); nota(90, 0.1, 'square', 0.15, q, 40); }
}

function folla() {
  rumore(2.2, 0.16, 0, 'bandpass', 1100, 0.6, 0.6);
  rumore(2.2, 0.08, 0.1, 'bandpass', 2400, 0.8, 0.8);
  [523, 659, 784, 1047].forEach((f, i) => nota(f, 0.28, 'triangle', 0.13, i * 0.13));
}

export function suona(n, o = {}) {
  if (!ctx || !attivi) return;
  suonati++;
  try {
    switch (n) {
      case 'dado': for (let i = 0; i < 5; i++) rumore(0.04, 0.7, i * 0.08 + Math.random() * 0.02, 'bandpass', 2500 + Math.random() * 1500, 2); break;
      case 'nero': rumore(0.04, 0.6, 0, 'bandpass', 3000, 2); rumore(0.04, 0.45, 0.07, 'bandpass', 2600, 2); break;
      case 'motore': motore(o.m, o.d || 0.8, o); break;
      case 'partenza': motore(1, 0.9, { ni: 1 }); stridio(0.5, 0, 0.12); break;
      case 'stridio': stridio(o.d || 0.6, 0, 0.15); break;
      case 'scontro': scontro(!!o.forte); break;
      case 'botto': scontro(true); break;
      case 'esplosione': esplosione(); break;
      case 'gomme': stridio(1.2, 0, 0.18); rumore(0.8, 0.1, 0.4, 'lowpass', 800, 0.5, 0.1); break;
      case 'box': box(); break;
      case 'ritorno': ritorno(); break;
      case 'ghiaia': rumore(0.5, 0.12, 0, 'lowpass', 900, 0.5, 0.05); break;
      case 'arrivo': folla(); break;
      case 'tocca': nota(660, 0.15, 'triangle', 0.18); nota(880, 0.25, 'triangle', 0.18, 0.16); break;
      default: nota(440, 0.1);
    }
  } catch (e) { console.warn('suono', e); }
}

// Per le prove: registra una sequenza di suoni senza altoparlanti e ritorna i campioni (mono, 44100 Hz).
export async function registra(sequenza, durata) {
  const vecchio = [ctx, uscita, attivi];
  const off = new OfflineAudioContext(1, Math.ceil(44100 * durata), 44100);
  ctx = off;
  uscita = off.createGain();
  uscita.gain.value = 0.9;
  const comp = off.createDynamicsCompressor();
  comp.threshold.value = -18; comp.ratio.value = 4;
  uscita.connect(comp).connect(off.destination);
  attivi = true;
  bufRumore = null;
  // ogni suono parte al suo tempo: si sposta l'origine dei tempi con un contesto «finto»
  for (const [quando, n, o] of sequenza) {
    const vero = ctx;
    ctx = new Proxy(vero, { get: (t, k) => (k === 'currentTime' ? quando : (typeof t[k] === 'function' ? t[k].bind(t) : t[k])) });
    suona(n, o);
    ctx = vero;
  }
  const buf = await off.startRendering();
  [ctx, uscita, attivi] = vecchio;
  bufRumore = null;
  return Array.from(buf.getChannelData(0));
}
