/**
 * compare_sheet.mjs — reference image next to the built render, one row per
 * asset, so "does it match the reference?" is answered by a picture rather than
 * by memory.
 *
 *   node tools/asset-forge/gate/compare_sheet.mjs
 *   node tools/asset-forge/gate/compare_sheet.mjs --only runner,cover_module
 *
 * Output: review/compare/<category>.png  (REF | RENDER pairs, labelled by index)
 *         review/compare.json            (index → id, plus a missing/extra list)
 *
 * Assets whose reference does not exist yet are listed in compare.json as
 * `no_reference` and simply skipped — the sheet never invents a comparison.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { decodePng } from './png.mjs';

const FORGE = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const REVIEW = path.join(FORGE, 'review');
const COMPARE = path.join(REVIEW, 'compare');
const RENDERS = path.join(FORGE, 'build', 'renders');

const onlyArg = process.argv.indexOf('--only');
const only = onlyArg !== -1 ? new Set(process.argv[onlyArg + 1].split(',')) : null;

const catalog = JSON.parse(fs.readFileSync(path.join(FORGE, 'catalog.json'), 'utf8'));

/** Nearest-neighbour resize to an exact box — never invents pixels. */
function resize(img, w, h) {
  const out = { width: w, height: h, channels: 3, data: Buffer.alloc(w * h * 3) };
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      const sx = Math.min(img.width - 1, Math.floor((x / w) * img.width));
      const sy = Math.min(img.height - 1, Math.floor((y / h) * img.height));
      const si = (sy * img.width + sx) * img.channels;
      const di = (y * w + x) * 3;
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
    data[i * 3] = rgb[0]; data[i * 3 + 1] = rgb[1]; data[i * 3 + 2] = rgb[2];
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
  const stride = img.width * 3;
  const raw = Buffer.alloc((stride + 1) * img.height);
  for (let y = 0; y < img.height; y += 1) {
    raw[y * (stride + 1)] = 0;
    img.data.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.width, 0);
  ihdr.writeUInt32BE(img.height, 4);
  ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Letterbox an image into a fixed cell so both halves share one scale. */
function fitInto(img, w, h) {
  const scale = Math.min(w / img.width, h / img.height);
  const tw = Math.max(1, Math.round(img.width * scale));
  const th = Math.max(1, Math.round(img.height * scale));
  const cell = newCanvas(w, h, [0x05, 0x08, 0x0c]);
  blit(cell, resize(img, tw, th), Math.floor((w - tw) / 2), Math.floor((h - th) / 2));
  return cell;
}

const PAIR_W = 300;   // each half
const PAIR_H = 300;
const GAP = 8;

/** First `references/<dir>/<id>.png` that exists. */
function findReference(id) {
  const root = path.join(FORGE, 'references');
  for (const dir of fs.readdirSync(root)) {
    const candidate = path.join(root, dir, `${id}.png`);
    if (fs.existsSync(candidate)) return candidate;
  }
  return path.join(root, 'missing', `${id}.png`);
}

/** Highest-detail render available for an id (prefers a 3/4 view). */
function renderFile(id) {
  const dir = path.join(RENDERS, id);
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir).filter((f) => f.startsWith('view-') && f.endsWith('.png')).sort();
  if (!files.length) return null;
  const threeQuarter = files.find((f) => f.includes('-034-') || f.includes('-060-') || f.includes('-040-'));
  return path.join(dir, threeQuarter ?? files[0]);
}

fs.mkdirSync(COMPARE, { recursive: true });
const byCategory = new Map();
const report = { generated: new Date().toISOString(), pairs: [], no_reference: [], no_render: [] };

for (const entry of catalog.entries) {
  if (only && !only.has(entry.id)) continue;
  // catalog.json carries no reference path, and the directories are not always
  // the category name (`enemy` → references/enemies/), so look for the id in any
  // reference directory rather than assuming the mapping.
  const ref = findReference(entry.id);
  const render = renderFile(entry.id);
  if (!fs.existsSync(ref)) { report.no_reference.push(entry.id); continue; }
  const refDir = path.basename(path.dirname(ref));
  if (!render) { report.no_render.push(entry.id); continue; }
  if (!byCategory.has(entry.category)) byCategory.set(entry.category, []);
  byCategory.get(entry.category).push({ id: entry.id, name: entry.name, ref, render });
}

for (const [category, pairs] of byCategory) {
  const rows = pairs.length;
  const canvas = newCanvas(PAIR_W * 2 + GAP * 3, rows * (PAIR_H + GAP) + GAP, [0x05, 0x08, 0x0c]);
  pairs.forEach((pair, i) => {
    const y = GAP + i * (PAIR_H + GAP);
    // reference on the left, render on the right, one pixel frame between
    for (const [x, file] of [[GAP, pair.ref], [GAP * 2 + PAIR_W, pair.render]]) {
      const img = decodePng(fs.readFileSync(file));
      const box = fitInto(img, PAIR_W, PAIR_H);
      blit(canvas, box, x, y);
    }
    report.pairs.push({ id: pair.id, row: i, category, reference: path.relative(FORGE, pair.ref), render: path.relative(FORGE, pair.render) });
    console.log(`  ${String(report.pairs.length).padStart(2)}. ${pair.id}`);
  });
  const out = path.join(COMPARE, `${category}.png`);
  fs.writeFileSync(out, encodePng(canvas));
  console.log(`${category.padEnd(8)} ${pairs.length} pair(s) → ${path.relative(process.cwd(), out)}`);
}


fs.writeFileSync(path.join(REVIEW, 'compare.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(`\n${report.pairs.length} comparable asset(s) · ${report.no_reference.length} without a reference · ${report.no_render.length} without a render`);
if (report.no_reference.length) console.log(`  no reference yet: ${report.no_reference.join(', ')}`);
