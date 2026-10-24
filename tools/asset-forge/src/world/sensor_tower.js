/**
 * sensor_tower — observation shaft with radar plates, dishes and a beacon
 * (`game/scenes/worlds/components/sensor_tower.tscn`).
 */
import { at, box, bevelBox, cyl, cone, torus, strut, greebles, boltRing, group, railing, truss, vent } from '../runtime/kit.js';
import { std, beacon, footing, mast, chevrons } from '../runtime/parts.js';
import { socket, finalize, pulseClip, spinClip, sweepClip } from '../runtime/rig.js';

export const meta = {
  id: 'sensor_tower',
  category: 'world',
  name: 'Sensor Tower',
  reference: 'references/world/sensor_tower.png',
  source: 'game/scenes/worlds/components/sensor_tower.tscn',
  targetHeight: 11.0,
  heightTolerance: 1.4,
  triangleBudget: 60000,
  meshBudget: 700,
  sockets: ['dish', 'beacon'],
  animations: ['dish_scan', 'beacon_pulse'],
};

export function build() {
  const m = std();
  const root = group('SensorTower');

  root.add(at(cyl(1.9, 2.1, 0.4, 8, m.dark), { y: 0.2 }));
  root.add(at(chevrons(m, { width: 2.4, count: 5, depth: 0.5 }), { y: 0.41, z: 1.5 }));
  root.add(at(footing(m, { width: 1.4, height: 0.6, toeLen: 0.7 }), { y: 0.4 }));

  /* shaft: armoured lower mast, open truss above ----------------------- */
  const shaft = group('Shaft');
  for (let i = 0; i < 5; i += 1) {
    const w = i === 0 ? 0.9 : 0.72;
    shaft.add(at(bevelBox(w, 0.86, w, i % 2 ? m.mid : m.bright, { radius: 0.03 }), { y: 1.1 + i * 0.92 }));
    shaft.add(at(box(w * 0.7, 0.06, w * 0.7, m.dark), { y: 1.1 + i * 0.92 - 0.4 }));
  }
  shaft.add(at(box(0.9, 0.3, 0.06, m.cyan), { x: 0, y: 3.2, z: 0.38 }));
  shaft.add(at(truss(0.66, 3.4, 0.66, m.mid, { bays: 6, thickness: 0.06 }), { y: 5.6 }));
  shaft.add(at(cyl(0.12, 0.12, 2.2, 8, m.dark), { y: 8.2 }));
  root.add(shaft);

  /* observation cabin --------------------------------------------------- */
  const cabin = group('Cabin');
  cabin.add(at(cyl(1.25, 1.05, 0.3, 8, m.dark), { y: 0.15 }));
  cabin.add(at(cyl(1.15, 1.15, 1.25, 8, m.bright), { y: 0.95 }));
  for (let i = 0; i < 8; i += 1) {
    const a = (i / 8) * Math.PI * 2;
    cabin.add(at(box(0.5, 0.2, 0.05, m.cyan), { x: Math.cos(a) * 1.1, y: 1.05, z: Math.sin(a) * 1.1, ry: -a }));
  }
  cabin.add(at(cyl(1.25, 1.2, 0.22, 8, m.mid), { y: 1.7 }));
  cabin.add(at(railing(5.4, 0.42, m.dark, { posts: 9 }), { x: -1.6, y: 1.6, z: 1.4, ry: Math.PI / 2 }));
  cabin.add(at(greebles({ w: 1.2, h: 1.1, d: 1.2, face: '+z', count: 5, seed: 111, materials: [m.dark, m.mid], centre: [0, 0.95, 0] })));
  at(cabin, { y: 5.5 });
  root.add(cabin);

  /* radar plates + dishes ------------------------------------------------ */
  const radar = group('RadarPlates');
  radar.add(at(box(1.9, 0.85, 0.07, m.bright), { y: 7.9, z: 0.3, rx: -0.22 }));
  radar.add(at(box(1.7, 0.06, 0.09, m.dark), { y: 7.9, z: 0.35 }));
  for (let i = 0; i < 5; i += 1) radar.add(at(box(1.7, 0.05, 0.02, m.mid), { y: 7.5 + i * 0.2, z: 0.36, rx: -0.22 }));
  radar.add(at(box(1.4, 0.5, 0.06, m.mid), { y: 8.9, z: -0.1, rx: 0.3 }));
  root.add(radar);

  const dishYaw = group('DishYaw');
  dishYaw.position.set(0.55, 8.35, 0.42);
  dishYaw.add(at(cyl(0.08, 0.1, 0.3, 8, m.dark), { y: 0.15 }));
  // two dishes back to back, as in the reference
  const bowlA = group('BowlA');
  bowlA.add(at(cone(0.44, 0.28, 12, m.bright, { open: true }), { y: 0.5, rx: -1.1 }));
  bowlA.add(at(cyl(0.02, 0.02, 0.4, 4, m.mid), { y: 0.55, z: 0.18, rx: 0.9 }));
  dishYaw.add(bowlA);
  const bowlB = bowlA.clone(true);
  bowlB.name = 'BowlB';
  bowlB.position.set(-1.05, 0.1, -0.2);
  bowlB.scale.setScalar(0.7);
  bowlB.rotation.y = 2.4;
  dishYaw.add(bowlB);
  root.add(dishYaw);

  root.add(at(mast(m, { h: 1.9, r: 0.04 }), { x: -0.5, y: 9.2, z: -0.5 }));
  root.add(at(beacon(m, { y: 11.0, r: 0.09, name: 'Beacon' }), { x: -0.5, z: -0.5 }));
  root.add(at(beacon(m, { y: 6.9, r: 0.06, name: 'Beacon_B' }), { x: 1.2, z: -0.6 }));
  root.add(at(vent(0.7, 0.4, 4, m.dark, m.cyan), { x: 0.9, y: 2.1, z: 0.4, ry: Math.PI / 2 }));
  root.add(at(boltRing({ radius: 0.42, count: 10, size: 0.028, y: 1.1, material: m.bright }), { y: 0 }));

  const dishSocket = socket(dishYaw, 'dish', { y: 0.6 });
  const beaconSocket = socket(root, 'beacon', { x: -0.5, y: 11.0, z: -0.5 });

  return finalize(root, {
    meta,
    sockets: { dish: dishSocket, beacon: beaconSocket },
    clips: [
      spinClip('dish_scan', 'DishYaw', { axis: 'y', turns: 1, duration: 9 }),
      pulseClip('beacon_pulse', 'Beacon', { from: 0.7, to: 1.4, duration: 1.6 }),
    ],
  });
}

void torus; void strut; void sweepClip;
