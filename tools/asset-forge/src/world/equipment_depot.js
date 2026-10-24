/**
 * equipment_depot — supply depot with stacked cargo
 * (`game/scenes/worlds/components/equipment_depot.tscn`).
 *
 * Reference features: blocky depot module with a rollout door and ribbed roof,
 * mismatched cargo stacked beside it, and a small service gantry with amber
 * hazard lamps on the roof.
 */
import { at, box, bevelBox, cyl, plate, greebles, group, vent, railing, cable } from '../runtime/kit.js';
import { std, doorFrame, crate, beacon, tank, guideStrip, chevrons, armourWall } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'equipment_depot',
  category: 'world',
  name: 'Equipment Depot',
  reference: 'references/world/equipment_depot.png',
  source: 'game/scenes/worlds/components/equipment_depot.tscn',
  targetHeight: 4.6,
  heightTolerance: 0.7,
  triangleBudget: 60000,
  meshBudget: 700,
  sockets: ['cargo_slot', 'door'],
  animations: ['lamp_pulse'],
};

export function build() {
  const m = std();
  const root = group('EquipmentDepot');

  /* apron -------------------------------------------------------------- */
  root.add(at(box(6.4, 0.22, 5.0, m.dark), { y: 0.11 }));
  root.add(at(chevrons(m, { width: 3.2, count: 7, depth: 0.6 }), { y: 0.22, z: 2.05 }));

  /* depot module ------------------------------------------------------- */
  const depot = group('DepotModule');
  depot.add(at(bevelBox(3.8, 2.9, 3.0, m.bright, { radius: 0.04 }), { y: 1.67, x: -0.6 }));
  // ribbed roof
  for (let i = 0; i < 7; i += 1) {
    depot.add(at(box(3.84, 0.14, 0.26, m.mid), { x: -0.6, y: 3.16, z: -1.32 + i * 0.44 }));
  }
  depot.add(at(box(3.9, 0.1, 3.1, m.dark), { x: -0.6, y: 3.06 }));
  // flank plating and cyan strip
  depot.add(at(box(0.08, 2.4, 0.5, m.dark), { x: -2.52, y: 1.6, z: 0.9 }));
  depot.add(at(box(0.04, 0.06, 2.4, m.cyan), { x: -2.56, y: 2.7, z: 0 }));
  depot.add(greebles({ w: 3.7, h: 2.6, d: 3.0, face: '+x', count: 7, seed: 71, materials: [m.dark, m.mid], centre: [-0.6, 1.67, 0] }));
  depot.add(at(vent(1.4, 0.42, 6, m.dark, m.cyan), { x: -0.6, y: 2.5, z: 1.52 }));
  root.add(depot);

  /* rollout door ------------------------------------------------------- */
  const door = group('DoorAssembly');
  door.add(doorFrame(m, { w: 2.0, h: 2.4 }));
  at(door, { x: -0.6, y: 0.22, z: 1.5 });
  root.add(door);
  const doorSocket = socket(door, 'door', { y: 1.0, z: 0.18 });
  // door lamp bar
  root.add(at(box(2.2, 0.08, 0.1, m.warn), { x: -0.6, y: 2.82, z: 1.56 }));

  /* cargo stacks ------------------------------------------------------- */
  const cargo = group('CargoStack');
  const stacks = [
    [1.55, 0.22, 0.55, 1.1, 0.85, 0.8, 0.15],
    [1.5, 0.22, -0.45, 0.9, 0.7, 0.7, -0.2],
    [1.62, 0.22, 1.5, 0.85, 0.6, 0.6, 0.5],
  ];
  for (const [x, y, z, w, h, d, ry] of stacks) {
    const c = crate(m, { w, h, d, seed: Math.floor(x * 10 + z * 3) });
    at(c, { x, y, z, ry });
    cargo.add(c);
  }
  cargo.add(at(crate(m, { w: 0.8, h: 0.62, d: 0.66, seed: 9 }), { x: 1.55, y: 1.32, z: 0.55, ry: 0.28 }));
  cargo.add(at(crate(m, { w: 0.62, h: 0.5, d: 0.62, seed: 12 }), { x: 1.52, y: 0.92, z: -0.42, ry: -0.4 }));
  cargo.add(at(tank(m, { r: 0.32, len: 0.9, y: 0.22 }), { x: 1.6, y: 0.02, z: -1.6, ry: Math.PI / 2 }));
  root.add(cargo);

  /* service gantry on the roof ----------------------------------------- */
  const gantry = group('Gantry');
  const deckY = 3.28;
  gantry.add(at(box(2.0, 0.1, 1.1, m.mid), { x: -1.0, y: deckY, z: -0.4 }));
  gantry.add(at(railing(1.9, 0.42, m.dark, { posts: 5 }), { x: -1.0, y: deckY + 0.05, z: -0.95 }));
  gantry.add(at(railing(1.9, 0.42, m.dark, { posts: 5 }), { x: -1.0, y: deckY + 0.05, z: 0.15 }));
  for (const sx of [-1, 1]) {
    gantry.add(at(cyl(0.06, 0.06, 0.9, 6, m.dark), { x: -1.0 + sx * 0.86, y: deckY + 0.5, z: -0.9 }));
    gantry.add(at(box(0.14, 0.14, 0.14, m.warn), { x: -1.0 + sx * 0.86, y: deckY + 0.98, z: -0.9 }));
  }
  gantry.add(at(box(1.9, 0.06, 0.1, m.dark), { x: -1.0, y: deckY + 0.94, z: -0.9 }));
  root.add(gantry);

  root.add(at(beacon(m, { y: 3.3, r: 0.07, name: 'Lamp' }), { x: 0.6, z: 1.3 }));
  root.add(at(beacon(m, { y: 3.3, r: 0.07, name: 'Lamp_B' }), { x: -1.8, z: 1.3 }));
  root.add(at(guideStrip(m, { len: 2.4, width: 0.1 }), { x: 1.6, y: 0.23, z: 2.0, ry: Math.PI / 2 }));
  root.add(cable([0.6, 3.4, 1.3], [1.6, 2.9, -0.6], 0.02, m.gap, { sag: 0.18 }));
  root.add(at(armourWall(m, { w: 1.4, h: 1.0, d: 0.14, windows: 0, seed: 74 }), { x: 0.6, y: 0.22, z: 2.3 }));

  const cargoSlot = socket(root, 'cargo_slot', { x: 1.55, y: 0.22, z: 0.55, ry: 0.15 });

  return finalize(root, {
    meta,
    sockets: { cargo_slot: cargoSlot, door: doorSocket },
    clips: [pulseClip('lamp_pulse', 'Lamp', { from: 0.8, to: 1.3, duration: 1.9 })],
  });
}

void plate; void bevelBox;
