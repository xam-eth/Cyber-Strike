#!/usr/bin/env node
/**
 * anim_strip.mjs — render every animation a model carries as a filmstrip.
 *
 * The clips are real `THREE.AnimationClip`s (see src/runtime/rig.js), so the
 * only honest way to show them is to play them: this drives the mixer to N
 * evenly spaced times, screenshots each, and composes the frames side by side
 * with `contact_sheet`'s PNG writer. No frame is invented and no timing is
 * faked — the frame's time is printed in the strip index.
 *
 *   node tools/asset-forge/gate/anim_strip.mjs                     # every animated model
 *   node tools/asset-forge/gate/anim_strip.mjs --only exo_operative,pulse_rifle
 *   node tools/asset-forge/gate/anim_strip.mjs --frames 8 --cell 200
 *
 * Output: tools/asset-forge/review/anim/<id>-<clip>.png  and review/anim.json
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { decodePng } from './png.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..', '..');
const FORGE = path.join(ROOT, 'tools', 'asset-forge');
const REVIEW = path.join(FORGE, 'review', 'anim');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (n, d) => { const i = argv.indexOf(n); return i === -1 ? d : argv[i + 1]; };
const only = flag('--only', '') ? flag('--only', '').split(',').map((s) => s.trim()) : null;
const FRAMES = Number(flag('--frames', '6'));
const CELL = Number(flag('--cell', '200'));
const VIEW = { az: Number(flag('--az', '34')), el: Number(flag('--el', '14')) };
const BG = [0x0b, 0x13, 0x1b];

const catalog = JSON.parse(fs.readFileSync(path.join(FORGE, 'catalog.json'), 'utf8'));
const targets = catalog.entries.filter((e) => (only ? only.includes(e.id) : (e.animations ?? []).length > 0));

/* ------------------------------------------------------------ png writing */

const CRC = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const tb = Buffer.from(type, 'ascii');
  let c = -1;
  for (let i = 0; i < tb.length; i += 1) c = CRC[(c ^ tb[i]) & 0xff] ^ (c >>> 8);
  for (let i = 0; i < data.length; i += 1) c = CRC[(c ^ data[i]) & 0xff] ^ (c >>> 8);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE((c ^ -1) >>> 0, 0);
  return Buffer.concat([len, tb, data, crc]);
}

function encodePng(img) {
  const raw = Buffer.alloc((img.width * img.channels + 1) * img.height);
  for (let y = 0; y < img.height; y += 1) {
    raw[y * (img.width * img.channels + 1)] = 0;
    img.data.copy(raw, y * (img.width * img.channels + 1) + 1, y * img.width * img.channels, (y + 1) * img.width * img.channels);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.width, 0);
  ihdr.writeUInt32BE(img.height, 4);
  ihdr[8] = 8;
  ihdr[9] = img.channels === 4 ? 6 : 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function canvas(w, h) {
  const data = Buffer.alloc(w * h * 3);
  for (let i = 0; i < w * h; i += 1) {
    data[i * 3] = BG[0]; data[i * 3 + 1] = BG[1]; data[i * 3 + 2] = BG[2];
  }
  return { width: w, height: h, channels: 3, data };
}

function blit(dst, src, ox, oy) {
  for (let y = 0; y < src.height; y += 1) {
    for (let x = 0; x < src.width; x += 1) {
      const dx = ox + x;
      const dy = oy + y;
      if (dx < 0 || dy < 0 || dx >= dst.width || dy >= dst.height) continue;
      const si = (y * src.width + x) * src.channels;
      const di = (dy * dst.width + dx) * 3;
      dst.data[di] = src.data[si];
      dst.data[di + 1] = src.data[si + 1];
      dst.data[di + 2] = src.data[si + 2];
    }
  }
}

function downscale(img, size) {
  const out = { width: size, height: size, channels: 3, data: Buffer.alloc(size * size * 3) };
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const sx = Math.min(img.width - 1, Math.floor((x / size) * img.width));
      const sy = Math.min(img.height - 1, Math.floor((y / size) * img.height));
      const si = (sy * img.width + sx) * img.channels;
      const di = (y * size + x) * 3;
      out.data[di] = img.data[si];
      out.data[di + 1] = img.data[si + 1];
      out.data[di + 2] = img.data[si + 2];
    }
  }
  return out;
}

/* --------------------------------------------------------------- browser -- */

const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

const port = Number(flag('--port', '8163'));
const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 900));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 600000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
const page = await browser.newPage();
await page.setViewport({ width: CELL, height: CELL, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.error('  pageerror:', e.message));
await page.goto(`http://127.0.0.1:${port}/tools/asset-forge/gallery.html?capture=1&nospin=1`, { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.__api, { timeout: 60000 });
await page.evaluate((s) => window.__api.resize(s), CELL);

fs.mkdirSync(REVIEW, { recursive: true });
const index = [];

for (const entry of targets) {
  try {
    await page.evaluate((id) => window.__api.load(id), entry.id);
    const clips = await page.evaluate(() => window.__api.clips());
    const declared = entry.animations ?? [];
    const usable = clips.filter((c) => declared.includes(c));
    if (!usable.length) {
      console.log(`· ${entry.id.padEnd(24)} no clips`);
      continue;
    }
    const strips = [];
    for (const clip of usable) {
      const frames = [];
      for (let i = 0; i < FRAMES; i += 1) {
        // sample the clip's own duration; the last frame is duration - epsilon so
        // it does not wrap to the first pose on a looping clip
        const t = (i / FRAMES) * 0.999;
        const shot = await page.evaluate(async ({ name, time, view }) => {
          const clipNames = await window.__api.clips();
          if (!clipNames.includes(name)) return null;
          const info = await window.__api.clipDuration(name);
          await window.__api.playClip(name, time * info);
          await window.__api.setView(view.az, view.el);
          const [img] = await window.__api.shots([view], 0);
          return { dataUrl: img.dataUrl, duration: info };
        }, { name: clip, time: t, view: VIEW });
        if (!shot) break;
        frames.push({ t: Number((t * shot.duration).toFixed(3)), duration: shot.duration, buffer: Buffer.from(shot.dataUrl.split(',')[1], 'base64') });
      }
      if (!frames.length) continue;
      const sheet = canvas(FRAMES * (CELL + 2) + 2, CELL + 4);
      frames.forEach((f, i) => {
        const img = decodePng(f.buffer);
        const small = downscale(img, CELL);
        blit(sheet, small, 2 + i * (CELL + 2), 2);
      });
      const file = path.join(REVIEW, `${entry.id}-${clip}.png`);
      fs.writeFileSync(file, encodePng(sheet));
      strips.push({ clip, file: path.relative(FORGE, file), duration: frames[0].duration, samples: frames.map((f) => f.t) });
    }
    if (strips.length) {
      index.push({ id: entry.id, category: entry.category, strips });
      console.log(`· ${entry.id.padEnd(24)} ${strips.map((s) => `${s.clip}(${s.duration}s)`).join(' ')}`);
    }
  } catch (e) {
    console.log(`· ${entry.id.padEnd(24)} ERROR ${e.message}`);
  }
}

await browser.close();
server.kill();

fs.writeFileSync(path.join(FORGE, 'review', 'anim.json'), `${JSON.stringify({
  generated: new Date().toISOString(),
  note: 'Filmstrips sampled from the model\u2019s own AnimationClip at N evenly spaced times. Frames are screenshots of a software renderer; they prove the clip exists and moves, not that it is well animated.',
  frames: FRAMES,
  cell: CELL,
  view: VIEW,
  models: index,
}, null, 2)}\n`);
console.log(`\n${index.length} models → ${index.reduce((a, m) => a + m.strips.length, 0)} strips in tools/asset-forge/review/anim/`);
