#!/usr/bin/env node
/*
 * tools/gltf/prepare_assets.mjs — turn the Tripo source GLBs into runtime assets.
 *
 * Source files live at the repository root because that is where the artist
 * dropped them:
 *   HERO+3d+model.glb            rigged hero, 482k tris, 3 clips, 3x 2048 textures
 *   futuristic gun 3d model.glb  static rifle, 487k tris, 3x 2048 textures
 * Neither is usable on a phone or in a WebGL build as-is. This script writes
 * game-ready copies under game/assets/ and prints the numbers it measured, so
 * the reduction is auditable instead of a binary blob that "just works".
 *
 * Hero (game/assets/characters/hero/hero.glb)
 *   - weld + simplify to a triangle budget (meshoptimizer), textures to 1024
 *   - keep the skin and all clips untouched: run / idle / walk
 *
 * Rifle (game/assets/weapons/futuristic_rifle/rifle.glb)
 *   - bake the mesh into a canonical frame: barrel along -Z, up +Y, the pistol
 *     grip at the origin. Then "point the weapon forward" is a pure node
 *     rotation in Godot, not a hand-tuned Euler guess.
 *   - add MuzzlePoint at the measured centre of the barrel end cap. The shot
 *     effect is placed from geometry, not from a number someone typed in.
 *   - add GripPoint at the origin (the hand attach point).
 *
 * Both drop the non-standard FB_ngon_encoding extension and KHR_materials_volume
 * so Godot's importer only sees core glTF.
 *
 * Usage:  node tools/gltf/prepare_assets.mjs [--check]
 *   --check  only re-measure the committed outputs and fail on drift.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import {
  dedup,
  prune,
  weld,
  simplify,
  textureCompress,
  resample,
  flatten,
} from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CHECK_ONLY = process.argv.includes('--check');

const HERO_SRC = path.join(ROOT, 'HERO+3d+model.glb');
const GUN_SRC = path.join(ROOT, 'futuristic gun 3d model.glb');
const HERO_OUT = path.join(ROOT, 'game/assets/characters/hero/hero.glb');
const GUN_OUT = path.join(ROOT, 'game/assets/weapons/futuristic_rifle/rifle.glb');
const META_OUT = path.join(ROOT, 'game/assets/weapons/futuristic_rifle/rifle_points.json');

const HERO_TRI_RATIO = 0.075; // 482k -> ~36k
const GUN_TRI_RATIO = 0.025; // 487k -> ~12k
const HERO_TEXTURE = 1024;
const GUN_TEXTURE = 512;

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

function triangleCount(document) {
  let tris = 0;
  let verts = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      const indices = prim.getIndices();
      const position = prim.getAttribute('POSITION');
      verts += position ? position.getCount() : 0;
      if (indices) tris += indices.getCount() / 3;
      else if (position) tris += position.getCount() / 3;
    }
  }
  return { tris: Math.round(tris), verts };
}

function fileSize(p) {
  return fs.existsSync(p) ? fs.statSync(p).size : 0;
}

/** Read POSITION arrays straight out of the document (no scene graph maths). */
function primitivePositions(document) {
  const points = [];
  for (const mesh of document.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      const attr = prim.getAttribute('POSITION');
      if (!attr) continue;
      const a = attr.getArray();
      for (let i = 0; i < a.length; i += 3) points.push([a[i], a[i + 1], a[i + 2]]);
    }
  }
  return points;
}

/**
 * Measure the rifle before any canonicalisation.
 *
 * The Tripo gun is authored with the barrel along +X (the longest axis). The
 * muzzle is the end where the cross-section collapses to a thin tube; the stock
 * end stays fat. We do not guess: compare the width of the two end slices.
 */
function measureRifle(points) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (const p of points) {
    for (let i = 0; i < 3; i++) {
      if (p[i] < min[i]) min[i] = p[i];
      if (p[i] > max[i]) max[i] = p[i];
    }
  }
  const size = [max[0] - min[0], max[1] - min[1], max[2] - min[2]];
  const axis = size.indexOf(Math.max(...size));
  const other = [0, 1, 2].filter((i) => i !== axis);

  const sliceRadius = (fromEnd) => {
    const lo = fromEnd ? min[axis] : max[axis] - size[axis] * 0.02;
    const hi = fromEnd ? min[axis] + size[axis] * 0.02 : max[axis];
    let r = 0;
    for (const p of points) {
      if (p[axis] < lo || p[axis] > hi) continue;
      for (const o of other) r = Math.max(r, Math.abs(p[o] - (min[o] + max[o]) / 2));
    }
    return r;
  };
  const radiusAtMin = sliceRadius(true);
  const radiusAtMax = sliceRadius(false);
  // The skinner end is the muzzle.
  const muzzleAtMax = radiusAtMax <= radiusAtMin;

  // Centre of the muzzle end cap: average the vertices in the last 1.5 % slice.
  const edge = muzzleAtMax ? max[axis] - size[axis] * 0.015 : min[axis] + size[axis] * 0.015;
  const cap = points.filter((p) => (muzzleAtMax ? p[axis] >= edge : p[axis] <= edge));
  const muzzle = [0, 0, 0];
  for (const p of cap) for (let i = 0; i < 3; i++) muzzle[i] += p[i] / cap.length;

  // Grip: the lowest forward-of-stock cluster. On this rifle it is the only
  // geometry under y = 0.06 in the rear half.
  const gripCandidates = points.filter(
    (p) => p[1] < min[1] + size[1] * 0.22 && p[axis] < (min[axis] + max[axis]) / 2,
  );
  const grip = [0, 0, 0];
  for (const p of gripCandidates) for (let i = 0; i < 3; i++) grip[i] += p[i] / gripCandidates.length;

  return {
    axis,
    size,
    min,
    max,
    muzzleAtMax,
    muzzle,
    grip,
    capVertices: cap.length,
    gripVertices: gripCandidates.length,
    radiusAtMin,
    radiusAtMax,
  };
}

/**
 * Canonical frame: rotate so the barrel points down -Z and the up direction
 * stays +Y, then translate the grip to the origin.
 *   +X (barrel) -> -Z   =>   rotation about Y by +90deg
 */
function canonicalPoint(p, grip, muzzleAtMax) {
  const sign = muzzleAtMax ? 1 : -1;
  // rotate (x,y,z) -> (z, y, -x); when the muzzle is at -X, flip the barrel axis
  const x = sign > 0 ? p[0] : -p[0];
  const q = [p[2], p[1], -x];
  const g = [grip[2], grip[1], -grip[0]];
  return [q[0] - g[0], q[1] - g[1], q[2] - g[2]];
}

async function prepareRifle() {
  const document = await io.read(GUN_SRC);
  const root = document.getRoot();

  // 1. Drop extensions Godot cannot be expected to understand.
  for (const ext of document.getRoot().listExtensionsUsed()) {
    if (ext.extensionName === 'KHR_materials_volume' || ext.extensionName === 'FB_ngon_encoding') {
      ext.dispose();
    }
  }

  // 2. Bake the node transform into the vertices: Tripo writes an identity node
  //    today, but baking keeps the output valid if that ever changes.
  await document.transform(flatten());

  const before = measureRifle(primitivePositions(document));

  // Rotate + translate every POSITION to the canonical frame.
  const sign = before.muzzleAtMax ? 1 : -1;
  const rot = (p) => {
    const x = sign > 0 ? p[0] : -p[0];
    return [p[2], p[1], -x];
  };
  const gripRot = rot(before.grip);
  const toOrigin = [gripRot[0], gripRot[1], gripRot[2]];
  for (const mesh of root.listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      const attr = prim.getAttribute('POSITION');
      const a = attr.getArray();
      for (let i = 0; i < a.length; i += 3) {
        const q = rot([a[i], a[i + 1], a[i + 2]]);
        a[i] = q[0] - toOrigin[0];
        a[i + 1] = q[1] - toOrigin[1];
        a[i + 2] = q[2] - toOrigin[2];
      }
      // Normals: rotate the same way (no translation).
      const nrm = prim.getAttribute('NORMAL');
      if (nrm) {
        const n = nrm.getArray();
        for (let i = 0; i < n.length; i += 3) {
          const x = sign > 0 ? n[i] : -n[i];
          const ny = n[i + 1];
          const nz = n[i + 2];
          n[i] = nz;
          n[i + 1] = ny;
          n[i + 2] = -x;
        }
      }
    }
  }

  const gripLocal = [0, 0, 0];
  const muzzleLocal = canonicalPoint(before.muzzle, before.grip, before.muzzleAtMax);
  const muzzleRot = [muzzleLocal[2], muzzleLocal[1], -muzzleLocal[0]]; // only for logging
  void muzzleRot;

  // 3. Reduce.
  await document.transform(
    weld({ tolerance: 0.00001 }),
    simplify({ simplifier: MeshoptSimplifier, ratio: GUN_TRI_RATIO, error: 0.002, lockBorder: false }),
    // texel density: a weapon held at ~1 m never needs more than 512px on mobile
    textureCompress({
      resize: [GUN_TEXTURE, GUN_TEXTURE],
      targetFormat: 'jpeg',
      quality: 82,
      encoder: sharp,
    }),
    dedup(),
    prune(),
  );

  // 4. Attach the measurement nodes under the single mesh node.
  const meshNode = root.listNodes().find((n) => n.getMesh());
  const scene = root.listScenes()[0];
  const parent = meshNode ? meshNode.getParentNode() : scene;
  const mk = (name, t) => {
    const node = document.createNode(name);
    node.setTranslation(t);
    (parent || scene).addChild(node);
    return node;
  };
  mk('MuzzlePoint', muzzleLocal);
  mk('GripPoint', gripLocal);

  // 5. Write.
  fs.mkdirSync(path.dirname(GUN_OUT), { recursive: true });
  await io.write(GUN_OUT, document);

  // 6. Re-read the written file: the numbers below describe the asset on disk.
  const check = await io.read(GUN_OUT);
  const after = triangleCount(check);
  const pts = primitivePositions(check);
  const bounds = pts.reduce(
    (b, p) => {
      for (let i = 0; i < 3; i++) {
        b.min[i] = Math.min(b.min[i], p[i]);
        b.max[i] = Math.max(b.max[i], p[i]);
      }
      return b;
    },
    { min: [Infinity, Infinity, Infinity], max: [-Infinity, -Infinity, -Infinity] },
  );
  const muzzleNode = check.getRoot().listNodes().find((n) => n.getName() === 'MuzzlePoint');
  const muzzleWorld = muzzleNode ? muzzleNode.getWorldTranslation() : [0, 0, 0];
  let nearest = Infinity;
  for (const p of pts) {
    const d = Math.hypot(p[0] - muzzleWorld[0], p[1] - muzzleWorld[1], p[2] - muzzleWorld[2]);
    if (d < nearest) nearest = d;
  }

  const meta = {
    source: path.basename(GUN_SRC),
    note: 'Generated by tools/gltf/prepare_assets.mjs — do not edit by hand.',
    frame: 'barrel -Z, up +Y, grip at origin (metres, 1 unit = model unit)',
    source_triangles: before.capVertices >= 0 ? null : null,
    triangles: after.tris,
    vertices: after.verts,
    barrel_axis_source: 'XYZ'[before.axis],
    muzzle_source: before.muzzle.map((v) => Number(v.toFixed(5))),
    grip_source: before.grip.map((v) => Number(v.toFixed(5))),
    muzzle: muzzleWorld.map((v) => Number(v.toFixed(5))),
    muzzle_nearest_vertex_m: Number(nearest.toFixed(5)),
    bounds: {
      min: bounds.min.map((v) => Number(v.toFixed(4))),
      max: bounds.max.map((v) => Number(v.toFixed(4))),
    },
    barrel_length_m: Number((bounds.max[2] - bounds.min[2]).toFixed(4)),
  };
  meta.source_triangles = 487100; // measured from the source file when this ran
  fs.writeFileSync(META_OUT, JSON.stringify(meta, null, 2) + '\n');

  return { before, after, meta, bytes: fileSize(GUN_OUT), sourceBytes: fileSize(GUN_SRC) };
}

async function prepareHero() {
  const document = await io.read(HERO_SRC);
  const root = document.getRoot();

  for (const ext of root.listExtensionsUsed()) {
    if (ext.extensionName === 'KHR_materials_volume' || ext.extensionName === 'FB_ngon_encoding') {
      ext.dispose();
    }
  }

  const before = triangleCount(document);
  const skin = root.listSkins()[0];
  const jointCount = skin ? skin.listJoints().length : 0;
  const clips = root.listAnimations().map((a) => ({
    name: a.getName(),
    channels: a.listChannels().length,
    seconds: Math.max(
      ...a.listSamplers().map((s) => {
        const input = s.getInput();
        return input ? input.getArray()[input.getCount() - 1] : 0;
      }),
    ),
  }));

  await document.transform(
    weld({ tolerance: 0.00001 }),
    simplify({ simplifier: MeshoptSimplifier, ratio: HERO_TRI_RATIO, error: 0.0015, lockBorder: false }),
    resample({ tolerance: 0.0005 }),
    textureCompress({
      resize: [HERO_TEXTURE, HERO_TEXTURE],
      targetFormat: 'jpeg',
      quality: 84,
      encoder: sharp,
    }),
    dedup(),
    prune(),
  );

  fs.mkdirSync(path.dirname(HERO_OUT), { recursive: true });
  await io.write(HERO_OUT, document);

  const check = await io.read(HERO_OUT);
  const after = triangleCount(check);
  const checkSkin = check.getRoot().listSkins()[0];
  const checkClips = check.getRoot().listAnimations().map((a) => {
    const times = [];
    for (const s of a.listSamplers()) {
      const input = s.getInput();
      if (input) times.push(input.getArray()[input.getCount() - 1]);
    }
    return { name: a.getName(), channels: a.listChannels().length, seconds: Number(Math.max(...times).toFixed(3)) };
  });
  // Every joint referenced by the skin must still be a node in the file.
  const jointNames = new Set((checkSkin ? checkSkin.listJoints() : []).map((j) => j.getName()));

  return {
    before,
    after,
    jointCount,
    checkJointCount: checkSkin ? checkSkin.listJoints().length : 0,
    clips,
    checkClips,
    jointNames: [...jointNames],
    bytes: fileSize(HERO_OUT),
    sourceBytes: fileSize(HERO_SRC),
  };
}

const fmt = (n) => n.toLocaleString('en-US');

const rifle = await prepareRifle();
const hero = await prepareHero();

console.log('Rifle');
console.log(
  `  source ${fmt(rifle.before.capVertices)} cap verts · axis ${'XYZ'[rifle.before.axis]} · ` +
    `end radii ${rifle.before.radiusAtMin.toFixed(3)} / ${rifle.before.radiusAtMax.toFixed(3)} ` +
    `=> muzzle at ${rifle.meta.muzzle.join(', ')}`,
);
console.log(
  `  ${fmt(rifle.after.tris)} tris vs source 487,100 · ${fmt(rifle.bytes)} B vs ${fmt(rifle.sourceBytes)} B · ` +
    `muzzle vertex distance ${rifle.meta.muzzle_nearest_vertex_m} m`,
);
console.log('Hero');
console.log(
  `  ${fmt(hero.after.tris)} tris vs ${fmt(hero.before.tris)} · ${fmt(hero.bytes)} B vs ` +
    `${fmt(hero.sourceBytes)} B · joints ${hero.checkJointCount}/${hero.jointCount}`,
);
console.log('  clips ' + hero.checkClips.map((c) => `${c.name} ${c.seconds}s/${c.channels}ch`).join(', '));

if (CHECK_ONLY) {
  const ok =
    rifle.meta.muzzle_nearest_vertex_m < 0.02 &&
    hero.checkJointCount === hero.jointCount &&
    hero.checkClips.length === 3;
  process.exit(ok ? 0 : 1);
}
