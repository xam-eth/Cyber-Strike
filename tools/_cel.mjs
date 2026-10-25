import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const root = process.cwd();
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg', '.glb': 'model/gltf-binary', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(8141, '0.0.0.0', r));
const browser = await puppeteer.launch({ executablePath: await chromium.executablePath(), args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'], headless: true, protocolTimeout: 180000 });
const page = await browser.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push('PAGEERROR ' + String(e).split('\n')[0]));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 160)); });
await page.setViewport({ width: 844, height: 390, deviceScaleFactor: 2 });
await page.goto('http://127.0.0.1:8141/index.html?ui=hero&ui_hold=1', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => document.querySelector('#hero-canvas')?.dataset.state === 'ready', { timeout: 60000 });
await page.waitForFunction(() => window.AegisHeroStage?.describe?.().celebration, { timeout: 30000 }).catch(() => {});
const info = await page.evaluate(() => window.AegisHeroStage.describe());
const box = await page.evaluate(() => {
  const b = document.getElementById('hero-canvas').getBoundingClientRect();
  return { x: Math.round(b.x), y: Math.round(b.y), width: Math.round(b.width), height: Math.round(b.height) };
});
for (const t of [0.0, 0.2, 0.55, 0.9, 1.4, 2.1]) {
  const at = await page.evaluate((s) => window.AegisHeroStage.poseAt(s), t);
  await new Promise((r) => setTimeout(r, 260));
  await page.screenshot({ path: `/tmp/cel-${String(t).replace('.', '_')}.png`, clip: box });
  if (at === null) break;
}
console.log(JSON.stringify({ celebration: info.celebration, seconds: info.celebrationSeconds, errors: errors.slice(0, 6) }));
await browser.close(); server.close();
