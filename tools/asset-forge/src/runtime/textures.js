/**
 * textures.js — procedural PBR maps, generated once and shared by every model.
 *
 * The forge is pure code, so the surfaces are too: no downloaded texture packs.
 * Each material gets a base-colour map, a tangent-space normal map and an
 * occlusion/roughness/metalness (ORM) map, all baked from the same height field
 * so the plating, bolts and wear line up across all three channels.
 *
 * Resolution is 2048 by default and 4096 on request (`?tex=4096` in the gallery,
 * `--tex 4096` in the gate). Textures are generated once per page and cached:
 * sixteen models share one set, so the export carries one copy of each image
 * instead of one copy per material.
 *
 * Rules kept from the palette contract:
 *  · the base-colour map is *grey*; colour comes from the material's tint, which
 *    is always a palette token, so `materials-on-palette` still means something;
 *  · nothing here invents a hue — wear is a lighter neutral, grime is the same
 *    neutral, darker.
 */
import * as THREE from 'three';

const DEFAULT_SIZE = 2048;

let SIZE = DEFAULT_SIZE;
let cache = null;
/** Tiled views of the shared maps, one per distinct repeat value. */
let repeatCache = new Map();

/** Resolution chosen by the caller (`?tex=` in the gallery, `--tex` in the gate). */
export function setTextureSize(px) {
  const n = Number(px);
  SIZE = Number.isFinite(n) && n >= 512 ? Math.min(4096, Math.round(n)) : DEFAULT_SIZE;
  cache = null;
  repeatCache = new Map();
}

export function textureSize() {
  return SIZE;
}

/* ------------------------------------------------------------------ noise -- */

/** Deterministic 2D hash in [0,1) — the whole pipeline stays reproducible. */
function hash2(x, y) {
  let h = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) >>> 0) / 4294967296;
}

function smooth(t) {
  return t * t * (3 - 2 * t);
}

/** Value noise on a wrapping lattice, so the texture tiles seamlessly. */
function valueNoise(x, y, period, seed) {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const xf = smooth(x - xi);
  const yf = smooth(y - yi);
  const wrap = (v) => ((v % period) + period) % period;
  const a = hash2(wrap(xi) + seed, wrap(yi));
  const b = hash2(wrap(xi + 1) + seed, wrap(yi));
  const c = hash2(wrap(xi) + seed, wrap(yi + 1));
  const d = hash2(wrap(xi + 1) + seed, wrap(yi + 1));
  const top = a + (b - a) * xf;
  const bottom = c + (d - c) * xf;
  return top + (bottom - top) * yf;
}

/** Fractal value noise, 4 octaves, tileable at `period` cells. */
function fbm(u, v, period, seed) {
  let sum = 0;
  let amp = 0.5;
  let freq = period;
  for (let o = 0; o < 4; o += 1) {
    sum += valueNoise(u * freq, v * freq, freq, seed + o * 17) * amp;
    amp *= 0.5;
    freq *= 2;
  }
  return sum;
}

/* --------------------------------------------------------------- surfaces -- */

/**
 * Height field: armour plate with recessed seams, a bolt per plate corner and
 * fine pitting. Everything else (colour, normal, roughness) is derived from it,
 * which is why the seams read as grooves in all three maps at once.
 */
function heightAt(u, v, platePx) {
  const x = u * SIZE;
  const y = v * SIZE;
  // plate grid: recessed seam every `platePx` pixels
  const gx = ((x % platePx) + platePx) % platePx;
  const gy = ((y % platePx) + platePx) % platePx;
  const seamW = Math.max(3, platePx * 0.012);
  const seam = (d) => (d < seamW ? 1 - d / seamW : d > platePx - seamW ? 1 - (platePx - d) / seamW : 0);
  const groove = Math.max(seam(gx), seam(gy)) * 0.55;

  // bolt heads at the plate corners
  const bx = gx - platePx * 0.09;
  const by = gy - platePx * 0.09;
  const bolt = Math.exp(-((bx * bx + by * by) / (2 * (platePx * 0.018) ** 2))) * 0.5;

  // broad panel bulge + pitting + a few long scratches
  const bulge = (fbm(u, v, 8, 3) - 0.5) * 0.12;
  const pits = (fbm(u, v, 96, 11) - 0.5) * 0.06;
  const scratch = Math.max(0, fbm(u * 3.1, v * 0.35, 22, 29) - 0.72) * 0.5;

  return 0.5 + bulge + pits + bolt - groove - scratch;
}

let HEIGHT = null;
let HEIGHT_W = 0;

function buildHeight() {
  // One lower-resolution height field is enough: the normal map is the only
  // consumer that needs per-pixel detail, and everything else is low frequency.
  HEIGHT_W = SIZE;
  HEIGHT = new Float32Array(SIZE * SIZE);
  const platePx = SIZE / 6; // six plates across the tile
  for (let y = 0; y < SIZE; y += 1) {
    const v = y / SIZE;
    for (let x = 0; x < SIZE; x += 1) {
      HEIGHT[y * SIZE + x] = heightAt(x / SIZE, v, platePx);
    }
  }
}

function heightPx(x, y) {
  const xi = ((x % SIZE) + SIZE) % SIZE;
  const yi = ((y % SIZE) + SIZE) % SIZE;
  return HEIGHT[yi * SIZE + xi];
}

/* ----------------------------------------------------------------- images -- */

function makeCanvas(size) {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  return canvas;
}

function finish(canvas, { srgb = false, repeat = 1, mime = 'image/png' } = {}) {
  const tex = new THREE.CanvasTexture(canvas);
  // GLTFExporter reads `userData.mimeType`; photographic colour/ORM data packs
  // into a 2K JPEG at a tenth of the PNG size, while the tangent normal keeps
  // PNG (JPEG ringing on a vector map is a visible shading bug).
  tex.userData.mimeType = mime;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(repeat, repeat);
  tex.anisotropy = 8;
  tex.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  tex.needsUpdate = true;
  return tex;
}

function baseColorCanvas() {
  const canvas = makeCanvas(SIZE);
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(SIZE, SIZE);
  const d = img.data;
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const i = (y * SIZE + x) * 4;
      const h = HEIGHT[y * SIZE + x];
      const u = x / SIZE;
      const v = y / SIZE;
      // base neutral, grooves darker, wear highlights brighter
      let shade = 0.46 + (h - 0.5) * 0.55;
      const grime = Math.max(0, fbm(u, v, 5, 61) - 0.55) * 0.5;
      shade -= grime * 0.35;
      // vertical streaks of weathering, as if water ran down the plate
      const streak = Math.max(0, fbm(u * 24, v * 0.6, 16, 77) - 0.66) * 0.3;
      shade -= streak * 0.25;
      shade = Math.min(1, Math.max(0.05, shade));
      const c = Math.round(shade * 255);
      d[i] = c;
      d[i + 1] = c;
      d[i + 2] = Math.round(c * 0.99);
      d[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

function normalCanvas(strength = 2.4) {
  const canvas = makeCanvas(SIZE);
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(SIZE, SIZE);
  const d = img.data;
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const dx = (heightPx(x + 1, y) - heightPx(x - 1, y)) * strength;
      const dy = (heightPx(x, y + 1) - heightPx(x, y - 1)) * strength;
      // tangent-space normal, +Y up in the image
      let nx = -dx;
      let ny = dy;
      let nz = 1;
      const len = Math.hypot(nx, ny, nz);
      nx /= len; ny /= len; nz /= len;
      const i = (y * SIZE + x) * 4;
      d[i] = Math.round((nx * 0.5 + 0.5) * 255);
      d[i + 1] = Math.round((ny * 0.5 + 0.5) * 255);
      d[i + 2] = Math.round((nz * 0.5 + 0.5) * 255);
      d[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

function ormCanvas() {
  const canvas = makeCanvas(SIZE);
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(SIZE, SIZE);
  const d = img.data;
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const i = (y * SIZE + x) * 4;
      const h = HEIGHT[y * SIZE + x];
      const u = x / SIZE;
      const v = y / SIZE;
      // R = ambient occlusion (deep seams darker), G = roughness, B = metalness
      const ao = Math.round(Math.min(1, Math.max(0.45, 0.55 + h * 0.55)) * 255);
      const rough = Math.min(1, Math.max(0.18, 0.62 - (h - 0.5) * 1.1 + fbm(u, v, 12, 43) * 0.18));
      const metal = Math.min(1, Math.max(0.55, 0.88 + (fbm(u, v, 6, 91) - 0.5) * 0.2));
      d[i] = ao;
      d[i + 1] = Math.round(rough * 255);
      d[i + 2] = Math.round(metal * 255);
      d[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

/** Emissive detail: a fine energy grain, so glow panels are not flat colour. */
function emissiveCanvas() {
  const canvas = makeCanvas(Math.min(SIZE, 1024));
  const size = canvas.width;
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(size, size);
  const d = img.data;
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const i = (y * size + x) * 4;
      const u = x / size;
      const v = y / size;
      const n = fbm(u, v, 10, 5) * 0.6 + 0.55;
      const scan = 0.86 + 0.14 * Math.sin(v * Math.PI * 128);
      const c = Math.round(Math.min(1, n * scan) * 255);
      d[i] = c; d[i + 1] = c; d[i + 2] = c; d[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

/* ------------------------------------------------------------------- API --- */

/**
 * The shared texture set. Built on first use and reused by every material, so a
 * GLB carries three 2K images (plus the small emissive grain) rather than one
 * set per material.
 */
export function pbrTextures() {
  if (cache) return cache;
  buildHeight();
  cache = {
    size: SIZE,
    base: finish(baseColorCanvas(), { srgb: true, mime: 'image/jpeg' }),
    normal: finish(normalCanvas(), { mime: 'image/png' }),
    orm: finish(ormCanvas(), { mime: 'image/jpeg' }),
    emissive: finish(emissiveCanvas(), { srgb: true, mime: 'image/jpeg' }),
  };
  return cache;
}

/**
 * A tiled view of a shared map.
 *
 * `repeat` is a sampler property, not a material property, and the maps are
 * shared by every material in the forge. Rather than give each material its own
 * copy of the pixels, this reuses the same image with a different wrap count —
 * so a 30 m road can tile 14× while a 1 m cover plate still tiles once, and the
 * export still carries exactly four images.
 */
function tiled(tex, repeat) {
  if (!(repeat > 1)) return tex;
  const k = `${tex.uuid}|${repeat}`;
  if (!repeatCache.has(k)) {
    const clone = tex.clone();
    clone.repeat.set(repeat, repeat);
    clone.userData.mimeType = tex.userData.mimeType;
    clone.needsUpdate = true;
    repeatCache.set(k, clone);
  }
  return repeatCache.get(k);
}

/** Attach the shared maps to a material (idempotent). */
export function applyPbr(material, { repeat = 1, emissiveMap = false } = {}) {
  const t = pbrTextures();
  if (material.map) return material;
  material.map = tiled(t.base, repeat);
  material.normalMap = tiled(t.normal, repeat);
  material.roughnessMap = tiled(t.orm, repeat);
  material.metalnessMap = tiled(t.orm, repeat);
  if (emissiveMap) material.emissiveMap = tiled(t.emissive, repeat);
  material.needsUpdate = true;
  return material;
}

/** Report for the gate: what was generated, at what size, and how big it is. */
export function textureReport() {
  const t = pbrTextures();
  const sizeOf = (tex) => {
    const img = tex.image;
    return { width: img.width, height: img.height };
  };
  return {
    size: SIZE,
    maps: {
      base: sizeOf(t.base),
      normal: sizeOf(t.normal),
      orm: sizeOf(t.orm),
      emissive: sizeOf(t.emissive),
    },
  };
}
