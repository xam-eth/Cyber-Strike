/**
 * stage_into_game.mjs — put the forged GLBs where Godot imports them.
 *
 * `build/glb/` is a build product (git-ignored). Godot can only import what
 * lives inside the project, so this copies every exported GLB to
 * `game/assets/forge/<category>/<id>.glb` and writes a manifest that the
 * headless verifier (`tools/asset-forge/godot/verify_import.gd`) reads back.
 *
 * The manifest is the contract between the forge and the engine: id, category,
 * path, expected height/length in metres, clip names and socket names. The
 * verifier fails the build if any of those disagree with what Godot actually
 * imported — that is the check that proves the asset works inside the game
 * rather than only inside a browser.
 *
 *   node tools/asset-forge/gate/stage_into_game.mjs
 *   node tools/asset-forge/gate/stage_into_game.mjs --dry-run
 */
import fs from 'node:fs';
import path from 'node:path';

const FORGE = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const REPO = path.resolve(FORGE, '..', '..');
const GLB_DIR = path.join(FORGE, 'build', 'glb');
const GAME_DIR = path.join(REPO, 'game', 'assets', 'forge');
const dryRun = process.argv.includes('--dry-run');

const catalog = JSON.parse(fs.readFileSync(path.join(FORGE, 'catalog.json'), 'utf8'));
// Prefer the full report; `results.json` is rewritten by `--only` runs and can
// therefore be missing most of the catalog.
const readReport = (file) => {
  const p = path.join(FORGE, file);
  if (!fs.existsSync(p)) return [];
  const json = JSON.parse(fs.readFileSync(p, 'utf8'));
  return json.results ?? json.assets ?? [];
};
const measured = new Map([...readReport('results.json'), ...readReport('build/quality-report.json')].map((a) => [a.id, a]));

const entries = [];
const missing = [];

for (const entry of catalog.entries) {
  const src = path.join(GLB_DIR, entry.category, `${entry.id}.glb`);
  if (!fs.existsSync(src)) { missing.push(entry.id); continue; }
  const rel = path.posix.join('forge', entry.category, `${entry.id}.glb`);
  const dest = path.join(GAME_DIR, entry.category, `${entry.id}.glb`);
  if (!dryRun) {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
  const m = measured.get(entry.id);
  entries.push({
    id: entry.id,
    category: entry.category,
    name: entry.name,
    // res:// path, exactly what a GDScript `load()` would use
    resource: `res://assets/${rel}`,
    source: entry.source,
    targetHeight: entry.target_height_m ?? null,
    targetLength: entry.target_length_m ?? null,
    normalisedBy: entry.normaliseBy ?? entry.normalise_by ?? 'height',
    measuredHeight: m?.measured?.height_m ?? null,
    measuredWidth: m?.measured?.width_m ?? null,
    triangles: m?.measured?.triangles ?? null,
    clips: entry.animations ?? [],
    sockets: entry.sockets ?? [],
    bytes: fs.statSync(src).size,
  });
}

const manifest = {
  generated: new Date().toISOString(),
  note: 'Written by tools/asset-forge/gate/stage_into_game.mjs — the forge → Godot contract. Verified by tools/asset-forge/godot/verify_import.gd.',
  entries,
};
if (!dryRun) {
  fs.writeFileSync(path.join(GAME_DIR, 'forge_manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
}

const byCategory = entries.reduce((acc, e) => { acc[e.category] = (acc[e.category] ?? 0) + 1; return acc; }, {});
console.log(`${dryRun ? '[dry-run] would stage' : 'staged'} ${entries.length} GLBs into game/assets/forge/`);
for (const [k, v] of Object.entries(byCategory)) console.log(`  ${k.padEnd(7)} ${v}`);
if (missing.length) console.log(`  not exported yet: ${missing.join(', ')}`);
const unmeasured = entries.filter((e) => e.measuredHeight === null).map((e) => e.id);
if (unmeasured.length) console.log(`  ⚠ no measurement on record (run a full gate first): ${unmeasured.join(', ')}`);
console.log(`manifest: game/assets/forge/forge_manifest.json`);
