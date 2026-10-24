#!/usr/bin/env node
/**
 * fetch_real_assets.mjs — the provenance ledger for every visible asset.
 *
 * The world is made of real, licensed, pre-modelled GLB files. None of them is
 * produced by project code, so the repository has to be able to prove where each
 * one came from and that it has not been swapped for something else. This script
 * is that proof:
 *
 *   node tools/asset-forge/real/fetch_real_assets.mjs --verify   # CI: hash check
 *   node tools/asset-forge/real/fetch_real_assets.mjs --fetch     # re-download
 *   node tools/asset-forge/real/fetch_real_assets.mjs --write     # rebuild manifest
 *
 * `--verify` exits non-zero if a listed file is missing, if its SHA-256 changed,
 * or if a `.glb` sits in the folder without an entry (an unaccounted asset).
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..', '..');
const REAL = path.join(ROOT, 'game', 'assets', 'world', 'real');
const MANIFEST = path.join(HERE, 'real-manifest.json');

const KENNEY_SHA = '2c8950b716e6765930b2b51409c59adf3d66fd5c';
const KENNEY_API = `https://api.github.com/repos/Hidencod/tge-assets/contents/packs/space-kit`;

const LIBRARIES = {
  'kenney-space-kit': {
    title: 'Kenney Space Kit',
    author: 'Kenney (www.kenney.nl)',
    license: 'CC0-1.0',
    license_url: 'https://creativecommons.org/publicdomain/zero/1.0/',
    source: 'https://github.com/Hidencod/tge-assets',
    source_pin: KENNEY_SHA,
    notes: 'Authored low-poly sci-fi kit: hangars, gates, turrets, dishes, machines, platforms, rocks, crystals, corridors. Self-contained GLB conversions by the mirror maintainer, also CC0.',
  },
  'babylon-powerplant': {
    title: 'Power Plant',
    author: 'Kammertonus (https://twitter.com/Kammertonus)',
    license: 'CC-BY-4.0',
    license_url: 'https://creativecommons.org/licenses/by/4.0/',
    source: 'https://github.com/BabylonJS/Assets',
    notes: 'Photoreal industrial power station: 285 meshes, 79 PBR materials, 65 baked 1024 px texture maps, 113,937 triangles.',
  },
  'derived-setpieces': {
    title: 'Power Plant set pieces',
    author: 'Kammertonus (https://twitter.com/Kammertonus)',
    license: 'CC-BY-4.0',
    license_url: 'https://creativecommons.org/licenses/by/4.0/',
    source: 'derived from game/assets/world/real/powerplant.glb',
    notes: 'Individual structures cut out of the Power Plant file (tank ring, tank pad, cooling tower, arch ribs, a single column, the drone, the crane carriage). Node hierarchy, materials and baked 1024 px maps are copied unchanged by real/slice_setpieces.mjs; nothing is modelled or re-textured.',
  },
  'babylon-ground': {
    title: 'Tiled ground plate',
    author: 'Kammertonus (https://twitter.com/Kammertonus)',
    license: 'CC-BY-4.0',
    license_url: 'https://creativecommons.org/licenses/by/4.0/',
    source: 'https://github.com/BabylonJS/Assets',
    notes: 'Real photographed stone-tile ground with baked PBR normal/diffuse/roughness maps at 1920 px. Used as the world floor: the tiles are geometry from the file, not a generated plane.',
  },
};

const sha256 = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

function libraryOf(rel) {
  if (rel.startsWith('kenney/')) return 'kenney-space-kit';
  if (rel.startsWith('ground/')) return 'babylon-ground';
  if (rel.startsWith('setpieces/')) return 'derived-setpieces';
  return 'babylon-powerplant';
}

/** Source that a given relative path came from, for re-download. */
function sourceOf(rel) {
  const base = path.basename(rel, '.glb');
  if (rel.startsWith('kenney/')) {
    return { kind: 'github-contents', repo: 'Hidencod/tge-assets', ref: KENNEY_SHA, path: `packs/space-kit/${base}.glb` };
  }
  if (rel.startsWith('ground/')) {
    return { kind: 'github-raw', repo: 'BabylonJS/Assets', ref: 'master', path: 'meshes/Buildings/ceiling.glb' };
  }
  if (rel.startsWith('setpieces/')) {
    // Cut from powerplant.glb by real/slice_setpieces.mjs. Regenerate rather than
    // download: the nodes, materials and maps are copied, never re-authored.
    return { kind: 'derived', from: 'powerplant.glb', tool: 'tools/asset-forge/real/slice_setpieces.mjs' };
  }
  return { kind: 'github-raw', repo: 'BabylonJS/Assets', ref: 'master', path: 'meshes/PowerPlant/powerplant.glb' };
}

function walk(dir, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(abs, acc);
    else if (entry.name.endsWith('.glb')) acc.push(path.relative(REAL, abs).split(path.sep).join('/'));
  }
  return acc;
}

function buildManifest() {
  const files = {};
  for (const rel of walk(REAL).sort()) {
    const abs = path.join(REAL, rel);
    const stat = fs.statSync(abs);
    files[rel] = {
      library: libraryOf(rel),
      bytes: stat.size,
      sha256: sha256(abs),
      source: sourceOf(rel),
    };
  }
  return {
    $comment: 'Generated by tools/asset-forge/real/fetch_real_assets.mjs --write. Every visible asset in the world is a real, licensed, pre-modelled GLB. tools/asset-forge/gate/real_asset_checks.mjs fails the build if a file is missing, edited, or sits in game/assets/world/real without an entry here.',
    generated: new Date().toISOString(),
    libraries: LIBRARIES,
    totals: {
      files: Object.keys(files).length,
      bytes: Object.values(files).reduce((a, f) => a + f.bytes, 0),
    },
    files,
  };
}

async function fetchJson(url) {
  const res = await fetch(url, { headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'asset-forge' } });
  if (!res.ok) throw new Error(`${url} → ${res.status}`);
  return res.json();
}

async function fetchAll(manifest) {
  for (const [rel, entry] of Object.entries(manifest.files)) {
    const abs = path.join(REAL, rel);
    if (fs.existsSync(abs) && sha256(abs) === entry.sha256) continue;
    const src = entry.source;
    if (src.kind === 'derived') continue;   // regenerated by slice_setpieces.mjs
    let buffer;
    if (src.kind === 'github-contents') {
      const data = await fetchJson(`https://api.github.com/repos/${src.repo}/contents/${encodeURI(src.path)}?ref=${src.ref}`);
      buffer = Buffer.from(data.content, 'base64');
    } else {
      const res = await fetch(`https://raw.githubusercontent.com/${src.repo}/${src.ref}/${encodeURI(src.path)}`);
      if (!res.ok) throw new Error(`${src.path} → ${res.status}`);
      buffer = Buffer.from(await res.arrayBuffer());
    }
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, buffer);
    console.log(`  fetched ${rel} (${Math.round(buffer.length / 1024)} KB)`);
  }
}

function verify(manifest) {
  const problems = [];
  const present = new Set(walk(REAL));
  for (const [rel, entry] of Object.entries(manifest.files)) {
    const abs = path.join(REAL, rel);
    if (!fs.existsSync(abs)) { problems.push(`missing: ${rel}`); continue; }
    const hash = sha256(abs);
    if (hash !== entry.sha256) problems.push(`edited: ${rel} (sha256 ${hash.slice(0, 12)}… ≠ ${entry.sha256.slice(0, 12)}…)`);
    if (!LIBRARIES[entry.library]) problems.push(`unlicensed: ${rel} → library "${entry.library}" is not in the ledger`);
    present.delete(rel);
  }
  for (const extra of present) problems.push(`unaccounted: ${extra} has no manifest entry`);
  return problems;
}

const mode = process.argv.includes('--fetch') ? 'fetch'
  : process.argv.includes('--write') ? 'write'
    : 'verify';

let manifest;
if (mode === 'write') {
  manifest = buildManifest();
  fs.writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 1)}\n`);
  console.log(`wrote ${path.relative(ROOT, MANIFEST)} — ${manifest.totals.files} files, ${(manifest.totals.bytes / 1048576).toFixed(1)} MB`);
} else {
  manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
}

if (mode === 'fetch') {
  await fetchAll(manifest);
  const problems = verify(manifest);
  if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
  console.log('all real assets present and hash-matching');
}

if (mode === 'verify') {
  const problems = verify(manifest);
  const counts = {};
  for (const entry of Object.values(manifest.files)) counts[entry.library] = (counts[entry.library] ?? 0) + 1;
  console.log(`${manifest.totals.files} real asset files · ${(manifest.totals.bytes / 1048576).toFixed(1)} MB`);
  for (const [lib, n] of Object.entries(counts)) {
    const spec = LIBRARIES[lib];
    console.log(`  ${String(n).padStart(3)} × ${spec.title} — ${spec.license} — ${spec.author}`);
  }
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exit(1);
  }
  console.log('provenance ledger verified');
}
