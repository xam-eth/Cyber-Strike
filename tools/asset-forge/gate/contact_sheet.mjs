#!/usr/bin/env node
/**
 * contact_sheet.mjs — compose the rendered evidence into review sheets.
 *
 * One sheet per category, plus a `combined.png`. Pure Node: the PNGs written by
 * the capture step are decoded with `png.mjs` and re-encoded here with zlib, so
 * the review artifact needs no image library and no network.
 *
 *   node tools/asset-forge/gate/contact_sheet.mjs
 *
 * Output: tools/asset-forge/review/<category>.png and review/sheet.json
 * (row-major index of what is where, so a reviewer can name the cell they mean).
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { decodePng } from './png.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FORGE = path.resolve(HERE, '..');
const BUILD = path.join(FORGE, 'build');
const REVIEW = path.join(FORGE, 'review');
const RENDERS = path.join(BUILD, 'renders');

const CELL = Number(process.env.SHEET_CELL ?? 240);
const COLS = Number(process.env.SHEET_COLS ?? 6);
const PAD = 4;
const BG = [0x0b, 0x13, 0x1b]; // palette "panel", so the sheet is on-brand

const catalog = JSON.parse(fs.readFileSync(path.join(FORGE, 'catalog.json'), 'utf8'));

/** Nearest-neighbour downscale, so a review sheet never invents pixels. */
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

function newCanvas(w, h, rgb) {
  const data = Buffer.alloc(w * h * 3);
  for (let i = 0; i < w * h; i += 1) {
    data[i * 3] = rgb[0];
    data[i * 3 + 1] = rgb[1];
    data[i * 3 + 2] = rgb[2];
  }
  return { width: w, height: h, channels: 3, data };
}

function blit(dst, src, ox, oy) {
  for (let y = 0; y < src.height; y += 1) {
    const dy = oy + y;
    if (dy < 0 || dy >= dst.height) continue;
    for (let x = 0; x < src.width; x += 1) {
      const dx = ox + x;
      if (dx < 0 || dx >= dst.width) continue;
      const si = (y * src.width + x) * src.channels;
      const di = (dy * dst.width + dx) * 3;
      dst.data[di] = src.data[si];
      dst.data[di + 1] = src.data[si + 1];
      dst.data[di + 2] = src.data[si + 2];
    }
  }
}

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i += 1) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}

function encodePng(img) {
  const raw = Buffer.alloc((img.width * 3 + 1) * img.height);
  for (let y = 0; y < img.height; y += 1) {
    raw[y * (img.width * 3 + 1)] = 0;
    img.data.copy(raw, y * (img.width * 3 + 1) + 1, y * img.width * 3, (y + 1) * img.width * 3);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.width, 0);
  ihdr.writeUInt32BE(img.height, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Choose the most informative existing view for a cell: the three-quarter one. */
function viewFile(id) {
  const dir = path.join(RENDERS, id);
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir).filter((f) => f.startsWith('view-') && f.endsWith('.png')).sort();
  if (!files.length) return null;
  const preferred = files.find((f) => f.includes('-034-') || f.includes('-035-') || f.includes('-040-'));
  return path.join(dir, preferred ?? files[Math.floor(files.length / 2)]);
}

fs.mkdirSync(REVIEW, { recursive: true });
const sheets = [];
const cells = [];
const stale = [];

const categories = [...new Set(catalog.entries.map((e) => e.category))];
for (const category of categories) {
  const entries = catalog.entries.filter((e) => e.category === category);
  const rows = Math.ceil(entries.length / COLS);
  const w = COLS * (CELL + PAD) + PAD;
  const h = rows * (CELL + PAD) + PAD;
  const canvas = newCanvas(w, h, BG);
  entries.forEach((entry, i) => {
    const col = i % COLS;
    const row = Math.floor(i / COLS);
    const ox = PAD + col * (CELL + PAD);
    const oy = PAD + row * (CELL + PAD);
    // separator frame, one pixel, so cells stay countable on a dark sheet
    const frame = newCanvas(CELL, CELL, [0x27, 0x38, 0x4a]);
    blit(canvas, frame, ox, oy);
    const file = viewFile(entry.id);
    if (file) {
      // A sheet is only evidence if the pixels are newer than the code. Stale
      // renders once hid a skin change completely, so say so out loud.
      const srcFile = path.join(FORGE, 'src', entry.category, `${entry.id}.js`);
      if (fs.existsSync(srcFile) && fs.statSync(file).mtimeMs < fs.statSync(srcFile).mtimeMs) {
        stale.push(`${entry.id} (${path.basename(file)} older than ${path.basename(srcFile)})`);
      }
      const img = decodePng(fs.readFileSync(file));
      const small = downscale(img, CELL - 2);
      blit(canvas, small, ox + 1, oy + 1);
    }
    cells.push({ id: entry.id, category, col, row, x: ox, y: oy, size: CELL, render: file ? path.relative(FORGE, file) : null });
  });
  const out = path.join(REVIEW, `${category}.png`);
  fs.writeFileSync(out, encodePng(canvas));
  sheets.push({ category, file: path.relative(FORGE, out), entries: entries.length, grid: `${COLS}x${rows}`, cell: CELL });
  console.log(`${category.padEnd(8)} ${String(entries.length).padStart(2)} entries → ${path.relative(process.cwd(), out)}`);
}

fs.writeFileSync(path.join(REVIEW, 'sheet.json'), `${JSON.stringify({
  generated: new Date().toISOString(),
  cell: CELL,
  columns: COLS,
  note: 'Nearest-neighbour downscale of build/renders/<id>/view-034-*.png. Sheets are review aids: a sheet cannot prove a model is right, it is where a human looks.',
  sheets,
  cells,
}, null, 2)}\n`);
console.log(`wrote review/sheet.json`);
if (stale.length) {
  console.warn(`\n⚠ ${stale.length} stale render(s) — run run_gate.mjs before trusting this sheet:`);
  for (const m of stale) console.warn(`  · ${m}`);
} else {
  console.log('freshness: every cell is newer than its model source');
}
