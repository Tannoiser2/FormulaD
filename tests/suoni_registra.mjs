// Registra gli effetti sonori in /tmp/suoni_formulad.wav e stampa il volume di ognuno (node tests/suoni_registra.mjs build/web).
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW || 'playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const dir = process.argv[2];
const tipi = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.css': 'text/css' };
http.createServer((req, res) => {
  const f = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': tipi[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' }); res.end(d); });
}).listen(8768);
const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined, args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await (await browser.newContext()).newPage();
p.on('pageerror', (e) => console.log('ERR', String(e)));
await p.goto('http://localhost:8768/index.html?rete=locale');
await p.waitForFunction(() => window.FR, null, { timeout: 60000 });
const seq = [[0, 'dado', {}], [0.8, 'motore', { m: 1, d: 0.6 }], [2, 'motore', { m: 3, d: 0.9 }], [3.5, 'motore', { m: 5, d: 1.1, fr: 3 }],
  [5.4, 'motore', { m: 6, d: 1.2, ol: 2 }], [7.3, 'scontro', { forte: true }], [8.3, 'nero', {}], [8.8, 'box', {}], [10.8, 'motore', { m: 4, d: 1, ni: true }],
  [12.3, 'gomme', {}], [14, 'esplosione', {}], [16, 'arrivo', {}]];
const dati = await p.evaluate(async (s) => window.FR.registraSuoni(s, 18.5), seq);
for (const [t, n] of seq) { let q = 0, c = 0; for (let i = Math.floor(t * 44100); i < Math.min(dati.length, Math.floor((t + 0.7) * 44100)); i++) { q += dati[i] ** 2; c++; } console.log(n.padEnd(11), (Math.sqrt(q / c)).toFixed(3)); }
const n = dati.length, b = Buffer.alloc(44 + n * 2);
b.write('RIFF', 0); b.writeUInt32LE(36 + n * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22);
b.writeUInt32LE(44100, 24); b.writeUInt32LE(88200, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(n * 2, 40);
let picco = 0; for (const v of dati) picco = Math.max(picco, Math.abs(v));
for (let i = 0; i < n; i++) b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, dati[i])) * 32000), 44 + i * 2);
fs.writeFileSync('/tmp/suoni_formulad.wav', b);
console.log('picco', picco.toFixed(2));
await browser.close();
process.exit(0);
