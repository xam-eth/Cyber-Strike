import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const CACHE = path.join(path.resolve(path.dirname(fileURLToPath(import.meta.url))), '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');
if (!fs.existsSync(LIB_DIR)) {
  const br = path.join(path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))), '..', 'bin', 'al2023.tar.br');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}
const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

const w = Number(process.argv[2] || 844);
const h = Number(process.argv[3] || 390);
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
const page = await browser.newPage();
await page.setViewport({ width: w, height: h, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
page.on('console', (m) => {
  const t = m.text();
  if (/STAGE=|CANVAS=|SAFE=|\d+,\d+,\d+x\d+/.test(t)) console.log(t);
});
await page.goto(`http://127.0.0.1:8199/web/index.html?qa_stage=DASHBOARD&qa_menu=1`, { waitUntil: 'load' });
await new Promise((r) => setTimeout(r, 18000));
await page.screenshot({ path: '/tmp/probe.png' });
await browser.close();
