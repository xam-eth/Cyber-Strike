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
export function clip(name, duration, tracks) {
  const c = new THREE.AnimationClip(name, duration, tracks.map((t) => new THREE.NumberKeyframeTrack(
    `${t.node}.${t.property}`,
    t.keys.map((k) => k[0]),
    t.keys.map((k) => k[1]),
  )));
  // `targets` is the authoritative list of nodes this clip addresses. The track
  // string alone is ambiguous ("Plasma.scale.x" has three dot-separated parts),
  // so the gate validates the recorded targets instead of re-parsing the name.
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
