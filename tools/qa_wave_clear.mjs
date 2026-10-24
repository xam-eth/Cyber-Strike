#!/usr/bin/env node
/*
 * Full-wave WebAssembly QA: earn 120 BP, purchase Nova, then replay.
 * Start the project-root server first:
 *   python -m http.server 800 --bind 0.0.0.0
 * Then: npm ci --prefix tools && node tools/qa_wave_clear.mjs
 *
 * Only touchscreen taps, swipes, holds and screenshots are sent to the game.
 * This is a strict exploratory gate: a real +120 BP is required to reach Nova.
 * Some spawns/devices may still lose; a failed attempt exits 1, not a PASS.
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'exports', 'qa-wave-clear');
const EFFECTS = process.argv.includes('--effects');
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
  const replayFrames = [];
  let impactAt = 0;
  page.on('console', message => {
    const line = message.text();
    lines.push(line);
    if (/^Effects QA: Nova impact=.+ damaged=[1-9]/.test(line) && !impactAt) impactAt = Date.now();
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

  const swipe = async (x1, y1, x2, y2) => {
    await page.touchscreen.touchStart(x1, y1);
    await page.touchscreen.touchMove(x2, y2);
    await delay(90);
    await page.touchscreen.touchEnd();
    await delay(190);
  };
  const preview = EFFECTS ? `${URL}${URL.includes('?') ? '&' : '?'}qa_effects` : URL;
  await page.goto(preview, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await waitFor('Encounter: Explore safe', 90000);
  await shot('00-explore');
  await tap(120, 195); // START, not the expanded SWAP plate.
  await waitFor('Encounter: Defense started', 300000);
  await delay(5000);
  await shot('01-first-contact');
  await fire(6000);
  await shot('02-after-fire');
  await tap(320, 400); // EMP, not FIRE.
  await delay(1200);
  await shot('03-after-first-fire-emp');
  console.log('KO now:', lines.filter(line => line.includes('Encounter: RUNNER KO')).length);
  for (let index = 0; index < 10 && !has('Results after wave'); index++) {
    await swipe(218, 465, 185, index < 3 ? 480 : 465); // open camera-look seam
    await fire(1600);
    if (index % 2 === 1) await shot(`turn-${index}`);
    if (index === 5 || index === 8) {
      await tap(320, 400); // EMP, not FIRE.
      await shot(`second-emp-${index}`);
    }
    console.log('TURN', index, 'KO', lines.filter(line => line.includes('Encounter: RUNNER KO')).length);
    if (lines.filter(line => line.includes('Encounter: RUNNER KO')).length >= 2) break;
  }
  if (!has('Results after wave')) {
    await tap(345, 68); // PAUSE
    await delay(550);
    await tap(185, 654);
  }
  await waitFor('Encounter: Results after wave', 45000);
  await shot('02-results');
  const bank = lines.find(line => line.includes('Progression: banked')) || '';
  const banked = Number(bank.match(/banked \+(\d+) BP/)?.[1] || 0);
  console.log('BANK:', bank);
  if (banked < 120) throw new Error(`Need 120 earned BP before testing an unlock, got ${banked}`);
  await tap(190, 765); // Results -> Explore
  await waitFor('Encounter: Returned to Explore', 15000);
  await tap(100, 290); // SWAP opens Armory when only one weapon is equipped.
  await shot('03-armory-ready');
  await tap(190, 404); // Nova, 120 BP
  await waitFor('Armory: unlocked nova_launcher', 15000);
  await shot('04-armory-nova-equipped');
  await tap(190, 533); // Return to field
  await delay(700);
  await tap(120, 195); // START DEFENSE with Nova equipped, above SWAP.
  await waitForCount('Encounter: Defense started', 2, 300000);
  let cdp;
  if (EFFECTS) {
    // Save compositor frames continuously: page.screenshot() can arrive only
    // after a sub-second impact has vanished on software-rendered WebGL.
    cdp = await page.createCDPSession();
    await cdp.send('Page.enable');
    cdp.on('Page.screencastFrame', ({ data, sessionId }) => {
      if (replayFrames.length < 80) replayFrames.push({ data, time: Date.now() });
      cdp.send('Page.screencastFrameAck', { sessionId }).catch(error => errors.push(String(error)));
    });
    await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1 });
    await delay(5000); // wait for the actual replay Runner, not an empty floor
  }
  await shot('05-nova-replay');
  if (EFFECTS) {
    // Results now restores the authored horizon instead of inheriting the
    // steep floor-facing camera from the first wave. Use a deliberate thumb
    // look toward the front-right Runner's approach and the floor near it;
    // a centered blind shot into the horizon cannot demonstrate splash art.
    await swipe(218, 465, 238, 485); // start in the open look lane, not EMP
    await shot('05b-nova-aimed-lane');
  }
  await fire(EFFECTS ? 5000 : 1700);
  await shot('06-nova-fired');
  if (EFFECTS) {
    const damagingImpact = () => lines.find(line =>
      /^Effects QA: Nova impact=.+ damaged=[1-9]/.test(line)) || '';
    for (let index = 0; index < 9 && !damagingImpact()
      && lines.filter(line => line.includes('Encounter: Results after wave')).length < 2; index++) {
      await swipe(218, 465, 183, index % 3 === 2 ? 485 : 465);
      await fire(2300);
      if (index % 2 === 0) await shot(`nova-search-${index}`);
    }
    const impact = damagingImpact();
    if (!impact) throw new Error('Nova rounds left the barrel, but none hit a real target; impact art not verified');
    console.log('TARGET IMPACT', impact);
    await delay(3000); // give the compositor a chance to present post-impact frames
    await shot('07-nova-target-impact');
    await cdp.send('Page.stopScreencast');
    for (const [index, frame] of replayFrames.entries()) {
      const name = `nova-replay-compositor-${String(index).padStart(2, '0')}.png`;
      fs.writeFileSync(path.join(OUT, name), Buffer.from(frame.data, 'base64'));
      console.log(`CAPTURE ${name} ${frame.time - impactAt}ms from target impact`);
    }
    if (replayFrames.length < 2) throw new Error('Too few WebGL compositor frames to inspect the impact');
  }
  if (errors.length) throw new Error(errors.join('\n'));
  console.log('PASS: 2 Runner KOs + 100 clear -> 120 banked -> Nova unlocked/equipped -> replay FIRE'
    + (EFFECTS ? ' -> damaging Nova impact' : ''));

} finally {
  await browser.close();
}
