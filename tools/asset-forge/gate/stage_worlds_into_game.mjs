#!/usr/bin/env node
/**
 * stage_worlds_into_game.mjs — put every mission world where Godot imports it.
 *
 * The forge ships three worlds, each one self-contained GLB built from licensed
 * assets. This copies each `build/worlds/<id>/world.glb` into
 * `game/assets/forge/worlds/`, re-encodes its photographic maps (the exporter
 * writes PNG; quality-92 JPEG is what the maps were photographed as, and it keeps
 * the repository shipping size honest), and writes the manifest that
 * `tools/asset-forge/godot/verify_import.gd` reads back inside the engine.
 *
 *   node tools/asset-forge/gate/stage_worlds_into_game.mjs [--dry-run]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { textureCompress } from '@gltf-transform/functions';
import sharp from 'sharp';
import validator from 'gltf-validator';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FORGE = path.resolve(HERE, '..');
const REPO = path.resolve(FORGE, '..', '..');
const BUILD = path.join(FORGE, 'build', 'worlds');
const REPORT = path.join(BUILD, 'worlds-report.json');
const GAME_DIR = path.join(REPO, 'game', 'assets', 'forge');
const OUT_DIR = path.join(GAME_DIR, 'worlds');
const MANIFEST = path.join(GAME_DIR, 'forge_manifest.json');
const dryRun = process.argv.includes('--dry-run');

if (!fs.existsSync(REPORT)) {
  console.error(`missing ${path.relative(REPO, REPORT)} — run: node tools/asset-forge/gate/world_shot.mjs`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(REPORT, 'utf8'));
const io = new NodeIO();
const entries = [];

for (const [worldId, world] of Object.entries(report.worlds)) {
  const src = path.join(BUILD, worldId, 'world.glb');
  if (!fs.existsSync(src)) {
    console.error(`missing ${path.relative(REPO, src)} — rerun the gate for ${worldId}`);
    process.exitCode = 1;
    continue;
  }

  const doc = await io.read(src);
  await doc.transform(textureCompress({
    encoder: sharp,
    targetFormat: 'jpeg',
    quality: 92,
    resize: [2048, 2048],
  }));
  const binary = await io.writeBinary(doc);
  const root = doc.getRoot();

  // Khronos validation, on the exact bytes Godot will import. A GLB that only
  // three.js accepts is not a shipping asset, and a broken file caught here is
  // caught before it is 20 MB of repository.
  const validation = await validator.validateBytes(new Uint8Array(binary));
  if (validation.issues.numErrors > 0) {
    console.error(`${worldId}: ${validation.issues.numErrors} glTF error(s)`);
    for (const message of validation.issues.messages.filter((m) => m.severity === 0).slice(0, 5)) {
      console.error(`  ${message.pointer || ''} ${message.message}`);
    }
    process.exitCode = 1;
    continue;
  }

  const names = new Set(root.listNodes().map((n) => n.getName()).filter(Boolean));
  const sockets = (world.meta?.spawns ?? []).filter((s) => names.has(s));
  const clips = root.listAnimations().map((a) => a.getName()).filter(Boolean);
  const size = world.bounds?.size ?? [0, 0, 0];

  const entry = {
    id: worldId,
    category: 'world',
    name: world.meta?.name ?? worldId,
    mission: world.meta?.mission ?? '',
    resource: `res://assets/forge/worlds/${worldId}.glb`,
    source: 'tools/asset-forge/src/worlds/' + (
      worldId === 'frostline_relay' ? 'frostline.js'
        : worldId === 'verdant_bloom' ? 'verdant.js'
          : 'emberfall.js'
    ),
    assetPolicy: 'every visible mesh is a licensed GLB from game/assets/world/real',
    targetHeight: size[1],
    targetLength: Math.max(size[0], size[2]),
    normalisedBy: 'height',
    measuredHeight: size[1],
    measuredWidth: size[0],
    measuredDepth: size[2],
    triangles: world.stats?.triangles ?? 0,
    meshes: root.listMeshes().length,
    materials: root.listMaterials().length,
    textures: root.listTextures().length,
    clips,
    sockets,
    theme: world.meta?.theme ?? null,
    validation: {
      errors: validation.issues.numErrors,
      warnings: validation.issues.numWarnings,
      khronos: validation.validatorVersion,
    },
    bytes: binary.byteLength,
  };
  entries.push(entry);

  console.log(
    `${worldId.padEnd(16)} ${entry.name.padEnd(18)} ${size.map((v) => v.toFixed(1)).join(' × ')} m · `
    + `${entry.triangles.toLocaleString('en-US')} tris · ${clips.length} clips · `
    + `${(binary.byteLength / 1048576).toFixed(1)} MB · glTF `
    + `${entry.validation.errors}E/${entry.validation.warnings}W`,
  );

  if (!dryRun) {
    fs.mkdirSync(OUT_DIR, { recursive: true });
    fs.writeFileSync(path.join(OUT_DIR, `${worldId}.glb`), binary);
  }
}

if (dryRun) {
  console.log('dry run — nothing written');
  process.exit(process.exitCode ?? 0);
}

// Remove staged worlds that no longer exist in the build, so Godot never imports
// a world the current build did not produce.
for (const file of fs.readdirSync(OUT_DIR)) {
  if (!file.endsWith('.glb')) continue;
  const id = file.replace(/\.glb$/, '');
  if (entries.some((e) => e.id === id)) continue;
  fs.rmSync(path.join(OUT_DIR, file));
  console.log(`removed stale ${file}`);
}

const manifest = {
  generated: new Date().toISOString(),
  note: 'Three mission worlds, each built from real licensed GLBs. Provenance: tools/asset-forge/real/real-manifest.json',
  attribution: {
    'Kenney Space Kit': 'CC0-1.0 — Kenney (www.kenney.nl)',
    'Kenney Nature Kit': 'CC0-1.0 — Kenney (www.kenney.nl)',
    'Cinder Yard / Power Plant + set pieces + ground plate': 'CC-BY-4.0 — Kammertonus (https://twitter.com/Kammertonus)',
  },
  entries,
};
fs.writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 1)}\n`);
console.log(`\nmanifest → ${path.relative(REPO, MANIFEST)} (${entries.length} worlds)`);
