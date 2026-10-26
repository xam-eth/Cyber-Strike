/*
 * HUD evidence: real frames out of the committed WebAssembly export.
 *
 * The engine is the shipped `web/index.pck` served from disk and driven with
 * real touch events at a real phone viewport -- not a mock-up, and not a
 * composited screenshot. Frames are written to SHOT_DIR (default /tmp/hud11).
 *
 *   node tools/hud_evidence.mjs calib 844x390
 *       one frame at device scale 1, so CSS pixel == canvas pixel; use it to
 *       read the coordinates the routes below are written in
 *   TAPS="x,y:frame-name;x,y:frame-name" node tools/hud_evidence.mjs taps 844x390
 *       tap, then shoot a frame under that name
 *
 * Requires `npm ci --prefix tools` and the al2023 libraries that
 * @sparticuz/chromium unpacks (`LD_LIBRARY_PATH=tools/.cache/lib`). The build
 * under test is whatever `web/index.pck` the branch currently commits: this
 * script never calls the engine's own build step, so a stale payload shows the
 * previous round's HUD.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const root = process.cwd();
const outDir = process.env.SHOT_DIR || '/tmp/hud11';
fs.mkdirSync(outDir, { recursive: true });
const mode = process.argv[2] || 'calib';
const [vw, vh] = (process.argv[3] || '844x390').split('x').map(Number);

const types = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
};
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    res.end();
    return;
  }
  res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(8161, '0.0.0.0', r));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 420000,
});
const page = await browser.newPage();
const lines = [];
page.on('console', (m) => lines.push(m.text()));
page.on('pageerror', (e) => lines.push('PAGEERROR ' + String(e).split('\n')[0]));
await page.setViewport({ width: vw, height: vh, hasTouch: true, isMobile: false, deviceScaleFactor: 1 });
await page.goto(`http://127.0.0.1:8161/web/index.html?qa_stage=GAMEPLAY`, {
  waitUntil: 'domcontentloaded',
  timeout: 90000,
});

const has = (t) => lines.some((l) => l.includes(t));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const waitFor = async (t, ms = 240000) => {
  const start = Date.now();
  while (!has(t)) {
    if (Date.now() - start > ms) throw new Error(`timeout: ${t}\n${lines.slice(-6).join('\n')}`);
    await sleep(400);
  }
};
const tap = async (x, y, hold = 120) => {
  await page.touchscreen.touchStart(x, y);
  await sleep(hold);
  await page.touchscreen.touchEnd();
  await sleep(700);
};
const shot = async (name) => {
  await sleep(600);
  await page.screenshot({ path: path.join(outDir, `${name}.png`) });
  console.log('FRAME', name);
};

await sleep(9000);
if (mode === 'calib') {
  const box = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const rect = canvas.getBoundingClientRect();
    return { x: rect.x, y: rect.y, w: rect.width, h: rect.height, inner: [innerWidth, innerHeight] };
  });
  console.log('CANVAS', JSON.stringify(box));
  await shot('calib');
} else {
  await waitFor('Encounter: Explore safe');
  await sleep(2500);
  await shot('01-explore');
  if (process.env.TAPS) {
    // "x,y:name;x,y:name" -- tap, then shoot a frame named `name`.
    for (const step of process.env.TAPS.split(';')) {
      const [coords, label] = step.split(':');
      const [x, y] = coords.split(',').map(Number);
      await tap(x, y);
      if (label) await shot(label);
    }
  } else if (mode === 'armory') {
    await tap(437, 135); // ARMORY · n BP
    await shot('02-armory');
  } else {
    await tap(447, 65); // pause plate
    await shot('02-pause');
  }
}
console.log('errors:', lines.filter((l) => l.startsWith('PAGEERROR')).slice(0, 3));
if (process.env.DEBUG_LINES) console.log('TAIL\n' + lines.slice(-Number(process.env.DEBUG_LINES)).join('\n'));
await browser.close();
server.close();
