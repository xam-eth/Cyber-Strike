#!/usr/bin/env node
/*
 * Prepare the Rare and Epic robot enemy source GLBs for runtime.
 *
 * Source meshes remain untouched in source-assets/. This mirrors the Robot Common
 * enemy pipeline: weld and simplify the skinned mesh, resample the native idle,
 * resize material textures to 1024 px, and remove unsupported extensions.
 * Animation retargeting is a separate, deterministic Python step so the mesh
 * optimizer can never silently copy Robot Common's animation channels onto a
 * different rest pose.
 *
 * Usage:
 *   node tools/gltf/prepare_robot_enemy_variants.mjs
 *   node tools/gltf/prepare_robot_enemy_variants.mjs --check
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import {
  dedup,
  prune,
  resample,
  simplify,
  textureCompress,
  weld,
} from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CHECK_ONLY = process.argv.includes('--check');
const TRIANGLE_RATIO = 0.075;
const TEXTURE_SIZE = 1024;
const MAX_RUNTIME_TRIANGLES = 50000;
const MAX_TEXTURE_EDGE = 1024;
const RETARGETED_CLIPS = new Set([
  'idle', 'walk', 'run', 'aim', 'aim_walk', 'aim_run', 'fire', 'reload', 'hit', 'death',
]);
const VARIANTS = [
  {
    id: 'enemy_robot_tier_2_rare',
    source: 'source-assets/enemies/enemy_robot_tier_2_rare_source.glb',
    output: 'game/assets/enemies/enemy_robot_tier_2_rare.glb',
  },
  {
    id: 'enemy_robot_tier_3_epic',
    source: 'source-assets/enemies/enemy_robot_tier_3_epic_source.glb',
    output: 'game/assets/enemies/enemy_robot_tier_3_epic.glb',
  },
];

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

function triangleCount(document) {
  let triangles = 0;
  let vertices = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const primitive of mesh.listPrimitives()) {
      const indices = primitive.getIndices();
      const positions = primitive.getAttribute('POSITION');
      vertices += positions ? positions.getCount() : 0;
      if (indices) triangles += indices.getCount() / 3;
      else if (positions) triangles += positions.getCount() / 3;
    }
  }
  return Math.round(triangles);
}

function animationInfo(document) {
  return document.getRoot().listAnimations().map((animation) => {
    const ends = animation
      .listSamplers()
      .map((sampler) => {
        const input = sampler.getInput();
        return input ? input.getArray()[input.getCount() - 1] : 0;
      });
    return {
      name: animation.getName(),
      channels: animation.listChannels().length,
      seconds: Number((ends.length ? Math.max(...ends) : 0).toFixed(3)),
    };
  });
}

async function textureInfo(document) {
  const result = [];
  for (const [index, texture] of document.getRoot().listTextures().entries()) {
    const image = texture.getImage();
    if (!image || image.length === 0) continue;
    const metadata = await sharp(image).metadata();
    result.push({
      index,
      name: texture.getName() || `texture-${index}`,
      width: metadata.width || 0,
      height: metadata.height || 0,
      format: metadata.format || 'unknown',
      bytes: image.length,
    });
  }
  return result;
}

function inspectSkin(document) {
  const skins = document.getRoot().listSkins();
  return {
    count: skins.length,
    joints: skins[0] ? skins[0].listJoints().length : 0,
  };
}

async function inspectVariant(variant, sourceDocument = null, sourceMetrics = null) {
  const outputPath = path.join(ROOT, variant.output);
  if (!fs.existsSync(outputPath)) {
    throw new Error(`${variant.output} is missing; run the asset build first.`);
  }
  const document = await io.read(outputPath);
  const triangles = triangleCount(document);
  const skin = inspectSkin(document);
  const clips = animationInfo(document);
  const textures = await textureInfo(document);
  const size = fs.statSync(outputPath).size;
  const sourceTriangles = sourceMetrics?.triangles ?? (sourceDocument ? triangleCount(sourceDocument) : null);
  const sourceSkin = sourceMetrics?.skin ?? (sourceDocument ? inspectSkin(sourceDocument) : null);
  const errors = [];

  if (skin.count !== 1 || skin.joints < 70) errors.push(`unexpected skin ${skin.count}/${skin.joints}`);
  if (sourceSkin && skin.joints !== sourceSkin.joints) {
    errors.push(`joint count changed ${sourceSkin.joints} -> ${skin.joints}`);
  }
  if (triangles <= 0 || triangles > MAX_RUNTIME_TRIANGLES) {
    errors.push(`triangle budget exceeded (${triangles} > ${MAX_RUNTIME_TRIANGLES})`);
  }
  if (!clips.some((clip) => clip.name === 'idle' && clip.seconds > 0)) {
    errors.push('native idle clip is missing');
  }
  const clipNames = new Set(clips.map((clip) => clip.name));
  const isBase = clips.length === 1 && clipNames.has('idle');
  const isRetargeted =
    clipNames.size === RETARGETED_CLIPS.size &&
    [...RETARGETED_CLIPS].every((name) => clipNames.has(name));
  if (!isBase && !isRetargeted) {
    errors.push(`expected idle-only or the complete 10-clip retarget, got ${clips.length} clips`);
  }
  if (textures.length === 0) errors.push('no embedded material textures were found');
  for (const texture of textures) {
    if (texture.width > MAX_TEXTURE_EDGE || texture.height > MAX_TEXTURE_EDGE) {
      errors.push(`${texture.name} remains ${texture.width}x${texture.height}`);
    }
  }

  return {
    id: variant.id,
    source: variant.source,
    output: variant.output,
    sourceBytes: fs.existsSync(path.join(ROOT, variant.source))
      ? fs.statSync(path.join(ROOT, variant.source)).size
      : 0,
    bytes: size,
    sourceTriangles,
    triangles,
    sourceJoints: sourceSkin ? sourceSkin.joints : null,
    joints: skin.joints,
    clips,
    textures,
    errors,
  };
}

async function prepareVariant(variant) {
  const sourcePath = path.join(ROOT, variant.source);
  const outputPath = path.join(ROOT, variant.output);
  if (!fs.existsSync(sourcePath)) throw new Error(`${variant.source} is missing.`);
  const source = await io.read(sourcePath);
  const sourceMetrics = {
    triangles: triangleCount(source),
    skin: inspectSkin(source),
  };

  if (CHECK_ONLY) return inspectVariant(variant, source, sourceMetrics);

  const root = source.getRoot();
  for (const extension of root.listExtensionsUsed()) {
    if (extension.extensionName === 'KHR_materials_volume' || extension.extensionName === 'FB_ngon_encoding') {
      extension.dispose();
    }
  }

  await source.transform(
    weld({ tolerance: 0.00001 }),
    simplify({ simplifier: MeshoptSimplifier, ratio: TRIANGLE_RATIO, error: 0.0015, lockBorder: false }),
    resample({ tolerance: 0.0005 }),
    textureCompress({
      resize: [TEXTURE_SIZE, TEXTURE_SIZE],
      targetFormat: 'jpeg',
      quality: 84,
      encoder: sharp,
    }),
    dedup(),
    prune(),
  );

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await io.write(outputPath, source);
  return inspectVariant(variant, source, sourceMetrics);
}

const reports = [];
for (const variant of VARIANTS) reports.push(await prepareVariant(variant));

for (const report of reports) {
  console.log(`${report.id}`);
  console.log(
    `  ${report.sourceTriangles === null ? 'source' : `${report.sourceTriangles.toLocaleString()} source`} → ` +
      `${report.triangles.toLocaleString()} runtime tris · ${report.bytes.toLocaleString()} B`,
  );
  console.log(
    `  joints ${report.sourceJoints ?? '?'} → ${report.joints} · ` +
      `textures ${report.textures.map((texture) => `${texture.width}x${texture.height}`).join(', ')}`,
  );
  console.log(`  clips ${report.clips.map((clip) => `${clip.name} ${clip.seconds}s`).join(', ')}`);
  for (const error of report.errors) console.error(`  ERROR: ${error}`);
}

const failed = reports.some((report) => report.errors.length > 0);
if (failed) process.exit(1);
