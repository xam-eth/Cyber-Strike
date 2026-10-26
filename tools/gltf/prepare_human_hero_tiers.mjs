#!/usr/bin/env node
/*
 * Optimize the five preserved human hero tier source GLBs for runtime rigging.
 * The original source meshes remain untouched in source-assets/characters/.
 * Each optimized model is still the supplied real mesh; this step welds,
 * simplifies, and compresses its material textures before skin weights are built.
 *
 * Usage:
 *   node tools/gltf/prepare_human_hero_tiers.mjs
 *   node tools/gltf/prepare_human_hero_tiers.mjs --check
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import {
  dedup,
  prune,
  simplify,
  textureCompress,
  weld,
} from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CHECK_ONLY = process.argv.includes('--check');
const TRIANGLE_RATIO = 0.075;
const MAX_RUNTIME_TRIANGLES = 50000;
const MAX_TEXTURE_EDGE = 1024;
const VARIANTS = [1, 2, 3, 4, 5].map((tier) => ({
  id: `hero_human_tier_${tier}`,
  tier,
  source: `source-assets/characters/human_hero_tiers/hero_human_tier_${tier}_source.glb`,
  output: `tools/gltf/build/human_hero_tiers/hero_human_tier_${tier}.glb`,
}));

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

function triangleCount(document) {
  let triangles = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const primitive of mesh.listPrimitives()) {
      const indices = primitive.getIndices();
      const positions = primitive.getAttribute('POSITION');
      if (indices) triangles += indices.getCount() / 3;
      else if (positions) triangles += positions.getCount() / 3;
    }
  }
  return Math.round(triangles);
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

async function inspectModel(variant, sourceTriangles) {
  const outputPath = path.join(ROOT, variant.output);
  if (!fs.existsSync(outputPath)) {
    throw new Error(`${variant.output} is missing; run the human hero build first.`);
  }
  const document = await io.read(outputPath);
  const root = document.getRoot();
  const triangles = triangleCount(document);
  const textures = await textureInfo(document);
  const errors = [];

  if (root.listMeshes().length !== 1 || triangles <= 0) {
    errors.push('expected exactly one non-empty real source mesh');
  }
  if (triangles > MAX_RUNTIME_TRIANGLES) {
    errors.push(`triangle budget exceeded (${triangles} > ${MAX_RUNTIME_TRIANGLES})`);
  }
  if (root.listSkins().length !== 0) errors.push('unexpected skin before rig generation');
  if (root.listAnimations().length !== 0) errors.push('unexpected animations before retargeting');
  if (textures.length === 0) errors.push('no embedded material textures were found');
  for (const texture of textures) {
    if (texture.width > MAX_TEXTURE_EDGE || texture.height > MAX_TEXTURE_EDGE) {
      errors.push(`${texture.name} remains ${texture.width}x${texture.height}`);
    }
  }

  return {
    id: variant.id,
    tier: variant.tier,
    source: variant.source,
    output: variant.output,
    sourceTriangles,
    triangles,
    bytes: fs.statSync(outputPath).size,
    textures,
    errors,
  };
}

async function prepareVariant(variant) {
  const sourcePath = path.join(ROOT, variant.source);
  const outputPath = path.join(ROOT, variant.output);
  if (!fs.existsSync(sourcePath)) throw new Error(`${variant.source} is missing.`);
  const source = await io.read(sourcePath);
  const sourceTriangles = triangleCount(source);
  const root = source.getRoot();
  if (root.listMeshes().length !== 1) {
    throw new Error(`${variant.source} must contain exactly one source mesh.`);
  }
  if (root.listSkins().length !== 0 || root.listAnimations().length !== 0) {
    throw new Error(`${variant.source} is no longer static and unrigged; review the pipeline.`);
  }
  if (sourceTriangles < 400000) {
    throw new Error(`${variant.source} unexpectedly contains only ${sourceTriangles} triangles.`);
  }

  if (CHECK_ONLY) return inspectModel(variant, sourceTriangles);

  for (const extension of root.listExtensionsUsed()) {
    if (extension.extensionName === 'KHR_materials_volume' || extension.extensionName === 'FB_ngon_encoding') {
      extension.dispose();
    }
  }

  await source.transform(
    weld({ tolerance: 0.00001 }),
    simplify({ simplifier: MeshoptSimplifier, ratio: TRIANGLE_RATIO, error: 0.0015, lockBorder: false }),
    textureCompress({
      resize: [1024, 1024],
      targetFormat: 'jpeg',
      quality: 84,
      encoder: sharp,
      slots: /^(baseColorTexture|metallicRoughnessTexture)$/,
    }),
    textureCompress({
      resize: [1024, 1024],
      encoder: sharp,
      slots: /^normalTexture$/,
    }),
    dedup(),
    prune(),
  );

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await io.write(outputPath, source);
  return inspectModel(variant, sourceTriangles);
}

const reports = [];
for (const variant of VARIANTS) reports.push(await prepareVariant(variant));

for (const report of reports) {
  console.log(`Human Operative T${report.tier}`);
  console.log(
    `  ${report.sourceTriangles.toLocaleString()} source → ` +
      `${report.triangles.toLocaleString()} runtime tris · ${report.bytes.toLocaleString()} B`,
  );
  console.log(
    `  textures ${report.textures.map((texture) => `${texture.width}x${texture.height} ${texture.format}`).join(', ')}`,
  );
  for (const error of report.errors) console.error(`  ERROR: ${error}`);
}

if (reports.some((report) => report.errors.length > 0)) process.exit(1);
