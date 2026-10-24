/**
 * png.mjs — minimal PNG reader (8-bit, non-interlaced) with no dependencies.
 *
 * The gate has to measure the renders it just took: coverage, silhouette
 * distinctness, luma spread. Puppeteer writes 8-bit RGBA PNGs, so the only
 * formats that matter are colour types 2 (RGB) and 6 (RGBA) at bit depth 8.
 * Anything else throws instead of guessing — a silent fallback would let the
 * quality number be computed from the wrong pixels.
 */
import zlib from 'node:zlib';

export function decodePng(buffer) {
  if (buffer.readUInt32BE(0) !== 0x89504e47) throw new Error('not a PNG');
  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colourType = 0;
  let interlace = 0;
  const idat = [];
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colourType = data[9];
      interlace = data[12];
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') {
      break;
    }
    offset += 12 + length;
  }
  if (bitDepth !== 8) throw new Error(`unsupported PNG bit depth ${bitDepth}`);
  if (interlace !== 0) throw new Error('interlaced PNG unsupported');
  const channels = colourType === 6 ? 4 : colourType === 2 ? 3 : 0;
  if (!channels) throw new Error(`unsupported PNG colour type ${colourType}`);

  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  const out = Buffer.alloc(width * height * channels);
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const cur = Buffer.from(line);
    for (let x = 0; x < stride; x += 1) {
      const a = x >= channels ? cur[x - channels] : 0;
      const b = prev[x];
      const c = x >= channels ? prev[x - channels] : 0;
      switch (filter) {
        case 0: break;
        case 1: cur[x] = (cur[x] + a) & 0xff; break;
        case 2: cur[x] = (cur[x] + b) & 0xff; break;
        case 3: cur[x] = (cur[x] + ((a + b) >> 1)) & 0xff; break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a);
          const pb = Math.abs(p - b);
          const pc = Math.abs(p - c);
          const pr = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
          cur[x] = (cur[x] + pr) & 0xff;
          break;
        }
        default: throw new Error(`bad PNG filter ${filter}`);
      }
    }
    cur.copy(out, y * stride);
    prev = cur;
  }
  return { width, height, channels, data: out };
}

export function pixel(img, x, y) {
  const i = (y * img.width + x) * img.channels;
  return [img.data[i], img.data[i + 1], img.data[i + 2], img.channels === 4 ? img.data[i + 3] : 255];
}

/** Relative luminance, 0..1, sRGB. */
export function luma(r, g, b) {
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
}

/**
 * Measure a render against the flat navy backdrop.
 * Returns coverage (fraction of pixels that are not backdrop), luma stats and a
 * coarse 16×16 occupancy grid used to compare two views.
 */
export function analyse(img, backdropRgb, tolerance = 10) {
  const [br, bg, bb] = backdropRgb;
  const grid = new Float64Array(16 * 16);
  let covered = 0;
  let sum = 0;
  let sumSq = 0;
  let minL = 1;
  let maxL = 0;
  const hist = new Array(32).fill(0);
  for (let y = 0; y < img.height; y += 1) {
    for (let x = 0; x < img.width; x += 1) {
      const [r, g, b] = pixel(img, x, y);
      const isBackdrop = Math.abs(r - br) <= tolerance && Math.abs(g - bg) <= tolerance && Math.abs(b - bb) <= tolerance;
      if (isBackdrop) continue;
      covered += 1;
      const L = luma(r, g, b);
      sum += L;
      sumSq += L * L;
      if (L < minL) minL = L;
      if (L > maxL) maxL = L;
      hist[Math.min(31, Math.floor(L * 32))] += 1;
      const gx = Math.min(15, Math.floor((x / img.width) * 16));
      const gy = Math.min(15, Math.floor((y / img.height) * 16));
      grid[gy * 16 + gx] += 1;
    }
  }
  const total = img.width * img.height;
  const coverage = covered / total;
  const mean = covered ? sum / covered : 0;
  const variance = covered ? Math.max(0, sumSq / covered - mean * mean) : 0;
  // fraction of grid cells that contain any coverage — a thin diagonal prop
  // should not fill the frame, but an empty corner should not read as a model
  const occupiedCells = [...grid].filter((v) => v > 0).length / grid.length;
  const norm = [...grid].map((v) => (covered ? v / covered : 0));
  return {
    coverage,
    meanLuma: mean,
    stdLuma: Math.sqrt(variance),
    minLuma: covered ? minL : null,
    maxLuma: covered ? maxL : null,
    lumaSpread: covered ? maxL - minL : 0,
    occupiedCells,
    histogram: hist,
    grid: norm,
  };
}

/** 1 - cosine similarity of two occupancy grids: 0 identical, 1 nothing shared. */
export function gridDistance(a, b) {
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (!na || !nb) return 1;
  return 1 - dot / (Math.sqrt(na) * Math.sqrt(nb));
}
