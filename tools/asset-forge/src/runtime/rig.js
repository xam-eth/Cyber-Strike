/**
 * Rig — pivots, sockets and animation clips, without a skinning skeleton.
 *
 * The forged props are built from object hierarchies, which is exactly what the
 * three.js AnimationMixer animates natively. A model returns real
 * `THREE.AnimationClip` objects whose tracks address nodes by name, so the
 * gallery, the gate and the GLB export all read the same clips — nothing here
 * is a description of an animation that only exists in a comment.
 *
 * Character-shaped models (the hero, the humanoid enemy) get a named limb
 * hierarchy instead of a bone rig. `docs/3D_ASSET_FORGE.md` states the limit
 * plainly: this is not a skinned mesh, so shoulders and knees do not deform.
 */
import * as THREE from 'three';

/** Socket: an empty transform other systems attach to (muzzle, grip, hand). */
export function socket(parent, name, { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 } = {}) {
  const s = new THREE.Object3D();
  s.name = name;
  s.position.set(x, y, z);
  s.rotation.set(rx, ry, rz);
  parent.add(s);
  return s;
}

/**
 * Build a clip from terse track descriptors.
 * `tracks: [{ node: 'Core', property: 'rotation.y', keys: [[0,0],[2,6.28]] }]`
 */
/**
 * Clip authoring, in two layers.
 *
 * Model files describe animation as `{ node, property: 'rotation.x', keys }`,
 * which is readable but is **not** something a glTF file can hold: glTF
 * animation channels address a whole node property (`translation`, `rotation`,
 * `scale`), never a single axis. Authoring per-axis tracks and exporting them
 * produced two real defects, caught by the Khronos validator:
 *
 *   · `ArmR.rotation[x]` — three's exporter cannot map a bracketed *rotation*
 *     track to a node target, so the clip exported with **zero channels**
 *     (`EMPTY_ENTITY`). The clip played in three.js and vanished in the GLB.
 *   · `HoverRing.scale.x` + `HoverRing.scale.y` — two scalar accessors on one
 *     `scale` target (`ANIMATION_DUPLICATE_TARGETS`, and `SCALAR` where glTF
 *     requires `VEC3`).
 *
 * So `clip()` groups tracks by (node, channel), samples every axis onto the
 * union of key times, and emits one `QuaternionKeyframeTrack` for rotation or
 * one `VectorKeyframeTrack` for position/scale. The mixer gets the same motion;
 * the GLB gets channels a spec-compliant importer — Godot included — can read.
 */
const AXES = ['x', 'y', 'z'];
const CHANNEL_DEFAULT = { rotation: 0, position: 0, scale: 1 };

function splitProperty(property) {
  const [base, axis] = String(property).split('.');
  if (!(base in CHANNEL_DEFAULT)) throw new Error(`cannot animate property "${property}"`);
  return { base, axis: axis ?? null };
}

/** Piecewise-linear sample of `keys` ([[time, value], …]) at `t`. */
function sampleKeys(keys, t, fallback) {
  if (!keys?.length) return fallback;
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i += 1) {
    const [t1, v1] = keys[i];
    const [t0, v0] = keys[i - 1];
    if (t <= t1) {
      const span = t1 - t0;
      return span <= 0 ? v1 : v0 + ((v1 - v0) * (t - t0)) / span;
    }
  }
  return keys[keys.length - 1][1];
}

export function clip(name, duration, tracks) {
  const groups = new Map();
  for (const track of tracks) {
    const { base, axis } = splitProperty(track.property);
    const key = `${track.node}\u0000${base}`;
    if (!groups.has(key)) groups.set(key, { node: track.node, base, axes: {} });
    groups.get(key).axes[axis ?? 'all'] = track.keys;
  }

  const out = [];
  for (const group of groups.values()) {
    const { node, base, axes } = group;
    const fallback = CHANNEL_DEFAULT[base];
    const timeSet = new Set();
    for (const keys of Object.values(axes)) for (const [t] of keys) timeSet.add(t);
    const times = [...timeSet].sort((a, b) => a - b);
    const value = (axis, t) => (axis ? sampleKeys(axes[axis], t, fallback) : fallback);

    if (base === 'rotation') {
      const values = [];
      const euler = new THREE.Euler();
      const quat = new THREE.Quaternion();
      for (const t of times) {
        euler.set(value('x', t), value('y', t), value('z', t), 'XYZ');
        quat.setFromEuler(euler);
        values.push(quat.x, quat.y, quat.z, quat.w);
      }
      out.push(new THREE.QuaternionKeyframeTrack(`${node}.quaternion`, times, values));
    } else {
      const values = [];
      for (const t of times) values.push(value('x', t), value('y', t), value('z', t));
      out.push(new THREE.VectorKeyframeTrack(`${node}.${base}`, times, values));
    }
  }

  const c = new THREE.AnimationClip(name, duration, out);
  // `targets` is the authoritative list of nodes this clip addresses, used by
  // the gate's clip-targets-exist check.
  c.userData = { forged: true, targets: [...new Set(tracks.map((t) => t.node))] };
  return c;
}

/** Continuous spin — turntables, radar dishes, energy columns. */
export function spinClip(name, node, { axis = 'y', turns = 1, duration = 4 } = {}) {
  return clip(name, duration, [{ node, property: `rotation.${axis}`, keys: [[0, 0], [duration, Math.PI * 2 * turns]] }]);
}

/** Breathing pulse on a uniform (or single-axis) scale, loopable. */
export function pulseClip(name, node, { from = 1, to = 1.06, duration = 2.4, axis = null } = {}) {
  const key = [[0, from], [duration / 2, to], [duration, from]];
  const axes = axis ? [axis] : ['x', 'y', 'z'];
  return clip(name, duration, axes.map((a) => ({ node, property: `scale.${a}`, keys: key })));
}

/** Oscillating rotation around a rest pose (yaw sweeps, sway, scan). */
export function sweepClip(name, node, { axis = 'y', amplitude = 0.6, duration = 6, offset = 0 } = {}) {
  return clip(name, duration, [{
    node,
    property: `rotation.${axis}`,
    keys: [
      [0, offset - amplitude],
      [duration / 2, offset + amplitude],
      [duration, offset - amplitude],
    ],
  }]);
}

/** One-shot translation/rotation ramp — recoil, shutter, burst. */
export function rampClip(name, node, { property = 'position.z', from = 0, to = -0.12, duration = 0.18, back = true } = {}) {
  const keys = back
    ? [[0, from], [duration, to], [duration * 2.2, from]]
    : [[0, from], [duration, to]];
  return clip(name, back ? duration * 2.2 : duration, [{ node, property, keys }]);
}

/** Collect clips, dropping any whose node is not in the graph (the gate also checks). */
export function clips(root, list) {
  return list.filter(Boolean);
}

/** Node-name inventory, used by the gate to prove a track target exists. */
export function nodeNames(root) {
  const names = [];
  root.traverse((o) => { if (o.name) names.push(o.name); });
  return names;
}

function uniquifyNames(root, protectedNodes) {
  const seen = new Map();
  root.traverse((o) => {
    if (!o.name || protectedNodes.has(o)) return;
    const n = seen.get(o.name) ?? 0;
    seen.set(o.name, n + 1);
    if (n > 0) o.name = `${o.name}_${n + 1}`;
  });
}

/**
 * Normalisation step, applied by `finalize` and reported in the gate.
 *
 * Models are authored at their true scale, but "true" is an intention until it
 * is measured. This scales the finished graph uniformly so its height equals
 * `meta.targetHeight`, then seats it on the ground plane for `origin: 'ground'`.
 * The applied factor is recorded on the root (`forge.normalisation`) *and*
 * printed in `results.json`, and the gate fails a factor outside 0.5–2.0 — a
 * 3× squash would mean the model's proportions are wrong, not that the
 * normaliser saved the day.
 */
export function normalize(root, meta) {
  const box3 = new THREE.Box3().setFromObject(root);
  const size = box3.getSize(new THREE.Vector3());
  // Two normalisation modes: 'height' (default, buildings and characters) and
  // 'length' (a rifle is 1.0 m long and 0.25 m tall — normalising it by height
  // would blow the length up).
  const byLength = meta.normaliseBy === 'length';
  const authoredHeight = (byLength ? Math.max(size.x, size.y, size.z) : size.y) || 1;
  const target = byLength ? (meta.targetLength ?? meta.targetHeight) : meta.targetHeight;
  const factor = target ? target / authoredHeight : 1;
  let groundOffset = 0;
  if (factor !== 1) {
    root.scale.multiplyScalar(factor);
    root.updateMatrixWorld(true);
  }
  const originMode = meta.origin ?? 'ground';
  if (originMode === 'ground' || originMode === 'centre') {
    // 'ground' seats the lowest vertex on y=0; 'centre' puts the bounding-box
    // centre on the origin. Both are measured after scaling, never assumed.
    const after = new THREE.Box3().setFromObject(root);
    if (originMode === 'ground') {
      groundOffset = -after.min.y;
      root.position.y += groundOffset;
    } else {
      const c = after.getCenter(new THREE.Vector3());
      groundOffset = -c.y;
      root.position.y -= c.y;
      root.position.x -= c.x;
      root.position.z -= c.z;
    }
    root.updateMatrixWorld(true);
  }
  root.userData.forge = {
    ...(root.userData.forge ?? {}),
    normalisation: {
      mode: byLength ? 'length' : 'height',
      authoredHeight: Number(authoredHeight.toFixed(4)),
      scale: Number(factor.toFixed(4)),
      groundOffset: Number(groundOffset.toFixed(4)),
    },
  };
  return { authoredHeight, factor, groundOffset };
}

/**
 * Give every mesh that needs one a tangent attribute.
 *
 * A material with a tangent-space normal map is not portable without TANGENT:
 * runtimes either generate it (slow, and they may use a different handedness
 * convention) or the validator warns `MESH_PRIMITIVE_GENERATED_TANGENT_SPACE`.
 * three.js computes them from uv + normal, so do it once at finalize time and
 * the exported GLB carries them explicitly.
 */
export function ensureTangents(root) {
  root.traverse((node) => {
    if (!node.isMesh || !node.geometry) return;
    const materials = Array.isArray(node.material) ? node.material : [node.material];
    if (!materials.some((m) => m && m.normalMap)) return; // only normal-mapped parts need TANGENT
    const geometry = node.geometry;
    if (geometry.getAttribute('tangent')) return;
    if (!geometry.getAttribute('uv') || !geometry.getAttribute('normal')) return;
    if (!geometry.getIndex()) {
      // computeTangents() requires an index. A sequential one is geometry-neutral
      // and costs 2-4 bytes per vertex.
      const count = geometry.getAttribute('position').count;
      const wide = count > 65535;
      const index = wide ? new Uint32Array(count) : new Uint16Array(count);
      for (let i = 0; i < count; i += 1) index[i] = i;
      geometry.setIndex(new THREE.BufferAttribute(index, 1));
    }
    try {
      geometry.computeTangents();
      sanitiseTangents(geometry);
    } catch {
      // A primitive without enough uv variation cannot produce tangents; leaving
      // it alone is better than writing a degenerate attribute.
    }
  });
}

/**
 * Repair degenerate tangents.
 *
 * `computeTangents()` writes (0,0,0,0) for vertices whose triangles have no uv
 * area (a fused seam, a degenerate strip). A zero-length TANGENT makes the
 * validator fail with ACCESSOR_VECTOR3_NON_UNIT, and a runtime that trusts it
 * renders black. Any vector orthogonal to the vertex normal is a valid
 * replacement — the shading is identical where the uv basis is undefined.
 */
function sanitiseTangents(geometry) {
  const tangent = geometry.getAttribute('tangent');
  const normal = geometry.getAttribute('normal');
  if (!tangent || !normal) return;
  for (let i = 0; i < tangent.count; i += 1) {
    let x = tangent.getX(i);
    let y = tangent.getY(i);
    let z = tangent.getZ(i);
    let w = tangent.getW(i);
    const length = Math.hypot(x, y, z);
    if (length > 1e-6) {
      tangent.setXYZW(i, x / length, y / length, z / length, w < 0 ? -1 : 1);
      continue;
    }
    const nx = normal.getX(i);
    const ny = normal.getY(i);
    const nz = normal.getZ(i);
    // Cross the normal with whichever world axis it is least parallel to.
    const ax = Math.abs(ny) > 0.9 ? 1 : 0;
    const ay = Math.abs(ny) > 0.9 ? 0 : 1;
    x = ay * nz - 0 * ny;
    y = 0 * nx - ax * nz;
    z = ax * ny - ay * nx;
    const fallback = Math.hypot(x, y, z) || 1;
    tangent.setXYZW(i, x / fallback, y / fallback, z / fallback, 1);
  }
  tangent.needsUpdate = true;
}

/**
 * Finish a model: name its sockets, make every node name unique (three.js and
 * the glTF animation resolver address nodes by name, so a duplicate "Collar"
 * silently animates the wrong object), stamp metadata, return the payload the
 * gallery and the gate both consume.
 */
export function finalize(root, { meta, sockets = {}, clips: animationClips = [] }) {
  const socketMap = {};
  for (const [key, node] of Object.entries(sockets)) {
    if (!node) continue;
    if (!node.name || node.name.startsWith('Object3D')) node.name = key;
    socketMap[key] = node;
  }
  uniquifyNames(root, new Set(Object.values(socketMap)));
  ensureTangents(root);
  for (const [key, node] of Object.entries(socketMap)) {
    if (node.name !== key) node.name = key;
  }
  normalize(root, meta);
  root.userData.forge = {
    ...(root.userData.forge ?? {}),
    id: meta.id,
    category: meta.category,
    sockets: Object.keys(socketMap),
    clips: animationClips.map((c) => c.name),
  };
  return {
    id: meta.id,
    root,
    sockets: socketMap,
    clips: animationClips,
    meta,
  };
}
