#!/usr/bin/env node
/*
 * tools/gltf/pack_world_textures.mjs — externalize + dedupe Aetherfall world
 * textures into game/assets/world/aetherfall/textures/<sha256>.<ext>.
 *
 * The Blender builders export GLBs with embedded images. Godot imports each
 * embedded copy as a separate texture even when several modules share the same
 * map, which bloats the web payload. This step rewrites every image to a
 * content-addressed URI one level up (`../textures/<sha>.<ext>`) and deletes
 * buffer views that only images used — geometry, materials and animations are
 * untouched. Byte-identical maps collapse to a single file.
 *
 *   node tools/gltf/pack_world_textures.mjs            # rewrite in place
 *   node tools/gltf/pack_world_textures.mjs --check    # fail on stray embedded
 *
 * Prunes texture files that no GLB references any more.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import {
  externalizeSharedTextures,
  writeSharedTextures,
  sharedTextureSummary,
  parseGlb,
  writeGlb,
} from '../asset-forge/gate/shared_textures.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const WORLD = path.join(ROOT, 'game', 'assets', 'world', 'aetherfall');
const TEXTURES = path.join(WORLD, 'textures');
const CHECK_ONLY = process.argv.includes('--check');

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'textures' && entry.name !== 'source_textures') walk(full, out);
    } else if (entry.name.endsWith('.glb')) out.push(full);
  }
  return out;
}

const registry = new Map();
let changed = 0;
let embedded = 0;
const RECOMPRESS = process.argv.includes('--recompress');

const SLOT_RANK = { albedo: 1, normal: 2, orm: 3 };

function classifyImages(json) {
  const slotOf = new Map();
  const assign = (textureRef, kind) => {
    const tex = json.textures?.[textureRef];
    if (!Number.isInteger(tex?.source)) return;
    const prev = slotOf.get(tex.source);
    if (!prev || SLOT_RANK[kind] > SLOT_RANK[prev]) slotOf.set(tex.source, kind);
  };
  for (const mat of json.materials ?? []) {
    const pbr = mat.pbrMetallicRoughness ?? {};
    if (Number.isInteger(pbr.baseColorTexture?.index)) assign(pbr.baseColorTexture.index, 'albedo');
    if (Number.isInteger(mat.normalTexture?.index)) assign(mat.normalTexture.index, 'normal');
    if (Number.isInteger(pbr.metallicRoughnessTexture?.index)) {
      assign(pbr.metallicRoughnessTexture.index, 'orm');
    }
    if (Number.isInteger(mat.occlusionTexture?.index)) assign(mat.occlusionTexture.index, 'orm');
  }
  return slotOf;
}

function usesAlpha(json, imageIndex) {
  for (const mat of json.materials ?? []) {
    if ((mat.alphaMode ?? 'OPAQUE') === 'OPAQUE') continue;
    const refs = [
      mat.pbrMetallicRoughness?.baseColorTexture?.index,
      mat.normalTexture?.index,
      mat.pbrMetallicRoughness?.metallicRoughnessTexture?.index,
      mat.occlusionTexture?.index,
      mat.emissiveTexture?.index,
    ];
    for (const ref of refs) {
      const tex = json.textures?.[ref];
      if (tex?.source === imageIndex) return true;
    }
  }
  return false;
}

const encodeCache = new Map();
const pendingEncodes = new Map();

async function encodeJpeg(data, kind) {
  const source = sharp(data);
  const meta = await source.metadata();
  let pipeline = source;
  if ((meta.width ?? 0) > 512 || (meta.height ?? 0) > 512) {
    pipeline = pipeline.resize(512, 512, { fit: 'inside' });
  }
  const quality = kind === 'orm' ? 96 : kind === 'normal' ? 94 : 92;
  const encoded = await pipeline
    .jpeg({
      quality,
      chromaSubsampling: kind === 'albedo' ? '4:2:0' : '4:4:4',
      mozjpeg: true,
    })
    .toBuffer();
  return encoded;
}

// --recompress: migrate ALREADY-EXTERNAL PNG textures to the same JPEG budget
// profile and rewrite every referencing GLB's image URI/mimeType in place.
// One-shot migration for trees packed before the budget re-encode existed.
if (RECOMPRESS && !CHECK_ONLY) {
  const decision = new Map(); // old file name -> { kind, alpha }
  const glbImages = []; // { file, json, bin, images: [{old, image}] }
  for (const file of walk(WORLD).sort()) {
    const input = fs.readFileSync(file);
    const { json, bin } = parseGlb(input);
    const slotOf = classifyImages(json);
    const images = [];
    (json.images ?? []).forEach((image, imageIndex) => {
      if (!image.uri || Number.isInteger(image.bufferView)) return;
      const old = path.basename(image.uri);
      const kind = slotOf.get(imageIndex) ?? 'albedo';
      const alpha = usesAlpha(json, imageIndex);
      const prev = decision.get(old);
      decision.set(old, {
        kind: prev && SLOT_RANK[prev.kind] > SLOT_RANK[kind] ? prev.kind : kind,
        alpha: (prev ? prev.alpha : false) || alpha,
      });
      images.push({ old, image });
    });
    if (images.length) glbImages.push({ file, json, bin, images });
  }
  const rename = new Map(); // old -> { name, mimeType }
  for (const [old, { kind, alpha }] of decision) {
    const full = path.join(TEXTURES, old);
    if (!fs.existsSync(full)) {
      console.error(`FATAL: ${old} referenced but missing from textures/`);
      process.exit(1);
    }
    const data = fs.readFileSync(full);
    if (alpha) {
      rename.set(old, { name: old, mimeType: old.endsWith('.png') ? 'image/png' : 'image/jpeg' });
      continue;
    }
    const encoded = await encodeJpeg(data, kind);
    const name = `${crypto.createHash('sha256').update(encoded).digest('hex')}.jpg`;
    fs.writeFileSync(path.join(TEXTURES, name), encoded);
    rename.set(old, { name, mimeType: 'image/jpeg' });
    console.log(`recompressed ${old} -> ${name} (${kind}, ${(data.length / 1e6).toFixed(2)}MB -> ${(encoded.length / 1e6).toFixed(2)}MB)`);
  }
  for (const { file, json, bin, images } of glbImages) {
    let dirty = false;
    for (const { old, image } of images) {
      const to = rename.get(old);
      if (!to) continue;
      const target = `../textures/${to.name}`;
      if (image.uri !== target) {
        image.uri = target;
        image.mimeType = to.mimeType;
        dirty = true;
      }
    }
    if (dirty) fs.writeFileSync(file, writeGlb(json, bin));
  }
  // Drop old files no GLB references any more.
  const keep = new Set();
  for (const file of walk(WORLD)) {
    const input = fs.readFileSync(file);
    const json = JSON.parse(input.subarray(20, 20 + input.readUInt32LE(12)).toString('utf8'));
    for (const image of json.images ?? []) {
      if (image.uri) keep.add(path.basename(image.uri));
    }
  }
  for (const name of fs.readdirSync(TEXTURES)) {
    if (!keep.has(name)) fs.unlinkSync(path.join(TEXTURES, name));
  }
  console.log(`recompress done: ${rename.size} texture decision(s)`);
}

// --- payload budget re-encode -------------------------------------------------
// The web export enforces a 100,000,000-byte PCK (godot-ci.yml). Godot's
// imported .ctex size scales with SOURCE PIXEL COUNT (not source file bytes),
// so the profile caps every map at 512px and re-compresses to JPEG before
// externalizing: albedo q90 (4:2:0), normal maps q92 (4:4:4 -- chroma
// subsampling would smear tangent frames), metallic/roughness q95 4:4:4
// (low-frequency data). Images carrying used alpha stay PNG (JPEG has no
// alpha). Slot classification walks each GLB's materials; results are cached
// by source hash so shared maps encode once.
if (!CHECK_ONLY) {
  for (const file of walk(WORLD).sort()) {
    const input = fs.readFileSync(file);
    const json = JSON.parse(input.subarray(20, 20 + input.readUInt32LE(12)).toString('utf8'));
    const binStart = 20 + input.readUInt32LE(12) + 8; // JSON chunk + header
    if (!(json.images ?? []).some((image) => Number.isInteger(image.bufferView))) continue;
    const slotOf = classifyImages(json);
    for (const [imageIndex, image] of (json.images ?? []).entries()) {
      if (!Number.isInteger(image.bufferView)) continue;
      const view = json.bufferViews[image.bufferView];
      const start = view.byteOffset ?? 0;
      const data = Buffer.from(input.subarray(binStart + start, binStart + start + view.byteLength));
      const key = crypto.createHash('sha256').update(data).digest('hex');
      if (encodeCache.has(key) || pendingEncodes.has(key)) continue;
      const kind = slotOf.get(imageIndex) ?? 'albedo';
      if (usesAlpha(json, imageIndex)) {
        encodeCache.set(key, { data, mimeType: 'image/png' });
        continue;
      }
      pendingEncodes.set(
        key,
        encodeJpeg(data, kind).then((encoded) => {
          const result = { data: encoded, mimeType: 'image/jpeg' };
          encodeCache.set(key, result);
          return result;
        })
      );
    }
  }
  await Promise.all(pendingEncodes.values());
}

for (const file of walk(WORLD).sort()) {
  const rel = path.relative(WORLD, file);
  const input = fs.readFileSync(file);
  const json = JSON.parse(input.subarray(20, 20 + input.readUInt32LE(12)).toString('utf8'));
  const hasEmbedded = (json.images ?? []).some((image) => Number.isInteger(image.bufferView));
  if (!hasEmbedded) continue;
  embedded += 1;
  if (CHECK_ONLY) {
    console.error(`embedded images remain in ${rel}`);
    continue;
  }
  const transform = (data, mimeType) => {
    if (mimeType !== 'image/png') return { data, mimeType };
    const key = crypto.createHash('sha256').update(data).digest('hex');
    return encodeCache.get(key) ?? { data, mimeType };
  };
  const packed = externalizeSharedTextures(input, rel, registry, transform);
  fs.writeFileSync(file, Buffer.from(packed));
  changed += 1;
  console.log(`packed ${rel}`);
}

if (CHECK_ONLY && embedded) {
  console.error(`FAIL: ${embedded} GLB(s) still carry embedded images`);
  process.exit(1);
}

if (!CHECK_ONLY) {
  fs.mkdirSync(TEXTURES, { recursive: true });
  // writeSharedTextures prunes hash-named files that are not in the registry,
  // so every texture a GLB still references must be loaded into the registry
  // first — otherwise a partial repack deletes the modules' shared maps.
  for (const file of walk(WORLD)) {
    const input = fs.readFileSync(file);
    const json = JSON.parse(input.subarray(20, 20 + input.readUInt32LE(12)).toString('utf8'));
    for (const image of json.images ?? []) {
      if (!image.uri) continue;
      const name = path.basename(image.uri);
      if (registry.has(name)) continue;
      const full = path.join(TEXTURES, name);
      if (fs.existsSync(full)) {
        registry.set(name, {
          fileName: name,
          data: fs.readFileSync(full),
          worlds: new Set(['<existing>']),
          references: 1,
        });
      } else {
        console.error(`FATAL: ${path.relative(WORLD, file)} references missing texture ${name}`);
        process.exit(1);
      }
    }
  }
  writeSharedTextures(registry, TEXTURES);
  // Prune files no GLB references any more — belt and braces on top of
  // writeSharedTextures' own cleanup.
  const keep = new Set();
  for (const file of walk(WORLD)) {
    const input = fs.readFileSync(file);
    const json = JSON.parse(input.subarray(20, 20 + input.readUInt32LE(12)).toString('utf8'));
    for (const image of json.images ?? []) {
      if (image.uri) keep.add(path.basename(image.uri));
    }
  }
  let pruned = 0;
  for (const name of fs.readdirSync(TEXTURES)) {
    if (!keep.has(name)) {
      fs.unlinkSync(path.join(TEXTURES, name));
      pruned += 1;
    }
  }
  console.log(sharedTextureSummary(registry));
  console.log(`repacked ${changed} GLB(s); pruned ${pruned} stale texture file(s)`);
}
