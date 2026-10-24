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
 * colours of the Kenney materials (authored in sRGB), `ground` is a *linear*
 * multiplier applied to the albedo of the scanned plate — which is why its values
 * are not 0–1 colours and one of them is above 1.0.
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
    // Linear multiplier on the scanned plate, not a colour (see realModels.js).
    // Polar ice is a bright, low-chroma surface: the plate is lifted hard so the
    // field reads as packed snow rather than wet asphalt, and tinted cool.
    ground: { tint: [0.78, 0.88, 1.0], lift: 1.35, rough: 0.95, metal: 0.0 },
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
    // The floor is unmapped Nature Kit grass, so this is the colour it is
    // lerped to, not a multiplier: `mix` 0.62 takes the kit's fluorescent mint
    // most of the way to a moss lawn and keeps a little of its glow.
    ground: { tint: [0.26, 0.36, 0.22], mix: 0.9, rough: 0.97, metal: 0.0 },
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
    // Ash, not smoke: the earlier 0.0040 density plus a 0.46 ground tint left the
    // east half of the yard reading as a brown void rather than a lit floor.
    // Ash haze, not a shutter: enough to separate the far fence from the sky,
    // not enough to eat the east half of the yard.
    fog: { color: '#5a2a16', density: 0.0016 },
    exposure: 1.30,
    environment: 1.15,
    lights: [
      // A key at 38° of elevation only lands a third of its energy on a flat
      // floor, which is why the foundry's scanned plate read as a void beside its
      // lit deck. At ~55° the same surface answers the light.
      { name: 'FurnaceKey', color: '#ffa866', intensity: 4.0, pos: [-62, 96, -44] },
      // The plant side of the yard is the side the key cannot reach, so the fill
      // sits opposite the key at a third of its strength rather than under the
      // floor: a fill from below reads as a bug once anything casts a shadow.
      { name: 'SlagFill', color: '#ff7a3a', intensity: 1.5, pos: [108, 44, 46] },
      { name: 'AshRim', color: '#5560d8', intensity: 0.7, pos: [70, 30, -70] },
      { name: 'Bounce', color: '#d97a3a', intensity: 0.35, pos: [0, -30, -20] },
    ],
    hemi: { sky: '#8a5433', ground: '#1a100c', intensity: 1.5 },
    kit: { steel: '#332a24', warm: '#a8642a', targetLight: 0.11, targetSat: 0.16, rough: 0.58, metal: 0.4 },
    ground: { tint: [1.0, 0.55, 0.34], lift: 3.4, rough: 0.9, metal: 0.04 },
    accent: '#ff7a1e',
    hazard: '#ffd166',
  },
};

/** The order the launcher lists them in: easiest mission first. */
export const THEME_ORDER = ['frostline', 'verdant', 'emberfall'];
