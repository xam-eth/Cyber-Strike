#!/usr/bin/env node
/*
 * Physical touch-target regression for the landscape Godot WebAssembly build.
 * Run the project-root preview server, then `node tools/qa_touch_targets.mjs`.
 * Uses only real browser key/touch events; ?qa_effect freezes an ACTUAL round
 * after it leaves the muzzle, not a mocked input or fabricated projectile.
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
const URL = process.argv.find(arg => arg.startsWith('--url='))?.slice(6) || 'http://127.0.0.1:8080/';
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
  const joiner = URL.includes('?') ? '&' : '?';
  const preview = `${URL}${joiner}qa_stage=GAMEPLAY&qa_world=frostline_relay&qa_effect&qa_camera&qa_touch`;
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
  const waitForCount = async (text, minimum, ms = 120000) => {
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
  const parseRects = (width, height) => {
    const marker = `Touch QA: viewport=${width}x${height} phase=explore `;
    const line = lines.filter(item => item.startsWith(marker)).at(-1);
    if (!line) throw new Error(`Missing Touch QA line for ${width}x${height}`);
    const rects = {};
    for (const match of line.matchAll(/([A-Z]+)=(-?\d+),(-?\d+),(\d+)x(\d+)/g)) {
      const [, name, x, y, w, h] = match;
      rects[name] = {
        x: Number(x),
        y: Number(y),
        w: Number(w),
        h: Number(h),
        cx: Math.round(Number(x) + Number(w) / 2),
        cy: Math.round(Number(y) + Number(h) / 2),
      };
    }
    return { line, rects };
  };
  const assertPhysicalRects = async (width, height, minimum) => {
    const marker = `Touch QA: viewport=${width}x${height} phase=explore `;
    await waitForCount(marker, 1);
    const { line, rects } = parseRects(width, height);
    for (const [name, min] of Object.entries(minimum)) {
      const rect = rects[name];
      if (!rect || rect.w < min || rect.h < min) {
        throw new Error(`${width}x${height} ${name} rendered hit rect must be >=${min}px: ${line}`);
      }
      if (rect.x < 0 || rect.y < 0 || rect.x + rect.w > width || rect.y + rect.h > height) {
        throw new Error(`${width}x${height} ${name} clips outside viewport: ${line}`);
      }
    }
    console.log('MEASURED', line);
    return rects;
  };
  const shot = async name => {
    await delay(250);
    await page.screenshot({ path: path.join(OUT, `${name}.png`) });
    console.log('FRAME', name);
  };
  const tap = async (x, y) => {
    await page.touchscreen.touchStart(x, y);
    await delay(180);
    await page.touchscreen.touchEnd();
    await delay(450);
  };
  const viewport = async (width, height, newScene = false) => {
    if (newScene) {
      await page.close();
      page = await browser.newPage();
      listen(page);
    }
    await page.setViewport({ width, height, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
    const explored = count('Encounter: Explore safe');
    await page.goto(preview, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await waitForCount('Encounter: Explore safe', explored + 1, 150000);
    await page.waitForFunction(() => document.body?.dataset?.mode === 'playing', { timeout: 30000 });
    await delay(900);
  };
  const fireFromRim = async (rect, name) => {
    const before = count('Shot QA: real shot frozen');
    const rimX = Math.round(rect.x + Math.max(12, rect.w * 0.22));
    const rimY = rect.cy;
    await page.keyboard.press('F8');
    await page.touchscreen.touchStart(rimX, rimY);
    await waitForCount('Shot QA: real shot frozen', before + 1);
    await shot(name);
    await page.touchscreen.touchEnd();
    await page.keyboard.press('F8');
    await delay(350);
  };

  await viewport(844, 390, false);
  const r844 = await assertPhysicalRects(844, 390, { FIRE: 92, ADS: 76, EMP: 76, SWAP: 76, PAUSE: 60 });
  await shot('01-landscape-844-explore');
  await fireFromRim(r844.FIRE, '02-landscape-844-fire-rim');

  const aims = count('Camera QA: aim=true');
  await page.touchscreen.touchStart(r844.ADS.cx, r844.ADS.cy);
  await delay(900);
  await shot('03-landscape-844-ads');
  await page.touchscreen.touchEnd();
  if (count('Camera QA: aim=true') <= aims) throw new Error('ADS touch did not enter real aim state');

  await tap(r844.EMP.cx, r844.EMP.cy);
  await shot('04-landscape-844-emp');

  const pauses = count('HUD: paused');
  const pauseX = r844.PAUSE.x < 422 ? Math.round(844 / 2 + 36) : r844.PAUSE.cx;
  await tap(pauseX, r844.PAUSE.cy);
  await waitForCount('HUD: paused', pauses + 1);
  await shot('05-landscape-844-pause');
  await page.keyboard.press('Escape');
  await waitForCount('HUD: resumed', 1);

  const armoryPauses = count('HUD: paused');
  await tap(r844.SWAP.cx, r844.SWAP.cy);
  await waitForCount('HUD: paused', armoryPauses + 1);
  await shot('06-landscape-844-armory');
  await page.keyboard.press('Escape');
  await waitForCount('HUD: resumed', 2);

  await viewport(667, 375, true);
  const r667 = await assertPhysicalRects(667, 375, { FIRE: 92, ADS: 76, EMP: 76, SWAP: 76, PAUSE: 60 });
  await shot('07-landscape-667-explore');
  await fireFromRim(r667.FIRE, '08-landscape-667-fire-rim');

  const compactPauses = count('HUD: paused');
  await tap(r667.SWAP.cx, r667.SWAP.cy);
  await waitForCount('HUD: paused', compactPauses + 1);
  await shot('09-landscape-667-armory');
  await page.keyboard.press('Escape');
  await waitForCount('HUD: resumed', 3);

  if (errors.length) throw new Error(errors.join('\n'));
  console.log('PASS: landscape 844x390 + 667x375 real shots from FIRE rim; ADS, EMP, Pause, SWAP and Armory respond cleanly');
} finally {
  await browser.close();
}
