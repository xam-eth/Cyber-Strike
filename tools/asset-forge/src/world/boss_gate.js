/**
 * boss_gate — the reinforced docking gate that opens once the generators are
 * down (`game/scenes/worlds/components/boss_gate.tscn`).
 *
 * Reference features: massive gunmetal frame, two shutter leaves with
 * horizontal slats, cyan seam lights up the jambs, power conduits, bolts, amber
 * warning hardware at the base. Dark beyond the opening.
 *
 * The two leaves are named `ShutterL` / `ShutterR` and animate apart along X —
 * the same motion `gate_open` describes in the game's own component notes.
 */
import { at, box, bevelBox, cyl, torus, strut, plate, greebles, boltRing, group, vent, cable } from '../runtime/kit.js';
import { std, beacon, chevrons, guideStrip } from '../runtime/parts.js';
import { socket, finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'boss_gate',
  category: 'world',
  name: 'Boss Gate',
  reference: 'references/world/boss_gate.png',
  source: 'game/scenes/worlds/components/boss_gate.tscn',
  targetHeight: 11.0,
  heightTolerance: 1.4,
  triangleBudget: 70000,
  meshBudget: 700,
  sockets: ['shutter_l', 'shutter_r'],
  animations: ['gate_open'],
};

const OPENING = 4.6;

export function build() {
  const m = std();
  const root = group('BossGate');

  /* plinth --------------------------------------------------------------- */
  root.add(at(box(9.6, 0.5, 3.2, m.dark), { y: 0.25 }));
  root.add(at(box(9.2, 0.1, 2.9, m.mid), { y: 0.55 }));
  root.add(at(chevrons(m, { width: 4.6, count: 8, depth: 0.8 }), { y: 0.6, z: 0.7 }));

  /* jambs ---------------------------------------------------------------- */
  for (const side of [-1, 1]) {
    const jamb = group(side < 0 ? 'JambL' : 'JambR');
    const x = side * (OPENING / 2 + 1.0);
    for (let i = 0; i < 6; i += 1) {
      const y = 0.6 + i * 1.62;
      jamb.add(at(bevelBox(1.7, 1.5, 2.5, i % 2 ? m.mid : m.bright, { radius: 0.03 }), { x, y: y + 0.75 }));
      jamb.add(at(box(1.76, 0.1, 2.56, m.dark), { x, y: y + 0.06 }));
      // cyan seam up the inner face
      jamb.add(at(box(0.06, 1.2, 0.1, m.cyan), { x: x - side * 0.86, y: y + 0.8, z: 1.1 }));
      jamb.add(at(box(0.06, 1.2, 0.1, m.cyan), { x: x - side * 0.86, y: y + 0.8, z: -1.1 }));
    }
    // angled buttresses at the base
    for (const sz of [-1, 1]) {
      const brace = at(box(0.4, 2.4, 0.4, m.mid), { x: x + side * 0.9, y: 1.6, z: sz * 1.5 });
      brace.rotation.z = side * 0.28;
      jamb.add(brace);
      jamb.add(at(bevelBox(1.2, 1.0, 1.0, m.dark, { radius: 0.03 }), { x: x + side * 1.35, y: 0.95, z: sz * 1.5 }));
    }
    jamb.add(at(greebles({ w: 1.6, h: 8.6, d: 2.5, face: side < 0 ? '+x' : '-x', count: 14, seed: 91 + side, materials: [m.dark, m.bright], centre: [x, 5.2, 0] })));
    jamb.add(at(boltRing({ radius: 0.5, count: 8, size: 0.035, y: 1.05, material: m.dark, axis: 'z' })));
    jamb.children[jamb.children.length - 1].position.set(x, 1.6, 1.3);
    root.add(jamb);
  }

  /* lintel ---------------------------------------------------------------- */
  const lintel = group('Lintel');
  lintel.add(at(bevelBox(OPENING + 3.6, 1.5, 2.6, m.mid, { radius: 0.04 }), { y: 10.2 }));
  lintel.add(at(box(OPENING + 3.76, 0.2, 2.76, m.dark), { y: 9.5 }));
  lintel.add(at(box(OPENING + 3.7, 0.12, 2.7, m.warn), { y: 10.98 }));
  lintel.add(at(box(OPENING - 0.4, 0.18, 0.12, m.cyan), { y: 9.72, z: 1.32 }));
  // overhead gantry mechanism
  for (const sx of [-1, 1]) {
    lintel.add(at(cyl(0.24, 0.24, 0.5, 12, m.dark, { axis: 'x' }), { x: sx * 1.5, y: 9.72, z: 1.5 }));
    lintel.add(at(cyl(0.1, 0.1, 2.2, 8, m.bright, { axis: 'x' }), { y: 9.92, z: 1.5 }));
  }
  lintel.add(at(greebles({ w: OPENING + 3.4, h: 1.3, d: 2.6, face: '+z', count: 10, seed: 92, materials: [m.dark, m.bright], centre: [0, 10.2, 0] })));
  root.add(lintel);

  /* shutters -------------------------------------------------------------- */
  const shutter = (side) => {
    const g = group(side < 0 ? 'ShutterL' : 'ShutterR');
    const leafW = OPENING / 2;
    g.add(at(bevelBox(leafW, 8.6, 0.34, m.bright, { radius: 0.02 }), { x: side * leafW / 2, y: 5.0 }));
    for (let i = 0; i < 9; i += 1) {
      g.add(at(box(leafW * 0.96, 0.62, 0.44, i % 2 ? m.mid : m.bright), { x: side * leafW / 2, y: 1.4 + i * 0.92, z: 0.02 }));
      g.add(at(box(leafW * 0.9, 0.06, 0.5, m.dark), { x: side * leafW / 2, y: 1.08 + i * 0.92, z: 0.03 }));
    }
    g.add(at(box(0.08, 8.4, 0.42, m.warn), { x: side * (leafW - 0.06), y: 5.0, z: 0.03 }));
    g.add(at(box(leafW * 0.5, 0.16, 0.46, m.warn), { x: side * leafW / 2, y: 0.9 }));
    return g;
  };
  const left = shutter(-1);
  const right = shutter(1);
  root.add(left, right);

  /* conduits + warning hardware ------------------------------------------ */
  const conduits = group('Conduits');
  for (const side of [-1, 1]) {
    conduits.add(strut([side * 3.3, 0.7, 1.4], [side * 3.3, 8.8, 1.4], 0.09, m.warn));
    conduits.add(cable([side * 3.3, 8.8, 1.4], [side * 2.2, 9.4, 1.4], 0.05, m.gap, { sag: 0.3 }));
  }
  root.add(conduits);
  root.add(at(box(1.6, 0.14, 0.12, m.warn), { y: 0.62, z: 1.5 }));
  root.add(at(beacon(m, { y: 9.6, r: 0.12, name: 'Beacon' }), { x: -3.0, z: 1.35 }));
  root.add(at(beacon(m, { y: 9.6, r: 0.12, name: 'Beacon_B' }), { x: 3.0, z: 1.35 }));
  root.add(at(guideStrip(m, { len: 3.0, width: 0.12 }), { y: 0.6, z: 1.4 }));

  const shutterL = socket(left, 'shutter_l', { x: -OPENING / 4, y: 5.0 });
  const shutterR = socket(right, 'shutter_r', { x: OPENING / 4, y: 5.0 });

  return finalize(root, {
    meta,
    sockets: { shutter_l: shutterL, shutter_r: shutterR },
    clips: [
      // leaves slide apart and back: the visible half of the gate opening
      clip('gate_open', 4.0, [
        { node: 'ShutterL', property: 'position.x', keys: [[0, 0], [2.2, -OPENING / 2], [3.2, -OPENING / 2], [4.0, 0]] },
        { node: 'ShutterR', property: 'position.x', keys: [[0, 0], [2.2, OPENING / 2], [3.2, OPENING / 2], [4.0, 0]] },
      ]),
    ],
  });
}

void plate; void torus; void vent; void bevelBox;
