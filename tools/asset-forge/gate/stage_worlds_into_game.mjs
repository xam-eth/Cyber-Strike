#!/usr/bin/env node
/**
 * stage_worlds_into_game.mjs — put every mission world where Godot imports it.
 *
 * The forge ships mission GLBs built from licensed assets. This copies
 * each `build/worlds/<id>/world.glb` into `game/assets/forge/worlds/`, re-encodes
 * its photographic maps (quality-92 JPEG), then moves byte-identical maps to
 * content-addressed shared textures so Godot imports one resource per distinct
 * image rather than one per embedded copy. It also writes the manifest that
 * `tools/asset-forge/godot/verify_import.gd` reads back inside the engine.
 *
 *   node tools/asset-forge/gate/stage_worlds_into_game.mjs [--dry-run]
 *   node tools/asset-forge/gate/stage_worlds_into_game.mjs --add-world titans
 *
 * `--add-world` preserves every already-staged GLB and texture byte. It is for
 * adding a new theatre, not replacing an existing one; use a full rebuild for
 * the latter so no stale texture references can survive.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { textureCompress } from '@gltf-transform/functions';
import sharp from 'sharp';
import validator from 'gltf-validator';
import {
  externalizeSharedTextures,
  sharedTextureResourceLoader,
  sharedTextureSummary,
  writeSharedTextures,
} from './shared_textures.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FORGE = path.resolve(HERE, '..');
const REPO = path.resolve(FORGE, '..', '..');
const BUILD = path.join(FORGE, 'build', 'worlds');
const REPORT = path.join(BUILD, 'worlds-report.json');
const GAME_DIR = path.join(REPO, 'game', 'assets', 'forge');
const OUT_DIR = path.join(GAME_DIR, 'worlds');
const TEXTURE_DIR = path.join(GAME_DIR, 'textures');
const MANIFEST = path.join(GAME_DIR, 'forge_manifest.json');
const dryRun = process.argv.includes('--dry-run');
const addWorldFlag = process.argv.indexOf('--add-world');
const addWorldIds = addWorldFlag === -1
  ? []
  : String(process.argv[addWorldFlag + 1] ?? '').split(',').map((id) => id.trim()).filter(Boolean);
const incremental = addWorldIds.length > 0;
const SOURCE_FILES = {
  frostline: 'frostline.js',
  frostline_relay: 'frostline.js',
  verdant: 'verdant.js',
  verdant_bloom: 'verdant.js',
  emberfall: 'emberfall.js',
  emberfall_foundry: 'emberfall.js',
  titans: 'titans.js',
};

if (!fs.existsSync(REPORT)) {
  console.error(`missing ${path.relative(REPO, REPORT)} — run: node tools/asset-forge/gate/world_shot.mjs`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(REPORT, 'utf8'));
const previousManifest = incremental && fs.existsSync(MANIFEST)
  ? JSON.parse(fs.readFileSync(MANIFEST, 'utf8'))
  : null;
if (incremental && !previousManifest) throw new Error('--add-world requires an existing staged manifest');
const preservedEntries = previousManifest?.entries ?? [];
for (const worldId of addWorldIds) {
  if (!report.worlds[worldId]) throw new Error(`${worldId}: missing from worlds-report.json`);
  if (preservedEntries.some((entry) => entry.id === worldId)) {
    throw new Error(`${worldId}: already staged; run a full rebuild instead of --add-world`);
  }
}

const io = new NodeIO();
const entries = [];
const stagedBinaries = [];
const sharedTextures = new Map();

// Read the source set before encoding any image. A map used by several Worlds
// must keep identical bytes everywhere; resizing it only for Emberfall would
// defeat content-addressed sharing and add a second runtime copy. Only maps
// owned exclusively by Emberfall are eligible for its compact 512 px budget.
const sourceDocs = new Map();
const sourceTextureWorlds = new Map();
for (const worldId of Object.keys(report.worlds)) {
  const src = path.join(BUILD, worldId, 'world.glb');
  if (!fs.existsSync(src)) continue;
  const doc = await io.read(src);
  sourceDocs.set(worldId, doc);
  for (const texture of doc.getRoot().listTextures()) {
    const hash = crypto.createHash('sha256').update(texture.getImage()).digest('hex');
    if (!sourceTextureWorlds.has(hash)) sourceTextureWorlds.set(hash, new Set());
    sourceTextureWorlds.get(hash).add(worldId);
  }
}

// Seed the exact previous content-addressed maps. New references are added by
// externalizeSharedTextures(); old GLBs and their manifest entries stay untouched.
for (const file of previousManifest?.shared_textures?.files ?? []) {
  const fileName = path.basename(file.path);
  const data = fs.readFileSync(path.join(TEXTURE_DIR, fileName));
  const actualHash = crypto.createHash('sha256').update(data).digest('hex');
  if (fileName !== `${actualHash}${path.extname(fileName)}` || data.length !== file.bytes) {
    throw new Error(`${fileName}: existing shared texture failed its content/hash check`);
  }
  sharedTextures.set(fileName, {
    fileName,
    data,
    worlds: new Set(file.worlds),
    references: file.references,
  });
}

for (const [worldId, world] of Object.entries(report.worlds)) {
  if (incremental && !addWorldIds.includes(worldId)) continue;
  if (!SOURCE_FILES[worldId]) throw new Error(`${worldId}: no source/provenance mapping`);
  const src = path.join(BUILD, worldId, 'world.glb');
  if (!fs.existsSync(src)) {
    console.error(`missing ${path.relative(REPO, src)} — rerun the gate for ${worldId}`);
    process.exitCode = 1;
    continue;
  }

  const doc = sourceDocs.get(worldId);
  if (!doc) throw new Error(`${worldId}: source document was not loaded`);
  const root = doc.getRoot();
  const originalNames = root.listTextures().map((texture) => texture.getName());
  let compactCount = 0;
  root.listTextures().forEach((texture, index) => {
    const hash = crypto.createHash('sha256').update(texture.getImage()).digest('hex');
    const owners = sourceTextureWorlds.get(hash);
    const compact = worldId === 'emberfall' && owners?.size === 1 && owners.has(worldId);
    if (compact) compactCount += 1;
    texture.setName(`__forge_${compact ? 'compact' : 'standard'}_${index}`);
  });
  try {
    const encoding = { encoder: sharp, targetFormat: 'jpeg', quality: 92 };
    if (compactCount > 0) {
      await doc.transform(textureCompress({
        ...encoding,
        resize: [512, 512],
        pattern: /^__forge_compact_/,
      }));
    }
    await doc.transform(textureCompress({
      ...encoding,
      resize: [2048, 2048],
      pattern: /^__forge_standard_/,
    }));
  } finally {
    root.listTextures().forEach((texture, index) => texture.setName(originalNames[index]));
  }
  const embedded = await io.writeBinary(doc);
  const binary = externalizeSharedTextures(embedded, worldId, sharedTextures);

  // Khronos validation, on the exact bytes Godot will import. A GLB that only
  // three.js accepts is not a shipping asset, and a broken file caught here is
  // caught before it is 20 MB of repository.
  const validation = await validator.validateBytes(new Uint8Array(binary), {
    externalResourceFunction: sharedTextureResourceLoader(sharedTextures),
  });
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
    source: `tools/asset-forge/src/worlds/${SOURCE_FILES[worldId]}`,
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

  stagedBinaries.push({ worldId, binary });
}

if (dryRun) {
  const shared = sharedTextureSummary(sharedTextures);
  console.log(`shared textures: ${shared.references} references → ${shared.count} distinct files`);
  console.log('dry run — nothing written');
  process.exit(process.exitCode ?? 0);
}

// Write only after every world passed validation, textures before the GLBs that
// reference them. A failed third world cannot leave two new GLBs with no maps.
const shared = writeSharedTextures(sharedTextures, TEXTURE_DIR);
fs.mkdirSync(OUT_DIR, { recursive: true });
for (const { worldId, binary } of stagedBinaries) {
  fs.writeFileSync(path.join(OUT_DIR, `${worldId}.glb`), binary);
}
console.log(`shared textures: ${shared.references} references → ${shared.count} distinct files`);

// Only a full rebuild may prune worlds. Incremental addition deliberately
// leaves every pre-existing GLB alone, including one absent from a partial report.
if (!incremental) {
  for (const file of fs.readdirSync(OUT_DIR)) {
    if (!file.endsWith('.glb')) continue;
    const id = file.replace(/\.glb$/, '');
    if (entries.some((e) => e.id === id)) continue;
    fs.rmSync(path.join(OUT_DIR, file));
    console.log(`removed stale ${file}`);
  }
}

const manifest = {
  generated: new Date().toISOString(),
  note: 'Mission worlds built from real licensed GLBs, with byte-identical images staged as shared runtime textures. Provenance: tools/asset-forge/real/real-manifest.json',
  shared_textures: shared,
  attribution: {
    'Kenney Space Kit': 'CC0-1.0 — Kenney (www.kenney.nl)',
    'Kenney Nature Kit': 'CC0-1.0 — Kenney (www.kenney.nl)',
    'Cinder Yard / Power Plant + set pieces + ground plate': 'CC-BY-4.0 — Kammertonus (https://twitter.com/Kammertonus)',
  },
  entries: incremental ? [...preservedEntries, ...entries] : entries,
};
fs.writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 1)}\n`);
console.log(`\nmanifest → ${path.relative(REPO, MANIFEST)} (${manifest.entries.length} worlds)`);
