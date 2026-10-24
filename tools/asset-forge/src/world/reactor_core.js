/**
 * reactor_core — the suspended cyan/emerald reactor from
 * `game/scenes/worlds/components/reactor_core.tscn`.
 *
 * Identity-defining features (taken from the reference render, in build order):
 *  1. Two tall armoured pylons with amber cross-bracing at the crown.
 *  2. A vessel **suspended** between them — the lower centre stays open, which
 *     is the gameplay requirement (`WORLD_BLOCKOUT.md`, component inventory),
 *     not a modelling accident.
 *  3. Emerald-turquoise plasma column inside a transparent sleeve.
 *  4. Stacked cyan energy halos around the sleeve.
 *  5. Splayed four-toe footings with amber vents.
 */
import { metal, paint, glow, glass, hazard } from '../runtime/materials.js';
import {
  at, box, bevelBox, cyl, torus, strut, greebles, boltRing, group, named, strip,
} from '../runtime/kit.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'reactor_core',
  category: 'world',
  name: 'Reactor Core',
  reference: 'references/world/reactor_core.png',
  source: 'game/scenes/worlds/components/reactor_core.tscn',
  targetHeight: 6.0,
  heightTolerance: 0.35,
  triangleBudget: 90000,
  meshBudget: 420,
  sockets: ['charge_fx'],
  animations: ['core_pulse'],
};

export function build() {
  const root = group('ReactorCore');

  const dark = metal('line', { roughness: 0.58, metalness: 0.8 });
  const mid = metal('lineHi', { roughness: 0.48, metalness: 0.75 });
  const bright = paint('ink2', { roughness: 0.42, metalness: 0.35 });
  const warn = hazard();
  const cyan = glow('info', 3.1);
  // Emission stays on the ok/info tokens; only the intensity differs, so the
  // column reads as one emerald light source rather than a white blowout.
  const green = glow('ok', 0.95, { base: 'ok' });
  const hot = glow('ok', 1.55, { base: 'ok' });
  const sleeveGlass = glass('info', { opacity: 0.16 });

  /* ---------------------------------------------------------- foundation */
  const foundation = group('Foundation');
  foundation.add(at(cyl(1.95, 2.15, 0.24, 6, dark), { y: 0.12 }));
  foundation.add(at(cyl(1.86, 1.86, 0.06, 6, mid), { y: 0.27 }));
  foundation.add(at(cyl(1.9, 1.9, 0.02, 6, bright, { open: true }), { y: 0.3 }));
  for (let i = 0; i < 6; i += 1) {
    const a = (i / 6) * Math.PI * 2;
    foundation.add(at(box(0.7, 0.1, 0.18, warn), {
      x: Math.cos(a) * 1.86, y: 0.29, z: Math.sin(a) * 1.86, ry: -a,
    }));
  }
  root.add(foundation);

  /* --------------------------------------------------------------- pylons */
  function buildPylon(side) {
    const g = group(side > 0 ? 'PylonR' : 'PylonL');
    const x = side * 2.05;

    for (let i = 0; i < 4; i += 1) {
      const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
      g.add(at(bevelBox(0.42, 0.5, 0.62, mid, { radius: 0.03 }), {
        x: x + Math.cos(a) * 0.52, y: 0.3, z: Math.sin(a) * 0.52, ry: -a,
      }));
      g.add(at(box(0.2, 0.06, 0.2, warn), { x: x + Math.cos(a) * 0.5, y: 0.56, z: Math.sin(a) * 0.5 }));
    }
    g.add(at(bevelBox(0.62, 0.34, 0.62, bright, { radius: 0.04 }), { x, y: 0.69 }));
    g.add(at(bevelBox(0.5, 0.22, 0.5, dark, { radius: 0.03 }), { x, y: 0.93 }));

    // Segmented shaft: alternating widths so it reads as armour, not a tube.
    let y = 0.98;
    const sectionH = 0.5;
    for (let i = 0; i < 9; i += 1) {
      const w = i % 3 === 0 ? 0.5 : 0.4;
      g.add(at(bevelBox(w, sectionH, w, i % 3 === 0 ? bright : mid, { radius: 0.02 }), { x, y: y + sectionH / 2 }));
      // recessed graphite band between armour segments
      g.add(at(box(w * 0.86, 0.09, w * 0.86, dark), { x, y: y + 0.045 }));
      if (i % 2 === 0) {
        g.add(at(box(0.05, sectionH * 0.62, 0.06, cyan), { x: x - side * (w / 2 + 0.01), y: y + sectionH / 2 }));
      }
      if (i % 3 === 1) {
        g.add(at(box(w * 0.6, 0.04, 0.06, warn), { x, y: y + sectionH * 0.85, z: w / 2 + 0.04 }));
      }
      y += sectionH;
    }

    const crown = bevelBox(0.82, 0.46, 0.82, mid, { radius: 0.03 });
    at(crown, { x, y: y + 0.23 });
    g.add(crown);
    g.add(at(box(0.86, 0.08, 0.86, warn), { x, y: y + 0.4 }));

    g.add(greebles({ w: 0.7, h: 0.4, d: 0.8, face: '+z', count: 6, seed: 11 + side, materials: [mid, bright, dark], centre: [x, y + 0.2, 0] }));
    return g;
  }
  root.add(buildPylon(-1));
  root.add(buildPylon(1));

  /* --------------------------------------------------------------- vessel */
  const vesselY = 2.85;
  const vessel = group('Vessel');
  vessel.add(at(cyl(0.66, 0.66, 2.5, 24, sleeveGlass, { open: true }), { y: vesselY }));

  // Plasma column: three nested cylinders give interior depth without a shader.
  const plasma = named(group('Plasma'), 'Plasma');
  plasma.add(at(cyl(0.4, 0.4, 2.35, 18, green), { y: vesselY }));
  plasma.add(at(cyl(0.26, 0.26, 2.3, 14, hot), { y: vesselY }));
  vessel.add(plasma);

  for (let i = 0; i < 4; i += 1) {
    const hy = vesselY - 0.95 + i * 0.63;
    const halo = group(`Halo${i}`);
    halo.add(at(torus(0.74, 0.055, mid, { radial: 6, tubular: 24 }), { y: hy, rx: Math.PI / 2 }));
    halo.add(at(torus(0.79, 0.022, cyan, { radial: 4, tubular: 24 }), { y: hy, rx: Math.PI / 2 }));
    vessel.add(halo);
  }

  function collar(y, r) {
    const c = group('Collar');
    c.add(at(cyl(r, r, 0.42, 12, mid), { y }));
    c.add(at(boltRing({ radius: r * 0.92, count: 10, size: 0.025, y: y + 0.22, material: bright })));
    c.add(at(torus(r * 0.98, 0.03, cyan, { radial: 4, tubular: 20 }), { y: y - 0.19, rx: Math.PI / 2 }));
    return c;
  }
  vessel.add(collar(vesselY + 1.32, 0.82));
  vessel.add(collar(vesselY - 1.3, 0.86));

  const hub = group('Hub');
  hub.add(at(bevelBox(1.5, 0.6, 1.5, mid, { radius: 0.05 }), { y: 4.72 }));
  hub.add(at(box(1.56, 0.05, 1.56, cyan), { y: 5.0 }));
  hub.add(at(cyl(0.5, 0.62, 0.3, 10, mid), { y: 5.2 }));
  hub.add(greebles({ w: 1.4, h: 0.5, d: 1.4, face: '+z', count: 8, seed: 31, materials: [mid, bright], centre: [0, 4.72, 0] }));
  vessel.add(hub);
  root.add(vessel);

  /* --------------------------------------------------------- service arms */
  const arms = group('ServiceArms');
  for (const side of [-1, 1]) {
    arms.add(strut([side * 1.65, 4.55, 0], [side * 0.78, 4.2, 0], 0.07, warn));
    arms.add(strut([side * 1.65, 4.55, 0], [side * 0.85, 4.9, 0], 0.05, mid));
    arms.add(strut([side * 1.2, 5.15, 0], [side * 1.55, 4.7, 0.35], 0.04, warn));
    arms.add(at(cyl(0.08, 0.08, 1.4, 8, mid, { axis: 'z' }), { x: side * 1.2, y: 3.2, z: 0 }));
  }
  arms.add(at(box(2.6, 0.12, 0.5, warn), { y: 5.28 }));
  root.add(arms);

  /* ------------------------------------------------------------- conduits */
  const conduits = group('Conduits');
  for (const side of [-1, 1]) {
    conduits.add(strut([side * 2.05, 1.0, 0.34], [side * 0.9, 1.55, 0.34], 0.06, warn));
    conduits.add(at(cyl(0.1, 0.1, 0.16, 8, mid, { axis: 'z' }), { x: side * 0.9, y: 1.55, z: 0.34 }));
  }
  root.add(conduits);

  /* ------------------------------------------------------------- trim */
  root.add(at(strip({ w: 1.2, h: 0.05, d: 0.04, glowMaterial: cyan, frameMaterial: dark }), { y: 6.02, z: 0.3 }));

  const charge = socket(root, 'charge_fx', { y: 4.72 });

  return finalize(root, {
    meta,
    sockets: { charge_fx: charge },
    clips: [pulseClip('core_pulse', 'Plasma', { from: 1, to: 1.05, duration: 2.6 })],
  });
}
