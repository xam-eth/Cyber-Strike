/**
 * wrecked_transport — broken hull, glazed cockpit, snapped wing, hot engine
 * damage (`game/scenes/worlds/components/wrecked_transport.tscn`).
 *
 * The wreck is half-buried at an angle: `origin: 'ground'` with the whole body
 * rotated, so the lowest torn plate touches y=0 and the tail rides up.
 */
import { at, box, bevelBox, cyl, cone, torus, strut, plate, greebles, group, cable, rng } from '../runtime/kit.js';
import { std, beacon } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'wrecked_transport',
  category: 'world',
  name: 'Wrecked Transport',
  reference: 'references/world/wrecked_transport.png',
  source: 'game/scenes/worlds/components/wrecked_transport.tscn',
  targetHeight: 3.4,
  heightTolerance: 0.6,
  triangleBudget: 70000,
  meshBudget: 600,
  sockets: ['hull_cut', 'wing_l'],
  animations: ['ember_flicker'],
};

export function build() {
  const m = std();
  const rand = rng(4242);
  const root = group('WreckedTransport');

  /* body: tilted so the nose is buried and the tail lifts --------------- */
  const body = group('Hull');
  body.position.set(0, 0.86, 0);
  body.rotation.set(0.2, 0.42, 0.19);

  body.add(at(bevelBox(2.0, 1.5, 5.4, m.mid, { radius: 0.06 }), { }));
  // torn plating along the top seam — a wreck is defined by broken edges
  for (let i = 0; i < 14; i += 1) {
    const t = at(box(0.12 + rand() * 0.25, 0.5 + rand() * 0.7, 0.06, i % 2 ? m.bright : m.mid), {
      x: -0.85 + rand() * 1.7, y: 0.78, z: -2.4 + i * 0.36,
    });
    t.rotation.set((rand() - 0.5) * 1.2, rand() * 3.14, (rand() - 0.5) * 1.4);
    body.add(t);
  }
  // creased belly plate and exposed frame ribs where the hull split
  body.add(at(box(2.04, 0.18, 1.4, m.dark), { y: -0.5, z: 0.6 }));
  for (let i = 0; i < 4; i += 1) {
    body.add(at(box(1.9, 0.08, 0.1, m.dark), { y: 0.3 + i * 0.16, z: -0.2 + i * 0.3, rx: 0.2 }));
  }
  body.add(at(box(2.06, 0.1, 5.2, m.dark), { y: 0.72 }));
  body.add(at(box(2.02, 0.12, 5.0, m.bright), { y: -0.72 }));
  // spine and ribs, plus torn plating
  for (let i = 0; i < 7; i += 1) {
    body.add(at(box(2.04, 0.5, 0.12, m.dark), { y: 0.2, z: -2.2 + i * 0.74 }));
  }
  body.add(at(box(1.1, 0.16, 4.0, m.bright), { y: 0.82 }));
  // cockpit glazing at the front-bottom
  const cockpit = group('Cockpit');
  cockpit.add(at(box(1.7, 0.7, 0.1, m.gap), { y: 0.2, z: 2.68 }));
  cockpit.add(at(box(1.6, 0.6, 0.06, m.cyan), { y: 0.2, z: 2.72 }));
  for (let i = 0; i < 3; i += 1) cockpit.add(at(box(0.06, 0.66, 0.05, m.dark), { x: -0.55 + i * 0.55, y: 0.2, z: 2.76 }));
  body.add(cockpit);
  // torn open bay on the far side
  body.add(at(box(0.1, 1.2, 1.8, m.gap), { x: -1.02, y: 0.1, z: -0.4 }));
  for (let i = 0; i < 5; i += 1) {
    const shard = at(box(0.06, 0.5 + rand() * 0.5, 0.4, m.bright), { x: -1.1, y: 0.2 + rand() * 0.3, z: -1.2 + i * 0.42 });
    shard.rotation.set(rand() * 0.6, rand() * 0.4, rand() * 0.8);
    body.add(shard);
  }
  // engines: two bells at the back, one burnt
  for (const sx of [-1, 1]) {
    const eng = group(sx < 0 ? 'EngineL' : 'EngineR');
    eng.add(at(cyl(0.36, 0.56, 0.7, 12, m.dark, { axis: 'z' }), { x: sx * 0.62, y: -0.1, z: -2.95 }));
    eng.add(at(cyl(0.5, 0.5, 0.12, 12, m.warn, { axis: 'z' }), { x: sx * 0.62, y: -0.1, z: -3.28 }));
    eng.add(at(cyl(0.3, 0.3, 0.1, 12, m.dark, { axis: 'z' }), { x: sx * 0.62, y: -0.1, z: -3.34 }));
    body.add(eng);
  }
  // tail fin
  const fin = at(box(0.14, 1.3, 1.1, m.bright), { y: 1.0, z: -2.1 });
  fin.rotation.x = -0.2;
  body.add(fin);
  body.add(at(box(0.16, 0.5, 0.9, m.dark), { y: 1.6, z: -2.2 }));
  body.add(at(beacon(m, { y: 1.75, r: 0.06, name: 'Ember' }), { z: -2.5 }));
  root.add(body);

  /* snapped wing lying on the ground ----------------------------------- */
  const wing = group('WingL');
  wing.add(at(bevelBox(3.0, 0.16, 1.5, m.mid, { radius: 0.03 }), { }));
  // snapped root end: jagged stubs instead of a clean cut
  for (let i = 0; i < 5; i += 1) {
    const stub = at(box(0.1 + rand() * 0.2, 0.16, 0.1 + rand() * 0.25, m.bright), { x: -1.5 + rand() * 0.2, y: 0.02, z: -0.6 + i * 0.3 });
    stub.rotation.set(rand() * 0.8, rand() * 1.2, rand() * 0.9);
    wing.add(stub);
  }
  wing.add(at(box(3.0, 0.08, 0.2, m.dark), { z: 0.6 }));
  wing.add(at(box(0.5, 0.3, 0.9, m.dark), { x: 1.2, y: 0.1 }));
  wing.add(at(cyl(0.22, 0.26, 0.6, 10, m.bright, { axis: 'z' }), { x: -0.9, z: 0.7 }));
  for (let i = 0; i < 4; i += 1) wing.add(at(box(0.5, 0.05, 0.9, m.dark), { x: -1.4 + i * 0.7, y: 0.09, z: 0.18 }));
  at(wing, { x: -2.5, y: 0.12, z: 1.5, ry: 0.9, rz: 0.05 });
  root.add(wing);

  /* scattered debris ---------------------------------------------------- */
  const debris = group('Debris');
  for (let i = 0; i < 9; i += 1) {
    const p = at(box(0.3 + rand() * 0.5, 0.06 + rand() * 0.1, 0.25 + rand() * 0.4, i % 3 ? m.mid : m.bright), {
      x: (rand() - 0.5) * 6.5, y: 0.04 + rand() * 0.06, z: (rand() - 0.5) * 6.5,
    });
    p.rotation.set(rand() * 0.2, rand() * 3.14, rand() * 0.2);
    debris.add(p);
  }
  for (let i = 0; i < 4; i += 1) {
    debris.add(at(cone(0.14 + rand() * 0.12, 0.5 + rand() * 0.4, 5, m.dark), {
      x: (rand() - 0.5) * 5, z: (rand() - 0.5) * 5,
    }));
  }
  root.add(debris);

  root.add(cable([-1.0, 0.9, 0.4], [-1.9, 0.2, 1.4], 0.03, m.gap, { sag: 0.2 }));
  root.add(at(box(0.06, 0.06, 1.6, m.warn), { x: 0.9, y: 0.5, z: 0.2, ry: 0.6 }));

  const cut = socket(body, 'hull_cut', { x: -1.0, y: 0.1, z: -0.4 });
  const wingSocket = socket(root, 'wing_l', { x: -3.1, y: 0.2, z: 1.9 });

  return finalize(root, {
    meta,
    sockets: { hull_cut: cut, wing_l: wingSocket },
    clips: [pulseClip('ember_flicker', 'Ember', { from: 0.6, to: 1.5, duration: 0.9 })],
  });
}

void plate; void greebles; void torus; void strut;
