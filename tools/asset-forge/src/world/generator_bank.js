/**
 * generator_bank — three contained generator towers with luminous columns
 * (`game/scenes/worlds/components/generator_bank.tscn`).
 *
 * Reference features: three identical towers, each with a glass sleeve around a
 * bright cyan energy column and repeated pressure bands, joined by feed/return
 * pipework on a shared service walk with amber warning lights.
 */
import { at, box, bevelBox, cyl, torus, strut, plate, greebles, boltRing, group, vent, railing, pipeRun } from '../runtime/kit.js';
import { std, beacon, footing, chevrons, guideStrip } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'generator_bank',
  category: 'world',
  name: 'Generator Bank',
  reference: 'references/world/generator_bank.png',
  source: 'game/scenes/worlds/components/generator_bank.tscn',
  targetHeight: 6.5,
  heightTolerance: 0.9,
  triangleBudget: 80000,
  meshBudget: 900,
  sockets: ['feed_pipe'],
  animations: ['energy_columns'],
};

export function build() {
  const m = std();
  const root = group('GeneratorBank');

  /* service walk ------------------------------------------------------- */
  root.add(at(box(7.4, 0.3, 3.6, m.dark), { y: 0.15 }));
  root.add(at(box(7.0, 0.08, 3.2, m.mid), { y: 0.33 }));
  root.add(at(guideStrip(m, { len: 6.4, width: 0.1 }), { y: 0.38, z: 1.3 }));
  root.add(at(chevrons(m, { width: 2.0, count: 5, depth: 0.5 }), { y: 0.38, z: -1.4 }));
  root.add(at(railing(4.2, 0.5, m.dark, { posts: 8 }), { x: 1.4, y: 0.34, z: -1.72 }));

  /* towers ------------------------------------------------------------- */
  const columns = group('EnergyColumns');
  const towerX = [-2.4, 0, 2.4];
  for (let t = 0; t < towerX.length; t += 1) {
    const x = towerX[t];
    const tower = group(`Tower${t + 1}`);
    tower.add(footing(m, { width: 1.0, height: 0.6 }));
    tower.children[0].position.set(x, 0.34, 0);

    // structural cage: four posts
    const cageH = 3.9;
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
      tower.add(at(box(0.13, cageH, 0.13, m.mid), { x: x + sx * 0.44, y: 0.94 + cageH / 2, z: sz * 0.44 }));
    }
    // pressure bands
    for (let i = 0; i < 5; i += 1) {
      const y = 1.2 + i * 0.82;
      tower.add(at(cyl(0.56, 0.56, 0.12, 16, m.dark), { x, y }));
      // boltRing places its bolts at `y` inside its own group, so the group
      // only carries the tower's X — setting y again here would double it.
      tower.add(at(boltRing({ radius: 0.47, count: 8, size: 0.022, y: y + 0.07, material: m.bright }), { x }));
      tower.add(at(torus(0.5, 0.022, m.cyan, { radial: 4, tubular: 20 }), { x, y: y - 0.07, rx: Math.PI / 2 }));
    }
    // glass sleeve + luminous column
    tower.add(at(cyl(0.42, 0.42, cageH - 0.3, 20, m.glass, { open: true }), { x, y: 0.94 + cageH / 2 }));
    const column = group(`Column${t + 1}`);
    // A large emissive area at full strength reads as white, not cyan: the
    // column's inner core carries the intensity, the outer sleeve stays dim.
    column.add(at(cyl(0.26, 0.26, cageH - 0.5, 14, m.cyanDim), { x, y: 0.94 + cageH / 2 }));
    column.add(at(cyl(0.12, 0.12, cageH - 0.4, 10, m.cyan), { x, y: 0.94 + cageH / 2 }));
    tower.add(column);
    // crown
    tower.add(at(bevelBox(1.1, 0.34, 1.1, m.bright, { radius: 0.03 }), { x, y: 0.94 + cageH + 0.17 }));
    tower.add(at(box(1.16, 0.07, 1.16, m.warn), { x, y: 0.94 + cageH + 0.36 }));
    tower.add(at(cyl(0.16, 0.2, 0.22, 8, m.mid), { x, y: 0.94 + cageH + 0.48 }));
    tower.add(at(beacon(m, { y: 0.94 + cageH + 0.56, r: 0.06, name: `TowerLight${t + 1}` }), { x }));
    root.add(tower);
  }
  root.add(columns);

  /* feed / return pipework --------------------------------------------- */
  const pipes = group('Pipes');
  pipes.add(pipeRun([[-3.2, 1.35, -0.62], [-1.2, 1.35, -0.62], [1.2, 1.35, -0.62], [3.2, 1.35, -0.62]], 0.1, m.bright, { segments: 10 }));
  pipes.add(pipeRun([[-3.2, 0.95, 0.62], [-1.2, 0.95, 0.62], [1.2, 0.95, 0.62], [3.2, 0.95, 0.62]], 0.075, m.mid, { segments: 8 }));
  for (const x of [-1.2, 1.2]) {
    pipes.add(at(cyl(0.13, 0.13, 0.2, 10, m.dark, { axis: 'x' }), { x, y: 1.35, z: -0.62 }));
    pipes.add(at(cyl(0.1, 0.1, 0.18, 8, m.dark, { axis: 'x' }), { x, y: 0.95, z: 0.62 }));
  }
  pipes.add(strut([3.2, 1.35, -0.62], [3.2, 0.6, -0.62], 0.09, m.mid));
  pipes.add(strut([-3.2, 0.95, 0.62], [-3.2, 0.55, 0.62], 0.07, m.mid));
  pipes.add(at(box(0.5, 0.5, 0.4, m.bright), { x: 3.2, y: 0.55, z: -0.62 }));
  pipes.add(at(box(0.4, 0.24, 0.03, m.warn), { x: 3.2, y: 0.55, z: -0.4 }));
  root.add(pipes);

  /* control cabinet ---------------------------------------------------- */
  const cab = group('Cabinet');
  cab.add(at(bevelBox(1.2, 1.5, 0.6, m.bright, { radius: 0.03 }), { y: 0.75 }));
  cab.add(at(box(1.26, 0.08, 0.66, m.dark), { y: 1.53 }));
  cab.add(at(box(0.7, 0.34, 0.03, m.gap), { y: 1.14, z: 0.31 }));
  cab.add(at(box(0.6, 0.2, 0.02, m.cyan), { y: 1.14, z: 0.33 }));
  for (let i = 0; i < 4; i += 1) cab.add(at(box(0.08, 0.03, 0.02, m.green), { x: -0.4 + i * 0.16, y: 0.82, z: 0.33 }));
  cab.add(at(vent(0.8, 0.3, 4, m.dark, m.cyan), { y: 0.5, z: 0.31 }));
  at(cab, { x: 3.05, y: 0.34, z: 1.15, ry: -0.4 });
  root.add(cab);

  const feed = socket(pipes, 'feed_pipe', { x: 3.2, y: 1.35, z: -0.62 });

  return finalize(root, {
    meta,
    sockets: { feed_pipe: feed },
    clips: [
      pulseClip('energy_columns', 'EnergyColumns', { from: 0.97, to: 1.03, duration: 2.2 }),
    ],
  });
}

void plate; void greebles;
