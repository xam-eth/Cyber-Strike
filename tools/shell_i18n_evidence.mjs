/*
 * Language evidence for the HTML shell: the same four screens, twice.
 *
 * The whole point of this round's i18n work is that English and Indonesian are
 * *both* real — not one language with strings swapped in at the last minute. The
 * only honest way to show that is two frames of the same screen, taken from the
 * same build, one per language, with no text edited between them.
 *
 *   node tools/shell_i18n_evidence.mjs 844x390
 *
 * Writes `<SHOT_DIR>/<locale>-<screen>.png` (SHOT_DIR defaults to /tmp/shell-i18n)
 * and prints the language each frame reports from `document.documentElement.lang`,
 * so a frame cannot silently belong to the wrong language.
 *
 * Requires `npm ci --prefix tools` and the al2023 libraries @sparticuz/chromium
 * unpacks (`LD_LIBRARY_PATH=tools/.cache/lib`). It serves the repository root,
 * because the shell loads `./ui/…` and `./game/assets/…` relative to index.html.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const root = process.cwd();
const outDir = process.env.SHOT_DIR || '/tmp/shell-i18n';
fs.mkdirSync(outDir, { recursive: true });
const [vw, vh] = (process.argv[2] || '844x390').split('x').map(Number);

const types = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
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
await new Promise((r) => server.listen(8162, '0.0.0.0', r));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 420000,
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const SCREENS = ['opening', 'hero', 'hub', 'settings'];
let failures = 0;

for (const locale of ['en', 'id']) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e).split('\n')[0]));
  await page.setViewport({ width: vw, height: vh, hasTouch: true, isMobile: false, deviceScaleFactor: 1 });
  for (const screen of SCREENS) {
    // `ui=<screen>` is the shell's own deep link; `ui_hold=1` keeps the engine
    // from booting, so the frame is the front end and nothing else.
    await page.goto(`http://127.0.0.1:8162/index.html?lang=${locale}&ui=${screen}&ui_hold=1`, {
      waitUntil: 'networkidle2',
      timeout: 60000,
    });
    await sleep(1400);
    const seen = await page.evaluate(() => document.documentElement.lang);
    const title = await page.evaluate(() => {
      const active = document.querySelector('.screen[data-active="true"]');
      return active ? active.id : 'none';
    });
    const name = `${locale}-${screen}`;
    await page.screenshot({ path: path.join(outDir, `${name}.png`) });
    console.log(`FRAME ${name} lang=${seen} screen=${title}`);
    if (seen !== locale) {
      failures += 1;
      console.error(`FAIL ${name}: page reports lang=${seen}, expected ${locale}`);
    }
    // A hub frame in Indonesian must not still be showing the English title.
    if (screen === 'hub') {
      const heading = await page.evaluate(() => document.getElementById('hub-title')?.textContent || '');
      const expected = locale === 'id' ? 'PILIH TEATER' : 'CHOOSE THEATRE';
      console.log(`  hub title: "${heading}"`);
      if (!heading.includes(expected)) {
        failures += 1;
        console.error(`FAIL ${name}: hub title "${heading}" does not include "${expected}"`);
      }
    }
  }
  if (errors.length) {
    failures += 1;
    console.error(`FAIL ${locale}: page errors ${JSON.stringify(errors.slice(0, 3))}`);
  }
  await page.close();
}

await browser.close();
server.close();
console.log(failures === 0 ? 'SHELL I18N EVIDENCE OK' : `SHELL I18N EVIDENCE FAILED: ${failures}`);
process.exit(failures === 0 ? 0 : 1);
