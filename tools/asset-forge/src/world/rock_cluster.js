/**
 * rock_cluster — warm sandstone/rose boundary rocks
 * (`game/scenes/worlds/components/rock_cluster.tscn`).
 *
 * The only warm-hued natural asset in the kit. It is deliberately built from
 * the palette's steel/amber tokens at low saturation: "warm rock" here means
 * amber-tinted graphite, not a new hue family (ART_DIRECTION.md §1 rule 1).
 */
import * as THREE from 'three';
import { at, box, group, rng, cone } from '../runtime/kit.js';
import { metal, paint } from '../runtime/materials.js';
import { socket, finalize } from '../runtime/rig.js';

export const meta = {
  id: 'rock_cluster',
  category: 'world',
  name: 'Rock Cluster',
  reference: 'references/world/rock_cluster.png',
  source: 'game/scenes/worlds/components/rock_cluster.tscn',
  targetHeight: 3.6,
  heightTolerance: 0.6,
  triangleBudget: 40000,
  meshBudget: 200,
  sockets: ['base'],
  animations: [],
};

function boulder(material, r, detail, rand) {
  const geo = new THREE.IcosahedronGeometry(r, detail);
  const pos = geo.attributes.position;
  // deterministic per-vertex displacement: a rock, not an icosahedron
  for (let i = 0; i < pos.count; i += 1) {
    const x = pos.getX(i);
    const y = pos.getY(i);
    const z = pos.getZ(i);
    const n = 0.78 + 0.32 * Math.sin(x * 3.1 + y * 2.3) * Math.cos(z * 2.7 - y * 1.4);
    pos.setXYZ(i, x * n, y * n * 0.82, z * n);
  }
  geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  void rand;
  return mesh;
}

export function build() {
  const rand = rng(90210);
  const rockDark = metal('line', { roughness: 0.86, metalness: 0.12 });
  const rockMid = paint('ink2', { roughness: 0.9, metalness: 0.08 });
  const rockWarm = paint('ink3', { roughness: 0.88, metalness: 0.06 });
  const rockAccent = paint('accent', { roughness: 0.9, metalness: 0.04 });
  const scrub = paint('ok', { roughness: 0.92, metalness: 0.02 });

  const root = group('RockCluster');

  const plan = [
    { x: 0, z: 0, r: 1.05, mat: rockMid, detail: 2 },
    { x: 1.15, z: 0.5, r: 0.72, mat: rockMid, detail: 1 },
    { x: -1.2, z: 0.3, r: 0.62, mat: rockMid, detail: 1 },
    { x: 0.4, z: -1.15, r: 0.5, mat: rockDark, detail: 1 },
    { x: -0.7, z: -0.95, r: 0.4, mat: rockDark, detail: 1 },
    { x: 0.9, z: -0.6, r: 0.34, mat: rockMid, detail: 1 },
  ];
  for (const p of plan) {
    const b = boulder(p.mat, p.r, p.detail, rand);
    at(b, { x: p.x, y: p.r * 0.62, z: p.z });
    b.rotation.set(rand() * 0.4, rand() * 3.14, rand() * 0.4);
    root.add(b);
  }
  // a warm strata band across the main boulder
  // A thin warm strata line, not a golden shell: the band is 8% of the rock's
  // height and the accent only touches the sunward side.
  const band = boulder(rockWarm, 1.04, 2, rand);
  band.scale.set(1.0, 0.07, 1.0);
  at(band, { y: 0.62 });
  root.add(band);
  const accent = boulder(rockAccent, 0.55, 1, rand);
  accent.scale.set(1.1, 0.12, 1.1);
  at(accent, { x: 0.35, y: 0.95, z: -0.2 });
  root.add(accent);

  // small scree at the base
  for (let i = 0; i < 10; i += 1) {
    const a = rand() * Math.PI * 2;
    const d = 1.5 + rand() * 1.4;
    const s = 0.1 + rand() * 0.16;
    const chip = boulder(i % 3 ? rockDark : rockMid, s, 0, rand);
    at(chip, { x: Math.cos(a) * d, y: s * 0.7, z: Math.sin(a) * d });
    chip.rotation.set(rand() * 3, rand() * 3, rand() * 3);
    root.add(chip);
  }
  // dry scrub tufts
  for (let i = 0; i < 3; i += 1) {
    const a = 0.7 + i * 1.9;
    for (let b = 0; b < 3; b += 1) {
      const blade = at(cone(0.03, 0.3 + rand() * 0.2, 4, scrub), {
        x: Math.cos(a) * 1.9 + (rand() - 0.5) * 0.2,
        y: 0.2,
        z: Math.sin(a) * 1.9 + (rand() - 0.5) * 0.2,
      });
      blade.rotation.set((rand() - 0.5) * 0.6, rand() * 3, (rand() - 0.5) * 0.4);
      root.add(blade);
    }
  }
  root.add(at(box(0.001, 0.001, 0.001, rockDark), { y: 0 }));

  const base = socket(root, 'base', { y: 0 });

  return finalize(root, { meta, sockets: { base }, clips: [] });
}
