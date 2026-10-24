/**
 * cover_module — waist-high segmented armour with a hazard top marking
 * (`game/scenes/worlds/components/cover_module.tscn`).
 *
 * Chest height is the point: 1.15 m, so it stops a body without blocking the
 * third-person camera over the shoulder. The top faces are the only surfaces
 * with a consistent read from above, so the hazard marking lives there.
 *
 * The first pass was three grey boxes with bolts on the front — it read as
 * office furniture, not as cover. What makes a barricade read is the *profile*:
 * a plinth that sits on the ground, a face that leans back, raised shoulders
 * with a firing notch between them, and braced feet. Those are the shapes the
 * redesign is built from; the plating is the same palette as everything else.
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

    // plinth: the part that looks like it is actually holding the wall up
    seg.add(at(bevelBox(w + 0.06, 0.16, 0.86, m.dark, { radius: 0.02 }), { x: cx, y: 0.08, z: -0.02 }));
    seg.add(at(box(w * 0.92, 0.04, 0.9, m.mid), { x: cx, y: 0.16, z: -0.02 }));

    // face leaning back toward the protected side, so a crouched player is
    // inside the shadow of the plate instead of standing behind a flat wall
    const face = at(bevelBox(w, 0.76, 0.5, i === 1 ? m.mid : m.bright, { radius: 0.035 }), { x: cx, y: 0.55, z: 0.03 });
    face.rotation.x = -0.09;
    seg.add(face);
    // back plate, offset, with the gap that reads as a hollow section
    seg.add(at(bevelBox(w * 0.96, 0.66, 0.26, m.dark, { radius: 0.02 }), { x: cx, y: 0.53, z: -0.26 }));

    // raised shoulders + firing notch between them. They are wedges, not
    // blocks: two canted caps on either side of the notch is the shape that
    // tells a player "shoot over this" instead of "this is a cupboard".
    for (const sx of [-1, 1]) {
      const shoulder = at(bevelBox(w * 0.3, 0.2, 0.44, m.bright, { radius: 0.02 }), { x: cx + sx * w * 0.32, y: 0.99, z: 0.02 });
      shoulder.rotation.x = -0.12;
      shoulder.rotation.z = sx * 0.14;
      seg.add(shoulder);
      const cap = at(bevelBox(w * 0.3, 0.04, 0.46, m.dark, { radius: 0.01 }), { x: cx + sx * w * 0.32, y: 1.09, z: 0.02 });
      cap.rotation.z = sx * 0.16;
      seg.add(cap);
      // notch cheeks angle inward
      const cheek = at(box(0.05, 0.14, 0.4, m.mid), { x: cx + sx * w * 0.16, y: 0.99, z: 0.04 });
      cheek.rotation.z = sx * 0.25;
      seg.add(cheek);
    }
    seg.add(at(box(w * 0.36, 0.05, 0.4, m.dark), { x: cx, y: 0.93, z: 0.02 }));

    // hazard marking along the top front edge, where a player reads it
    seg.add(at(box(w * 0.5, 0.02, 0.22, m.warn), { x: cx, y: 0.945, z: 0.2 }));
    // edge guards + bolts
    for (const sx of [-1, 1]) {
      seg.add(at(box(0.08, 0.86, 0.68, m.dark), { x: cx + sx * (w / 2 - 0.04), y: 0.5 }));
      seg.add(at(box(0.05, 0.3, 0.03, m.cyan), { x: cx + sx * (w / 2 - 0.04), y: 0.5, z: 0.3 }));
      // braced foot: the diagonal that anchors the segment to the ground
      const brace = at(box(0.08, 0.5, 0.06, m.mid), { x: cx + sx * (w / 2 - 0.1), y: 0.2, z: -0.5 });
      brace.rotation.x = 0.5;
      seg.add(brace);
    }
    seg.add(at(boltRing({ radius: 0.13, count: 6, size: 0.02, material: m.dark, axis: 'z' }), { x: cx, y: 0.5, z: 0.29 }));
    seg.add(greebles({ w: w * 0.8, h: 0.5, d: 0.5, face: '+z', count: 3, seed: 141 + i, materials: [m.dark, m.mid], centre: [cx, 0.48, 0] }));
    // stencilled hazard tick low on the face
    seg.add(at(plate(0.26, 0.09, 0.02, m.warn), { x: cx - w * 0.18, y: 0.3, z: 0.32 }));
    // back-side equipment rail
    seg.add(at(box(w * 0.7, 0.08, 0.12, m.dark), { x: cx, y: 0.68, z: -0.42 }));
    root.add(seg);
    x += w + 0.05;
  });

  /* end caps and warning lights ---------------------------------------- */
  const span = x;
  for (const sx of [-1, 1]) {
    root.add(at(box(0.12, 0.98, 0.72, m.dark), { x: sx * (span / 2), y: 0.55 }));
    root.add(at(cone(0.06, 0.14, 5, m.warn), { x: sx * (span / 2 - 0.08), y: 1.04 }));
    root.add(at(cyl(0.045, 0.045, 0.05, 8, m.danger), { x: sx * (span / 2 - 0.08), y: 1.06 }));
  }
  // stowed antenna on one end only, so the wall is not symmetric
  root.add(at(cyl(0.02, 0.02, 0.7, 6, m.dark), { x: span / 2 - 0.2, y: 1.4, z: -0.22 }));
  root.add(at(cyl(0.035, 0.035, 0.03, 8, m.cyan), { x: span / 2 - 0.2, y: 1.76, z: -0.22 }));
  root.add(at(vent(0.5, 0.22, 3, m.dark, m.cyan), { y: 0.45, z: -0.4, ry: Math.PI }));
  root.add(at(chevrons(m, { width: 2.4, count: 6, depth: 0.36 }), { z: -0.1 }));
  root.add(at(guideStrip(m, { len: 2.2, width: 0.06 }), { y: 0.98 }));

  const top = socket(root, 'top_mark', { y: 0.95 });

  return finalize(root, { meta, sockets: { top_mark: top }, clips: [] });
}
