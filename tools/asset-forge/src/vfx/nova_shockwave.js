/**
 * nova_shockwave — the Nova Launcher's 4 m splash ring
 * (`game/scenes/weapons/nova_projectile.tscn`, `nova_shockwave.gd`).
 *
 * Authored at the real gameplay radius (4 m tall/wide) so a designer can drop
 * it into a scene and read the actual splash size, not a schematic of it.
 */
import { glow, paint } from '../runtime/materials.js';
import { at, cyl, torus, ring, sphere, group, named } from '../runtime/kit.js';
import { socket, finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'nova_shockwave',
  category: 'vfx',
  name: 'Nova Shockwave',
  reference: 'references/vfx/nova_shockwave.png',
  source: 'game/scenes/weapons/nova_projectile.tscn',
  targetHeight: 4.0,
  heightTolerance: 0.5,
  origin: 'centre',
  triangleBudget: 20000,
  meshBudget: 80,
  sockets: ['centre'],
  animations: ['expand', 'fade'],
};

export function build() {
  const amber = glow('accent', 2.0);
  const amberDim = glow('accent', 0.9);
  const cyan = glow('info', 1.6);
  const shell = paint('ink', { roughness: 0.4, metalness: 0.1 });

  const root = named(group('NovaShockwave'), 'NovaShockwave');
  const wave = group('Wave');
  // ground ring at the splash radius
  wave.add(at(ring(1.86, 2.0, amber, { segments: 64 }), { y: -1.98 }));
  wave.add(at(ring(1.6, 1.72, amberDim, { segments: 64 }), { y: -1.96 }));
  // expanding torus shell
  wave.add(at(torus(1.9, 0.05, amber, { radial: 6, tubular: 64 }), { y: -1.98, rx: Math.PI / 2 }));
  const dome = group('Dome');
  dome.add(at(sphere(1.9, amberDim, { widthSegments: 28, heightSegments: 12 }), { y: -1.96, sy: 0.42 }));
  wave.add(dome);
  root.add(wave);

  const core = group('Core');
  core.add(at(sphere(0.26, cyan, { widthSegments: 14, heightSegments: 10 })));
  core.add(at(cyl(0.1, 0.1, 0.5, 10, amberDim, { axis: 'y' })));
  root.add(core);
  root.add(at(cyl(0.03, 0.03, 3.6, 6, amberDim, {}), { y: 0.2 }));
  root.add(at(torus(0.9, 0.03, amberDim, { radial: 4, tubular: 40 }), { y: -1.9, rx: Math.PI / 2 }));
  root.add(at(sphere(0.35, shell, { widthSegments: 10, heightSegments: 6 }), { y: -2.0, sy: 0.1 }));

  return finalize(root, {
    meta,
    sockets: { centre: socket(root, 'centre', { y: 0 }) },
    clips: [
      clip('expand', 0.55, [
        { node: 'Wave', property: 'scale.x', keys: [[0, 0.15], [0.55, 1]] },
        { node: 'Wave', property: 'scale.z', keys: [[0, 0.15], [0.55, 1]] },
        { node: 'Dome', property: 'scale.y', keys: [[0, 0.2], [0.55, 1]] },
        { node: 'Core', property: 'scale.x', keys: [[0, 1.4], [0.55, 0.4]] },
      ]),
      clip('fade', 0.5, [
        { node: 'Wave', property: 'scale.x', keys: [[0, 1], [0.5, 1.35]] },
        { node: 'Wave', property: 'scale.z', keys: [[0, 1], [0.5, 1.35]] },
        { node: 'Dome', property: 'scale.y', keys: [[0, 1], [0.5, 0.1]] },
        { node: 'Core', property: 'scale.y', keys: [[0, 0.4], [0.5, 0]] },
      ]),
    ],
  });
}
