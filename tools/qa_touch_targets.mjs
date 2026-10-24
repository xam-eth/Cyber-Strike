#!/usr/bin/env node
/*
 * Physical touch-target regression for the Godot WebAssembly build.
 * Run the project-root preview server, then `node tools/qa_touch_targets.mjs`.
 * Uses only real browser key/touch events; ?qa_effect freezes an ACTUAL round
 * after it leaves the muzzle, not a mocked input or fabricated projectile.
 * The taps below sit INSIDE the new plates but OUTSIDE their old hit rectangles.
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'exports', 'qa-touch-targets');
const URL = process.argv.find(arg => arg.startsWith('--url='))?.slice(6) || 'http://127.0.0.1:800/';
const LIB_DIR = path.join(ROOT, 'tools', '.cache', 'al2023-lib', 'lib');
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const entry = path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium')));
  const compressed = path.join(entry, '..', 'bin', 'al2023.tar.br');
  const tar = path.join(ROOT, 'tools', '.cache', 'al2023.tar');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(compressed)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}
fs.mkdirSync(OUT, { recursive: true });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
try {
  let page = await browser.newPage();
  const lines = [];
  const errors = [];
  const preview = `${URL}${URL.includes('?') ? '&' : '?'}qa_effect&qa_camera&qa_touch`;
  const listen = target => {
    target.on('console', message => {
      const line = message.text();
      lines.push(line);
      if (/^(Encounter:|HUD:|Shot QA:|Touch QA:)/.test(line)) console.log(line);
      if (/SCRIPT ERROR:|Parse Error:/.test(line)) errors.push(line);
    });
    target.on('pageerror', error => errors.push(String(error)));
  };
  listen(page);
  const count = text => lines.filter(line => line.includes(text)).length;
  const waitForCount = async (text, minimum, ms = 45000) => {
    if (count(text) >= minimum) return;
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { page.off('console', check); reject(new Error(`Timeout waiting for ${text} #${minimum}`)); }, ms);
      const check = () => {
        if (count(text) >= minimum) {
          clearTimeout(timer);
          page.off('console', check);
          resolve();
        }
      };
      page.on('console', check);
    });
  };
  const assertPhysicalRects = async (width, height, minimum) => {
    const marker = `Touch QA: viewport=${width}x${height} phase=explore `;
    await waitForCount(marker, 1);
    const line = lines.filter(item => item.startsWith(marker)).at(-1);
    for (const [name, min] of Object.entries(minimum)) {
      const found = line.match(new RegExp(`${name}=(\\d+),(\\d+),(\\d+)x(\\d+)`));
      if (!found || Number(found[3]) < min || Number(found[4]) < min) {
        throw new Error(`${width}x${height} ${name} rendered hit rect must be >=${min}px: ${line}`);
      }
    }
    console.log('MEASURED', line);
  };
  const shot = async name => {
    await delay(250);
    await page.screenshot({ path: path.join(OUT, `${name}.png`) });
    console.log('FRAME', name);
  };
  const tap = async (x, y) => { await page.touchscreen.tap(x, y); await delay(400); };
  const viewport = async (width, height, newScene = false) => {
    if (newScene) {
      // Changing emulated mobile sizes on an already-loaded Godot canvas can
      // retain the old viewport meta scale (375x667 becomes 391x696). A new
      // browser page makes the measurement a REAL native-size canvas.
      await page.close();
      page = await browser.newPage();
      listen(page);
    }
    await page.setViewport({ width, height, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
    if (newScene) {
      const explored = count('Encounter: Explore safe');
      await page.goto(preview, { waitUntil: 'domcontentloaded', timeout: 90000 });
      await waitForCount('Encounter: Explore safe', explored + 1, 90000);
    }
    await delay(850);
  };
  const fireFromNewRim = async (x, y, name) => {
    const before = count('Shot QA: real shot frozen');
    await page.keyboard.press('F8');
    await page.touchscreen.touchStart(x, y);
    await waitForCount('Shot QA: real shot frozen', before + 1);
    await shot(name);
    await page.touchscreen.touchEnd();
    await page.keyboard.press('F8'); // Resume the genuine, frozen shot.
    await delay(350);
  };

  await viewport(390, 844);
  await page.goto(preview, {
    waitUntil: 'domcontentloaded', timeout: 90000,
  });
  await waitForCount('Encounter: Explore safe', 1, 90000);
  await assertPhysicalRects(390, 844, { FIRE: 200, ADS: 122, EMP: 122, SWAP: 122, PAUSE: 62 });
  await shot('01-portrait-390-explore');
  await fireFromNewRim(185, 700, '02-portrait-390-fire-rim'); // Old FIRE began at x218.

  const aims = count('Camera QA: aim=true');
  await page.touchscreen.touchStart(263, 530); // Old ADS began at x282/y538.
  await delay(900);
  await shot('03-portrait-390-ads-rim');
  await page.touchscreen.touchEnd();
  if (count('Camera QA: aim=true') <= aims) throw new Error('ADS rim did not enter real aim state');
  await tap(263, 400); // Old EMP began at x282/y432; Explore reports NO TARGETS.
  await shot('04-portrait-390-emp-rim');
  const pauses = count('HUD: paused');
  await tap(317, 68); // Old Pause began at x322.
  await waitForCount('HUD: paused', pauses + 1);
  await shot('05-portrait-390-pause-rim');
  await page.keyboard.press('Escape');
  await waitForCount('HUD: resumed', 1);
  const armoryPauses = count('HUD: paused');
  await tap(132, 290); // Old SWAP ended at x116.
  await waitForCount('HUD: paused', armoryPauses + 1);
  await shot('06-portrait-390-swap-rim-armory');
  await page.keyboard.press('Escape');
  await waitForCount('HUD: resumed', 2);

  await viewport(375, 667, true);
  await assertPhysicalRects(375, 667, { FIRE: 184, ADS: 106, EMP: 106, SWAP: 110, PAUSE: 62 });
  await shot('07-portrait-375-explore');
  await fireFromNewRim(187, 555, '08-portrait-375-fire-rim'); // Old FIRE began at x203.

  await viewport(844, 390, true);
  await assertPhysicalRects(844, 390, { FIRE: 178, ADS: 110, EMP: 110, SWAP: 110, PAUSE: 62 });
  await shot('09-landscape-844-explore');
  await fireFromNewRim(662, 290, '10-landscape-844-fire-rim'); // Old FIRE began at x684.

  await viewport(667, 375, true);
  await assertPhysicalRects(667, 375, { FIRE: 178, ADS: 110, EMP: 110, SWAP: 110, PAUSE: 62 });
  await shot('11-landscape-667-explore');
  const compactPauses = count('HUD: paused');
  await tap(480, 125); // Compact Explore WEAPON opens Armory; old Armory overlaps it.
  await waitForCount('HUD: paused', compactPauses + 1);
  await shot('12-landscape-667-armory');
  await page.keyboard.press('Escape');
  await waitForCount('HUD: resumed', 3);
  if (errors.length) throw new Error(errors.join('\n'));
  console.log('PASS: real shots from three new FIRE rims; ADS, EMP, Pause, SWAP and compact Armory respond to touches');
} finally {
  await browser.close();
}
