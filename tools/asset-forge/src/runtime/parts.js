/**
 * parts.js — reusable sub-assemblies for the NEON FRONTIER kit.
 *
 * These exist so a depot, a lab and a command centre share one lander footing,
 * one door frame and one beacon instead of three slightly different ones. The
 * kit's cohesion check (`views-differ`, palette gate, and the contact sheet
 * review) depends on that: a family of buildings has to look like one
 * manufacturer made them.
 */
import {
  at, box, bevelBox, cyl, cone, sphere, torus, ring, plate, strut, greebles,
  boltRing, group, named, vent, railing, dish, cable, rng, pick, strip,
} from './kit.js';
import { metal, paint, glow, glass, hazard, shadowGap } from './materials.js';

/** Standard material set, so every prop is built from the same six surfaces. */
export function std() {
  return {
    dark: metal('line', { roughness: 0.6, metalness: 0.5 }),
    mid: metal('lineHi', { roughness: 0.5, metalness: 0.55 }),
    bright: paint('ink2', { roughness: 0.45, metalness: 0.25 }),
    ink: paint('ink', { roughness: 0.38, metalness: 0.2 }),
    warn: hazard(),
    cyan: glow('info', 1.5),
    cyanDim: glow('info', 0.55),
    greenDim: glow('ok', 0.5, { base: 'ok' }),
    green: glow('ok', 1.3, { base: 'ok' }),
    danger: glow('danger', 1.2),
    violet: glow('ability', 1.3),
    violetDim: glow('ability', 0.34),
    glass: glass('info', { opacity: 0.18 }),
    gap: shadowGap(),
  };
}

/** Splayed four-toe lander footing used by towers, turrets and the reactor. */
export function footing(m, { width = 0.9, height = 0.5, toes = 4, toeLen = 0.55 } = {}) {
  const g = group('Footing');
  g.add(at(bevelBox(width, height * 0.5, width, m.mid, { radius: 0.02 }), { y: height * 0.28 }));
  for (let i = 0; i < toes; i += 1) {
    const a = (i / toes) * Math.PI * 2 + Math.PI / 4;
    const toe = bevelBox(0.26, height * 0.42, toeLen, m.dark, { radius: 0.02 });
    at(toe, { x: Math.cos(a) * (width * 0.42 + toeLen * 0.28), y: height * 0.2, z: Math.sin(a) * (width * 0.42 + toeLen * 0.28), ry: -a });
    g.add(toe);
  }
  g.add(at(box(width * 0.9, 0.03, width * 0.9, m.warn), { y: height * 0.53 }));
  return g;
}

/** Armoured service door: recessed frame, two leaves, warning stripe, lamps. */
export function doorFrame(m, { w = 1.2, h = 2.0, faceTop = false } = {}) {
  const g = group('Door');
  g.add(at(box(w + 0.3, h + 0.24, 0.14, m.dark), { y: (h + 0.24) / 2, z: 0.02 }));
  g.add(at(box(w, h, 0.08, m.gap), { y: h / 2, z: 0.09 }));
  for (const side of [-1, 1]) {
    g.add(at(box(w / 2 - 0.03, h - 0.08, 0.06, m.mid), { x: side * (w / 4), y: h / 2, z: 0.12 }));
    g.add(at(box(0.05, h - 0.2, 0.02, m.cyan), { x: side * (w / 2 - 0.12), y: h / 2, z: 0.16 }));
  }
  g.add(at(box(w + 0.34, 0.07, 0.2, m.warn), { y: h + 0.2, z: 0.04 }));
  if (faceTop) g.add(at(box(0.24, 0.06, 0.06, m.cyan), { y: h + 0.32, z: 0.1 }));
  return g;
}

/** Beacon on a short mast: cylinder body + emissive dome. Name it for anim. */
export function beacon(m, { y = 0, r = 0.09, h = 0.16, colour = m.cyan, name = 'Beacon' } = {}) {
  const g = named(group(name), name);
  g.add(at(cyl(r * 0.8, r, h, 8, m.dark), { y: y + h / 2 }));
  g.add(at(sphere(r * 0.82, colour, { heightSegments: 6 }), { y: y + h }));
  return g;
}

/** Cargo crate with banded edges. Sizes vary; the language does not. */
export function crate(m, { w = 1.0, h = 0.8, d = 0.7, seed = 3, accent = m.warn } = {}) {
  const rand = rng(seed);
  const g = group('Crate');
  g.add(at(bevelBox(w, h, d, m.bright, { radius: 0.02 }), { y: h / 2 }));
  // corner posts
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    g.add(at(box(0.07, h * 1.01, 0.07, m.dark), { x: sx * (w / 2 - 0.035), y: h / 2, z: sz * (d / 2 - 0.035) }));
  }
  g.add(at(box(w * 0.99, 0.06, 0.05, m.dark), { y: h * 0.28, z: d / 2 + 0.02 }));
  g.add(at(box(w * 0.99, 0.06, 0.05, m.dark), { y: h * 0.72, z: d / 2 + 0.02 }));
  g.add(at(box(w * 0.28, 0.12, 0.02, accent), { y: h * 0.5, z: d / 2 + 0.031 }));
  g.add(greebles({ w: w * 0.8, h: h * 0.7, d, face: '+x', count: 2 + Math.floor(rand() * 3), seed, materials: [m.dark, m.mid], centre: [0, h / 2, 0] }));
  return g;
}

/** Pressure vessel / tank on saddle legs. */
export function tank(m, { r = 0.5, len = 1.4, y = 0 } = {}) {
  const g = group('Tank');
  g.add(at(cyl(r, r, len, 14, m.bright, { axis: 'z' }), { y: y + r }));
  g.add(at(cyl(r * 0.62, r * 0.98, r * 0.4, 14, m.mid, { axis: 'z' }), { y: y + r, z: len / 2 + r * 0.18 }));
  g.add(at(cyl(r * 0.62, r * 0.98, r * 0.4, 14, m.mid, { axis: 'z' }), { y: y + r, z: -len / 2 - r * 0.18 }));
  for (const z of [-len * 0.3, len * 0.3]) {
    g.add(at(torus(r * 1.02, 0.03, m.dark, { radial: 5, tubular: 16 }), { y: y + r, z, rx: 0, ry: 0 }));
  }
  for (const x of [-1, 1]) {
    g.add(at(box(0.1, y + r * 0.6, 0.16, m.dark), { x: x * r * 0.7, y: (y + r * 0.6) / 2, z: len * 0.22 }));
  }
  g.add(at(box(0.5, 0.05, len * 0.9, m.warn), { y: y + r * 2 + 0.01, sx: 1 }));
  return g;
}

/** Antenna mast with optional dish and tie-off struts. */
export function mast(m, { h = 2.4, r = 0.05, braces = true } = {}) {
  const g = group('Mast');
  g.add(at(cyl(r * 0.55, r, h, 8, m.mid), { y: h / 2 }));
  for (let i = 0; i < 3; i += 1) {
    const y = h * (0.3 + i * 0.24);
    g.add(at(cyl(r * 1.35, r * 1.35, 0.035, 8, m.dark), { y }));
  }
  if (braces) {
    for (let i = 0; i < 3; i += 1) {
      const a = (i / 3) * Math.PI * 2;
      g.add(strut([Math.cos(a) * 0.42, 0.02, Math.sin(a) * 0.42], [Math.cos(a) * r, h * 0.55, Math.sin(a) * r], 0.018, m.dark, { segments: 4 }));
    }
  }
  return g;
}

/** Cyan guide strip recessed into a floor plate. */
export function guideStrip(m, { len = 4, width = 0.08 } = {}) {
  return strip({ w: len, h: width, d: 0.03, glowMaterial: m.cyan, frameMaterial: m.dark });
}

/** Hazard chevrons across a width — painted, not emissive. */
export function chevrons(m, { width = 1.6, count = 5, depth = 0.5 } = {}) {
  const g = group('Chevrons');
  for (let i = 0; i < count; i += 1) {
    const x = -width / 2 + (width / count) * (i + 0.5);
    g.add(at(box(width / count * 0.42, 0.012, depth * 0.7, m.warn), { x, y: 0.006, ry: 0.34 }));
  }
  return g;
}

/** Rooftop HVAC cluster: duct, fan, vent and cabling. */
export function hvac(m, { w = 1.2, d = 0.8, h = 0.4, seed = 5 } = {}) {
  const g = group('HVAC');
  g.add(at(bevelBox(w, h, d, m.mid, { radius: 0.02 }), { y: h / 2 }));
  const fan = at(cyl(h * 0.34, h * 0.34, 0.05, 10, m.gap), { y: h + 0.02 });
  g.add(fan);
  g.add(at(torus(h * 0.34, 0.022, m.dark, { radial: 4, tubular: 14 }), { y: h + 0.03, rx: Math.PI / 2 }));
  g.add(at(vent(0.6, 0.22, 5, m.dark, m.cyan), { x: w * 0.28, y: h * 0.55, z: d / 2 + 0.01 }));
  g.add(greebles({ w: w * 0.9, h: h * 0.7, d, face: '+z', count: 3, seed, materials: [m.dark, m.bright], centre: [0, h / 2, 0] }));
  return g;
}

/** Armoured wall module with recessed panels and a slit window. */
export function armourWall(m, { w = 3, h = 2.4, d = 0.24, windows = 1, seed = 9 } = {}) {
  const g = group('ArmourWall');
  g.add(at(box(w, h, d, m.mid), { y: h / 2 }));
  g.add(at(box(w * 0.94, 0.08, d + 0.06, m.dark), { y: h - 0.05 }));
  g.add(at(box(w * 0.94, 0.1, d + 0.06, m.dark), { y: 0.06 }));
  for (let i = 0; i < windows; i += 1) {
    const x = windows === 1 ? 0 : -w / 3 + (i / (windows - 1)) * (w * 0.66);
    g.add(at(box(w / (windows + 1) * 0.7, 0.26, 0.05, m.gap), { x, y: h * 0.7, z: d / 2 }));
    g.add(at(box(w / (windows + 1) * 0.7, 0.05, 0.02, m.cyan), { x, y: h * 0.7 - 0.14, z: d / 2 + 0.032 }));
  }
  g.add(greebles({ w: w * 0.9, h: h * 0.75, d, face: '+z', count: 4, seed, materials: [m.dark, m.bright], centre: [0, h / 2, 0] }));
  return g;
}

/** Landing-pad deck: hex plate, guide ring, chevrons, beacons. */
export function padDeck(m, { radius = 5, name = 'PadDeck' } = {}) {
  const g = group(name);
  g.add(at(cyl(radius, radius * 1.02, 0.28, 6, m.mid), { y: 0.14 }));
  g.add(at(cyl(radius * 0.92, radius * 0.92, 0.06, 6, m.dark), { y: 0.3 }));
  g.add(at(ring(radius * 0.52, radius * 0.58, m.cyan, { segments: 48 }), { y: 0.34 }));
  g.add(at(ring(radius * 0.7, radius * 0.72, m.warn, { segments: 48 }), { y: 0.34 }));
  for (let i = 0; i < 6; i += 1) {
    const a = (i / 6) * Math.PI * 2;
    g.add(at(box(radius * 0.3, 0.02, 0.16, m.bright), { x: Math.cos(a) * radius * 0.78, y: 0.34, z: Math.sin(a) * radius * 0.78, ry: -a }));
  }
  return g;
}

export { at, box, bevelBox, cyl, cone, sphere, torus, plate, strut, greebles, boltRing, group, named, vent, railing, dish, cable, rng, pick, strip };
