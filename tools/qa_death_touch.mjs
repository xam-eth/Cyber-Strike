#!/usr/bin/env node
/*
 * Real WebAssembly defeat reveal: one touch starts Defense and the player
 * stands still until actual Runner attacks exhaust health. No damage API,
 * injected enemy, profile edit or animation seek. The full Blender death clip
 * should remain in view before Results replaces it.
 *
 * python -m http.server 800 --bind 0.0.0.0
 * node tools/qa_death_touch.mjs
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'exports', 'qa-death-touch');
const URL = process.argv.find(arg => arg.startsWith('--url='))?.slice(6) || 'http://127.0.0.1:800/';
const LIB_DIR = path.join(ROOT, 'tools', '.cache', 'al2023-lib', 'lib');
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const entry = path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium')));
  const tar = path.join(ROOT, 'tools', '.cache', 'al2023.tar');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(path.join(entry, '..', 'bin', 'al2023.tar.br'))));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
fs.mkdirSync(OUT, { recursive: true });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const lines = [];
  const errors = [];
  const revealFrames = [];
  let revealAt = 0;
  let resultsAt = 0;
  page.on('console', message => {
    const line = message.text();
    lines.push(line);
    if (line.includes('Encounter: Defeat reveal before Results')) revealAt = Date.now();
    if (line.includes('Encounter: Results after wave')) resultsAt = Date.now();
    if (/Encounter:|Progression:|Rig QA:/.test(line)) console.log(line);
    if (/SCRIPT ERROR:|Parse Error:/.test(line)) errors.push(line);
  });
  const cdp = await page.createCDPSession();
  await cdp.send('Page.enable');
  cdp.on('Page.screencastFrame', ({ data, sessionId }) => {
    if (revealAt && !resultsAt && revealFrames.length < 24) {
      revealFrames.push({ data, ms: Date.now() - revealAt });
    }
    cdp.send('Page.screencastFrameAck', { sessionId }).catch(error => errors.push(String(error)));
  });
  await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1 });
  page.on('pageerror', error => errors.push(String(error)));
  const waitFor = (text, ms) => new Promise((resolve, reject) => {
    if (lines.some(line => line.includes(text))) return resolve();
    const timer = setTimeout(() => { page.off('console', check); reject(new Error(`Timeout waiting for ${text}`)); }, ms);
    const check = () => {
      if (lines.some(line => line.includes(text))) {
        clearTimeout(timer);
        page.off('console', check);
        resolve();
      }
    };
    page.on('console', check);
  });
  const shot = async name => {
    await page.screenshot({ path: path.join(OUT, `${name}.png`) });
    console.log('FRAME', name);
  };
  const preview = `${URL}${URL.includes('?') ? '&' : '?'}qa_camera`;
  await page.goto(preview, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await waitFor('Encounter: Explore safe', 90000);
  await page.touchscreen.tap(120, 195); // START, above enlarged SWAP.
  await waitFor('Encounter: Defense started', 300000);
  await waitFor('Encounter: Defeat reveal before Results', 600000);
  if (lines.some(line => line.includes('Encounter: Results after wave'))) {
    throw new Error('Results appeared in the same frame as defeat, hiding the authored collapse');
  }
  await shot('01-death-start');
  await delay(1200);
  await shot('02-death-mid');
  await waitFor('Encounter: Results after wave', 60000);
  await cdp.send('Page.stopScreencast');
  await shot('03-results');
  for (const [index, frame] of revealFrames.entries()) {
    const name = `death-compositor-${String(index).padStart(2, '0')}.png`;
    fs.writeFileSync(path.join(OUT, name), Buffer.from(frame.data, 'base64'));
    console.log(`CAPTURE ${name} +${frame.ms}ms`);
  }
  if (errors.length) throw new Error(errors.join('\n'));
  const revealIndex = lines.findIndex(line => line.includes('Encounter: Defeat reveal before Results'));
  const resultsIndex = lines.findIndex(line => line.includes('Encounter: Results after wave'));
  const clips = lines.slice(revealIndex, resultsIndex)
    .filter(line => line.startsWith('Camera QA:') && line.includes('clip=death'));
  const bones = lines.slice(revealIndex, resultsIndex)
    .filter(line => line.startsWith('Rig QA: death'));
  const collapsed = bones.some(line =>
    Number(line.match(/t=([\d.]+)/)?.[1] || 0) > 0.75
    && Number(line.match(/head_y=([\d.]+)/)?.[1] || 10) < 0.65);
  if (clips.length < 2 || revealFrames.length < 2 || !collapsed) {
    throw new Error(`Need visible-time samples and a lowered Blender head bone before Results; got ${clips.length} clips, ${revealFrames.length} compositor frames, collapsed=${collapsed}`);
  }
  console.log(`PASS: real Runner defeat; ${clips.length} death clip samples, lowered head bone, ${revealFrames.length} compositor frames before Results. Rendered motion quality remains OPEN.`);
} finally {
  await browser.close();
}
