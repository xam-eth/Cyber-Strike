/**
 * pulse_bolt — the Pulse Rifle's projectile
 * (`game/scenes/weapons/pulse_projectile.tscn`).
 *
 * Sits on its own centre line pointing -Z, 1.2 m long including the trail, so a
 * gameplay system can spawn it at a muzzle socket and travel it along its local
 * -Z without a per-weapon rotation table.
 */
import { paint, glow } from '../runtime/materials.js';
import { at, cyl, cone, sphere, torus, group, named } from '../runtime/kit.js';
import { socket, finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'pulse_bolt',
  category: 'vfx',
  name: 'Pulse Bolt',
  reference: 'references/vfx/pulse_bolt.png',
  source: 'game/scenes/weapons/pulse_projectile.tscn',
  targetHeight: null,
  targetLength: 1.2,
  normaliseBy: 'length',
  origin: 'centre',
  heightTolerance: 0.2,
  triangleBudget: 12000,
  meshBudget: 60,
  sockets: ['head', 'tail'],
  animations: ['travel', 'impact'],
};

export function build() {
  const core = glow('info', 2.4);
  const halo = glow('info', 0.8);
  const shell = paint('ink', { roughness: 0.3, metalness: 0.2 });

  const root = named(group('PulseBolt'), 'PulseBolt');
  const bolt = group('Bolt');
  // head: pointed nose, energy core, halo shell
  bolt.add(at(cone(0.05, 0.22, 10, core), { z: -0.44, rx: -Math.PI / 2 }));
  bolt.add(at(cyl(0.05, 0.05, 0.26, 10, core, { axis: 'z' }), { z: -0.2 }));
  bolt.add(at(cyl(0.085, 0.085, 0.3, 12, halo, { axis: 'z' }), { z: -0.18 }));
  bolt.add(at(sphere(0.075, shell, { widthSegments: 10, heightSegments: 6 }), { z: -0.22 }));
  // afterglow trail
  const trail = group('Trail');
  for (let i = 0; i < 5; i += 1) {
    const r = 0.05 - i * 0.008;
    const t = at(cyl(r, r * 0.4, 0.12, 8, i < 2 ? halo : core, { axis: 'z' }), { z: 0.0 + i * 0.11 });
    t.scale.set(1 - i * 0.14, 1 - i * 0.14, 1);
    trail.add(t);
  }
  bolt.add(trail);
  bolt.add(at(torus(0.08, 0.012, core, { radial: 4, tubular: 14 }), { z: -0.3 }));
  root.add(bolt);

  return finalize(root, {
    meta,
    sockets: {
      head: socket(bolt, 'head', { z: -0.5 }),
      tail: socket(bolt, 'tail', { z: 0.58 }),
    },
    clips: [
      clip('travel', 0.5, [
        { node: 'Trail', property: 'scale.z', keys: [[0, 1], [0.25, 1.18], [0.5, 1]] },
        { node: 'Bolt', property: 'rotation.z', keys: [[0, 0], [0.5, Math.PI * 2]] },
      ]),
      clip('impact', 0.26, [
        { node: 'Bolt', property: 'scale.x', keys: [[0, 1], [0.12, 2.4], [0.26, 0]] },
        { node: 'Bolt', property: 'scale.y', keys: [[0, 1], [0.12, 2.4], [0.26, 0]] },
        { node: 'Bolt', property: 'scale.z', keys: [[0, 1], [0.12, 1.4], [0.26, 0]] },
      ]),
    ],
  });
}
