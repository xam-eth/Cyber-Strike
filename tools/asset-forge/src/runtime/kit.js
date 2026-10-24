/**
 * Kit — the primitive vocabulary shared by every forged model.
 *
 * Everything here is deterministic: given the same seed the same vertices, in
 * the same order. That is what makes the gate's "build twice, compare" check
 * meaningful instead of decorative.
 *
 * Units are metres, +Y up, -Z forward (the same convention the Godot assets use,
 * where a character faces -Z).
 */
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

/* ------------------------------------------------------------------ random */

/** mulberry32 — small, fast, deterministic. */
export function rng(seed = 1) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function pick(rand, list) {
  return list[Math.floor(rand() * list.length) % list.length];
}

/* --------------------------------------------------------------- placement */

/** Apply position/rotation/scale in place and return the object (chainable). */
export function at(obj, { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, sx = 1, sy = 1, sz = 1 } = {}) {
  obj.position.set(x, y, z);
  obj.rotation.set(rx, ry, rz);
  obj.scale.set(sx, sy, sz);
  return obj;
}

export function named(obj, name) {
  obj.name = name;
  return obj;
}

export function group(name) {
  const g = new THREE.Group();
  g.name = name;
  return g;
}

/* ---------------------------------------------------------------- geometry */

function mesh(geometry, material, name) {
  const m = new THREE.Mesh(geometry, material);
  m.castShadow = true;
  m.receiveShadow = true;
  if (name) m.name = name;
  return m;
}

/** Hard-edged box — the workhorse. */
export function box(w, h, d, material, opts = {}) {
  return mesh(new THREE.BoxGeometry(w, h, d), material, opts.name);
}

/** Chamfered box. `radius` is the bevel in metres; keep it small. */
export function bevelBox(w, h, d, material, { radius = 0.02, segments = 1, ...opts } = {}) {
  const r = Math.min(radius, Math.min(w, h, d) * 0.45);
  return mesh(new RoundedBoxGeometry(w, h, d, segments, r), material, opts.name);
}

/** Cylinder along +Y by default; `axis` re-orients it. */
export function cyl(rTop, rBottom, h, segments, material, { axis = 'y', open = false, ...opts } = {}) {
  const g = new THREE.CylinderGeometry(rTop, rBottom, h, segments, 1, open);
  if (axis === 'x') g.rotateZ(Math.PI / 2);
  if (axis === 'z') g.rotateX(Math.PI / 2);
  return mesh(g, material, opts.name);
}

export function cone(r, h, segments, material, opts = {}) {
  return mesh(new THREE.ConeGeometry(r, h, segments), material, opts.name);
}

export function sphere(r, material, { widthSegments = 12, heightSegments = 8, ...opts } = {}) {
  return mesh(new THREE.SphereGeometry(r, widthSegments, heightSegments), material, opts.name);
}

export function ring(rInner, rOuter, material, { segments = 24, ...opts } = {}) {
  const g = new THREE.RingGeometry(rInner, rOuter, segments);
  g.rotateX(-Math.PI / 2);
  return mesh(g, material, opts.name);
}

export function torus(r, tube, material, { radial = 8, tubular = 24, ...opts } = {}) {
  return mesh(new THREE.TorusGeometry(r, tube, radial, tubular), material, opts.name);
}

/** Thin panel with a chamfer — the detail that makes a plate read as a plate. */
export function plate(w, h, t, material, { radius = 0.008, ...opts } = {}) {
  return bevelBox(w, h, t, material, { radius, segments: 1, ...opts });
}

/** A cylinder spanning two points — struts, pipes, cables, braces. */
export function strut(from, to, radius, material, { segments = 6, name } = {}) {
  const a = new THREE.Vector3(...from);
  const b = new THREE.Vector3(...to);
  const dir = new THREE.Vector3().subVectors(b, a);
  const len = dir.length();
  const g = new THREE.CylinderGeometry(radius, radius, len, segments, 1, false);
  const m = new THREE.Mesh(g, material);
  m.name = name ?? '';
  m.position.copy(a).addScaledVector(dir, 0.5);
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().normalize());
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}

/** Sagging cable between two points. Deterministic sag, no physics. */
export function cable(from, to, radius, material, { sag = 0.25, segments = 20, name } = {}) {
  const a = new THREE.Vector3(...from);
  const b = new THREE.Vector3(...to);
  const mid = a.clone().add(b).multiplyScalar(0.5);
  mid.y -= sag;
  const curve = new THREE.CatmullRomCurve3([a, mid, b]);
  const g = new THREE.TubeGeometry(curve, segments, radius, 5, false);
  return mesh(g, material, name);
}

/** A pipe run through a list of points. */
export function pipeRun(points, radius, material, { segments = 8, name } = {}) {
  const out = group(name ?? 'PipeRun');
  for (let i = 0; i < points.length - 1; i += 1) {
    out.add(strut(points[i], points[i + 1], radius, material, { segments }));
  }
  return out;
}

/* ------------------------------------------------------------------ detail */

/**
 * Scatter small greeble plates across one face of a box volume.
 * `face` is one of +x,-x,+y,-y,+z,-z. Everything stays inside the volume.
 */
export function greebles({
  w, h, d, face = '+z', count = 12, seed = 7, materials, size = [0.06, 0.2],
  inset = 0, name = 'Greebles', centre = [0, 0, 0],
}) {
  const rand = rng(seed);
  const out = group(name);
  const [minS, maxS] = size;
  for (let i = 0; i < count; i += 1) {
    const sw = minS + rand() * (maxS - minS);
    const sh = minS + rand() * (maxS - minS) * 0.7;
    const st = 0.01 + rand() * 0.03;
    const m = pick(rand, materials);
    const piece = st > 0.028
      ? bevelBox(sw, sh, st, m, { radius: 0.004, segments: 1 })
      : box(sw, sh, st, m);
    const [cx, cy, cz] = centre;
    const jitterX = (rand() - 0.5) * Math.max(0.01, w - sw);
    const jitterY = (rand() - 0.5) * Math.max(0.01, h - sh);
    if (face === '+z') at(piece, { x: cx + jitterX, y: cy + jitterY, z: cz + d / 2 + st / 2 + inset });
    else if (face === '-z') at(piece, { x: cx + jitterX, y: cy + jitterY, z: cz - d / 2 - st / 2 - inset, ry: Math.PI });
    else if (face === '+x') at(piece, { x: cx + w / 2 + st / 2 + inset, y: cy + jitterY, z: cz + jitterX, ry: Math.PI / 2 });
    else if (face === '-x') at(piece, { x: cx - w / 2 - st / 2 - inset, y: cy + jitterY, z: cz + jitterX, ry: -Math.PI / 2 });
    else if (face === '+y') {
      piece.geometry.dispose();
      piece.geometry = new THREE.BoxGeometry(sw, st, sh);
      at(piece, { x: cx + jitterX, y: cy + h / 2 + st / 2 + inset, z: cz + jitterY });
    } else {
      piece.geometry.dispose();
      piece.geometry = new THREE.BoxGeometry(sw, st, sh);
      at(piece, { x: cx + jitterX, y: cy - h / 2 - st / 2 - inset, z: cz + jitterY });
    }
    out.add(piece);
  }
  return out;
}

/** Bolt/rivet ring around a cylinder face. Cheap, and it sells scale. */
export function boltRing({ radius = 0.3, count = 12, size = 0.02, y = 0, material, axis = 'y', name = 'Bolts' }) {
  const out = group(name);
  const geo = new THREE.CylinderGeometry(size, size, size * 1.6, 6, 1, false);
  for (let i = 0; i < count; i += 1) {
    const a = (i / count) * Math.PI * 2;
    const bolt = mesh(geo, material);
    if (axis === 'y') at(bolt, { x: Math.cos(a) * radius, y, z: Math.sin(a) * radius });
    else if (axis === 'x') at(bolt, { x: y, y: Math.cos(a) * radius, z: Math.sin(a) * radius, rz: Math.PI / 2 });
    else at(bolt, { x: Math.cos(a) * radius, y: Math.sin(a) * radius, z: y, rx: Math.PI / 2 });
    out.add(bolt);
  }
  return out;
}

/** Inset shadow gap: a slightly smaller dark box behind a plate. */
export function seam(w, h, material, { depth = 0.012, ...opts } = {}) {
  return box(w, h, depth, material, opts);
}

/** Emissive strip, recessed into a dark frame so it does not glow into space. */
export function strip({ w = 0.4, h = 0.03, d = 0.03, glowMaterial, frameMaterial, frame = 0.012, name = 'Strip' }) {
  const g = group(name);
  g.add(at(box(w + frame * 2, h + frame * 2, d, frameMaterial), { z: -0.002 }));
  g.add(at(box(w, h, d * 1.4, glowMaterial), { z: 0.002 }));
  return g;
}

/**
 * Parabolic dish opening toward +Z, with a rim, a feed horn in front of the
 * bowl and three feed struts. Built from its own material clone so setting
 * DoubleSide here cannot change a shared cached material elsewhere.
 */
export function dish(radius, material, { depth = 0.22, segments = 20, name = 'Dish', rimMaterial } = {}) {
  const g = group(name);
  const points = [];
  const steps = 8;
  for (let i = 0; i <= steps; i += 1) {
    const t = i / steps;
    points.push(new THREE.Vector2(radius * t, -depth * t * t));
  }
  const lathe = new THREE.LatheGeometry(points, segments);
  lathe.rotateX(-Math.PI / 2);
  const bowlMat = material.clone();
  bowlMat.side = THREE.DoubleSide;
  const bowl = mesh(lathe, bowlMat, `${name}_Bowl`);
  g.add(bowl);
  g.add(at(torus(radius, radius * 0.035, rimMaterial ?? material, { radial: 5, tubular: segments }), { z: 0.0 }));
  const horn = group('Feed');
  horn.add(at(cone(radius * 0.14, radius * 0.22, 8, material), { z: radius * 0.42, rx: Math.PI }));
  for (let i = 0; i < 3; i += 1) {
    const a = (i / 3) * Math.PI * 2;
    horn.add(strut(
      [Math.cos(a) * radius * 0.9, Math.sin(a) * radius * 0.9, -depth * 0.4],
      [0, 0, radius * 0.36],
      radius * 0.012, material, { segments: 4 },
    ));
  }
  g.add(horn);
  return g;
}

/** Guard rail along X. */
export function railing(length, height, material, { posts = 6, name = 'Railing' } = {}) {
  const g = group(name);
  const postGeo = new THREE.CylinderGeometry(0.018, 0.018, height, 6);
  for (let i = 0; i < posts; i += 1) {
    const p = mesh(postGeo, material);
    at(p, { x: -length / 2 + (length / (posts - 1)) * i, y: height / 2 });
    g.add(p);
  }
  g.add(at(box(length, 0.03, 0.03, material), { y: height }));
  g.add(at(box(length, 0.025, 0.025, material), { y: height * 0.55 }));
  return g;
}

/** Triangulated truss for masts and pylons. */
export function truss(width, height, depth, material, { bays = 5, thickness = 0.05, name = 'Truss' } = {}) {
  const g = group(name);
  const hw = width / 2;
  const hd = depth / 2;
  const corners = [
    [-hw, -hd], [hw, -hd], [hw, hd], [-hw, hd],
  ];
  for (const [cx, cz] of corners) g.add(at(box(thickness, height, thickness, material), { x: cx, y: height / 2, z: cz }));
  for (let i = 0; i <= bays; i += 1) {
    const y = (height / bays) * i;
    for (let c = 0; c < 4; c += 1) {
      const a = corners[c];
      const b = corners[(c + 1) % 4];
      g.add(strut([a[0], y, a[1]], [b[0], y, b[1]], thickness * 0.55, material, { segments: 4 }));
    }
    if (i < bays) {
      const y2 = (height / bays) * (i + 1);
      for (let c = 0; c < 4; c += 1) {
        const a = corners[c];
        const b = corners[(c + 1) % 4];
        g.add(strut([a[0], y, a[1]], [b[0], y2, b[1]], thickness * 0.45, material, { segments: 4 }));
      }
    }
  }
  return g;
}

/** Vent grille: a dark recess with fins. */
export function vent(w, h, fins, material, glowMaterial, { name = 'Vent' } = {}) {
  const g = group(name);
  g.add(box(w, h, 0.02, material));
  const finGeo = new THREE.BoxGeometry(w * 0.86, h / (fins * 2.4), 0.015);
  for (let i = 0; i < fins; i += 1) {
    const fin = mesh(finGeo, i % 2 === 0 ? material : (glowMaterial ?? material));
    at(fin, { y: -h / 2 + (h / fins) * (i + 0.5), z: 0.014 });
    g.add(fin);
  }
  return g;
}

/** Merge a group's meshes that share a material — keeps draw calls honest. */
export function mergeByMaterial(source, { keepNames = [] } = {}) {
  const buckets = new Map();
  const keep = [];
  source.updateMatrixWorld(true);
  const toRemove = [];
  source.traverse((o) => {
    if (!o.isMesh) return;
    if (keepNames.includes(o.name)) { keep.push(o); return; }
    const m = o.material;
    const key = m.uuid;
    if (!buckets.has(key)) buckets.set(key, { material: m, geometries: [] });
    const geo = o.geometry.clone();
    geo.applyMatrix4(o.matrixWorld);
    buckets.get(key).geometries.push(geo);
    toRemove.push(o);
  });
  for (const o of toRemove) o.removeFromParent();
  const merged = group('Merged');
  for (const { material, geometries } of buckets.values()) {
    const geo = mergeGeometries(geometries, false);
    if (!geo) continue;
    const m = mesh(geo, material);
    merged.add(m);
    for (const g of geometries) g.dispose();
  }
  for (const k of keep) if (!k.parent) merged.add(k);
  merged.matrixAutoUpdate = true;
  return merged;
}

/** Full bounding box of an object graph, in its own space. */
export function measure(root) {
  const box3 = new THREE.Box3().setFromObject(root);
  const size = box3.getSize(new THREE.Vector3());
  const centre = box3.getCenter(new THREE.Vector3());
  return { box: box3, size, centre, min: box3.min.clone(), max: box3.max.clone() };
}

/** Uniform-scale a graph so its tallest axis hits a target height in metres. */
export function fitToHeight(root, targetHeight) {
  const { size } = measure(root);
  const h = size.y || 1;
  const s = targetHeight / h;
  root.scale.multiplyScalar(s);
  return s;
}
