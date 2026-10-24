/**
 * command_center — the west-outpost military building
 * (`game/scenes/worlds/components/command_center.tscn`).
 *
 * Reference features: armoured foundation + angular hull, raised command bridge
 * with a cyan visor-window band, blast door, roof vents, an antenna mast, a
 * radar dish on a yoke, corner armour blocks with fasteners.
 */
import {
  at, box, bevelBox, cyl, plate, greebles, boltRing, group, vent, railing, dish, cable,
} from '../runtime/kit.js';
import { std, doorFrame, beacon, mast, hvac, armourWall } from '../runtime/parts.js';
import { socket, finalize, pulseClip, spinClip, sweepClip } from '../runtime/rig.js';

export const meta = {
  id: 'command_center',
  category: 'world',
  name: 'Command Centre',
  reference: 'references/world/command_center.png',
  source: 'game/scenes/worlds/components/command_center.tscn',
  targetHeight: 7.5,
  heightTolerance: 1.0,
  triangleBudget: 70000,
  meshBudget: 700,
  sockets: ['dish_yaw', 'door'],
  animations: ['beacon_pulse', 'dish_scan'],
};

export function build() {
  const m = std();
  const root = group('CommandCentre');

  /* foundation + hull ------------------------------------------------ */
  root.add(at(box(6.4, 0.36, 5.4, m.dark), { y: 0.18 }));
  root.add(at(box(6.0, 0.12, 5.0, m.mid), { y: 0.4 }));

  const hull = group('Hull');
  hull.add(at(bevelBox(5.2, 2.1, 4.2, m.mid, { radius: 0.05 }), { y: 1.45 }));
  hull.add(at(box(5.26, 0.12, 4.26, m.dark), { y: 2.5 }));
  // corner armour blocks
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const corner = group('CornerArmour');
    corner.add(at(bevelBox(0.8, 2.3, 0.8, m.bright, { radius: 0.04 }), { x: sx * 2.25, y: 1.45, z: sz * 1.75 }));
    corner.add(boltRing({ radius: 0.3, count: 6, size: 0.03, y: 0.2, material: m.dark, axis: 'z' }));
    corner.children[corner.children.length - 1].position.set(sx * 2.25, 1.9, sz * 2.16);
    hull.add(corner);
  }
  hull.add(greebles({ w: 5.0, h: 1.8, d: 4.2, face: '+z', count: 14, seed: 41, materials: [m.dark, m.bright, m.mid], centre: [0, 1.45, 0] }));
  hull.add(at(vent(1.2, 0.4, 6, m.dark, m.cyan), { x: -1.4, y: 1.9, z: 2.13 }));
  // chamfered crown: a second, inset storey so the silhouette is stepped
  hull.add(at(box(4.6, 0.22, 3.7, m.bright), { y: 2.66 }));
  hull.add(at(box(4.72, 0.1, 3.82, m.dark), { y: 2.78 }));
  // rib plates down the flanks
  for (const sx of [-1, 1]) {
    for (let i = 0; i < 4; i += 1) {
      hull.add(at(box(0.1, 1.7, 0.42, m.dark), { x: sx * 2.62, y: 1.4, z: -1.4 + i * 0.92 }));
      hull.add(at(box(0.04, 0.06, 0.44, m.cyan), { x: sx * 2.68, y: 2.2, z: -1.4 + i * 0.92 }));
    }
  }
  // hazard bollards at the front corners
  for (const sx of [-1, 1]) hull.add(at(cyl(0.09, 0.11, 0.7, 8, m.warn), { x: sx * 2.9, y: 0.72, z: 2.5 }));
  root.add(hull);

  /* blast door ------------------------------------------------------- */
  const door = group('DoorAssembly');
  door.add(doorFrame(m, { w: 1.5, h: 2.2, faceTop: true }));
  door.position.set(0.9, 0.46, 2.12);
  root.add(door);
  const doorSocket = socket(door, 'door', { y: 1.0, z: 0.2 });

  /* raised command bridge -------------------------------------------- */
  const bridge = group('Bridge');
  bridge.add(at(bevelBox(4.0, 1.15, 2.6, m.dark, { radius: 0.05 }), { y: 3.2, z: -0.4 }));
  bridge.add(at(box(4.06, 0.1, 2.66, m.bright), { y: 3.78, z: -0.4 }));
  // cyan visor-window band
  for (let i = 0; i < 5; i += 1) {
    bridge.add(at(box(0.62, 0.4, 0.06, m.gap), { x: -1.5 + i * 0.75, y: 3.3, z: 0.92 }));
    bridge.add(at(box(0.56, 0.3, 0.02, m.cyan), { x: -1.5 + i * 0.75, y: 3.3, z: 0.95 }));
  }
  bridge.add(at(box(4.1, 0.16, 0.12, m.warn), { y: 3.02, z: 0.95 }));
  // bridge rails and a roof lip
  bridge.add(at(railing(3.8, 0.42, m.dark, { posts: 7 }), { y: 3.83, z: 0.92 }));
  bridge.add(at(box(4.2, 0.14, 0.2, m.mid), { y: 3.9, z: -1.72 }));
  root.add(bridge);

  /* roof equipment --------------------------------------------------- */
  const roof = group('Roof');
  roof.add(at(hvac(m, { w: 1.3, d: 0.9, h: 0.42, seed: 12 }), { x: -1.3, y: 2.56, z: -0.9 }));
  roof.add(at(hvac(m, { w: 0.9, d: 0.7, h: 0.32, seed: 17 }), { x: -1.3, y: 2.56, z: 0.2 }));
  roof.add(at(vent(1.0, 0.3, 5, m.dark, m.cyan), { x: 1.6, y: 2.66, z: -1.1, rx: -Math.PI / 2 }));
  // radar dish on a yoke
  const yoke = group('DishYoke');
  yoke.add(at(cyl(0.16, 0.22, 0.5, 8, m.dark), { y: 0.25 }));
  const yaw = group('DishYaw');
  yaw.add(at(cyl(0.1, 0.1, 0.24, 8, m.mid), { y: 0.12 }));
  const bowl = dish(0.7, m.bright, { depth: 0.3, rimMaterial: m.dark });
  at(bowl, { y: 0.5, rx: -0.45, ry: 0.35 });
  yaw.add(bowl);
  yoke.add(yaw);
  roof.add(at(yoke, { x: 1.4, y: 3.9, z: -1.4 }));
  root.add(roof);

  /* mast + beacons --------------------------------------------------- */
  const mastGroup = group('MastAssembly');
  mastGroup.add(at(mast(m, { h: 2.6, braces: true }), { x: -1.9, y: 3.9, z: -1.6 }));
  mastGroup.add(at(beacon(m, { y: 6.5, r: 0.1, name: 'Beacon' }), { x: -1.9, z: -1.6 }));
  mastGroup.add(at(beacon(m, { y: 2.56, r: 0.07, name: 'Beacon_L' }), { x: -2.35, z: 1.85 }));
  mastGroup.add(at(beacon(m, { y: 2.56, r: 0.07, name: 'Beacon_R' }), { x: 2.35, z: 1.85 }));
  mastGroup.add(cable([-1.9, 5.4, -1.6], [1.4, 4.4, -1.4], 0.025, m.gap, { sag: 0.25 }));
  root.add(mastGroup);

  // wall modules flanking the front, so the facade is not one flat slab
  root.add(at(armourWall(m, { w: 1.7, h: 1.5, d: 0.2, windows: 1, seed: 21 }), { x: -1.9, y: 0.46, z: 2.18 }));
  root.add(at(armourWall(m, { w: 1.5, h: 1.5, d: 0.2, windows: 0, seed: 22 }), { x: 2.4, y: 0.46, z: 2.18 }));

  const dishSocket = socket(yaw, 'dish_yaw', { y: 0.5 });

  return finalize(root, {
    meta,
    sockets: { dish_yaw: dishSocket, door: doorSocket },
    clips: [
      pulseClip('beacon_pulse', 'Beacon', { from: 0.85, to: 1.25, duration: 1.7 }),
      spinClip('dish_scan', 'DishYaw', { axis: 'y', turns: 1, duration: 14 }),
    ],
  });
}

void plate;
