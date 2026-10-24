#!/usr/bin/env node
/*
 * Real browser/input regression for the WebAssembly run-to-reward loop.
 * Start the project-root server first:
 *   python -m http.server 800 --bind 0.0.0.0
 * Then: npm ci --prefix tools && node tools/qa_combat_loop.mjs
 *
 * This does not inject Godot state or award BP. It taps the rendered canvas,
 * holds FIRE, triggers EMP, and checks the printed reward from an actual KO.
 * Depending on the device/frame rate, wave-one enemies may win: a failed KO
 * is reported honestly rather than converting a zero-BP Results into PASS.
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'exports', 'qa-combat-loop');
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
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
fs.mkdirSync(OUT, { recursive: true });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const lines = [];
  const errors = [];
  page.on('console', message => {
    const line = message.text();
    lines.push(line);
    if (/Encounter:|Progression:|Armory:/.test(line)) console.log(line);
    if (/SCRIPT ERROR:|Parse Error:/.test(line)) errors.push(line);
  });
  page.on('pageerror', error => errors.push(String(error)));
  const has = text => lines.some(line => line.includes(text));
  const waitForCount = async (text, count = 1, ms = 180000) => {
    if (lines.filter(line => line.includes(text)).length >= count) return;
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => { page.off('console', check); reject(new Error(`Timeout waiting for ${text} #${count}`)); }, ms);
      const check = () => {
        if (lines.filter(line => line.includes(text)).length >= count) {
          clearTimeout(timeout);
          page.off('console', check);
          resolve();
        }
      };
      page.on('console', check);
    });
  };
  const waitFor = (text, ms = 180000) => waitForCount(text, 1, ms);
  const shot = async name => {
    await delay(350);
    await page.screenshot({ path: path.join(OUT, `${name}.png`) });
    console.log('FRAME', name);
  };
  const tap = async (x, y) => { await page.touchscreen.tap(x, y); await delay(500); };
  const fire = async ms => {
    await page.touchscreen.touchStart(323, 746);
    await delay(ms);
    await page.touchscreen.touchEnd();
  };

  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await waitFor('Encounter: Explore safe', 90000);
  await shot('01-explore');
  await tap(120, 195); // START, above the expanded SWAP plate.
  await waitFor('Encounter: Defense started', 300000);
  await delay(5000);
  await shot('02-first-contact');
  if (!has('Results after wave')) {
    await fire(6000);
    await shot('03-after-fire');
    await tap(320, 400); // EMP: its new portrait face is x258..382/y338..462.
    await delay(1200);
    await shot('04-after-emp');
  }
  if (!has('Results after wave') && !has('Encounter: Runner KO')) await fire(5000);
  if (!has('Results after wave')) {
    await tap(345, 68); // PAUSE: the 64px top-right plate.
    await delay(550);
    await tap(185, 654); // FINISH RUN · RESULTS
  }
  await waitFor('Encounter: Results after wave', 45000);
  await shot('05-results');
  const bank = lines.find(line => line.includes('Progression: banked +')) || '';
  const match = bank.match(/banked \+(\d+) BP · wallet (\d+)/);
  if (!match || Number(match[1]) <= 0) throw new Error(`Real reward was not earned: ${bank || 'no bank event'}`);
  console.log('EARNED', `${match[1]} BP`, 'WALLET', match[2]);
  await tap(190, 765); // Results -> Return to Explore
  await waitFor('Encounter: Returned to Explore', 15000);
  await tap(100, 290); // SWAP opens Armory with one equipped weapon.
  await shot('06-armory-after-reward');
  await page.keyboard.press('Escape');
  await delay(850);
  const preparations = lines.filter(line => line.includes('Encounter: Preparing Defense')).length;
  const defenses = lines.filter(line => line.includes('Encounter: Defense started')).length;
  await tap(120, 195); // START, above the expanded SWAP plate.
  await waitForCount('Encounter: Preparing Defense', preparations + 1, 15000);
  await waitForCount('Encounter: Defense started', defenses + 1, 300000);
  await shot('07-replay-defense');
  // Capture controls and the rifle *during* a held shot, not just after ammo
  // changed. These are visual evidence, not an assertion of AAA VFX quality.
  await delay(3700);
  await page.touchscreen.touchStart(323, 746);
  await delay(550);
  await shot('08-portrait-fire-held');
  await page.touchscreen.touchEnd();
  await page.setViewport({ width: 844, height: 390, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  await delay(900);
  await shot('09-landscape');
  if (errors.length) throw new Error(errors.join('\n'));
  console.log('PASS: actual touch KO -> BP banked -> Results -> Explore -> Armory -> replay');
} finally {
  await browser.close();
}
