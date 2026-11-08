#!/usr/bin/env node
/*
 * tools/gltf/upgrade_closeup_textures.mjs — promote selected close-up PBR
 * maps to 1024 px for the Aetherfall world (Polish pass 3).
 *
 * The Blender builders generate 1024 px surface sets (pbr_lib, fixed seeds)
 * and the packer's 512 px budget profile downscales them before shipping.
 * This tool regenerates the chosen sets at their native 1024 px, encodes them
 * with the SAME JPEG profile as the packer (albedo q92 4:2:0, normal q94
 * 4:4:4, ORM q96 4:4:4, mozjpeg), writes new content-addressed files into
 * game/assets/world/aetherfall/textures/, and rewrites every GLB image URI
 * that referenced the old hash. In-place URI replacement is byte-length safe
 * (sha256 hex -> sha256 hex); GLB geometry/materials/anim are untouched.
 *
 * Old files are pruned by the regular `node tools/gltf/pack_world_textures.mjs`
 * pass afterwards (registry rebuild + stale-file prune).
 *
 *   node tools/gltf/upgrade_closeup_textures.mjs
 *
 * Old hashes are discovered from the GLBs themselves (the representative
 * material per surface kind, e.g. IceVein -> ice_rock), never hardcoded.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { parseGlb, writeGlb } from '../asset-forge/gate/shared_textures.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const WORLD = path.join(ROOT, 'game', 'assets', 'world', 'aetherfall');
const TEXTURES = path.join(WORLD, 'textures');

// Slots promoted per surface kind. Budget: ~+4.7 MB of .ctex headroom in the
// 100,000,000-byte PCK budget, leaving the rest for Gate E bake maps (P4).
// Selection is visual-impact-first: the ground the player stands on
// (ice_rock), the structure metal at arm's length (metal), the interactable
// panel faces (composite), the geology the route cuts through (rock), and the
// gate/spire paint (deck). Normal/ORM stay 512 px where the extra pixels do
// not change the read at distance.
const PROMOTE = {
  ice_rock: ['albedo', 'normal', 'orm'],
  metal: ['albedo', 'normal', 'orm'],
  composite: ['albedo'],
  rock: ['albedo', 'normal'],
  deck: ['albedo'],
};

// Per-slot encode caps. Polish pass 4 budget trade: the metal ORM map is
// low-frequency roughness data (the packer's own profile treats ORM as such),
// and at 1024 px its .ctex cost ~2 MB of the 100 MB PCK budget. The Gate E
// bake composites need that room more, so this one map encodes at 512 px
// while the promoted albedo/normal detail maps keep 1024 px.
const CAP_OVERRIDES = { 'metal/orm': 512 };

// Representative material name per kind (enrich_aetherfall.MAT_SURFACE), used
// to discover each kind's current map hashes from the GLB material slots.
const KIND_MATERIAL = {
  metal: 'Steel',
  composite: 'Composite',
  ice_rock: 'IceVein',
  rock: 'Rock',
  deck: 'PaintedSteel',
};

// Same encode profile as pack_world_textures.mjs encodeJpeg.
const SLOT_ENCODE = {
  albedo: { quality: 92, chromaSubsampling: '4:2:0' },
  normal: { quality: 94, chromaSubsampling: '4:4:4' },
  orm: { quality: 96, chromaSubsampling: '4:4:4' },
};
const SLOT_FILE = { albedo: '.png', normal: '_normal.png', orm: '_orm.png' };

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'textures' && entry.name !== 'source_textures') walk(full, out);
    } else if (entry.name.endsWith('.glb')) out.push(full);
  }
  return out;
}

function materialSlotUris(json) {
  const imgs = json.images ?? [];
  const texs = json.textures ?? [];
  const uriOf = (t) => {
    if (!t || t.get === undefined && t.index === undefined) return null;
    const ti = t.index;
    if (!Number.isInteger(ti) || ti >= texs.length) return null;
    const src = texs[ti].source;
    if (!Number.isInteger(src) || src >= imgs.length) return null;
    const uri = imgs[src].uri;
    return typeof uri === 'string' ? path.basename(uri) : null;
  };
  return (mat) => ({
    albedo: uriOf(mat?.pbrMetallicRoughness?.baseColorTexture),
    orm: uriOf(mat?.pbrMetallicRoughness?.metallicRoughnessTexture),
    normal: uriOf(mat?.normalTexture),
  });
}

// --- 1. discover current (kind, slot) -> hash from the GLBs -----------------
// Majority vote across every GLB that carries the representative material:
// a shared map is referenced by many assets, while a per-asset bake composite
// (Gate E) can shadow it if we trust the first GLB seen. The common URI wins.
const files = walk(WORLD).sort();
const votes = {}; // kind -> slot -> Map(basename -> count)
for (const file of files) {
  const { json } = parseGlb(fs.readFileSync(file));
  const slotsOf = materialSlotUris(json);
  for (const mat of json.materials ?? []) {
    for (const [kind, name] of Object.entries(KIND_MATERIAL)) {
      if (mat.name !== name) continue;
      votes[kind] ??= { albedo: new Map(), orm: new Map(), normal: new Map() };
      for (const [slot, uri] of Object.entries(slotsOf(mat))) {
        if (!uri) continue;
        const tally = votes[kind][slot];
        tally.set(uri, (tally.get(uri) ?? 0) + 1);
      }
    }
  }
}
const kindSlots = {}; // kind -> { slot -> old basename }
for (const [kind, slots] of Object.entries(votes)) {
  kindSlots[kind] = {};
  for (const [slot, tally] of Object.entries(slots)) {
    kindSlots[kind][slot] = [...tally.entries()].sort((a, b) => b[1] - a[1])[0][0];
  }
}
for (const kind of Object.keys(PROMOTE)) {
  const slots = kindSlots[kind];
  if (!slots) {
    console.error(`FATAL: representative material for ${kind} not found in any GLB`);
    process.exit(1);
  }
  for (const slot of PROMOTE[kind]) {
    const old = slots[slot];
    if (!old || !fs.existsSync(path.join(TEXTURES, old))) {
      console.error(`FATAL: ${kind}/${slot} -> ${old ?? '(none)'} missing from textures/`);
      process.exit(1);
    }
  }
}

// --- 2. regenerate the sets at 1024 px and encode with the packer profile ---
const python = fs.existsSync(path.join(ROOT, '.venv', 'bin', 'python'))
  ? path.join(ROOT, '.venv', 'bin', 'python')
  : 'python3';
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'closeup-1024-'));
const rename = new Map(); // old basename -> new basename
let wroteBytes = 0;
let freedBytes = 0;
for (const [kind, slots] of Object.entries(PROMOTE)) {
  const outDir = path.join(tmp, kind);
  execFileSync(python, [path.join(ROOT, 'tools', 'blender', 'gen_surface_set.py'), kind, outDir], {
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  for (const slot of slots) {
    const png = path.join(outDir, `aetherfall_${kind}${SLOT_FILE[slot]}`);
    const data = fs.readFileSync(png);
    const cap = CAP_OVERRIDES[`${kind}/${slot}`] ?? 1024;
    let pipeline = sharp(data);
    const meta = await pipeline.metadata();
    if ((meta.width ?? 0) > cap || (meta.height ?? 0) > cap) {
      pipeline = pipeline.resize(cap, cap, { fit: 'inside' });
    }
    const encoded = await pipeline
      .jpeg({ ...SLOT_ENCODE[slot], mozjpeg: true })
      .toBuffer();
    const name = `${crypto.createHash('sha256').update(encoded).digest('hex')}.jpg`;
    fs.writeFileSync(path.join(TEXTURES, name), encoded);
    const old = kindSlots[kind][slot];
    rename.set(old, name);
    wroteBytes += encoded.length;
    freedBytes += fs.statSync(path.join(TEXTURES, old)).size;
    console.log(`promoted ${kind}/${slot}: ${old.slice(0, 8)} -> ${name.slice(0, 8)} (${(encoded.length / 1024).toFixed(0)} KB)`);
  }
}

// --- 3. rewrite every GLB URI that referenced a promoted hash ---------------
let rewritten = 0;
for (const file of files) {
  const input = fs.readFileSync(file);
  const { json, bin } = parseGlb(input);
  let dirty = false;
  for (const image of json.images ?? []) {
    if (typeof image.uri !== 'string') continue;
    const next = rename.get(path.basename(image.uri));
    if (next && next !== path.basename(image.uri)) {
      image.uri = `../textures/${next}`;
      dirty = true;
    }
  }
  if (dirty) {
    fs.writeFileSync(file, Buffer.from(writeGlb(json, bin)));
    rewritten += 1;
  }
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(
  `promote done: ${rename.size} map(s), ${rewritten} GLB(s) rewritten; ` +
    `jpg bytes +${wroteBytes} / -${freedBytes} (prune of old files is done by pack_world_textures.mjs)`
);
