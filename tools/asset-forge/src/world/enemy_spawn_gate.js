/**
 * enemy_spawn_gate — open arch with warning panels and cyan guide strips
 * (`game/scenes/worlds/components/enemy_spawn_gate.tscn`).
 *
 * The middle has to stay genuinely clear: `spawn_point` sits on the deck inside
 * the arch and nothing may intersect the passage between the two legs.
 */
import { at, box, bevelBox, cyl, cone, torus, strut, greebles, boltRing, group, vent } from '../runtime/kit.js';
import { std, beacon, chevrons, guideStrip } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'enemy_spawn_gate',
  category: 'world',
  name: 'Enemy Spawn Gate',
  reference: 'references/world/enemy_spawn_gate.png',
  source: 'game/scenes/worlds/components/enemy_spawn_gate.tscn',
  targetHeight: 5.2,
  heightTolerance: 0.7,
  triangleBudget: 50000,
  meshBudget: 500,
  sockets: ['spawn_point'],
  animations: ['strip_pulse'],
};

const SPAN = 3.4;

export function build() {
  const m = std();
  const root = group('EnemySpawnGate');

  root.add(at(box(6.6, 0.34, 2.4, m.dark), { y: 0.17 }));
  root.add(at(box(6.2, 0.08, 2.1, m.mid), { y: 0.36 }));
  root.add(at(chevrons(m, { width: 3.0, count: 6, depth: 0.7 }), { y: 0.41, z: 0.85 }));

  /* legs ----------------------------------------------------------------- */
  for (const side of [-1, 1]) {
    const leg = group(side < 0 ? 'LegL' : 'LegR');
    const x = side * (SPAN / 2 + 0.45);
    leg.add(at(bevelBox(0.9, 0.5, 1.5, m.bright, { radius: 0.03 }), { x, y: 0.6 }));
    let y = 0.85;
    for (let i = 0; i < 4; i += 1) {
      const h = 0.86;
      leg.add(at(bevelBox(0.72 - i * 0.04, h, 1.25 - i * 0.05, i % 2 ? m.mid : m.bright, { radius: 0.03 }), { x, y: y + h / 2 }));
      leg.add(at(box(0.76 - i * 0.04, 0.07, 1.3 - i * 0.05, m.dark), { x, y: y + 0.03 }));
      // cyan guide strip facing the passage
      leg.add(at(box(0.05, h * 0.7, 0.1, m.cyan), { x: x - side * 0.38, y: y + h / 2, z: 0.5 }));
      leg.add(at(box(0.05, h * 0.7, 0.1, m.cyan), { x: x - side * 0.38, y: y + h / 2, z: -0.5 }));
      y += h;
    }
    // warning panels on the outer face
    for (let i = 0; i < 2; i += 1) {
      leg.add(at(box(0.04, 0.5, 0.8, m.warn), { x: x + side * 0.38, y: 1.6 + i * 1.6, z: 0 }));
      leg.add(at(box(0.06, 0.22, 0.3, m.dark), { x: x + side * 0.4, y: 1.6 + i * 1.6, z: 0 }));
    }
    leg.add(at(greebles({ w: 0.7, h: 3.4, d: 1.2, face: '+z', count: 6, seed: 131 + side, materials: [m.dark, m.bright], centre: [x, 2.6, 0] })));
    leg.add(at(boltRing({ radius: 0.38, count: 8, size: 0.026, y: 0.6, material: m.dark, axis: 'z' })));
    leg.children[leg.children.length - 1].position.set(x, 0.6, 0.78);
    root.add(leg);
  }

  /* arch ----------------------------------------------------------------- */
  const arch = group('Arch');
  arch.add(at(bevelBox(SPAN + 1.9, 0.8, 1.45, m.mid, { radius: 0.04 }), { y: 4.6 }));
  arch.add(at(box(SPAN + 2.0, 0.14, 1.5, m.dark), { y: 4.16 }));
  arch.add(at(box(SPAN + 1.8, 0.1, 1.4, m.warn), { y: 5.02 }));
  arch.add(at(box(SPAN - 0.6, 0.12, 0.1, m.cyan), { y: 4.24, z: 0.72 }));
  arch.add(at(box(SPAN - 0.6, 0.12, 0.1, m.cyan), { y: 4.24, z: -0.72 }));
  arch.add(at(greebles({ w: SPAN + 1.6, h: 0.7, d: 1.4, face: '+z', count: 8, seed: 132, materials: [m.dark, m.bright], centre: [0, 4.6, 0] })));
  for (const sx of [-1, 1]) {
    arch.add(strut([sx * (SPAN / 2 + 0.2), 4.2, 0], [sx * (SPAN / 2 - 0.1), 3.0, 0], 0.05, m.mid));
    arch.add(at(box(0.3, 0.5, 0.3, m.warn), { x: sx * (SPAN / 2 - 0.55), y: 4.05, z: 0.62 }));
  }
  root.add(arch);

  /* beacons + emitter pads ------------------------------------------------ */
  root.add(at(beacon(m, { y: 4.95, r: 0.08, name: 'Strip' }), { x: -(SPAN / 2 + 0.4), z: 0 }));
  root.add(at(beacon(m, { y: 4.95, r: 0.08, name: 'Strip_B' }), { x: SPAN / 2 + 0.4, z: 0 }));
  for (const sx of [-1, 1]) {
    root.add(at(cyl(0.16, 0.2, 0.05, 8, m.dark), { x: sx * 0.9, y: 0.4, z: 0 }));
    root.add(at(cyl(0.13, 0.13, 0.02, 8, m.cyan), { x: sx * 0.9, y: 0.43, z: 0 }));
  }
  root.add(at(guideStrip(m, { len: 2.6, width: 0.1 }), { y: 0.41, ry: Math.PI / 2 }));
  root.add(at(vent(0.6, 0.3, 4, m.dark, m.danger), { y: 0.9, z: -1.1, x: SPAN / 2 + 0.45, ry: Math.PI }));

  const spawn = socket(root, 'spawn_point', { y: 0.4, z: 0 });

  return finalize(root, {
    meta,
    sockets: { spawn_point: spawn },
    clips: [pulseClip('strip_pulse', 'Strip', { from: 0.7, to: 1.5, duration: 1.4 })],
  });
}

void cone; void torus;
