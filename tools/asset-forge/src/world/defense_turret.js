/**
 * defense_turret — yaw bearing, armoured housing, twin barrels, optical sensor
 * (`game/scenes/worlds/components/defense_turret.tscn`).
 *
 * The hierarchy is the animation: `Yaw` turns the whole head, `BarrelL` and
 * `BarrelR` recoil independently, and both muzzles plus the sensor are sockets
 * a gameplay system can attach to.
 */
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, plate, greebles, boltRing, group, vent } from '../runtime/kit.js';
import { std, footing, beacon, chevrons } from '../runtime/parts.js';
import { socket, finalize, sweepClip, clip, rampClip } from '../runtime/rig.js';

export const meta = {
  id: 'defense_turret',
  category: 'world',
  name: 'Defence Turret',
  reference: 'references/world/defense_turret.png',
  source: 'game/scenes/worlds/components/defense_turret.tscn',
  targetHeight: 2.8,
  heightTolerance: 0.4,
  triangleBudget: 40000,
  meshBudget: 300,
  sockets: ['muzzle_l', 'muzzle_r', 'sensor'],
  animations: ['yaw_sweep', 'fire_recoil'],
};

export function build() {
  const m = std();
  const root = group('DefenceTurret');

  /* mount + base --------------------------------------------------------- */
  root.add(at(cyl(1.05, 1.15, 0.18, 8, m.dark), { y: 0.09 }));
  root.add(at(chevrons(m, { width: 1.6, count: 4, depth: 0.4 }), { y: 0.19, z: 0.9 }));
  root.add(at(footing(m, { width: 0.9, height: 0.5, toeLen: 0.4 }), { y: 0.18 }));
  root.add(at(cyl(0.6, 0.7, 0.5, 12, m.mid), { y: 0.92 }));
  root.add(at(boltRing({ radius: 0.64, count: 12, size: 0.03, y: 1.15, material: m.bright })));
  root.add(at(torus(0.66, 0.04, m.cyan, { radial: 4, tubular: 24 }), { y: 1.14, rx: Math.PI / 2 }));

  /* yaw head ------------------------------------------------------------- */
  const yaw = group('Yaw');
  yaw.position.y = 1.16;

  yaw.add(at(cyl(0.56, 0.56, 0.24, 12, m.dark), { y: 0.12 }));
  const housing = group('Housing');
  housing.add(at(bevelBox(1.15, 0.72, 1.3, m.bright, { radius: 0.05 }), { y: 0.6 }));
  // sloped glacis at the front
  const glacis = at(bevelBox(1.1, 0.5, 0.5, m.mid, { radius: 0.04 }), { y: 0.8, z: 0.72 });
  glacis.rotation.x = -0.36;
  housing.add(glacis);
  housing.add(at(box(1.2, 0.08, 1.36, m.dark), { y: 0.98 }));
  housing.add(at(box(0.9, 0.06, 0.9, m.warn), { y: 1.03, z: -0.1 }));
  // cooling fins on the flanks
  for (const sx of [-1, 1]) {
    for (let i = 0; i < 4; i += 1) {
      housing.add(at(box(0.05, 0.34, 0.1, m.dark), { x: sx * 0.6, y: 0.62, z: -0.42 + i * 0.22 }));
    }
  }
  housing.add(at(vent(0.5, 0.26, 4, m.dark, m.cyan), { y: 0.55, z: -0.66, ry: Math.PI }));
  housing.add(at(greebles({ w: 1.1, h: 0.6, d: 1.2, face: '+y', count: 6, seed: 101, materials: [m.dark, m.mid], centre: [0, 0.6, 0] })));
  yaw.add(housing);

  /* sensor ---------------------------------------------------------------- */
  const sensor = group('Sensor');
  sensor.add(at(box(0.44, 0.3, 0.2, m.dark), { y: 0.86, z: 0.86 }));
  sensor.add(at(box(0.34, 0.16, 0.04, m.cyan), { y: 0.86, z: 0.97 }));
  sensor.add(at(cyl(0.05, 0.05, 0.3, 6, m.mid, { axis: 'z' }), { y: 1.04, z: 0.7 }));
  yaw.add(sensor);

  /* barrels --------------------------------------------------------------- */
  const barrel = (side, name) => {
    const g = group(name);
    const x = side * 0.26;
    g.add(at(cyl(0.12, 0.14, 0.42, 10, m.mid, { axis: 'z' }), { x, y: 0.72, z: 0.5 }));
    g.add(at(cyl(0.075, 0.075, 1.3, 10, m.bright, { axis: 'z' }), { x, y: 0.72, z: 1.3 }));
    // muzzle brake: two rings and a slotted tip
    for (const z of [1.82, 1.94]) g.add(at(cyl(0.115, 0.115, 0.08, 10, m.dark, { axis: 'z' }), { x, y: 0.72, z }));
    g.add(at(cyl(0.1, 0.1, 0.16, 10, m.dark, { axis: 'z' }), { x, y: 0.72, z: 2.02 }));
    g.add(at(cyl(0.055, 0.055, 0.03, 10, m.cyan, { axis: 'z' }), { x, y: 0.72, z: 2.11 }));
    // barrel shroud
    g.add(at(box(0.2, 0.2, 0.36, m.mid), { x, y: 0.72, z: 0.82 }));
    return g;
  };
  const barrelL = barrel(-1, 'BarrelL');
  const barrelR = barrel(1, 'BarrelR');
  yaw.add(barrelL, barrelR);
  yaw.add(at(box(0.5, 0.16, 0.2, m.dark), { y: 0.72, z: 0.55 }));
  yaw.add(at(beacon(m, { y: 1.0, r: 0.05, name: 'StatusLight' }), { x: 0.42, z: -0.4 }));

  /* asymmetric kit -------------------------------------------------------- *
   * A turret that is symmetric in plan view renders almost identically from
   * 0° and 90°, which the views-differ check flags (it scored 0.109 against a
   * 0.12 floor). Real turrets are lopsided because the feed, the cable run and
   * the tools all live on one side, so the detail is added asymmetrically. */
  // ammunition feed drum on the right flank
  const feed = group('AmmoFeed');
  feed.add(at(cyl(0.24, 0.24, 0.26, 12, m.mid, { axis: 'x' }), { x: 0.74, y: 0.52, z: -0.1 }));
  feed.add(at(cyl(0.26, 0.26, 0.04, 12, m.dark, { axis: 'x' }), { x: 0.86, y: 0.52, z: -0.1 }));
  feed.add(at(boltRing({ radius: 0.17, count: 8, size: 0.022, material: m.bright, axis: 'x', y: 0.88 }), { y: 0.52, z: -0.1 }));
  feed.add(at(box(0.16, 0.1, 0.3, m.dark), { x: 0.62, y: 0.62, z: -0.32 }));
  housing.add(feed);
  // cable conduit down the left flank, into the base
  for (let i = 0; i < 5; i += 1) {
    const seg = at(cyl(0.035, 0.035, 0.16, 6, m.dark), { x: -0.66, y: 0.95 - i * 0.17, z: -0.5 });
    seg.rotation.z = i < 2 ? 0.2 : -0.15;
    housing.add(seg);
  }
  root.add(at(box(0.12, 0.5, 0.12, m.dark), { x: -0.78, y: 0.6, z: -0.5 }));
  // rear maintenance hatch, offset to one side
  housing.add(at(box(0.34, 0.4, 0.05, m.dark), { x: 0.22, y: 0.58, z: -0.72 }));
  housing.add(at(box(0.2, 0.24, 0.03, m.mid), { x: 0.22, y: 0.58, z: -0.76 }));
  // ladder rungs on one side of the pedestal only
  for (let i = 0; i < 3; i += 1) {
    root.add(at(box(0.24, 0.03, 0.04, m.mid), { x: -0.5, y: 0.55 + i * 0.18, z: 0.22 }));
  }

  root.add(yaw);

  const muzzleL = socket(barrelL, 'muzzle_l', { x: -0.26, y: 0.72, z: 2.16 });
  const muzzleR = socket(barrelR, 'muzzle_r', { x: 0.26, y: 0.72, z: 2.16 });
  const sensorSocket = socket(sensor, 'sensor', { y: 0.86, z: 1.0 });

  return finalize(root, {
    meta,
    sockets: { muzzle_l: muzzleL, muzzle_r: muzzleR, sensor: sensorSocket },
    clips: [
      sweepClip('yaw_sweep', 'Yaw', { axis: 'y', amplitude: 0.75, duration: 7.2 }),
      clip('fire_recoil', 0.5, [
        { node: 'BarrelL', property: 'position.z', keys: [[0, 0], [0.06, -0.16], [0.5, 0]] },
        { node: 'BarrelR', property: 'position.z', keys: [[0, 0], [0.06, -0.16], [0.5, 0]] },
        { node: 'Housing', property: 'position.z', keys: [[0, 0], [0.06, -0.05], [0.5, 0]] },
      ]),
    ],
  });
}

void plate; void cone; void sphere; void strut; void bevelBox; void rampClip;
