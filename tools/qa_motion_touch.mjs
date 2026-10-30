#!/usr/bin/env node
/*
 * WebAssembly landscape in-game motion and weapon feedback capture.
 * Start the project-root server first:
 *   python3 -m http.server 8080 --bind 0.0.0.0
 * Then: npm ci --prefix tools && node tools/qa_motion_touch.mjs
 * Optional: add --record for an ignored diagnostic WebM of the canvas.
 *
 * Captures the actual Blender hero under movement, ADS and firing in safe Explore.
 * Keyboard movement is used to keep the right thumb available for FIRE/ADS;
 * these screenshots and clip logs are NOT acceptance of animation quality.
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'exports', 'qa-motion-touch');
const RECORD = process.argv.includes('--record');
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
  await page.setViewport({ width: 844, height: 390, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const lines = [];
  const errors = [];
  page.on('console', message => {
    const line = message.text();
    lines.push(line);
    if (/Encounter:|Progression:|Armory:|Touch QA:/.test(line)) console.log(line);
    if (/SCRIPT ERROR:|Parse Error:/.test(line)) errors.push(line);
  });
  page.on('pageerror', error => errors.push(String(error)));
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
  const joiner = URL.includes('?') ? '&' : '?';
  const preview = `${URL}${joiner}qa_stage=GAMEPLAY&qa_world=frostline_relay&qa_camera&qa_touch`;
  await page.goto(preview, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await waitFor('Encounter: Explore safe', 150000);
  await page.waitForFunction(() => document.body?.dataset?.mode === 'playing', { timeout: 30000 });
  await delay(900);
  await waitFor('Touch QA: viewport=844x390 phase=explore ', 45000);
  const touchLine = lines.filter(line => line.startsWith('Touch QA: viewport=844x390 phase=explore ')).at(-1);
  const centerOf = name => {
    const m = touchLine?.match(new RegExp(`${name}=(-?\\d+),(-?\\d+),(\\d+)x(\\d+)`));
    if (!m) throw new Error(`Missing ${name} rect in ${touchLine}`);
    return { x: Math.round(Number(m[1]) + Number(m[3]) / 2), y: Math.round(Number(m[2]) + Number(m[4]) / 2) };
  };
  const ads = centerOf('ADS');
  const fire = centerOf('FIRE');

  if (RECORD) {
    const started = await page.evaluate(() => {
      const canvas = document.querySelector('#canvas');
      const mime = 'video/webm;codecs=vp8';
      if (!canvas?.captureStream || !window.MediaRecorder?.isTypeSupported(mime)) return false;
      window.__motionChunks = [];
      window.__motionStarted = performance.now();
      window.__motionRecorder = new MediaRecorder(canvas.captureStream(16), {
        mimeType: mime, videoBitsPerSecond: 1400000,
      });
      window.__motionRecorder.ondataavailable = event => {
        if (event.data.size > 0) window.__motionChunks.push(event.data);
      };
      window.__motionRecorder.start(2000);
      return true;
    });
    if (!started) throw new Error('This browser cannot record canvas VP8/WebM; try without --record');
  }
  await shot('01-idle');
  await page.touchscreen.touchStart(ads.x, ads.y);
  await delay(900);
  await shot('02-ads-held');
  await page.touchscreen.touchEnd();
  await page.touchscreen.touchStart(fire.x, fire.y);
  await delay(750);
  await shot('03-fire-held');
  await page.touchscreen.touchEnd();
  await page.keyboard.down('KeyS');
  await delay(1000);
  await shot('04-move');
  await page.touchscreen.touchStart(fire.x, fire.y);
  await delay(850);
  await shot('05-move-fire-held');
  await page.touchscreen.touchEnd();
  await page.keyboard.up('KeyS');
  await page.keyboard.press('KeyG');
  await waitFor('clip=reload', 30000);
  await shot('06-reload');
  if (RECORD) {
    const recording = await page.evaluate(async () => {
      const recorder = window.__motionRecorder;
      const blob = await new Promise(resolve => {
        recorder.onstop = () => resolve(new Blob(window.__motionChunks, { type: recorder.mimeType }));
        recorder.stop();
      });
      const bytes = new Uint8Array(await blob.arrayBuffer());
      let binary = '';
      for (let offset = 0; offset < bytes.length; offset += 32768) {
        binary += String.fromCharCode(...bytes.subarray(offset, offset + 32768));
      }
      return { base64: btoa(binary), seconds: (performance.now() - window.__motionStarted) / 1000 };
    });
    const filename = path.join(OUT, 'hero-motion.webm');
    fs.writeFileSync(filename, Buffer.from(recording.base64, 'base64'));
    console.log(`RECORDED ${filename} (${recording.seconds.toFixed(1)}s wall time; actual encoded FPS may be much lower than 16)`);
  }
  const traces = lines.filter(line => line.startsWith('Camera QA:'));
  console.log('CLIP TRACE', traces.slice(-15).join('\n'));
  if (errors.length) throw new Error(errors.join('\n'));
  if (!traces.some(line => line.includes('aim=true'))
      || !traces.some(line => line.includes('fire=true'))
      || !traces.some(line => line.includes('clip=aim_run'))
      || !traces.some(line => line.includes('clip=reload'))) {
    throw new Error('Camera trace never observed ADS, FIRE, aim_run and reload in gameplay');
  }
  console.log('PASS: actual landscape 844x390 Explore ADS/FIRE/run/reload inputs and clip traces');
} finally {
  await browser.close();
}
