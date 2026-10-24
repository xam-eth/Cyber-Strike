/**
 * assembly.js — instancing.
 *
 * `src/world/*.js` each build *one* prop. The world builds forty-odd of them, so
 * two things have to be true before a single AnimationMixer can drive the lot:
 *
 *  1. Node names are unique. two turrets both contain a node called `Yaw`, and
 *     three.js binds animation tracks by name — without a prefix, turret A's
 *     sweep would also spin turret B's barrels.
 *  2. Clip names are unique, and their track names carry the same prefix.
 *
 * Both are handled here, in one place, so a model author never has to think
 * about how many copies of their prop the world will place.
 */
import * as THREE from 'three';
import { registry } from '../registry.js';

const deg = (d) => (d * Math.PI) / 180;

/** Rewrite `Node.channel` → `prefix__Node.channel` for every track in `clip`. */
function prefixClip(clip, prefix, name) {
  const tracks = clip.tracks.map((track) => {
    const clone = track.clone();
    const dot = clone.name.indexOf('.');
    clone.name = dot === -1
      ? `${prefix}__${clone.name}`
      : `${prefix}__${clone.name.slice(0, dot)}${clone.name.slice(dot)}`;
    return clone;
  });
  const out = new THREE.AnimationClip(`${prefix}.${name}`, clip.duration, tracks);
  out.userData = { ...clip.userData, instance: prefix, source: name };
  return out;
}

/** Give every descendant a world-unique name. Returns nothing: it is in-place. */
function prefixNodes(root, prefix) {
  root.traverse((node) => {
    if (node.name) node.name = `${prefix}__${node.name}`;
  });
}

/**
 * Place one catalogued prop. Async because the registry resolves modules through
 * `load()`, the same door the gate and the gallery use.
 * @returns {Promise<{ holder: THREE.Group, clips: THREE.AnimationClip[], meta: object }>}
 */
export async function placeProp(placement) {
  const entry = registry[placement.id];
  if (!entry) throw new Error(`world layout references unknown asset "${placement.id}"`);

  // `build()` is pure, so placing the same id twice yields two independent trees
  // that share the material and texture caches — 40 props, one texture set.
  const module = await entry.load();
  const payload = module.build();
  const root = payload.root;
  prefixNodes(root, placement.name);

  // The models are authored at ground level; a placement can lift them via pos[1].
  root.name = `${placement.name}__Root`;
  root.position.set(0, 0, 0);

  const holder = new THREE.Group();
  holder.name = placement.name;
  const [x, y, z] = placement.pos;
  holder.position.set(x, y, z);
  holder.rotation.set(deg(placement.roll ?? 0), deg(placement.yaw ?? 0), deg(placement.pitch ?? 0), 'YXZ');
  const scale = placement.scale ?? 1;
  if (Array.isArray(scale)) holder.scale.set(scale[0], scale[1], scale[2]);
  else holder.scale.setScalar(scale);
  holder.userData.district = placement.district;
  holder.userData.assetId = placement.id;
  holder.add(root);

  const animationClips = (payload.clips ?? []).map((clip) => prefixClip(clip, placement.name, clip.name));
  return { holder, clips: animationClips, meta: payload.meta };
}

/**
 * Build every placement in `list`, grouped by district.
 * @returns {{ root: THREE.Group, clips: THREE.AnimationClip[], stats: object }}
 */
export async function assembleProps(list) {
  const root = new THREE.Group();
  root.name = 'Districts';
  const districts = new Map();
  const animationClips = [];
  const counts = {};
  let triangles = 0;

  for (const placement of list) {
    if (!districts.has(placement.district)) {
      const g = new THREE.Group();
      g.name = `District_${placement.district}`;
      districts.set(placement.district, g);
      root.add(g);
    }
    // Sequential on purpose: models are pure but share one material cache, and a
    // serial build keeps texture generation to a single first call.
    // eslint-disable-next-line no-await-in-loop
    const { holder, clips, meta } = await placeProp(placement);
    districts.get(placement.district).add(holder);
    animationClips.push(...clips);
    counts[placement.id] = (counts[placement.id] ?? 0) + 1;

    holder.traverse((node) => {
      if (!node.isMesh || !node.geometry) return;
      node.castShadow = true;
      node.receiveShadow = true;
      const index = node.geometry.getIndex();
      const position = node.geometry.getAttribute('position');
      triangles += index ? index.count / 3 : (position ? position.count / 3 : 0);
    });
    void meta;
  }

  return {
    root,
    clips: animationClips,
    stats: {
      instances: list.length,
      counts,
      districts: [...districts.keys()],
      triangles: Math.round(triangles),
    },
  };
}
