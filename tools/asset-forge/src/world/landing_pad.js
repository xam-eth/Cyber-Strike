/**
 * landing_pad — the east vehicle apron
 * (`game/scenes/worlds/components/landing_pad.tscn`).
 *
 * Reference features: raised hexagonal deck with an inset cyan guide ring,
 * amber corner beacons on stanchions, safety rails, weathered panel seams and a
 * shallow ramp on one side. The pad is a walkable surface, so the deck top is
 * flat and the collision it implies is a box, not a trimesh.
 */
import { at, box, bevelBox, cyl, cone, torus, ring, plate, greebles, group, railing, strut } from '../runtime/kit.js';
import { std, padDeck, beacon, chevrons, guideStrip, crate, tank } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'landing_pad',
  category: 'world',
  name: 'Landing Pad',
  reference: 'references/world/landing_pad.png',
  source: 'game/scenes/worlds/components/landing_pad.tscn',
  targetHeight: 1.2,
  heightTolerance: 0.2,
  triangleBudget: 50000,
  meshBudget: 500,
  sockets: ['pad_centre'],
  animations: ['beacon_cycle'],
  origin: 'ground',
};

export function build() {
  const m = std();
  const root = group('LandingPad');

  /* raised foundation --------------------------------------------------- */
  root.add(at(cyl(7.0, 7.4, 0.6, 6, m.dark), { y: 0.3 }));
  root.add(at(cyl(7.3, 7.3, 0.08, 6, m.mid), { y: 0.63 }));
  // panel seams across the deck: six radial joints
  for (let i = 0; i < 6; i += 1) {
    const a = (i / 6) * Math.PI * 2;
    root.add(at(box(6.4, 0.02, 0.06, m.gap), { x: Math.cos(a) * 3.2, y: 0.68, z: Math.sin(a) * 3.2, ry: -a }));
  }

  /* deck markings ------------------------------------------------------- */
  root.add(at(padDeck(m, { radius: 6.2, name: 'Deck' }), { y: 0.6 }));
  root.add(at(chevrons(m, { width: 3.0, count: 6, depth: 1.0 }), { y: 0.94, z: 4.4 }));
  root.add(at(chevrons(m, { width: 3.0, count: 6, depth: 1.0 }), { y: 0.94, z: -4.4, ry: Math.PI }));
  root.add(at(guideStrip(m, { len: 3.6, width: 0.12 }), { y: 0.95, ry: Math.PI / 2 }));

  /* corner beacons on stanchions ---------------------------------------- */
  for (let i = 0; i < 6; i += 1) {
    const a = (i / 6) * Math.PI * 2 + Math.PI / 6;
    const x = Math.cos(a) * 6.55;
    const z = Math.sin(a) * 6.55;
    const post = group(`Post${i}`);
    post.add(at(cyl(0.1, 0.12, 1.05, 8, m.mid), { y: 0.52 }));
    post.add(at(cyl(0.16, 0.16, 0.08, 8, m.dark), { y: 1.06 }));
    post.add(at(box(0.06, 0.5, 0.3, m.dark), { y: 0.95, ry: -a }));
    at(post, { x, z });
    root.add(post);
    root.add(at(beacon(m, { y: 1.08, r: 0.085, name: i === 0 ? 'Beacon' : `Beacon${i + 1}` }), { x, z }));
  }

  /* safety rails on the far arcs ---------------------------------------- */
  for (const a0 of [2.2, 3.1, 4.0]) {
    const rail = railing(3.0, 0.62, m.dark, { posts: 5 });
    at(rail, { x: Math.cos(a0) * 6.5, y: 0.64, z: Math.sin(a0) * 6.5, ry: -a0 + Math.PI / 2 });
    root.add(rail);
  }

  /* access ramp --------------------------------------------------------- */
  const ramp = group('Ramp');
  ramp.add(at(box(3.0, 0.16, 1.8, m.mid), { y: 0.4, rz: 0.0 }));
  ramp.children[0].rotation.x = 0.34;
  ramp.children[0].position.set(0, 0.42, 1.0);
  for (const sx of [-1, 1]) {
    ramp.add(at(box(0.14, 0.5, 1.9, m.dark), { x: sx * 1.5, y: 0.28, z: 1.0, rx: 0.34 }));
    ramp.add(at(box(0.06, 0.05, 1.9, m.warn), { x: sx * 1.5, y: 0.54, z: 1.0, rx: 0.34 }));
  }
  at(ramp, { y: 0, z: 6.4 });
  root.add(ramp);

  /* ground clutter: fuel tank + crates at the edge ---------------------- */
  root.add(at(tank(m, { r: 0.5, len: 1.5, y: 0 }), { x: -5.4, y: 0, z: 4.2, ry: 0.5 }));
  root.add(at(crate(m, { w: 0.9, h: 0.7, d: 0.7, seed: 81 }), { x: 5.3, y: 0, z: 4.0, ry: -0.3 }));
  root.add(at(crate(m, { w: 0.7, h: 0.55, d: 0.6, seed: 82 }), { x: 5.1, y: 0.7, z: 4.15, ry: 0.2 }));
  root.add(at(cone(0.22, 0.5, 8, m.warn), { x: 4.6, y: 0.25, z: 2.6 }));

  const centre = socket(root, 'pad_centre', { y: 0.94 });

  return finalize(root, {
    meta,
    sockets: { pad_centre: centre },
    clips: [pulseClip('beacon_cycle', 'Beacon', { from: 0.75, to: 1.35, duration: 2.4 })],
  });
}

void plate; void greebles; void torus; void ring; void strut; void bevelBox;
