// Gli effetti sonori suonano davvero in una gara: clic come un giocatore, poi controlla che l'audio sia attivo
// e quanti suoni sono partiti (node tests/suoni_vivi.mjs build/web).
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW || 'playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const dir = process.argv[2];
const tipi = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.css': 'text/css' };
http.createServer((req, res) => {
  const f = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': tipi[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' }); res.end(d); });
}).listen(8769);
const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined, args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
p.on('pageerror', (e) => console.log('ERR', String(e)));
await p.goto('http://localhost:8769/index.html?rete=locale&auto=4&veloce=2');
await p.waitForFunction(() => window.FR, null, { timeout: 60000 });
console.log('prima del clic:', await p.evaluate(() => window.FR.statoAudio()));
await p.waitForTimeout(3000);
await p.mouse.click(400, 400);
await p.waitForTimeout(12000);
console.log('dopo il clic e 12 s di gara:', await p.evaluate(() => window.FR.statoAudio()));
await browser.close();
process.exit(0);
