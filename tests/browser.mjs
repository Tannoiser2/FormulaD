// Prova completa nel browser: schermo grande (Godot web) + telefoni + un ospite con il gioco completo,
// collegati con la rete "locale" (BroadcastChannel).
// node tests/browser.mjs [cartella build] [cartella foto] [telefoni] [secondi]
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW || 'playwright');
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || '/tmp/prova_web');
const NT = Number(process.argv[4] || 2);
const DURATA = Number(process.argv[5] || 240) * 1000;
// ONLINE=1: gara online (un computer ospite; un telefono che prova a entrare deve essere respinto)
const ONLINE = process.env.ONLINE === '1';
const OSPITE = ONLINE;
fs.mkdirSync(out, { recursive: true });
const tipi = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.css': 'text/css', '.ttf': 'font/ttf', '.webp': 'image/webp', '.png': 'image/png' };
http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(dir, p);
  if (!fs.existsSync(f)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': tipi[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(8765);

const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const ctx = await browser.newContext();
const errori = [];
function ascolta(p, chi) {
  p.on('console', (m) => { if (m.type() === 'error') errori.push(chi + ': ' + m.text()); });
  p.on('pageerror', (e) => errori.push(chi + ' pageerror: ' + e.message));
}
const tv = await ctx.newPage();
await tv.setViewportSize({ width: Number(process.env.LARG || 1280), height: Number(process.env.ALT || 720) });
tv.setDefaultTimeout(180000);
ascolta(tv, 'TV');
async function foto(p, f) { try { await p.screenshot({ path: `${out}/${f}.png`, timeout: 120000 }); } catch (e) { console.log('foto non riuscita', f); } }
const quanti = ONLINE ? 1 : NT;
await tv.goto(`http://localhost:8765/index.html?rete=locale&subito&veloce=3&stanza=${quanti}${ONLINE ? '&online' : ''}&regole=${process.env.REGOLE || 'avanzate'}${process.env.OPZ || ''}`);
let codice = '';
for (let i = 0; i < 240 && !codice; i++) {
  await tv.waitForTimeout(1000);
  codice = await tv.evaluate(() => window.FR?.codice?.() || '');
}
console.log('codice stanza', codice);
await tv.waitForTimeout(2500);
await foto(tv, 'tv_1_stanza');
const nomi = ['Stefano', 'Chiara', 'Marco', 'Lina'];
const tel = [];
for (let i = 0; i < NT; i++) {
  const p = await ctx.newPage();
  await p.setViewportSize(i % 2 ? { width: 844, height: 390 } : { width: 390, height: 844 });
  ascolta(p, 'tel' + i);
  await p.goto(`http://localhost:8765/telefono.html?s=${codice}&rete=locale`);
  if (i === 0) await foto(p, 'tel_0_ingresso');
  await p.fill('#nom', nomi[i]);
  await p.click('#entra');
  await tv.waitForTimeout(1200);
  if (ONLINE) {
    await tv.waitForTimeout(8000);
    const t = await p.evaluate(() => document.body.innerText + ' | sk=' + (window.FDprova?.stato()?.sk ?? 'nessuno'));
    console.log('telefono:', JSON.stringify(t.slice(-300)));
    console.log(t.includes('si gioca dal computer') ? 'telefono respinto dalla gara online: ok' : 'ERRORE: il telefono non è stato respinto');
    await foto(p, 'tel_respinto');
    continue;
  }
  tel.push(p);
}
if (tel[0]) await foto(tel[0], 'tel_1_attesa');
await foto(tv, 'tv_2_stanza_piena');
let osp = null;
if (OSPITE) {
  osp = await ctx.newPage();
  await osp.setViewportSize({ width: 1024, height: 768 });
  ascolta(osp, 'ospite');
  await osp.goto(`http://localhost:8765/index.html?rete=locale&subito&s=${codice}&nome=Ospite&autoguida=1`);
}
const t0 = Date.now();
let fotoAssetto = false;
let fotoQual = false;
let fotoBarra = false;
let fatte = 0, fotoMarcia = false, fotoMossa = false, fotoOspite = 0, fine = false, fotoAnte = 0;
while (Date.now() - t0 < DURATA && !fine) {
  await tv.waitForTimeout(700);
  for (let i = 0; i < tel.length; i++) {
    const p = tel[i];
    const s = await p.evaluate(() => { const s = window.FDprova.stato(); return s ? { fase: s.fase, n: s.n, att: s.att, uid: window.FDprova.uid(), tocca: window.FDprova.tocca() } : null; });
    if (!s) continue;
    if (s.fase === 'fine') { fine = true; break; }
    if (!s.att || !s.tocca) continue;
    if (s.att.tipo === 'qualifica') {
      if (!fotoQual) { await foto(p, 'tel_0_qualifica'); fotoQual = true; }
      await p.locator('[data-qm]').nth(1).click();
      fatte++;
    } else if (s.att.tipo === 'qritira') {
      await p.click('[data-qr="0"]');
      fatte++;
    } else if (s.att.tipo === 'assetto') {
      // tocchi veri: un punto spostato (se l'assetto è libero), le gomme, poi conferma
      if (s.att.libero) { await p.click('[data-z="tenuta"][data-d="-1"]'); await p.click('[data-z="gomme"][data-d="1"]'); }
      const g = p.locator('[data-g]');
      if (await g.count()) await g.last().click();
      if (!fotoAssetto) { await foto(p, `tel_1_assetto${s.att.box ? '_box' : ''}`); fotoAssetto = true; }
      await p.click('#oka');
      fatte++;
    } else if (s.att.tipo === 'marcia') {
      if (!fotoMarcia && fatte > 2) { await foto(p, 'tel_2_marcia'); await foto(tv, 'tv_3_attesa_telefono'); fotoMarcia = true; }
      // la marcia più alta che non costa nulla, ma non oltre la 4a
      const ok = s.att.marce.filter((o) => !o.fuori && Object.keys(o.costo).length === 0 && o.m <= 4);
      const m = (ok.length ? ok[ok.length - 1] : s.att.marce[0]).m;
      // due tocchi sulla plancia: il primo mostra dove si può arrivare, il secondo conferma
      const pt = await p.evaluate((m) => window.FDprova.marcia(m), m);
      await p.mouse.click(pt.x, pt.y);
      await p.waitForTimeout(250);
      if (fatte > 2 && fotoAnte < 4) { await foto(p, `tel_2_anteprima_${i}_${fotoAnte}`); if (!fotoAnte) await foto(tv, 'tv_3b_anteprima_telefono'); fotoAnte++; }
      await p.mouse.click(pt.x, pt.y);
      fatte++;
      if (fatte > 6 && !fotoBarra) {
        fotoBarra = true;
        await tv.waitForTimeout(1100);
        await foto(tv, 'tv_5_barra_dadi');
        // la scheda con ordine e cronaca sul telefono
        if (await p.locator('.pista .bsch').count()) {
          await p.click('.pista .bsch');
          await p.waitForTimeout(300);
          await foto(p, 'tel_6_scheda_ordine');
          await p.click('#scheda [data-t="cronaca"]');
          await p.waitForTimeout(300);
          await foto(p, 'tel_6_scheda_cronaca');
          const righe = await p.locator('#scheda .log div').count();
          console.log('righe di cronaca nella scheda:', righe);
          await p.click('#scheda [data-t=""]');
          console.log('scheda chiusa:', (await p.locator('#scheda').count()) === 0);
        }
      }
    } else {
      // la casella più lontana tra quelle che non costano nulla; se non ce n'è, la meno cara
      const costo = (o) => (o.fu ? 1000 : 0) + (o.te ? 50 : 0) + Object.values(o.u || {}).reduce((a, b) => a + b, 0) * 10 - o.mo;
      const best = [...s.att.opz].sort((a, b) => costo(a) - costo(b))[0];
      if (!fotoMossa && fatte > 5 && await p.locator('#mappa').count()) {
        await p.evaluate((c) => window.FDprova.scegli(c), best.c);
        await p.waitForTimeout(300);
        await foto(p, 'tel_3_mossa');
        for (const q of tel) if (q !== p) await foto(q, 'tel_3_attesa');
        await foto(tv, 'tv_4_mossa_telefono');
        fotoMossa = true;
        // ingrandisce con la rotella e sposta trascinando con il mouse (come un dito)
        const bx = await p.locator('#mappa').boundingBox();
        const cx = bx.x + bx.width / 2, cy = bx.y + bx.height / 2;
        await p.mouse.move(cx, cy);
        for (let k = 0; k < 4; k++) { await p.mouse.wheel(0, -250); await p.waitForTimeout(80); }
        await p.waitForTimeout(200);
        await foto(p, 'tel_4_zoom');
        await p.mouse.move(cx, cy); await p.mouse.down();
        for (let k = 1; k <= 10; k++) { await p.mouse.move(cx + k * 12, cy + k * 6); await p.waitForTimeout(20); }
        await p.mouse.up();
        await p.waitForTimeout(250);
        await foto(p, 'tel_5_spostata');
        // la scelta resta e un tocco senza trascinare sceglie ancora la casella
        const ancora = await p.evaluate(() => window.FDprova.stato().att?.tipo);
        console.log('dopo zoom e trascinamento la scelta è ancora aperta:', ancora);
        await p.click('#centra');
        await p.waitForTimeout(200);
      }
      await p.evaluate((c) => window.FDprova.manda({ t: 'mossa', c }), best.c);
      fatte++;
    }
    await p.waitForTimeout(300);
  }
  if (osp && fotoOspite < 2 && Date.now() - t0 > (fotoOspite ? 200000 : 70000)) { await foto(osp, 'ospite_' + fotoOspite); fotoOspite++; }
}
await tv.waitForTimeout(4000);
await foto(tv, 'tv_9_fine');
await foto(tel[0], 'tel_9_fine');
if (osp) await foto(osp, 'ospite_9');
console.log(`decisioni dai telefoni: ${fatte}, gara finita: ${fine}, secondi: ${Math.round((Date.now() - t0) / 1000)}`);
console.log(errori.length ? 'ERRORI:\n' + [...new Set(errori)].slice(0, 30).join('\n') : 'nessun errore nel browser');
await browser.close();
process.exit(fine && !errori.length ? 0 : 1);
