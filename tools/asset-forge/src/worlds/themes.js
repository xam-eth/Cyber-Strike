/**
 * themes.js — art direction, as data.
 *
 * Three missions, three moods. A theme is the only place a colour is written
 * down: sky gradient, fog, the four lights, how the licensed kit's surfaces are
 * graded, and how the photographed ground is tinted. The geometry never changes
 * between worlds — what changes is light, atmosphere and the props chosen for
 * that mission.
 *
 * Nothing in here generates a texture or a mesh. `kit` grades the *existing*
 * colours of the Kenney materials (sRGB), `ground` multiplies the albedo of the
 * scanned plate, both are multipliers on real surfaces.
 */

export const THEMES = {
  /* ------------------------------------------------------------- frostline */
  frostline: {
    id: 'frostline',
    label: 'Frostline Relay',
    mood: 'polar dusk: white ice, cyan light, air you can see',
    sky: { top: '#040d18', mid: '#0d2b3b', bottom: '#2f5f70', glow: '#59e6ff' },
    fog: { color: '#20414f', density: 0.0028 },
    exposure: 1.0,
    environment: 0.95,
    lights: [
      { name: 'PolarKey', color: '#cfe4ff', intensity: 2.5, pos: [-52, 46, -96] },
      { name: 'IceFill', color: '#6ea4e8', intensity: 0.7, pos: [96, 34, 24] },
      { name: 'AuroraRim', color: '#8fe4ff', intensity: 0.8, pos: [-30, 18, 88] },
      { name: 'Bounce', color: '#8fb4c6', intensity: 0.25, pos: [12, -26, 40] },
    ],
    hemi: { sky: '#5d8298', ground: '#101a20', intensity: 0.85 },
    kit: { steel: '#46545e', warm: '#4b6c7a', targetLight: 0.13, targetSat: 0.10, rough: 0.68, metal: 0.26 },
    ground: { tint: [0.72, 0.80, 0.88], rough: 0.95, metal: 0.0 },
    accent: '#59e6ff',
    hazard: '#ff8a3d',
  },

  /* --------------------------------------------------------------- verdant */
  verdant: {
    id: 'verdant',
    label: 'Verdant Bloom',
    mood: 'humid overgrowth: moss, spore light, a warm green sun',
    sky: { top: '#03120a', mid: '#143226', bottom: '#2f5a3c', glow: '#8cff9e' },
    fog: { color: '#15301f', density: 0.0038 },
    exposure: 1.0,
    environment: 0.95,
    lights: [
      { name: 'CanopySun', color: '#fff0c0', intensity: 4.0, pos: [-24, 92, 58] },
      { name: 'MossFill', color: '#63c98a', intensity: 1.0, pos: [88, 28, -34] },
      { name: 'SporeRim', color: '#9a68e6', intensity: 0.75, pos: [-76, 22, -52] },
      { name: 'Bounce', color: '#93b878', intensity: 0.22, pos: [10, -24, -30] },
    ],
    hemi: { sky: '#6f9c7c', ground: '#101a12', intensity: 0.55 },
    kit: { steel: '#465142', warm: '#6b8a45', targetLight: 0.21, targetSat: 0.13, rough: 0.7, metal: 0.14 },
    ground: { tint: [0.30, 0.42, 0.26], rough: 0.97, metal: 0.0 },
    // Organics keep their own greens; they are only pulled toward the world's
    // moss tone and left bright, or the canopy reads as black cardboard.
    nature: { tint: '#5f9c63', tintLerp: 0.10, valueMul: 1.05, satMul: 1.25, rough: 0.94, metal: 0.0 },
    accent: '#8cff9e',
    hazard: '#ffd166',
  },

  /* -------------------------------------------------------------- emberfall */
  emberfall: {
    id: 'emberfall',
    label: 'Emberfall Foundry',
    mood: 'volcanic industry: black basalt, molten seams, ash in the air',
    sky: { top: '#070302', mid: '#1d0b06', bottom: '#5e2610', glow: '#ff7a1e' },
    fog: { color: '#3d1a0f', density: 0.0040 },
    exposure: 1.0,
    environment: 0.9,
    lights: [
      { name: 'FurnaceKey', color: '#ff9d54', intensity: 2.9, pos: [-70, 40, -40] },
      { name: 'SlagFill', color: '#ff5a1e', intensity: 0.7, pos: [40, -8, 30] },
      { name: 'AshRim', color: '#5560d8', intensity: 0.55, pos: [70, 30, -70] },
      { name: 'Bounce', color: '#d97a3a', intensity: 0.3, pos: [0, -30, -20] },
    ],
    hemi: { sky: '#5e3520', ground: '#0a0605', intensity: 0.8 },
    kit: { steel: '#332a24', warm: '#a8642a', targetLight: 0.11, targetSat: 0.16, rough: 0.58, metal: 0.4 },
    ground: { tint: [0.46, 0.32, 0.27], rough: 0.9, metal: 0.04 },
    accent: '#ff7a1e',
    hazard: '#ffd166',
  },
};

/** The order the launcher lists them in: easiest mission first. */
export const THEME_ORDER = ['frostline', 'verdant', 'emberfall'];
