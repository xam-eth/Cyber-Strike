/**
 * index.js — the three worlds, as one list.
 *
 * Each world is data (a theme, a layout, a terrain configuration, landmarks);
 * `compose.js` is the single builder they share. Adding a world means adding a
 * module here and nothing else.
 *
 *   import { WORLDS, buildWorld, buildAll } from './index.js';
 *   const world = await buildWorld('frostline');   // -> { root, clips, stats, meta }
 */
import { composeWorld, themeLighting, themeSky, heightFogVolume } from './compose.js';
import { ROLES } from './roles.js';
import frostline from './frostline.js';
import verdant from './verdant.js';
import emberfall from './emberfall.js';

/** id used by the viewer, the gate and the game → module. */
export const WORLDS = {
  frostline,
  verdant,
  emberfall,
};

/** Short ids, in mission order. */
export const WORLD_IDS = Object.keys(WORLDS);

/** The id the game boots into when nothing is selected. */
export const DEFAULT_WORLD = 'frostline';

export function worldConfig(id) {
  const world = WORLDS[id] ?? WORLDS[DEFAULT_WORLD];
  if (!world) throw new Error(`unknown world "${id}" (have: ${WORLD_IDS.join(', ')})`);
  return world;
}

export async function buildWorld(id) {
  return composeWorld(worldConfig(id), ROLES);
}

/** Lighting rig + sky for a world, shared by the viewer, the gate and the docs. */
export function worldAtmosphere(id, scene) {
  const world = worldConfig(id);
  const sky = themeSky(world.theme);
  const lights = themeLighting(scene, world.theme);
  const haze = heightFogVolume(world.theme);
  if (haze) scene.add(haze);
  return {
    theme: world.theme,
    sky,
    haze,
    lights,
  };
}

/** Every world in mission order — the gate renders all of them. */
export async function buildAll() {
  const out = {};
  for (const id of WORLD_IDS) out[id] = await buildWorld(id);
  return out;
}

export { ROLES };
