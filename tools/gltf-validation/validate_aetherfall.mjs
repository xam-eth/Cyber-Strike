#!/usr/bin/env node
/**
 * Runs the official Khronos glTF Validator over every tracked Aetherfall GLB.
 *
 * This checks file-format and glTF conformance only. It deliberately does not
 * turn a zero-error report into a claim about modelling, art direction, Godot
 * rendering, collision, or target-device performance.
 *
 * Usage:
 *   npm ci --prefix tools/gltf-validation
 *   npm run --prefix tools/gltf-validation validate:aetherfall
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import validator from 'gltf-validator';

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(toolDirectory, '..', '..');
const assetRoot = path.join(root, 'game', 'assets', 'world', 'aetherfall');
const outPath = path.join(root, 'docs', 'world', 'aetherfall', 'validation', 'gltf_validation.json');

function listGlbs(directory) {
  return fs.readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => entry.isDirectory()
      ? listGlbs(path.join(directory, entry.name))
      : entry.name.endsWith('.glb') ? [path.join(directory, entry.name)] : [])
    .sort();
}

function sourceFor(runtimePath) {
  const stem = runtimePath.replaceAll('\\', '/');
  if (stem === 'models/connector_ramp.glb') return 'source/connector_ramp.blend';
  if (stem === 'models/energy_orbit.glb') return 'source/energy_orbit.blend';
  if (stem.startsWith('models/')) return 'source/aetherfall_kit.blend';
  const firstFolder = stem.split('/')[0];
  const sourceByFamily = {
    archive: 'source/aetherfall_archive_interior.blend',
    expanse: 'source/aetherfall_connected_expanse.blend',
    ice_planet: 'source/aetherfall_ice_planet.blend',
    interactives: 'source/aetherfall_interactives.blend',
    landmarks: 'source/aetherfall_landmarks.blend',
    phase2: 'source/aetherfall_phase2_cover.blend',
    vertical: 'source/aetherfall_vertical_infrastructure.blend',
  };
  if (!sourceByFamily[firstFolder]) throw new Error(`No source mapping for ${runtimePath}`);
  return sourceByFamily[firstFolder];
}

function issueCounts(messages) {
  return messages.reduce((counts, message) => {
    counts[message.code] = (counts[message.code] ?? 0) + 1;
    return counts;
  }, {});
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

const files = listGlbs(assetRoot);
const assets = [];
for (const filename of files) {
  const bytes = fs.readFileSync(filename);
  const runtimePath = path.relative(assetRoot, filename).replaceAll(path.sep, '/');
  const result = await validator.validateBytes(new Uint8Array(bytes), {
    uri: runtimePath,
    format: 'glb',
    writeTimestamp: false,
    maxIssues: 0,
    // shared content-addressed textures live next to the module folders;
    // resolve ../textures/<sha>.png exactly like Godot's importer does.
    externalResourceFunction: async (uri) => {
      const resolved = path.resolve(path.dirname(filename), uri);
      return new Uint8Array(fs.readFileSync(resolved));
    },
  });
  const issues = result.issues;
  const info = result.info;
  assets.push({
    runtime_path: `game/assets/world/aetherfall/${runtimePath}`,
    source_path: sourceFor(runtimePath),
    sha256: sha256(bytes),
    bytes: bytes.byteLength,
    validation_status: issues.numErrors === 0 && issues.numWarnings === 0
      ? 'format_valid_no_warnings'
      : issues.numErrors === 0 ? 'format_valid_with_warnings' : 'format_errors',
    issues: {
      errors: issues.numErrors,
      warnings: issues.numWarnings,
      infos: issues.numInfos,
      hints: issues.numHints,
      by_code: issueCounts(issues.messages),
    },
    stats: {
      generator: info.generator ?? null,
      materials: info.materialCount ?? 0,
      textures: Boolean(info.hasTextures),
      draw_calls: info.drawCallCount ?? 0,
      vertices: info.totalVertexCount ?? 0,
      triangles: info.totalTriangleCount ?? 0,
      max_uv_sets: info.maxUVs ?? 0,
      max_attributes: info.maxAttributes ?? 0,
      animations: info.animationCount ?? 0,
    },
    art_status: 'legacy_runtime_asset_unaccepted_for_production_polish',
    next_required_gate: 'asset_brief_and_reference_then_base_mesh_review',
  });
}

const totals = assets.reduce((summary, asset) => {
  summary.glb_assets += 1;
  summary.bytes += asset.bytes;
  summary.errors += asset.issues.errors;
  summary.warnings += asset.issues.warnings;
  summary.infos += asset.issues.infos;
  summary.draw_calls += asset.stats.draw_calls;
  summary.vertices += asset.stats.vertices;
  summary.triangles += asset.stats.triangles;
  return summary;
}, { glb_assets: 0, bytes: 0, errors: 0, warnings: 0, infos: 0, draw_calls: 0, vertices: 0, triangles: 0 });

const report = {
  report_schema: 'aetherfall.gltf-validation.v1',
  scope: 'All GLB files under game/assets/world/aetherfall at the time this command ran.',
  validator: {
    package: 'gltf-validator',
    version: validator.version(),
    upstream: 'https://github.com/KhronosGroup/glTF-Validator',
  },
  interpretation: [
    'This is a Khronos glTF conformance report, not a visual-art, Godot-import, collision, or performance sign-off.',
    'MESH_PRIMITIVE_GENERATED_TANGENT_SPACE is retained as a release blocker for normal-mapped production assets: tangents must be explicitly exported or the target-engine tangent-generation path must be tested and accepted.',
    'No asset is promoted to production-polished by this static report.',
  ],
  totals,
  assets,
};
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`Validated ${totals.glb_assets} GLBs with ${totals.errors} errors, ${totals.warnings} warnings, and ${totals.infos} infos.`);
console.log(path.relative(root, outPath));
if (totals.errors > 0) process.exitCode = 1;
