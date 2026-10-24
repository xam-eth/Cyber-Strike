/**
 * cover_module — waist-high segmented armour with a hazard top marking
 * (`game/scenes/worlds/components/cover_module.tscn`).
 *
 * Chest height is the point: 1.15 m, so it stops a body without blocking the
 * third-person camera over the shoulder. The top faces are the only surfaces
 * with a consistent read from above, so the hazard marking lives there.
 */
import { at, box, bevelBox, cyl, plate, greebles, boltRing, group, vent, cone } from '../runtime/kit.js';
import { std, chevrons, guideStrip } from '../runtime/parts.js';
import { socket, finalize } from '../runtime/rig.js';

export const meta = {
  id: 'cover_module',
  category: 'world',
  name: 'Cover Module',
  reference: 'references/world/cover_module.png',
  source: 'game/scenes/worlds/components/cover_module.tscn',
  targetHeight: 1.15,
  heightTolerance: 0.16,
  triangleBudget: 30000,
  meshBudget: 260,
  sockets: ['top_mark'],
  animations: [],
};

export function build() {
  const m = std();
  const root = group('CoverModule');

  /* three segments so a squad can break it into smaller covers ---------- */
  const widths = [1.15, 1.0, 1.15];
  let x = -(widths.reduce((a, b) => a + b, 0) + 0.1) / 2;
  widths.forEach((w, i) => {
    const seg = group(`Segment${i + 1}`);
    const cx = x + w / 2;
    // body: armoured face with a chamfered top
    seg.add(at(bevelBox(w, 0.82, 0.62, i === 1 ? m.mid : m.bright, { radius: 0.03 }), { x: cx, y: 0.41 }));
    seg.add(at(box(w * 0.98, 0.12, 0.7, m.dark), { x: cx, y: 0.86 }));
    seg.add(at(box(w * 0.9, 0.1, 0.66, m.mid), { x: cx, y: 0.24 }));
    // hazard top marking
    seg.add(at(box(w * 0.42, 0.02, 0.3, m.warn), { x: cx, y: 0.93 }));
    // edge guards + bolts
    for (const sx of [-1, 1]) {
      seg.add(at(box(0.08, 0.92, 0.7, m.dark), { x: cx + sx * (w / 2 - 0.04), y: 0.46 }));
      seg.add(at(box(0.05, 0.34, 0.03, m.cyan), { x: cx + sx * (w / 2 - 0.04), y: 0.5, z: 0.35 }));
    }
    seg.add(at(boltRing({ radius: 0.14, count: 6, size: 0.02, material: m.dark, axis: 'z' }), { x: cx, y: 0.45, z: 0.32 }));
    seg.add(greebles({ w: w * 0.85, h: 0.6, d: 0.62, face: '+z', count: 3, seed: 141 + i, materials: [m.dark, m.mid], centre: [cx, 0.45, 0] }));
    // back-side equipment rail
    seg.add(at(box(w * 0.7, 0.08, 0.1, m.dark), { x: cx, y: 0.62, z: -0.34 }));
    root.add(seg);
    x += w + 0.05;
  });

  /* end caps and warning lights ---------------------------------------- */
  const span = x;
  for (const sx of [-1, 1]) {
    root.add(at(box(0.12, 0.98, 0.72, m.dark), { x: sx * (span / 2), y: 0.49 }));
    root.add(at(cone(0.06, 0.14, 5, m.warn), { x: sx * (span / 2 - 0.08), y: 0.98 }));
    root.add(at(cyl(0.045, 0.045, 0.05, 8, m.danger), { x: sx * (span / 2 - 0.08), y: 1.0 }));
  }
  root.add(at(vent(0.5, 0.22, 3, m.dark, m.cyan), { y: 0.45, z: -0.33, ry: Math.PI }));
  root.add(at(chevrons(m, { width: 2.4, count: 6, depth: 0.36 }), { z: 0.1 }));
  root.add(at(guideStrip(m, { len: 2.2, width: 0.06 }), { y: 0.95 }));
  root.add(at(plate(0.3, 0.12, 0.03, m.warn), { y: 0.55, z: 0.33, x: -span / 4 }));

  const top = socket(root, 'top_mark', { y: 0.95 });

  return finalize(root, { meta, sockets: { top_mark: top }, clips: [] });
}
