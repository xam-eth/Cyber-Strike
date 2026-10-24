/**
 * realAssembly.js — turn a role spec into a placed, animated instance.
 *
 * Composition only. Each part is a real GLB loaded by `realModels.js`; this file
 * decides where the parts sit, gives them unique names, and authors the motion
 * tracks that make the world breathe.
 *
 * Naming: every node is prefixed with the instance name (`SensorTower_03__Dish`).
 * three.js binds animation tracks by node name, so without the prefix the dish of
 * one tower would also spin on the other four.
 */
import * as THREE from 'three';
import { clip } from '../runtime/rig.js';
import { makePart } from './realModels.js';
import { ROLE_SPECS } from './roleSpecs.js';

const DEG = Math.PI / 180;

/**
 * Livery, not geometry: give a placed part a glowing edge. The mesh still comes
 * from the real file; only the emissive channel of its own material changes, and
 * the material is cloned so one lit beacon does not light every other part.
 */
function applyLivery(group, { color, intensity = 0.7 }) {
  const tint = new THREE.Color(color);
  group.traverse((node) => {
    if (!node.isMesh) return;
    const source = node.material;
    if (!source || source.emissive === undefined) return;
    const lit = source.clone();
    lit.emissive = tint.clone();
    lit.emissiveIntensity = intensity;
    lit.needsUpdate = true;
    node.material = lit;
  });
}

function prefixNodes(root, prefix) {
  root.traverse((node) => {
    if (node.name) node.name = `${prefix}__${node.name}`;
  });
}

function prefixTrack(clipIn, prefix, name) {
  // `motionClip` was already given the fully prefixed node name, so the track
  // names are final — re-prefixing here silently produced orphan tracks.
  const tracks = clipIn.tracks.map((track) => track.clone());
  // Dots are legal in glTF but Godot's importer rewrites them, so the clip name
  // is written exactly the way both engines will report it.
  const out = new THREE.AnimationClip(`${prefix}_${name}`, clipIn.duration, tracks);
  out.userData = { instance: prefix, source: name };
  return out;
}

/**
 * Motion from data: a spin is two keys, a sweep is three, a pulse is three scale
 * keys. Durations are seconds and speeds are rad/s, so the numbers are readable.
 */
function motionClip(name, nodeName, spec) {
  const duration = spec.duration ?? (Math.PI * 2) / Math.max(spec.speed ?? 1, 0.01);
  if (spec.kind === 'spin') {
    return clip(name, duration, [{
      node: nodeName,
      property: `rotation.${spec.axis ?? 'y'}`,
      keys: [[0, 0], [duration, Math.PI * 2 * (spec.turns ?? 1)]],
    }]);
  }
  if (spec.kind === 'sweep') {
    const a = spec.amount ?? 0.5;
    const d = duration * 2;
    return clip(name, d, [{
      node: nodeName,
      property: `rotation.${spec.axis ?? 'y'}`,
      keys: [[0, -a], [d / 2, a], [d, -a]],
    }]);
  }
  if (spec.kind === 'bob') {
    const a = spec.amount ?? 0.05;
    const d = duration;
    return clip(name, d, [{
      node: nodeName,
      property: 'position.y',
      keys: [[0, 0], [d / 2, a], [d, 0]],
    }]);
  }
  // pulse — scale about the rest pose
  const a = spec.amount ?? 0.05;
  const d = duration;
  const keys = [[0, 1 - a], [d / 2, 1 + a], [d, 1 - a]];
  return clip(name, d, ['x', 'y', 'z'].map((axis) => ({
    node: nodeName,
    property: `scale.${axis}`,
    keys,
  })));
}

/**
 * Build one role instance.
 * @param {string} roleId key of ROLE_SPECS
 * @param {{ name: string, pos: number[], yaw?: number, scale?: number|number[], district: string }} placement
 */
export async function buildRole(roleId, placement) {
  const spec = ROLE_SPECS[roleId];
  if (!spec) throw new Error(`unknown role "${roleId}"`);

  const root = new THREE.Group();
  root.name = placement.name;
  const [x, y, z] = placement.pos;
  root.position.set(x, y, z);
  root.rotation.y = (placement.yaw ?? 0) * DEG;
  const scale = placement.scale ?? 1;
  if (Array.isArray(scale)) root.scale.set(scale[0], scale[1], scale[2]);
  else root.scale.setScalar(scale);
  root.userData.role = roleId;
  root.userData.district = placement.district;

  const sources = [];
  for (const part of spec.parts) {
    const built = await makePart({ ...part, name: part.name ?? part.model });
    built.group.userData.rolePart = part.name ?? part.model;
    if (part.emissive) applyLivery(built.group, part.emissive);
    root.add(built.group);
    sources.push(built.source);
  }

  prefixNodes(root, placement.name);

  const clips = [];
  for (const rule of spec.anim ?? []) {
    const nodeName = `${placement.name}__${rule.node}`;
    if (!root.getObjectByName(nodeName)) {
      throw new Error(`${roleId}/${placement.name}: motion rule targets missing node ${rule.node}`);
    }
    clips.push(prefixTrack(
      motionClip(rule.node, nodeName, rule),
      placement.name,
      `${rule.node}_${rule.kind}`,
    ));
  }

  return { root, clips, sources: [...new Set(sources)], roleId };
}
