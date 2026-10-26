import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const root = process.cwd();
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(8160, '0.0.0.0', r));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 300000,
});
const page = await browser.newPage();
const lines = [];
page.on('console', (m) => lines.push(m.text()));
page.on('pageerror', (e) => lines.push('PAGEERROR ' + String(e).split('\n')[0]));
const [w, h] = (process.argv[2] || '844x390').split('x').map(Number);
await page.setViewport({ width: w, height: h, hasTouch: true, isMobile: true, deviceScaleFactor: 2 });
await page.goto(`http://127.0.0.1:8160/web/index.html?qa_stage=GAMEPLAY&weapon=pulse_rifle&qa_world=neon_frontier`, { waitUntil: 'domcontentloaded', timeout: 90000 });
const has = (t) => lines.some((l) => l.includes(t));
const waitFor = async (t, ms = 180000) => {
  const start = Date.now();
  while (!has(t)) {
    if (Date.now() - start > ms) throw new Error('timeout: ' + t + '\n' + lines.slice(-5).join('\n'));
    await new Promise((r) => setTimeout(r, 400));
  }
};
const tap = async (x, y) => { await page.touchscreen.tap(x, y); await new Promise((r) => setTimeout(r, 700)); };
const shot = async (name) => { await new Promise((r) => setTimeout(r, 500)); await page.screenshot({ path: `/tmp/hud2-${name}.png` }); console.log('FRAME', name); };

await new Promise((r) => setTimeout(r, 9000));
await shot('00-frontend');
await tap(422, 264); // CONTINUE past the chapter card
await waitFor('Encounter: Explore safe', 240000);
await new Promise((r) => setTimeout(r, 2500));
await shot('01-explore');
await tap(120, 195); // START defense
await waitFor('Encounter: Defense started', 300000);
await new Promise((r) => setTimeout(r, 7000));
await shot('02-combat');
await tap(345, 68); // pause plate
await new Promise((r) => setTimeout(r, 1200));
await shot('03-pause');
await page.keyboard.press('Escape');
await new Promise((r) => setTimeout(r, 900));
await tap(100, 290); // armory entry (SWAP)
await new Promise((r) => setTimeout(r, 1600));
await shot('04-armory');
console.log('errors:', lines.filter((l) => l.startsWith('PAGEERROR')).slice(0, 3));
await browser.close(); server.close();
