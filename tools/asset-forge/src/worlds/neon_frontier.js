/**
 * neon_frontier.js — the world, assembled.
 *
 * This is the single composition root for the 3D world deliverable. Nothing here
 * invents geometry: terrain comes from `terrain.js`, props come from
 * `src/world/*.js` via the catalog registry, and placement comes from
 * `layout.js`, which mirrors the shipped Godot zones.
 *
 *   import { buildWorld } from './worlds/neon_frontier.js';
 *   const world = buildWorld();          // { root, clips, stats, meta }
 *   mixer = new THREE.AnimationMixer(world.root);
 *   world.clips.forEach((c) => mixer.clipAction(c).play());
 *
 * The result is renderable as-is: callers add lights, an environment and a
 * camera. Exporting it to glTF (see `gate/world_export.mjs`) gives one file the
 * whole world can be inspected in.
 */
import * as THREE from 'three';
import { registry } from '../registry.js';
import { rng } from '../runtime/kit.js';
import { PALETTE } from '../runtime/palette.js';
import { pulseClip, ensureTangents } from '../runtime/rig.js';
import { WORLD, PLACEMENTS, SCATTER, PLAYER_SPAWNS } from './layout.js';
import { buildTerrain } from './terrain.js';
import { assembleProps, placeProp } from './assembly.js';

const DEG = Math.PI / 180;

/**
 * Vegetation and geology are placed from the game's own coordinate lists, with a
 * deterministic per-instance tilt/scale so nineteen identical flora do not read
 * as nineteen identical flora. The seed is the index, so the world is stable
 * across reloads and across exports.
 */
async function scatterProps() {
  const root = new THREE.Group();
  root.name = 'Scatter';
  const clips = [];
  const counts = {};

  // eslint-disable-next-line no-await-in-loop
  const push = async (id, name, pos, { yaw = 0, scale = 1, jitter = 0 } = {}) => {
    const rand = rng(pos[0] * 31 + pos[1] * 17 + 7);
    const wobble = 1 + (rand() - 0.5) * jitter;
    const { holder, clips: placed } = await placeProp({
      id,
      name,
      pos,
      yaw: yaw + (rand() - 0.5) * jitter * 90,
      scale: [scale * wobble, scale * (1 + (rand() - 0.5) * jitter * 0.6), scale * wobble],
      pitch: (rand() - 0.5) * jitter * 6,
      roll: (rand() - 0.5) * jitter * 6,
      district: 'wilds',
    });
    root.add(holder);
    clips.push(...placed);
    counts[id] = (counts[id] ?? 0) + 1;
  };

  for (const [i, [x, z]] of SCATTER.crystal.entries()) {
    await push('crystal_cluster', `FrontierCrystalCluster_${String(i).padStart(2, '0')}`, [x, 0, z], { yaw: i * 41, jitter: 0.18 });
  }
  for (const [i, [x, z]] of SCATTER.flora.entries()) {
    await push('alien_flora', `LuminousAlienFlora_${String(i).padStart(2, '0')}`, [x, 0, z], { yaw: i * 23, jitter: 0.3 });
  }
  for (const [i, [x, z, s]] of SCATTER.rocks.entries()) {
    await push('rock_cluster', `FrontierRockCluster_${String(i).padStart(2, '0')}`, [x, 0, z], { yaw: i * 57, scale: s, jitter: 0.22 });
  }

  return { root, clips, counts };
}

/**
 * World-level motion. The props carry their own clips; these are the beats that
 * belong to the *place* rather than to one prop — the deck lights breathing out
 * of step, the arena warning ring pulsing on the reactor's rhythm, and the
 * skyline antennae idling.
 */
function worldMotion(terrainRoot) {
  const clips = [];
  const lamps = [];
  terrainRoot.traverse((node) => {
    if (node.name.startsWith('ArenaDeckLamp_')) lamps.push(node.name);
  });
  // Out of phase, so the deck never blinks in unison (which reads as a bug).
  lamps.forEach((name, i) => {
    clips.push(pulseClip(`deck_lamp_${i}`, name, { from: 1, to: 1.35, duration: 2.4 + i * 0.55 }));
  });
  const hazard = terrainRoot.getObjectByName('ArenaHazardRing');
  if (hazard) clips.push(pulseClip('hazard_breathe', 'ArenaHazardRing', { from: 1, to: 1.008, duration: 5.2 }));
  return clips;
}

export async function buildWorld() {
  const root = new THREE.Group();
  root.name = 'NeonFrontier';

  const terrain = buildTerrain();
  root.add(terrain.root);

  const props = await assembleProps(PLACEMENTS);
  root.add(props.root);

  const scatter = await scatterProps();
  root.add(scatter.root);

  // Player spawn markers: empty nodes with a readable name, so the game can find
  // them (`world.root.getObjectByName('spawn_outpost')`) and so the exported GLB
  // documents where a match may start.
  const spawns = new THREE.Group();
  spawns.name = 'PlayerSpawns';
  for (const spawn of PLAYER_SPAWNS) {
    const marker = new THREE.Object3D();
    marker.name = spawn.name;
    marker.position.set(spawn.pos[0], spawn.pos[1], spawn.pos[2]);
    spawns.add(marker);
  }
  root.add(spawns);

  // Terrain is built here rather than by a model module, so it does not pass
  // through `finalize()`. Run the same tangent pass over the finished graph:
  // normal-mapped ground and deck need explicit TANGENT to be portable.
  ensureTangents(root);

  const clips = [...props.clips, ...scatter.clips, ...worldMotion(terrain.root)];

  const counts = { ...props.stats.counts };
  for (const [id, n] of Object.entries(scatter.counts)) counts[id] = (counts[id] ?? 0) + n;

  const stats = {
    instances: props.stats.instances + Object.values(scatter.counts).reduce((a, b) => a + b, 0),
    counts,
    districts: [...props.stats.districts, 'wilds'],
    triangles: props.stats.triangles,
    clips: clips.length,
    assets: Object.keys(counts).length,
  };

  const meta = {
    id: 'neon_frontier_world',
    name: 'NEON FRONTIER — Frontier Outpost',
    category: 'world',
    width: WORLD.width,
    depth: WORLD.depth,
    centreZ: WORLD.centreZ,
    spawns: PLAYER_SPAWNS.map((s) => s.name),
    palette: PALETTE,
  };

  root.userData.forge = { id: meta.id, stats, meta };
  return { root, clips, stats, meta };
}

/** Lighting rig used by the viewer and by the render captures — one definition. */
export function worldLighting(scene) {
  const key = new THREE.DirectionalLight(0xffe2b4, 4.6);
  key.position.set(-58, 74, 46);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.near = 10;
  key.shadow.camera.far = 320;
  key.shadow.camera.left = -130;
  key.shadow.camera.right = 130;
  key.shadow.camera.top = 130;
  key.shadow.camera.bottom = -130;
  key.shadow.bias = -0.0006;
  key.name = 'KeySun';

  const fill = new THREE.DirectionalLight(0x54c8ff, 1.5);
  fill.position.set(80, 40, -60);
  fill.name = 'CyanFill';

  const rim = new THREE.DirectionalLight(0xb79cff, 1.5);
  rim.position.set(-40, 22, -90);
  rim.name = 'VioletRim';

  const sky = new THREE.HemisphereLight(0x3d5a75, 0x0d151d, 2.0);
  sky.name = 'SkyBounce';

  scene.add(key, fill, rim, sky);
  return { key, fill, rim, sky };
}
