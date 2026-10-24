#!/usr/bin/env node
/**
 * stage_world_into_game.mjs — put the assembled real world where Godot imports it.
 *
 * The forge no longer ships one GLB per prop; it ships one world. This copies
 * `build/world/world.glb` into `game/assets/forge/world/`, measures it from the
 * binary, and writes the manifest that `tools/asset-forge/godot/verify_import.gd`
 * reads back inside the engine. If Godot's importer disagrees with the numbers
 * written here, the verify job fails — that is the proof the world works in the
 * game and not only in a browser.
 *
 *   node tools/asset-forge/gate/stage_world_into_game.mjs [--dry-run]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { textureCompress } from '@gltf-transform/functions';
import sharp from 'sharp';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FORGE = path.resolve(HERE, '..');
const REPO = path.resolve(FORGE, '..', '..');
const SRC = path.join(FORGE, 'build', 'world', 'world.glb');
const REPORT = path.join(FORGE, 'build', 'world', 'world-report.json');
const GAME_DIR = path.join(REPO, 'game', 'assets', 'forge');
const DEST = path.join(GAME_DIR, 'world', 'world.glb');
const MANIFEST = path.join(GAME_DIR, 'forge_manifest.json');
const dryRun = process.argv.includes('--dry-run');

if (!fs.existsSync(SRC)) {
  console.error(`missing ${path.relative(REPO, SRC)} — run: node tools/asset-forge/gate/world_shot.mjs`);
  process.exit(1);
}
if (!fs.existsSync(REPORT)) {
  console.error(`missing ${path.relative(REPO, REPORT)} — run the world shot first`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(REPORT, 'utf8'));
const io = new NodeIO();
const doc = await io.read(SRC);

// The exporter writes every map as PNG; lossless 2K normals and albedo made a
// 61 MB file. Re-encode the photographic maps as high-quality JPEG (which is
// what they were photographed as) and keep the size in the range a repository
// can carry, without dropping a single texture.
await doc.transform(
  textureCompress({
    encoder: sharp,
    targetFormat: 'jpeg',
    quality: 92,
    resize: [2048, 2048],
  }),
);
const compressedBytes = await io.writeBinary(doc);

const root = doc.getRoot();

/* ------------------------------------------------------------- measure -- */

// The world's own bounds: every mesh primitive position accessor, unioned.
const min = [Infinity, Infinity, Infinity];
const max = [-Infinity, -Infinity, -Infinity];
let triangles = 0;
for (const mesh of root.listMeshes()) {
  for (const prim of mesh.listPrimitives()) {
    const pos = prim.getAttribute('POSITION');
    if (!pos) continue;
    triangles += (prim.getIndices()?.getCount() ?? pos.getCount()) / 3;
    const lo = pos.getMin([]);
    const hi = pos.getMax([]);
    for (let i = 0; i < 3; i += 1) {
      min[i] = Math.min(min[i], lo[i]);
      max[i] = Math.max(max[i], hi[i]);
    }
  }
}
const accessorSize = max.map((v, i) => +(v - min[i]).toFixed(3));
// Node transforms carry the scale (the Power Plant is authored in its own
// 245 m space and placed at 24 m), so the authoritative bounds come from the
// assembled scene in the browser, recorded in the report.
const size = report.world?.bounds?.size ?? accessorSize;
const clips = root.listAnimations().map((a) => a.getName()).filter(Boolean);
const sockets = (report.world?.meta?.spawns ?? []);
const bytes = compressedBytes.byteLength;

// Write the compact file next to the source, then stage that one.
const COMPACT = path.join(path.dirname(SRC), 'world.game.glb');
fs.writeFileSync(COMPACT, compressedBytes);

// Sockets are exported as empty nodes; Godot keeps them if the name survives.
const nodeNames = new Set(root.listNodes().map((n) => n.getName()).filter(Boolean));
const survivingSockets = sockets.filter((s) => nodeNames.has(s));

const entry = {
  id: 'neon_frontier_world',
  category: 'world',
  name: report.world?.meta?.name ?? 'NEON FRONTIER — Frontier Outpost',
  resource: 'res://assets/forge/world/world.glb',
  source: 'tools/asset-forge/src/worlds/neon_frontier.js',
  assetPolicy: 'every visible mesh is a licensed GLB from game/assets/world/real',
  targetHeight: size[1],
  targetLength: Math.max(size[0], size[2]),
  normalisedBy: 'height',
  measuredHeight: size[1],
  measuredWidth: size[0],
  measuredDepth: size[2],
  triangles: Math.round(triangles),
  meshes: root.listMeshes().length,
  materials: root.listMaterials().length,
  textures: root.listTextures().length,
  clips,
  sockets: survivingSockets,
  bytes,
};

const manifest = {
  generated: new Date().toISOString(),
  note: 'One assembled world, built from real licensed GLBs. Provenance: tools/asset-forge/real/real-manifest.json',
  attribution: {
    'Kenney Space Kit': 'CC0-1.0 — Kenney (www.kenney.nl)',
    'Cinder Yard / Power Plant + ground plate': 'CC-BY-4.0 — Kammertonus (https://twitter.com/Kammertonus)',
  },
  entries: [entry],
};

console.log(`world      ${size.join(' × ')} m · ${entry.triangles.toLocaleString('en-US')} tris · `
  + `${clips.length} clips · ${entry.meshes} meshes · ${(bytes / 1048576).toFixed(1)} MB`);
console.log(`sockets    ${survivingSockets.length}/${sockets.length} kept as named nodes`);
console.log(`meshes     ${root.listMeshes().length} after re-encode`);

if (dryRun) {
  console.log('dry run — nothing written');
  process.exit(0);
}

// The old procedural prop set no longer describes this world; drop it so Godot
// only imports what the build actually produced.
let removed = 0;
if (fs.existsSync(GAME_DIR)) {
  for (const dirent of fs.readdirSync(GAME_DIR, { withFileTypes: true })) {
    if (!dirent.isDirectory()) continue;
    for (const file of fs.readdirSync(path.join(GAME_DIR, dirent.name))) {
      if (!file.endsWith('.glb')) continue;
      if (dirent.name === 'world' && file === 'world.glb') continue;
      fs.rmSync(path.join(GAME_DIR, dirent.name, file));
      removed += 1;
    }
  }
}

fs.mkdirSync(path.dirname(DEST), { recursive: true });
fs.copyFileSync(COMPACT, DEST);
fs.writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 1)}\n`);

console.log(`staged     ${path.relative(REPO, DEST)}`);
console.log(`manifest   ${path.relative(REPO, MANIFEST)} (${removed} stale procedural GLB(s) removed)`);
