/**
 * training_drone — the hovering trainer (`game/scenes/enemies/training_drone.tscn`).
 *
 * The scene sets `hover = true`, `hover_lift = 0.72` and fits the model at
 * 1.15 m, so the drone is authored **centred on its own origin** with a
 * spinning hover plate beneath it: the plate is the thing the game bobs, and the
 * origin has to be inside it or the bob looks like a slide.
 *
 * Rebuilt from the reference: a **dark armoured pod** wearing a wide cyan visor
 * lens, a chunky segmented skirt ring, four angled thruster nozzles with amber
 * exhausts, and a stub cannon. The previous build was a pale dome with a blown
 * cyan ball on top — the compare sheet (`review/compare/enemy.png`) showed a
 * different object, not a variant of this one.
 */
import { metal, paint, glow } from '../runtime/materials.js';
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, greebles, group, named, ring } from '../runtime/kit.js';
import { socket, finalize, clip } from '../runtime/rig.js';

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
  // Dark armoured pod: graphite shell over a near-black chassis, with the only
  // pale metal on the skirt edges — the reference is a black object with one
  // hot cyan lens, not a white one.
  const shell = metal('lineHi', { roughness: 0.42, metalness: 0.62 });
  const dark = metal('line', { roughness: 0.6, metalness: 0.5 });
  const chassis = paint('panel2', { roughness: 0.72, metalness: 0.2 });
  const bright = paint('ink3', { roughness: 0.4, metalness: 0.3 });
  const cyan = glow('info', 1.5);
  const cyanDim = glow('info', 0.55);
  const amber = glow('accent', 1.6);
  const warn = paint('accent', { roughness: 0.6, metalness: 0.05 });

  const root = named(group('TrainingDrone'), 'TrainingDrone');
  const body = group('Body');

  /* pod: a squat rounded shell, widest in the middle ------------------------ */
  const hull = group('Hull');
  const pod = at(sphere(0.34, shell, { widthSegments: 16, heightSegments: 12 }), { y: 0.04 });
  pod.scale.set(1.0, 0.82, 0.92);
  hull.add(pod);
  // seam band around the equator + a pale bezel where the lens sits
  hull.add(at(torus(0.335, 0.028, dark, { radial: 5, tubular: 28 }), { y: 0.04, rx: Math.PI / 2 }));
  hull.add(at(bevelBox(0.4, 0.1, 0.12, bright, { radius: 0.02 }), { y: 0.05, z: 0.3 }));
  // the visor: a wide rounded lens, recessed into a dark socket
  hull.add(at(bevelBox(0.42, 0.2, 0.1, dark, { radius: 0.05 }), { y: 0.04, z: 0.28 }));
  const visor = at(sphere(0.17, cyanDim, { widthSegments: 14, heightSegments: 8 }), { y: 0.04, z: 0.31 });
  visor.scale.set(1.25, 0.62, 0.5);
  hull.add(visor);
  const visorCore = at(sphere(0.1, cyan, { widthSegments: 12, heightSegments: 8 }), { y: 0.04, z: 0.35 });
  visorCore.scale.set(1.3, 0.55, 0.4);
  hull.add(visorCore);
  // visor rim, so the lens reads as glass in a housing
  hull.add(at(torus(0.19, 0.018, shell, { radial: 4, tubular: 20 }), { y: 0.04, z: 0.3, rx: Math.PI / 2, ry: 0 }));
  // crown plate + antenna stubs
  hull.add(at(bevelBox(0.22, 0.06, 0.26, bright, { radius: 0.02 }), { y: 0.3 }));
  hull.add(at(cyl(0.012, 0.012, 0.26, 5, dark), { x: -0.09, y: 0.44 }));
  hull.add(at(cyl(0.012, 0.012, 0.18, 5, dark), { x: 0.09, y: 0.4 }));
  hull.add(at(sphere(0.02, cyan, { widthSegments: 6, heightSegments: 4 }), { x: 0.09, y: 0.5 }));
  // side vents
  for (const sx of [-1, 1]) {
    for (let i = 0; i < 3; i += 1) {
      hull.add(at(box(0.03, 0.1, 0.16, dark), { x: sx * 0.3, y: 0.02 + i * 0.06, z: -0.02 }));
    }
  }
  // stub cannon on the right cheek
  hull.add(at(cyl(0.05, 0.055, 0.2, 8, dark, { axis: 'z' }), { x: 0.2, y: -0.02, z: 0.34 }));
  hull.add(at(cyl(0.03, 0.03, 0.06, 8, amber, { axis: 'z' }), { x: 0.2, y: -0.02, z: 0.45 }));
  hull.add(at(greebles({ w: 0.4, h: 0.2, d: 0.4, face: '+y', count: 5, seed: 301, materials: [dark, shell], centre: [0, 0.22, 0] })));
  body.add(hull);

  /* skirt: segmented ring plate carrying four thruster nozzles -------------- */
  const skirt = group('Skirt');
  skirt.position.y = -0.2;
  const SEG = 14;
  for (let i = 0; i < SEG; i += 1) {
    const a = (i / SEG) * Math.PI * 2;
    const seg = at(bevelBox(0.16, 0.12, 0.11, i % 2 ? shell : bright, { radius: 0.02 }), {
      x: Math.cos(a) * 0.42, z: Math.sin(a) * 0.42,
    });
    seg.rotation.y = -a;
    skirt.add(seg);
  }
  skirt.add(at(cyl(0.4, 0.44, 0.06, SEG, dark), { y: 0.06 }));
  for (let i = 0; i < 4; i += 1) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
    const nx = Math.cos(a) * 0.34;
    const nz = Math.sin(a) * 0.34;
    skirt.add(at(cyl(0.1, 0.12, 0.14, 10, dark), { x: nx, y: -0.08, z: nz }));
    skirt.add(at(cyl(0.08, 0.08, 0.02, 10, amber), { x: nx, y: -0.16, z: nz }));
    skirt.add(strut([Math.cos(a) * 0.2, 0.06, Math.sin(a) * 0.2], [nx, -0.02, nz], 0.03, shell, { segments: 6 }));
  }
  skirt.add(at(ring(0.3, 0.4, cyanDim, { segments: 32 }), { y: -0.02 }));
  body.add(skirt);
  root.add(body);

  /* hover ring: the part that spins ---------------------------------------- */
  const hoverRing = group('HoverRing');
  hoverRing.position.y = -0.34;
  hoverRing.add(at(torus(0.46, 0.02, shell, { radial: 5, tubular: 32 }), { rx: Math.PI / 2 }));
  for (let i = 0; i < 8; i += 1) {
    const a = (i / 8) * Math.PI * 2;
    hoverRing.add(at(box(0.05, 0.025, 0.06, cyanDim), { x: Math.cos(a) * 0.46, z: Math.sin(a) * 0.46, ry: -a }));
  }
  root.add(hoverRing);

  /* thruster exhaust glow under the hull ------------------------------------ */
  const thrust = group('Thrust');
  thrust.position.y = -0.36;
  for (let i = 0; i < 4; i += 1) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
    const flame = at(cone(0.06, 0.16, 8, amber), { x: Math.cos(a) * 0.34, z: Math.sin(a) * 0.34, rx: Math.PI });
    thrust.add(flame);
  }
  thrust.add(at(cyl(0.2, 0.12, 0.05, 12, glow('accent', 0.4)), { y: 0.05 }));
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
  const sensor = socket(hull, 'sensor', { y: 0.04, z: 0.38 });

  return finalize(root, { meta, sockets: { hover_ring: ringSocket, sensor }, clips });
}

void bevelBox;
