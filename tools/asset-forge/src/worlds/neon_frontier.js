/**
 * neon_frontier.js — the world, assembled from real assets.
 *
 * Composition root. Nothing in this file creates geometry, textures or
 * materials; it places real GLB files and hands one animation clip list to the
 * viewer. The layers:
 *
 *   terrainReal.js  — ground tiles, road plates, arena deck, perimeter, craters
 *   layout.js       — where each role stands (mirrors the shipped Godot zones)
 *   roleSpecs.js    — which real models each role is made of, and what moves
 *   assemblyReal.js — instance building, name prefixing, motion clips
 *   roleSpecs.LANDMARKS — the Power Plant set piece
 *
 *   const world = await buildWorld();
 *   mixer = new THREE.AnimationMixer(world.root);
 *   world.clips.forEach((c) => mixer.clipAction(c).play());
 */
import * as THREE from 'three';
import { PALETTE } from '../runtime/palette.js';
import { makePart } from './realModels.js';
import { buildRole } from './assemblyReal.js';
import { ROLE_SPECS, LANDMARKS } from './roleSpecs.js';
import { WORLD, PLACEMENTS, SCATTER, PLAYER_SPAWNS } from './layout.js';
import { buildTerrain } from './terrainReal.js';

const DEG = Math.PI / 180;

/** Scatter props: the game's own coordinate lists, with a deterministic tilt. */
async function scatter() {
  const root = new THREE.Group();
  root.name = 'Scatter';
  const clips = [];
  const counts = {};
  const sources = [];

  const place = async (roleId, name, pos, { yaw = 0, scale = 1, jitter = 0 } = {}) => {
    const seed = Math.abs(pos[0] * 31 + pos[1] * 17 + 7);
    const rand = () => {
      const x = Math.sin(seed + name.length * 13.7) * 43758.5453;
      return x - Math.floor(x);
    };
    const built = await buildRole(roleId, {
      name,
      pos,
      yaw: yaw + (rand() - 0.5) * jitter * 90,
      scale: [scale, scale * (1 + (rand() - 0.5) * jitter * 0.5), scale],
      district: 'wilds',
    });
    root.add(built.root);
    clips.push(...built.clips);
    sources.push(...built.sources);
    counts[roleId] = (counts[roleId] ?? 0) + 1;
  };

  for (const [i, [x, z]] of SCATTER.crystal.entries()) {
    await place('crystal_cluster', `FrontierCrystalCluster_${String(i).padStart(2, '0')}`, [x, 0, z], { yaw: i * 41, jitter: 0.18 });
  }
  for (const [i, [x, z]] of SCATTER.flora.entries()) {
    await place('alien_flora', `LuminousAlienFlora_${String(i).padStart(2, '0')}`, [x, 0, z], { yaw: i * 23, jitter: 0.3 });
  }
  for (const [i, [x, z, s]] of SCATTER.rocks.entries()) {
    await place('rock_cluster', `FrontierRockCluster_${String(i).padStart(2, '0')}`, [x, 0, z], { yaw: i * 57, scale: s, jitter: 0.22 });
  }

  return { root, clips, counts, sources };
}

export async function buildWorld() {
  const root = new THREE.Group();
  root.name = 'NeonFrontier';
  const sources = [];

  const terrain = await buildTerrain();
  root.add(terrain.root);
  sources.push(...terrain.sources);

  /* ------------------------------------------------------------- roles -- */
  const districts = new Map();
  const clips = [];
  const counts = {};
  let triangles = 0;

  for (const placement of PLACEMENTS) {
    if (!districts.has(placement.district)) {
      const g = new THREE.Group();
      g.name = `District_${placement.district}`;
      districts.set(placement.district, g);
      root.add(g);
    }
    const built = await buildRole(placement.id, placement);
    districts.get(placement.district).add(built.root);
    clips.push(...built.clips);
    sources.push(...built.sources);
    counts[placement.id] = (counts[placement.id] ?? 0) + 1;
  }

  /* ---------------------------------------------------------- landmarks -- */
  const landmarkGroup = new THREE.Group();
  landmarkGroup.name = 'District_landmark';
  for (const [id, spec] of Object.entries(LANDMARKS)) {
    const part = await makePart({
      model: spec.model,
      height: spec.height,
      pos: spec.pos,
      yaw: spec.yaw,
      name: `Landmark_${id}`,
    });
    landmarkGroup.add(part.group);
    sources.push(part.source);
  }
  root.add(landmarkGroup);

  /* ------------------------------------------------------------ scatter -- */
  const scattered = await scatter();
  root.add(scattered.root);
  clips.push(...scattered.clips);
  sources.push(...scattered.sources);
  for (const [id, n] of Object.entries(scattered.counts)) counts[id] = (counts[id] ?? 0) + n;

  /* ------------------------------------------------------------- spawns -- */
  const spawns = new THREE.Group();
  spawns.name = 'PlayerSpawns';
  for (const spawn of PLAYER_SPAWNS) {
    const marker = new THREE.Object3D();
    marker.name = spawn.name;
    marker.position.set(spawn.pos[0], spawn.pos[1], spawn.pos[2]);
    spawns.add(marker);
  }
  root.add(spawns);

  /* -------------------------------------------------------------- stats -- */
  const seen = new Set();
  root.traverse((node) => {
    if (!node.isMesh) return;
    if (node.userData.realSource) seen.add(node.userData.realSource);
    const geometry = node.geometry;
    const index = geometry?.getIndex();
    const position = geometry?.getAttribute('position');
    triangles += index ? index.count / 3 : (position ? position.count / 3 : 0);
  });

  const stats = {
    instances: PLACEMENTS.length + Object.values(scattered.counts).reduce((a, b) => a + b, 0),
    counts,
    districts: [...districts.keys(), 'landmark'],
    triangles: Math.round(triangles),
    clips: clips.length,
    roles: Object.keys(ROLE_SPECS).length,
    realFiles: [...seen].length,
    realFileList: [...seen].sort(),
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
    assetPolicy: 'every mesh is a real licensed GLB from game/assets/world/real',
  };

  root.userData.forge = { id: meta.id, stats, meta };
  return { root, clips, stats, meta };
}

/** Lighting rig, shared by the viewer and the capture script. */
export function worldLighting(scene) {
  const key = new THREE.DirectionalLight(0xffe0bb, 2.9);
  key.position.set(-62, 78, 52);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.near = 10;
  key.shadow.camera.far = 360;
  key.shadow.camera.left = -150;
  key.shadow.camera.right = 150;
  key.shadow.camera.top = 150;
  key.shadow.camera.bottom = -150;
  key.shadow.bias = -0.0008;
  key.name = 'KeySun';

  const fill = new THREE.DirectionalLight(0x9fc6ff, 1.25);
  fill.position.set(88, 44, -66);
  fill.name = 'CoolFill';

  const rim = new THREE.DirectionalLight(0xc9b4ff, 0.7);
  rim.position.set(-46, 24, -96);
  rim.name = 'RimLight';

  const sky = new THREE.HemisphereLight(0x9db6cc, 0x2b2a26, 1.5);
  sky.name = 'SkyBounce';

  // Warm bounce off the concrete apron, so the field is not lit by sky alone.
  const bounce = new THREE.DirectionalLight(0xffc98a, 0.35);
  bounce.position.set(20, -30, -60);
  bounce.name = 'GroundBounce';

  scene.add(key, fill, rim, sky, bounce);
  return { key, fill, rim, sky };
}

export { DEG };
