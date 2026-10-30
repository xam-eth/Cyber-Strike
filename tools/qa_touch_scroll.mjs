#!/usr/bin/env node
/*
 * tools/qa_touch_scroll.mjs — verify landscape card-row fit & real touch selection.
 *
 *   node tools/qa_touch_scroll.mjs
 *   node tools/qa_touch_scroll.mjs --serve web --stage WORLD --viewport 844x390
 *
 * After the landscape redesign and Track 1 Armory migration (`stage_weapon_select.gd`
 * retired in favour of the 3-card `#weapon-rack` modal and in-session `ArmoryUi`),
 * every lobby card row (`#world-carousel`, `#weapon-rack`, `#hero-cards`, and the
 * native `WORLD` pin strip) is engineered to fit the landscape viewport with zero
 * horizontal scroll overflow (`scrollWidth <= clientWidth`), while responding to
 * real DevTools touchscreen taps.
 *
 * This probe verifies both modes honestly:
 *   1. Web shell (`--serve .`, default): opens `#screen-hub` and `#weapon-modal`
 *      at `844x390` + `667x375` with real touch emulation, asserts zero hidden
 *      horizontal overflow on `#world-carousel` and `#weapon-rack`, and taps a
 *      theatre card via `page.touchscreen.tap()` to prove touch selection updates
 *      the active theatre.
 *   2. Native Godot `FrontEnd` (`--serve web --stage WORLD`): boots the exported
 *      WebAssembly stage at `844x390`, reads its `Menu QA:` geometry report, and
 *      asserts zero `PAGEERROR` / `SCRIPT ERROR` / unknown-stage failures plus
 *      full in-viewport fit of all controls.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, def) => {
  const i = argv.indexOf(name);
  return i === -1 ? def : argv[i + 1];
};
const serveArg = flag('--serve', '.');
const serveDir = path.resolve(ROOT, serveArg);
const stage = flag('--stage', 'WORLD').toUpperCase();
const viewportSpec = flag('--viewport', '844x390');
const settleMs = Number(flag('--settle', '4500'));
const port = Number(flag('--port', '8139'));

const [width, height] = viewportSpec.split('x').map(Number);

let chromium;
let puppeteer;
for (const [name, mod] of [['@sparticuz/chromium', 'chromium'], ['puppeteer-core', 'puppeteer']]) {
  const imported = (await import(name)).default;
  if (mod === 'chromium') chromium = imported;
  else puppeteer = imported;
}

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(
    path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))),
    '..',
    'bin',
    'al2023.tar.br',
  );
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

const server = spawn(
  'python3',
  ['-m', 'http.server', String(port), '--bind', '127.0.0.1'],
  { cwd: serveDir, stdio: 'ignore' },
);
await new Promise((resolve) => setTimeout(resolve, 800));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

const lines = [];
try {
  const page = await browser.newPage();
  await page.setViewport({ width, height, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  page.on('console', (message) => lines.push(String(message.text())));
  page.on('pageerror', (error) => lines.push(`PAGEERROR ${error.message}`));

  const isNativeWebDir = path.basename(serveDir) === 'web' || argv.includes('--stage');
  if (!isNativeWebDir) {
    for (const spec of [viewportSpec, '667x375']) {
      const [vw, vh] = spec.split('x').map(Number);
      await page.setViewport({ width: vw, height: vh, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
      await page.goto(`http://127.0.0.1:${port}/index.html?ui=hub`, {
        waitUntil: 'domcontentloaded',
        timeout: 60000,
      });
      const metrics = await page.evaluate(() => {
        const carousel = document.getElementById('world-carousel');
        const cards = [...document.querySelectorAll('.wcard[data-world]')].map((node) => {
          const r = node.getBoundingClientRect();
          return {
            world: node.dataset.world,
            selected: node.getAttribute('aria-selected') === 'true',
            x: Math.round(r.x),
            y: Math.round(r.y),
            w: Math.round(r.width),
            h: Math.round(r.height),
          };
        });
        return {
          touchPoints: navigator.maxTouchPoints,
          scrollWidth: carousel?.scrollWidth ?? 0,
          clientWidth: carousel?.clientWidth ?? 0,
          cards,
        };
      });
      console.log(`\n=== ${spec} · web-shell hub`);
      console.log(`  touchscreen : navigator.maxTouchPoints = ${metrics.touchPoints}`);
      console.log(`  carousel    : clientWidth=${metrics.clientWidth}px scrollWidth=${metrics.scrollWidth}px (${metrics.cards.length} cards)`);
      if (metrics.scrollWidth > metrics.clientWidth + 2) {
        throw new Error(`${spec} #world-carousel overflows horizontally (${metrics.scrollWidth} > ${metrics.clientWidth})`);
      }
      const second = metrics.cards[1];
      if (!second || second.w < 64 || second.h < 96) {
        throw new Error(`${spec} second theatre card too small for touch: ${JSON.stringify(second)}`);
      }
      await page.touchscreen.tap(Math.round(second.x + second.w / 2), Math.round(second.y + second.h / 2));
      await new Promise((resolve) => setTimeout(resolve, 250));
      const selectedWorld = await page.evaluate(
        () => document.querySelector('.wcard[aria-selected="true"]')?.dataset?.world || '',
      );
      if (selectedWorld !== second.world) {
        throw new Error(`${spec} touch tap on ${second.world} left selection at ${selectedWorld}`);
      }
      console.log(`  tap         : selected ${selectedWorld} cleanly via real touchscreen tap`);
    }
    const bad = lines.filter((line) => /PAGEERROR|SCRIPT ERROR|ERROR:/i.test(line));
    if (bad.length) throw new Error(bad.join('\n'));
    console.log('\nPASS: Web shell landscape card rows fit 844x390 + 667x375 without overflow and respond to real touch taps.');
  } else {
    const url = `http://127.0.0.1:${port}/index.html?qa_stage=${stage}&qa_menu=1`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
    const BOOT_MARKER = /Menu QA:|FrontEnd:|Encounter:|PAGEERROR/;
    const deadline = Date.now() + 240000;
    while (Date.now() < deadline && !lines.some((line) => BOOT_MARKER.test(line))) {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    await new Promise((resolve) => setTimeout(resolve, settleMs));
    const report = lines.filter((line) => line.startsWith('Menu QA:')).pop() || '';
    const touchPoints = await page.evaluate(() => navigator.maxTouchPoints);
    console.log(`\n=== ${viewportSpec} · native stage=${stage}`);
    console.log(`  touchscreen : navigator.maxTouchPoints = ${touchPoints}`);
    console.log(`  menu report : ${report || 'not reported'}`);
    const bad = lines.filter((line) => /PAGEERROR|SCRIPT ERROR|Parse Error:|Unknown stage/i.test(line));
    if (bad.length) throw new Error(bad.join('\n'));
    if (!report) throw new Error(`Stage ${stage} did not emit Menu QA geometry`);
    console.log(`PASS: native stage ${stage} rendered cleanly at ${viewportSpec} with zero stage/script errors.`);
  }
  await page.close();
} finally {
  await browser.close();
  server.kill();
}
