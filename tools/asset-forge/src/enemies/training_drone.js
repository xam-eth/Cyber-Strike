/**
 * training_drone — the hovering trainer (`game/scenes/enemies/training_drone.tscn`).
 *
 * The scene sets `hover = true`, `hover_lift = 0.72` and fits the model at
 * 1.15 m, so the drone is authored **centred on its own origin** with a
 * spinning hover ring beneath it: the ring is the thing the game bobs, and the
 * origin has to be inside it or the bob looks like a slide.
 */
import { metal, paint, glow } from '../runtime/materials.js';
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, greebles, group, named, ring } from '../runtime/kit.js';
import { socket, finalize, clip, spinClip, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'training_drone',
  category: 'enemy',
  name: 'Training Drone',
  reference: 'references/enemies/training_drone.png',
  source: 'game/scenes/enemies/training_drone.tscn',
  targetHeight: 1.15,
  heightTolerance: 0.1,
  origin: 'centre',
  triangleBudget: 35000,
  meshBudget: 220,
  sockets: ['hover_ring', 'sensor'],
  animations: ['hover', 'hit', 'death'],
};

export function build() {
  const shell = metal('lineHi', { roughness: 0.42, metalness: 0.62 });
  const dark = metal('line', { roughness: 0.6, metalness: 0.5 });
  const bright = paint('ink2', { roughness: 0.4, metalness: 0.25 });
  const cyan = glow('info', 1.9);
  const cyanDim = glow('info', 0.7);
  const eye = glow('danger', 2.0);
  const warn = paint('accent', { roughness: 0.6, metalness: 0.05 });

  const root = named(group('TrainingDrone'), 'TrainingDrone');
  const body = group('Body');

  /* core chassis: a squat lens with a cyan sensor eye --------------------- */
  const hull = group('Hull');
  hull.add(at(cyl(0.3, 0.34, 0.24, 16, bright, {}), {}));
  hull.add(at(torus(0.33, 0.03, shell, { radial: 5, tubular: 24 }), { rx: Math.PI / 2 }));
  hull.add(at(cyl(0.18, 0.24, 0.1, 16, dark, {}), { y: 0.16 }));
  hull.add(at(cyl(0.1, 0.1, 0.05, 12, cyanDim, {}), { y: 0.22 }));
  hull.add(at(sphere(0.14, cyan, { widthSegments: 12, heightSegments: 8 }), { y: 0.5 }));
  hull.add(at(cyl(0.14, 0.18, 0.2, 12, dark, {}), { y: 0.36 }));
  hull.add(at(sphere(0.055, eye, { widthSegments: 10, heightSegments: 6 }), { y: -0.04, z: 0.33 }));
  hull.add(at(box(0.2, 0.05, 0.04, warn), { y: 0.06, z: 0.31 }));
  hull.add(at(greebles({ w: 0.5, h: 0.2, d: 0.5, face: '+y', count: 5, seed: 301, materials: [dark, shell], centre: [0, 0.12, 0] })));
  body.add(hull);

  /* three hover pods on outriggers ---------------------------------------- */
  for (let i = 0; i < 3; i += 1) {
    const a = (i / 3) * Math.PI * 2 + Math.PI / 6;
    const pod = group(`Pod${i + 1}`);
    pod.add(strut([Math.cos(a) * 0.2, 0, Math.sin(a) * 0.2], [Math.cos(a) * 0.42, 0.02, Math.sin(a) * 0.42], 0.035, shell, { segments: 6 }));
    pod.add(at(cyl(0.1, 0.12, 0.16, 10, bright, {}), { x: Math.cos(a) * 0.46, y: 0.02, z: Math.sin(a) * 0.46 }));
    pod.add(at(cyl(0.07, 0.07, 0.03, 10, cyan, {}), { x: Math.cos(a) * 0.46, y: 0.1, z: Math.sin(a) * 0.46 }));
    pod.add(at(cyl(0.06, 0.08, 0.04, 10, dark, {}), { x: Math.cos(a) * 0.46, y: -0.07, z: Math.sin(a) * 0.46 }));
    body.add(pod);
  }
  root.add(body);

  /* hover ring: the part that spins ---------------------------------------- */
  const hoverRing = group('HoverRing');
  hoverRing.position.y = -0.3;
  hoverRing.add(at(torus(0.42, 0.022, shell, { radial: 5, tubular: 32 }), { rx: Math.PI / 2 }));
  for (let i = 0; i < 6; i += 1) {
    const a = (i / 6) * Math.PI * 2;
    hoverRing.add(at(box(0.05, 0.03, 0.05, cyanDim), { x: Math.cos(a) * 0.42, z: Math.sin(a) * 0.42, ry: -a }));
  }
  hoverRing.add(at(ring(0.3, 0.38, cyanDim, { segments: 32 }), { y: -0.01 }));
  root.add(hoverRing);

  /* thruster glow under the hull ------------------------------------------- */
  const thrust = group('Thrust');
  thrust.position.y = -0.14;
  thrust.add(at(cone(0.2, 0.16, 12, cyanDim), { rx: Math.PI }));
  thrust.add(at(cyl(0.16, 0.16, 0.01, 12, cyan), { y: 0.08 }));
  root.add(thrust);

  const clips = [
    // hover: the whole body lifts and settles; the game adds its own bob too,
    // so this stays small and the ring does the visible work
    clip('hover', 2.2, [
      { node: 'Body', property: 'position.y', keys: [[0, 0], [1.1, 0.05], [2.2, 0]] },
      { node: 'Body', property: 'rotation.y', keys: [[0, -0.1], [1.1, 0.1], [2.2, -0.1]] },
      { node: 'Thrust', property: 'scale.y', keys: [[0, 1], [1.1, 1.35], [2.2, 1]] },
      { node: 'HoverRing', property: 'rotation.y', keys: [[0, 0], [2.2, Math.PI * 2]] },
    ]),
    clip('hit', 0.3, [
      { node: 'Body', property: 'position.x', keys: [[0, 0], [0.08, 0.06], [0.3, 0]] },
      { node: 'Body', property: 'rotation.z', keys: [[0, 0], [0.08, 0.2], [0.3, 0]] },
    ]),
    clip('death', 0.9, [
      { node: 'Body', property: 'rotation.z', keys: [[0, 0], [0.9, 1.6]] },
      { node: 'Body', property: 'position.y', keys: [[0, 0], [0.9, -0.9]] },
      { node: 'HoverRing', property: 'scale.x', keys: [[0, 1], [0.9, 0.2]] },
      { node: 'HoverRing', property: 'scale.z', keys: [[0, 1], [0.9, 0.2]] },
    ]),
  ];

  const ringSocket = socket(hoverRing, 'hover_ring', { y: 0 });
  const sensor = socket(hull, 'sensor', { y: -0.04, z: 0.36 });

  return finalize(root, { meta, sockets: { hover_ring: ringSocket, sensor }, clips });
}

void spinClip; void pulseClip; void bevelBox;
