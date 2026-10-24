/**
 * crystal_cluster — tapered mineral shards on geological roots
 * (`game/scenes/worlds/components/crystal_cluster.tscn`).
 *
 * Shards are lathed hexagonal prisms with a pointed tip, not cones: the facet
 * edges are what make it read as crystal at gameplay distance.
 */
import { at, cyl, cone, sphere, group, rng, plate } from '../runtime/kit.js';
import { std } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';
import * as THREE from 'three';

export const meta = {
  id: 'crystal_cluster',
  category: 'world',
  name: 'Crystal Cluster',
  reference: 'references/world/crystal_cluster.png',
  source: 'game/scenes/worlds/components/crystal_cluster.tscn',
  targetHeight: 3.2,
  heightTolerance: 0.5,
  triangleBudget: 40000,
  meshBudget: 300,
  sockets: ['harvest_point'],
  animations: ['shimmer'],
};

/** One shard: hex prism body + faceted tip, returned as a group. */
function shard(material, { r = 0.22, bodyH = 1.2, tipH = 0.5, seed = 1 } = {}) {
  const g = group('Shard');
  g.add(at(cyl(r, r, bodyH, 6, material), { y: bodyH / 2 }));
  g.add(at(cone(r, tipH, 6, material), { y: bodyH + tipH / 2 }));
  // a lighter facet strip down one edge
  g.add(at(cyl(r * 0.28, r * 0.28, bodyH * 0.9, 4, material, { open: true }), { x: r * 0.62, y: bodyH / 2 }));
  void seed;
  return g;
}

export function build() {
  const m = std();
  const rand = rng(31415);
  const root = group('CrystalCluster');

  /* rock base ----------------------------------------------------------- */
  const base = group('RockBase');
  for (let i = 0; i < 7; i += 1) {
    const a = (i / 7) * Math.PI * 2;
    const boulder = new THREE.Mesh(
      new THREE.DodecahedronGeometry(0.5 + rand() * 0.42, 0),
      m.dark,
    );
    boulder.castShadow = true;
    boulder.receiveShadow = true;
    at(boulder, { x: Math.cos(a) * (0.7 + rand() * 0.5), y: 0.18 + rand() * 0.12, z: Math.sin(a) * (0.7 + rand() * 0.5) });
    boulder.rotation.set(rand() * 3, rand() * 3, rand() * 3);
    base.add(boulder);
  }
  base.add(at(cyl(1.15, 1.35, 0.22, 8, m.mid), { y: 0.11 }));
  root.add(base);

  /* shards -------------------------------------------------------------- */
  const crystals = group('Crystals');
  const plan = [
    { x: 0.0, z: 0.0, r: 0.30, h: 1.9, mat: m.cyanDim, lean: 0.0 },
    { x: 0.42, z: 0.18, r: 0.20, h: 1.3, mat: m.greenDim, lean: 0.16 },
    { x: -0.38, z: 0.26, r: 0.22, h: 1.5, mat: m.cyanDim, lean: -0.2 },
    { x: 0.16, z: -0.44, r: 0.17, h: 1.0, mat: m.greenDim, lean: 0.12 },
    { x: -0.22, z: -0.4, r: 0.15, h: 0.8, mat: m.cyanDim, lean: -0.1 },
    { x: 0.62, z: -0.2, r: 0.13, h: 0.7, mat: m.greenDim, lean: 0.34 },
    { x: -0.6, z: -0.12, r: 0.12, h: 0.55, mat: m.cyanDim, lean: -0.3 },
  ];
  for (const p of plan) {
    const s = shard(p.mat, { r: p.r, bodyH: p.h, tipH: p.r * 1.9 });
    at(s, { x: p.x, y: 0.22, z: p.z, rz: p.lean, ry: rand() * 3.14 });
    crystals.add(s);
    // matching inner glow core, slightly smaller
    const inner = shard(m.cyan, { r: p.r * 0.45, bodyH: p.h * 0.86, tipH: p.r * 0.9 });
    at(inner, { x: p.x, y: 0.24, z: p.z, rz: p.lean, ry: rand() * 3.14 });
    crystals.add(inner);
  }
  root.add(crystals);

  /* mineral roots ------------------------------------------------------- */
  const roots = group('Roots');
  for (let i = 0; i < 5; i += 1) {
    const a = (i / 5) * Math.PI * 2 + 0.4;
    const r = at(cone(0.06, 0.8, 4, m.mid), { x: Math.cos(a) * 1.3, y: 0.1, z: Math.sin(a) * 1.3 });
    r.rotation.set(Math.PI / 2 - 0.2, -a, 0);
    roots.add(r);
  }
  root.add(roots);

  const harvest = socket(root, 'harvest_point', { y: 2.4 });

  return finalize(root, {
    meta,
    sockets: { harvest_point: harvest },
    clips: [pulseClip('shimmer', 'Crystals', { from: 0.97, to: 1.03, duration: 3.1 })],
  });
}

void plate;
