/**
 * arc_chain — the Arc Shooter's chaining beam
 * (`game/scenes/weapons/arc_projectile.tscn`).
 *
 * Two forks leaving one origin, sized to the weapon's real chain radius (5 m,
 * `arc_shooter.tres`) so the effect shows what the gameplay rule actually
 * covers. Fork angles are 28° apart, the same spread the chain search produces
 * between two nearby targets.
 */
import { glow, paint } from '../runtime/materials.js';
import { at, cyl, cone, sphere, torus, strut, group, named, rng } from '../runtime/kit.js';
import { socket, finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'arc_chain',
  category: 'vfx',
  name: 'Arc Chain',
  reference: 'references/vfx/arc_chain.png',
  source: 'game/scenes/weapons/arc_projectile.tscn',
  targetHeight: null,
  targetLength: 6.0,
  normaliseBy: 'length',
  origin: 'none',
  heightTolerance: 0.4,
  triangleBudget: 20000,
  meshBudget: 80,
  sockets: ['origin', 'fork_a', 'fork_b'],
  animations: ['strike', 'fork'],
};

/** A jagged lightning path from A to B, deterministic per seed. */
function arcPath(from, to, { seed = 1, segments = 9, jitter = 0.22, radius = 0.022, material, name }) {
  const rand = rng(seed);
  const g = named(group(name), name);
  let prev = from;
  for (let i = 1; i <= segments; i += 1) {
    const t = i / segments;
    const next = [
      from[0] + (to[0] - from[0]) * t + (i === segments ? 0 : (rand() - 0.5) * jitter),
      from[1] + (to[1] - from[1]) * t + (i === segments ? 0 : (rand() - 0.5) * jitter),
      from[2] + (to[2] - from[2]) * t + (i === segments ? 0 : (rand() - 0.5) * jitter),
    ];
    g.add(strut(prev, next, radius * (1 - t * 0.4), material, { segments: 5 }));
    prev = next;
  }
  return g;
}

export function build() {
  const spark = glow('info', 2.6);
  const sparkDim = glow('info', 1.1);
  const shell = paint('ink', { roughness: 0.4, metalness: 0.1 });

  const root = named(group('ArcChain'), 'ArcChain');
  const origin = [0, 0, 0];
  const forkA = [-1.3, 0.1, -5.8];
  const forkB = [1.35, -0.1, -5.7];

  const bolt = group('Bolt');
  bolt.add(arcPath(origin, forkA, { seed: 11, material: spark, name: 'Main' }));
  bolt.add(arcPath(origin, forkA, { seed: 12, material: sparkDim, radius: 0.045, jitter: 0.3, name: 'MainHalo' }));
  bolt.add(arcPath([0, 0, -0.4], forkB, { seed: 21, material: spark, name: 'ForkA' }));
  bolt.add(arcPath([0, 0, -0.4], forkB, { seed: 22, material: sparkDim, radius: 0.04, jitter: 0.28, name: 'ForkAHalo' }));
  bolt.add(arcPath([0, 0, -2.4], [0.9, 0.6, -4.4], { seed: 31, material: sparkDim, radius: 0.016, name: 'ForkB' }));
  root.add(bolt);

  root.add(at(sphere(0.14, spark, { widthSegments: 12, heightSegments: 8 }), { z: -0.02 }));
  root.add(at(torus(0.2, 0.02, sparkDim, { radial: 4, tubular: 18 }), { z: -0.02 }));
  root.add(at(cyl(0.06, 0.12, 0.24, 10, shell, { axis: 'z' }), { z: 0.12 }));
  // contact flashes at each fork end
  root.add(at(sphere(0.16, spark, { widthSegments: 10, heightSegments: 6 }), { x: forkA[0], y: forkA[1], z: forkA[2] }));
  root.add(at(sphere(0.12, spark, { widthSegments: 10, heightSegments: 6 }), { x: forkB[0], y: forkB[1], z: forkB[2] }));

  return finalize(root, {
    meta,
    sockets: {
      origin: socket(root, 'origin', { z: -0.02 }),
      fork_a: socket(root, 'fork_a', { x: forkA[0], y: forkA[1], z: forkA[2] }),
      fork_b: socket(root, 'fork_b', { x: forkB[0], y: forkB[1], z: forkB[2] }),
    },
    clips: [
      clip('strike', 0.22, [
        { node: 'Bolt', property: 'scale.x', keys: [[0, 0.4], [0.06, 1.06], [0.22, 1]] },
        { node: 'Bolt', property: 'scale.z', keys: [[0, 0.2], [0.1, 1.04], [0.22, 1]] },
      ]),
      clip('fork', 0.4, [
        { node: 'ForkA', property: 'scale.z', keys: [[0, 0], [0.16, 1], [0.4, 0]] },
        { node: 'ForkA', property: 'scale.x', keys: [[0, 0], [0.16, 1], [0.4, 0]] },
        { node: 'ForkB', property: 'scale.z', keys: [[0, 0], [0.24, 1], [0.4, 0]] },
      ]),
    ],
  });
}

void cone;
