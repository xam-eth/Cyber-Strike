/**
 * impact_burst — the small hit flash every projectile spawns
 * (`game/scripts/weapons/impact_burst.gd`).
 *
 * 0.7 m across at full size, which is the scale the reference impact effect
 * uses against a 1.8 m character: big enough to read, small enough not to hide
 * the target.
 */
import { glow, paint } from '../runtime/materials.js';
import { at, cyl, cone, sphere, torus, group, named } from '../runtime/kit.js';
import { socket, finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'impact_burst',
  category: 'vfx',
  name: 'Impact Burst',
  reference: 'references/vfx/impact_burst.png',
  source: 'game/scripts/weapons/impact_burst.gd',
  targetHeight: 0.7,
  heightTolerance: 0.12,
  origin: 'centre',
  triangleBudget: 12000,
  meshBudget: 60,
  sockets: ['centre'],
  animations: ['burst'],
};

export function build() {
  const hot = glow('ink', 1.6, { base: 'accent' });
  const amber = glow('accent', 1.8);
  const amberDim = glow('accent', 0.7);
  const cyan = glow('info', 1.2);

  const root = named(group('ImpactBurst'), 'ImpactBurst');
  const burst = group('Burst');
  burst.add(at(sphere(0.1, hot, { widthSegments: 12, heightSegments: 8 }), {}));
  burst.add(at(torus(0.19, 0.022, amber, { radial: 5, tubular: 24 }), { rx: Math.PI / 2 }));
  burst.add(at(torus(0.26, 0.016, amberDim, { radial: 5, tubular: 24 }), { rx: 0.5, ry: 0.7 }));
  burst.add(at(torus(0.23, 0.014, cyan, { radial: 5, tubular: 24 }), { rx: -0.6, ry: 1.2 }));
  // sparks: eight short spikes on a ring
  for (let i = 0; i < 8; i += 1) {
    const a = (i / 8) * Math.PI * 2;
    const s = at(cone(0.018, 0.16, 4, i % 2 ? amber : hot), {
      x: Math.cos(a) * 0.16, y: 0.02 + Math.sin(a * 2) * 0.05, z: Math.sin(a) * 0.16,
    });
    s.rotation.set(Math.PI / 2, 0, -a + Math.PI / 2);
    burst.add(s);
  }
  root.add(burst);
  root.add(at(cyl(0.16, 0.02, 0.04, 10, amberDim, {}), { y: -0.18 }));

  return finalize(root, {
    meta,
    sockets: { centre: socket(root, 'centre', {}) },
    clips: [
      clip('burst', 0.3, [
        { node: 'Burst', property: 'scale.x', keys: [[0, 0.25], [0.1, 1.15], [0.3, 0]] },
        { node: 'Burst', property: 'scale.y', keys: [[0, 0.25], [0.1, 1.15], [0.3, 0]] },
        { node: 'Burst', property: 'scale.z', keys: [[0, 0.25], [0.1, 1.15], [0.3, 0]] },
        { node: 'Burst', property: 'rotation.y', keys: [[0, 0], [0.3, 1.4]] },
      ]),
    ],
  });
}

void paint;
