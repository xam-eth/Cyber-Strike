/**
 * enemy_spawn_gate — the hostile portal enemies walk out of
 * (`game/scenes/worlds/components/enemy_spawn_gate.tscn`).
 *
 * Rebuilt from its reference, which is a **pointed gothic arch**, not a steel
 * gantry: two legs of overlapping scale-plates climb to an ogive crown, each
 * plate carries a swept spike, a row of red eye-lamps runs along the summit, and
 * the opening is filled by a violet energy membrane. The old model was a
 * rectangular frame with no membrane at all — the compare sheet
 * (`review/compare/world.png`) made that unmissable.
 *
 * `spawn_point` sits on the deck *inside* the arch; the membrane is a visual
 * shell around that point and must not be treated as collision.
 */
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, greebles, group, vent } from '../runtime/kit.js';
import { std, chevrons, beacon } from '../runtime/parts.js';
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

/** Half-width of the opening at the springing line. */
const HALF_W = 1.55;
/** Height where the arch starts curving. */
const SPRING = 2.55;
/** Total crown height of the arch centreline. */
const APEX = 4.55;

/**
 * Pointed-arch centreline, as a quadratic Bézier from the top of one leg
 * (side·HALF_W, SPRING) to the apex (0, APEX). The control point sits above and
 * inward of the springing, which is what produces the ogive point.
 *
 * `archPoint` returns position *and* tangent angle, because a segment that is
 * not rotated to the tangent reads as a floating brick — the first version of
 * this rebuild did exactly that.
 */
function archPoint(t, side) {
  const u = 1 - t;
  const p0 = [side * HALF_W, SPRING];
  const p1 = [side * HALF_W * 0.42, APEX + 0.75];
  const p2 = [0, APEX];
  const x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0];
  const y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1];
  const dx = 2 * u * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0]);
  const dy = 2 * u * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1]);
  return { x, y, angle: Math.atan2(dy, dx) };
}

export function build() {
  const m = std();
  const root = group('EnemySpawnGate');

  /* deck ------------------------------------------------------------------ */
  root.add(at(box(6.4, 0.3, 2.6, m.dark), { y: 0.15 }));
  root.add(at(box(5.9, 0.07, 2.2, m.mid), { y: 0.34 }));
  root.add(at(chevrons(m, { width: 2.6, count: 6, depth: 0.62 }), { y: 0.38, z: 1.0 }));

  /* plinths: hazard-chevroned blocks at the foot of each leg ---------------- */
  for (const side of [-1, 1]) {
    const px = side * (HALF_W + 0.55);
    const plinth = group(side < 0 ? 'PlinthL' : 'PlinthR');
    plinth.add(at(bevelBox(1.1, 1.0, 1.35, m.dark, { radius: 0.04 }), { x: px, y: 0.84 }));
    plinth.add(at(bevelBox(0.86, 0.62, 1.0, m.mid, { radius: 0.03 }), { x: px, y: 1.62 }));
    // amber chevron stack, the only warm accent in the reference
    for (let i = 0; i < 3; i += 1) {
      const ch = at(box(0.4, 0.1, 0.06, m.warn), { x: px, y: 0.62 + i * 0.22, z: 0.7 });
      ch.rotation.z = 0;
      plinth.add(ch);
    }
    // red vents on the outer cheek
    for (let i = 0; i < 2; i += 1) {
      plinth.add(at(box(0.06, 0.16, 0.3, m.danger), { x: px + side * 0.56, y: 1.0 + i * 0.3, z: 0.2 }));
    }
    // gothic ribs flanking the plinth
    for (let i = 0; i < 3; i += 1) {
      const rib = at(cone(0.09, 0.62 - i * 0.1, 4, m.mid), { x: px + side * (0.3 + i * 0.12), y: 1.25, z: -0.5 + i * 0.42 });
      rib.rotation.z = side * 0.5;
      rib.rotation.x = -0.35;
      plinth.add(rib);
    }
    root.add(plinth);
  }

  /* legs: one continuous tapered column, wrapped in scale plates ----------- *
   * The column is the structural line the arch springs from; the plates are
   * decoration on it. Building the legs *out of* loose plates left a visible
   * gap between leg and arch. */
  for (const side of [-1, 1]) {
    const leg = group(side < 0 ? 'LegL' : 'LegR');
    const x = side * HALF_W;
    const top = SPRING;
    leg.add(at(bevelBox(0.66, top - 1.9, 0.86, m.mid, { radius: 0.03 }), { x, y: (1.9 + top) / 2 }));
    const plateCount = 5;
    for (let i = 0; i < plateCount; i += 1) {
      const y = 2.06 + i * 0.42;
      const w = 0.8 - i * 0.03;
      // each plate overhangs the one below, like a scale — always overlapping
      const plateMesh = at(bevelBox(w, 0.34, 1.02, i % 2 ? m.bright : m.mid, { radius: 0.03 }), { x, y });
      plateMesh.rotation.z = side * -0.05;
      leg.add(plateMesh);
      leg.add(at(box(w * 0.94, 0.05, 0.9, m.dark), { x, y: y - 0.19 }));
      // swept spike pointing away from the opening
      const spike = at(cone(0.07, 0.34, 4, m.mid), { x: x + side * 0.42, y: y + 0.06, z: 0 });
      spike.rotation.z = side * -1.2;
      leg.add(spike);
    }
    root.add(leg);
  }

  /* the pointed arch: ONE continuous rib swept along the ogive -------------- *
   * Per-segment boxes crossed each other at the crown and read as a basket
   * weave. A polyline of struts through the same curve cannot cross itself, and
   * the scale plates are then hung on the outside of the rib. */
  const arch = group('Arch');
  const STEPS = 22;
  const pts = [];
  for (let i = 0; i <= STEPS; i += 1) {
    const t = i / STEPS;
    // left leg → apex → right leg
    const side = t < 0.5 ? -1 : 1;
    pts.push(archPoint(t < 0.5 ? t * 2 : (1 - t) * 2, side));
  }
  for (let i = 1; i < pts.length; i += 1) {
    const a = pts[i - 1];
    const b = pts[i];
    arch.add(strut([a.x, a.y, 0], [b.x, b.y, 0], 0.19, m.mid, { segments: 6 }));
  }
  // scale plates hung on the outside of the rib, pointing outward
  for (let i = 1; i < pts.length - 1; i += 1) {
    const p = pts[i];
    const outward = p.x < 0 ? -1 : 1;
    const plateMesh = at(bevelBox(0.44, 0.2, 0.62, m.bright, { radius: 0.02 }), {
      x: p.x + outward * 0.26, y: p.y + 0.06, z: 0,
    });
    plateMesh.rotation.z = -outward * (0.9 - Math.abs(p.x) / HALF_W * 0.7);
    arch.add(plateMesh);
    if (i % 4 === 2) {
      const spike = at(cone(0.055, 0.3, 4, m.mid), {
        x: p.x + outward * 0.5, y: p.y + 0.18, z: 0,
      });
      spike.rotation.z = -outward * 1.15;
      arch.add(spike);
    }
  }
  // crown finial
  arch.add(at(cone(0.14, 0.6, 4, m.mid), { y: APEX + 0.3, z: 0 }));
  arch.add(at(cone(0.09, 0.3, 4, m.bright), { y: APEX + 0.7, z: 0 }));

  /* red eye-lamps seated on the rib ---------------------------------------- */
  const lamp = (x, y, scale = 1) => {
    const g = group('Lamp');
    g.add(at(sphere(0.09 * scale, m.danger, { widthSegments: 10, heightSegments: 6 }), { x, y, z: 0.24 }));
    g.add(at(torus(0.11 * scale, 0.02, m.bright, { radial: 4, tubular: 12 }), { x, y, z: 0.24 }));
    return g;
  };
  for (let i = 0; i < 3; i += 1) {
    const t = 0.3 + i * 0.16;
    for (const side of [-1, 1]) {
      const p = archPoint(t, side);
      arch.add(lamp(p.x, p.y + 0.2, 1 - i * 0.08));
    }
  }
  arch.add(lamp(0, APEX + 0.05, 1.2));
  root.add(arch);

  /* violet membrane: a rimmed oval set behind the arch ---------------------- *
   * Two fixes from the first rebuild: it rendered as a flat lavender blob
   * because a large emissive area at full intensity reads white-tinted, and it
   * sat in front of the ribs. The fill is now a dim field with structure, and
   * only the rim runs hot. */
  const membrane = group('Membrane');
  const my = (SPRING + APEX) / 2 + 0.1;
  const mh = (APEX - SPRING) / 2 + 0.34;
  const mw = HALF_W * 0.74;
  const fill = at(sphere(1.0, m.violetDim, { widthSegments: 18, heightSegments: 12 }), {
    y: my, z: -0.42, sx: mw, sy: mh, sz: 0.2,
  });
  membrane.add(fill);
  // bright rim following the membrane outline
  const rim = at(torus(1.0, 0.026, m.violet, { radial: 4, tubular: 44 }), { y: my, z: -0.22 });
  rim.scale.set(mw, mh, 1);
  membrane.add(rim);
  // energy striations inside, so the field has structure instead of a blob
  for (let i = 0; i < 9; i += 1) {
    const spread = 1 - Math.abs(i - 4) * 0.13;
    const h = mh * 1.55 * spread;
    membrane.add(at(box(0.022, h, 0.02, m.violet), {
      x: (i - 4) * 0.2, y: my + (i % 2 ? 0.1 : -0.1), z: -0.24,
    }));
  }
  // a few horizontal energy bands, so the field is not a set of vertical bars
  for (let i = 0; i < 3; i += 1) {
    const w = mw * 1.35 * (1 - Math.abs(i - 1) * 0.35);
    membrane.add(at(box(w, 0.02, 0.02, m.violet), { y: my + (i - 1) * 0.5, z: -0.24 }));
  }
  root.add(membrane);

  /* threshold guide strips -------------------------------------------------- */
  root.add(at(box(0.06, 0.02, 1.6, m.cyan), { y: 0.37, z: 0.2 }));
  root.add(at(beacon(m, { y: 0.42, r: 0.05, name: 'GateBeacon' }), { x: -HALF_W - 0.9, z: 1.1 }));
  root.add(at(greebles({ w: 2.0, h: 0.3, d: 0.5, face: '+z', count: 4, seed: 91, materials: [m.dark, m.mid], centre: [0, 0.6, 0.62] })));

  const spawn = socket(root, 'spawn_point', { y: 0.42, z: 0.1 });

  return finalize(root, {
    meta,
    sockets: { spawn_point: spawn },
    clips: [pulseClip('strip_pulse', 'Membrane', { from: 0.86, to: 1.12, duration: 3.0 })],
  });
}

void cyl; void strut; void vent;
