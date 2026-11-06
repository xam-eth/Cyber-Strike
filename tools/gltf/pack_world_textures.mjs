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
import {
  externalizeSharedTextures,
  writeSharedTextures,
  sharedTextureSummary,
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
  const packed = externalizeSharedTextures(input, rel, registry);
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
