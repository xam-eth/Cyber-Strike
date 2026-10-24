/**
 * alien_flora — luminous buds, varied leaves, arching fronds
 * (`game/scenes/worlds/components/alien_flora.tscn`).
 *
 * Foliage is built from curved, tapered blades rather than stacked boxes: it is
 * the only organic silhouette in the world kit and it has to stay organic at
 * 1.8 m, or the alien zones read as more architecture.
 */
import { at, cyl, sphere, cone, group, rng } from '../runtime/kit.js';
import { std } from '../runtime/parts.js';
import { socket, finalize, sweepClip } from '../runtime/rig.js';
import * as THREE from 'three';

export const meta = {
  id: 'alien_flora',
  category: 'world',
  name: 'Alien Flora',
  reference: 'references/world/alien_flora.png',
  source: 'game/scenes/worlds/components/alien_flora.tscn',
  targetHeight: 1.8,
  heightTolerance: 0.3,
  triangleBudget: 30000,
  meshBudget: 250,
  sockets: ['root'],
  animations: ['sway'],
};

/** A tapered blade curved along its own length, opening toward +Y. */
function frond(material, { length = 1.1, width = 0.16, curl = 0.55, segments = 9 } = {}) {
  const points = [];
  for (let i = 0; i <= segments; i += 1) {
    const t = i / segments;
    points.push(new THREE.Vector2(
      Math.max(0.001, width * (1 - t * 0.92)),
      t * length,
    ));
  }
  const geo = new THREE.LatheGeometry(points, 4);
  // squash the lathe into a blade and curl it back
  geo.scale(1, 1, 0.35);
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i += 1) {
    const y = pos.getY(i);
    const t = y / length;
    pos.setZ(i, pos.getZ(i) - curl * t * t * length * 0.6);
    pos.setX(i, pos.getX(i) * (1 + t * 0.2));
  }
  geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

export function build() {
  const m = std();
  const rand = rng(2718);
  const root = group('AlienFlora');

  /* soil patch ---------------------------------------------------------- */
  const soil = group('Soil');
  soil.add(at(cyl(0.62, 0.74, 0.16, 9, m.dark), { y: 0.08 }));
  soil.add(at(cyl(0.5, 0.5, 0.05, 9, m.mid), { y: 0.17 }));
  root.add(soil);

  /* stems + arching fronds ---------------------------------------------- */
  const canopy = group('Canopy');
  const stems = [
    { x: 0.0, z: 0.0, h: 0.95, lean: 0.0 },
    { x: 0.22, z: 0.12, h: 0.7, lean: 0.22 },
    { x: -0.2, z: -0.06, h: 0.78, lean: -0.18 },
    { x: 0.06, z: -0.24, h: 0.6, lean: 0.1 },
  ];
  stems.forEach((s, i) => {
    const stem = group(`Stem${i + 1}`);
    stem.add(at(cyl(0.028, 0.045, s.h, 6, m.mid), { y: s.h / 2 }));
    const blades = 4;
    for (let b = 0; b < blades; b += 1) {
      const f = frond(b % 2 ? m.greenDim : m.cyanDim, {
        length: 0.55 + rand() * 0.5, width: 0.1 + rand() * 0.07, curl: 0.4 + rand() * 0.5,
      });
      at(f, { y: s.h * (0.55 + b * 0.12) });
      f.rotation.set(0.5 + rand() * 0.4, (b / blades) * Math.PI * 2 + rand(), s.lean);
      stem.add(f);
    }
    // luminous bud at the crown
    stem.add(at(sphere(0.075 + rand() * 0.03, m.cyan, { widthSegments: 10, heightSegments: 6 }), { y: s.h }));
    stem.add(at(cone(0.05, 0.14, 5, m.green, { }), { y: s.h + 0.11, rx: Math.PI }));
    at(stem, { x: s.x, y: 0.18, z: s.z, rz: s.lean * 0.4 });
    canopy.add(stem);
  });
  root.add(canopy);

  /* low ground leaves --------------------------------------------------- */
  for (let i = 0; i < 7; i += 1) {
    const a = (i / 7) * Math.PI * 2 + 0.3;
    const leaf = frond(i % 2 ? m.greenDim : m.cyanDim, { length: 0.42 + rand() * 0.2, width: 0.1, curl: 1.3 });
    at(leaf, { x: Math.cos(a) * 0.4, y: 0.17, z: Math.sin(a) * 0.4 });
    leaf.rotation.set(1.15 + rand() * 0.2, -a, 0);
    root.add(leaf);
  }

  /* spore stalks -------------------------------------------------------- */
  for (let i = 0; i < 3; i += 1) {
    const a = (i / 3) * Math.PI * 2 + 1.1;
    root.add(at(cyl(0.012, 0.018, 0.34, 4, m.mid), { x: Math.cos(a) * 0.56, y: 0.34, z: Math.sin(a) * 0.56 }));
    root.add(at(sphere(0.035, m.cyan, { widthSegments: 8, heightSegments: 5 }), { x: Math.cos(a) * 0.56, y: 0.52, z: Math.sin(a) * 0.56 }));
  }

  const anchor = socket(root, 'root', { y: 0.1 });

  return finalize(root, {
    meta,
    sockets: { root: anchor },
    clips: [sweepClip('sway', 'Canopy', { axis: 'z', amplitude: 0.045, duration: 5.5 })],
  });
}
