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
    mood: 'polar dusk, Blade Runner on ice: white ice, cyan searchlights, monorail cutting haze, air you can see breathe',
    sky: { top: '#030c18', mid: '#0b2438', bottom: '#2a5468', glow: '#59e6ff' },
    // Cinematic haze: Syd Mead volumetric — shafts from aurora rim through ice dust.
    // 0.0028 was clean air; 0.0034 is visible breath without eating the yard.
    fog: { color: '#1c3a48', density: 0.0034 },
    exposure: 1.05,
    environment: 0.98,
    lights: [
      { name: 'PolarKey', color: '#cfe4ff', intensity: 2.8, pos: [-58, 52, -104] },
      { name: 'IceFill', color: '#6ea4e8', intensity: 0.85, pos: [96, 34, 24] },
      // Aurora rim is the story light — from the polar gate (north), so the eye goes north.
      { name: 'AuroraRim', color: '#8fe4ff', intensity: 1.2, pos: [-28, 22, 92] },
      { name: 'Bounce', color: '#8fb4c6', intensity: 0.28, pos: [12, -26, 40] },
    ],
    hemi: { sky: '#5d8298', ground: '#0f1a20', intensity: 0.9 },
    // Steel darker (0.13→0.11) for stronger silhouette against cyan.
    kit: { steel: '#3e4c56', warm: '#4b6c7a', targetLight: 0.11, targetSat: 0.11, rough: 0.66, metal: 0.28 },
    // Polar ice lifted 1.35→1.5 so it glows under aurora like wet runway reflecting neon.
    ground: { tint: [0.78, 0.88, 1.0], lift: 1.5, rough: 0.94, metal: 0.0 },
    accent: '#59e6ff',
    hazard: '#ff8a3d',
  },

  /* --------------------------------------------------------------- verdant */
  verdant: {
    id: 'verdant',
    label: 'Verdant Bloom',
    mood: 'humid overgrowth, Destiny EDZ + Annihilation: moss eating steel, spore light pulsing, canopy sun god rays through bloom',
    sky: { top: '#021208', mid: '#0f2e22', bottom: '#2d5a3e', glow: '#8cff9e' },
    // Spore haze denser — god rays through canopy, like Destiny's EDZ at golden hour with Annihilation shimmer.
    fog: { color: '#122e1e', density: 0.0042 },
    exposure: 1.05,
    environment: 0.98,
    lights: [
      { name: 'CanopySun', color: '#fff0c0', intensity: 4.4, pos: [-22, 98, 64] },
      { name: 'MossFill', color: '#63c98a', intensity: 1.1, pos: [88, 28, -34] },
      // Spore rim stronger (0.75→1.0) — violet bloom from the north, makes moss read as luminescent.
      { name: 'SporeRim', color: '#9a68e6', intensity: 1.0, pos: [-76, 26, -56] },
      { name: 'Bounce', color: '#93b878', intensity: 0.26, pos: [10, -24, -30] },
    ],
    hemi: { sky: '#6f9c7c', ground: '#0e1a12', intensity: 0.6 },
    kit: { steel: '#3e4a42', warm: '#6b8a45', targetLight: 0.19, targetSat: 0.14, rough: 0.68, metal: 0.15 },
    ground: { tint: [0.24, 0.34, 0.20], mix: 0.92, rough: 0.97, metal: 0.0 },
    // Organics slightly more saturated (satMul 1.25→1.35) so canopy pops against steel.
    nature: { tint: '#5f9c63', tintLerp: 0.12, valueMul: 1.08, satMul: 1.35, rough: 0.92, metal: 0.0 },
    accent: '#8cff9e',
    hazard: '#ffd166',
  },

  /* -------------------------------------------------------------- emberfall */
  emberfall: {
    id: 'emberfall',
    label: 'Emberfall Foundry',
    mood: 'volcanic megastructure, Syd Mead furnace: black basalt, molten seams, ore monorail overhead, rocket gantry silhouetted, ash breathing',
    sky: { top: '#060302', mid: '#1a0a06', bottom: '#5e2612', glow: '#ff7a1e' },
    // Ash haze a bit denser 0.0016→0.0022 — megastructure silhouette needs separation, but not so much the yard vanishes. Cinder Yard plant must remain sharp.
    fog: { color: '#4e2816', density: 0.0022 },
    exposure: 1.35,
    environment: 1.18,
    lights: [
      // Furnace key higher and hotter — 55°→58°, intensity 4.0→4.6 so scanned plate glows like molten basalt catching fire.
      { name: 'FurnaceKey', color: '#ffa866', intensity: 4.6, pos: [-64, 108, -48] },
      { name: 'SlagFill', color: '#ff7a3a', intensity: 1.9, pos: [112, 48, 52] },
      // Ash rim stronger 0.7→1.05 — violet backlight from foundry's heart, makes slag pools pop and rocket silhouette read.
      { name: 'AshRim', color: '#5560d8', intensity: 1.05, pos: [74, 34, -74] },
      { name: 'Bounce', color: '#d97a3a', intensity: 0.38, pos: [0, -30, -20] },
    ],
    hemi: { sky: '#8a5433', ground: '#1a100c', intensity: 1.55 },
    kit: { steel: '#2e2420', warm: '#a8642a', targetLight: 0.10, targetSat: 0.18, rough: 0.56, metal: 0.42 },
    // Ground lifted 3.4→3.6 so basalt doesn't read as void next to lit deck — megastructure floor must feel hot.
    ground: { tint: [1.0, 0.55, 0.34], lift: 3.6, rough: 0.88, metal: 0.05 },
    accent: '#ff7a1e',
    hazard: '#ffd166',
  },
};

/** The order the launcher lists them in: easiest mission first. */
export const THEME_ORDER = ['frostline', 'verdant', 'emberfall'];
