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
    mood: 'polar volumetric dusk v2.1 — Blade Runner on ice, air is a visible medium but ground stays readable: aurora shafts cut low mist, ice glows like wet neon runway, distance desaturates to cyan',
    // v2.1: pull back from v2 wash — keep breath visible but preserve depth: 0.0052→0.0036, height mist subtle
    sky: { top: '#02101c', mid: '#0a2a46', bottom: '#3a788e', glow: '#8af2ff', glowStrength: 0.26, horizonHaze: 0.32, sunWarmth: 0.0 },
    fog: { color: '#122a3a', density: 0.0036, height: 16, heightFalloff: 0.16, hazeColor: '#8af2ff', hazeStrength: 0.10 },
    exposure: 1.12,
    environment: 1.02,
    lights: [
      { name: 'PolarKey', color: '#d6ecff', intensity: 3.0, pos: [-58, 52, -104] },
      { name: 'IceFill', color: '#7ab4ff', intensity: 0.88, pos: [96, 34, 24] },
      // Aurora rim 1.75→1.55 — still silhouette but not blowing out ice
      { name: 'AuroraRim', color: '#7cf0ff', intensity: 1.55, pos: [-28, 22, 92] },
      { name: 'Bounce', color: '#9cc4d8', intensity: 0.30, pos: [12, -26, 40] },
      { name: 'SearchRay', color: '#8fe4ff', intensity: 0.62, pos: [142, 18, -6] },
    ],
    hemi: { sky: '#7aa8c0', ground: '#0a151e', intensity: 0.98 },
    kit: { steel: '#3c4c5a', warm: '#4b6c7a', targetLight: 0.108, targetSat: 0.10, rough: 0.64, metal: 0.30 },
    ground: { tint: [0.74, 0.86, 1.0], lift: 1.58, rough: 0.92, metal: 0.0 },
    accent: '#8af2ff',
    hazard: '#ff8a3d',
    atmosphere: { dustDensity: 0.012, dustColor: '#8af2ff', bloom: 0.36, vignette: 0.28 },
  },

  /* --------------------------------------------------------------- verdant */
  verdant: {
    id: 'verdant',
    label: 'Verdant Bloom',
    mood: 'humid jungle cathedral v2.1 — canopy god rays but ground readable: thick spore haze only low, steel eaten, mist pools not washes',
    sky: { top: '#01140a', mid: '#0e2e1e', bottom: '#2f6a42', glow: '#7dff9c', glowStrength: 0.28, horizonHaze: 0.36, sunWarmth: 0.18 },
    fog: { color: '#0f2e1e', density: 0.0046, height: 12, heightFalloff: 0.20, hazeColor: '#7dff9c', hazeStrength: 0.12 },
    exposure: 1.08,
    environment: 0.99,
    lights: [
      { name: 'CanopySun', color: '#fff2b0', intensity: 4.5, pos: [-22, 98, 64] },
      { name: 'MossFill', color: '#6ee89a', intensity: 1.15, pos: [88, 28, -34] },
      // Spore rim 1.45→1.25 — still luminescent but not washing foliage
      { name: 'SporeRim', color: '#b18cff', intensity: 1.25, pos: [-76, 26, -56] },
      { name: 'Bounce', color: '#a8d18a', intensity: 0.28, pos: [10, -24, -30] },
      { name: 'CanopyScatter', color: '#8cff9e', intensity: 0.48, pos: [0, 42, 18] },
    ],
    hemi: { sky: '#7fbd94', ground: '#0c1a14', intensity: 0.68 },
    kit: { steel: '#3c463e', warm: '#6b8a45', targetLight: 0.19, targetSat: 0.13, rough: 0.68, metal: 0.14 },
    ground: { tint: [0.22, 0.32, 0.18], mix: 0.92, rough: 0.97, metal: 0.0 },
    nature: { tint: '#52b06e', tintLerp: 0.13, valueMul: 1.09, satMul: 1.38, rough: 0.90, metal: 0.0 },
    accent: '#7dff9c',
    hazard: '#ffd166',
    atmosphere: { dustDensity: 0.014, dustColor: '#7dff9c', bloom: 0.32, vignette: 0.30 },
  },

  /* -------------------------------------------------------------- emberfall */
  emberfall: {
    id: 'emberfall',
    label: 'Emberfall Foundry',
    mood: 'wildfire megastructure v2.1 — ash & heat haze but megastructure stays sharp: furnace key is a sun, floor breathes, silhouette survives ash',
    sky: { top: '#0a0302', mid: '#1e0c06', bottom: '#7a3318', glow: '#ff8c1a', glowStrength: 0.34, horizonHaze: 0.42, sunWarmth: 0.42 },
    fog: { color: '#3a1e0a', density: 0.0028, height: 20, heightFalloff: 0.11, hazeColor: '#ff7a1e', hazeStrength: 0.14 },
    exposure: 1.42,
    environment: 1.22,
    lights: [
      { name: 'FurnaceKey', color: '#ffb07a', intensity: 4.8, pos: [-64, 108, -48] },
      { name: 'SlagFill', color: '#ff7a2e', intensity: 1.95, pos: [112, 48, 52] },
      // Ash rim 1.65→1.35 — backlight survives but not blowing out steel
      { name: 'AshRim', color: '#6a6eff', intensity: 1.35, pos: [74, 34, -74] },
      { name: 'Bounce', color: '#e89a5a', intensity: 0.38, pos: [0, -30, -20] },
      { name: 'HeatGlow', color: '#ff4a0a', intensity: 0.72, pos: [6, 6, 0] },
    ],
    hemi: { sky: '#9a5a35', ground: '#1e120c', intensity: 1.55 },
    kit: { steel: '#2c211c', warm: '#a8642a', targetLight: 0.10, targetSat: 0.19, rough: 0.56, metal: 0.42 },
    ground: { tint: [1.0, 0.54, 0.32], lift: 3.6, rough: 0.86, metal: 0.05 },
    accent: '#ff8c1a',
    hazard: '#ffd166',
    atmosphere: { dustDensity: 0.016, dustColor: '#ff7a1e', bloom: 0.42, vignette: 0.34 },
  },

  /* -------------------------------------------------------------- the titans — NEW 3D station interior */
  titans: {
    id: 'titans',
    label: 'THE TITANS',
    mood: 'station interior 3D yang diserang — sempit intimately 60x60, setengah hancur, hybrid percikan orange (human) + biru (alien), lantai bolong, dinding sobek/penyok abstract, luar angkasa hanya di 3 breach',
    // Sky: station interior tidak lihat langit 360, cuma glimpses dari breach — dark void dengan horizon orange tipis dari reaktor bocor
    sky: { top: '#050a12', mid: '#0f1f2e', bottom: '#2a3f4a', glow: '#ff7a1e', glowStrength: 0.22, horizonHaze: 0.28, sunWarmth: 0.32 },
    // Interior dust: tebal tapi rendah (height 10) — debu mengendap di bawah, bukan wash
    fog: { color: '#1a262e', density: 0.0042, height: 10, heightFalloff: 0.22, hazeColor: '#ff7a1e', hazeStrength: 0.11 },
    exposure: 1.25,
    environment: 1.15,
    lights: [
      // Key: lampu darurat station warm (dari atas koridor)
      { name: 'StationKey', color: '#ffe0a8', intensity: 3.2, pos: [0, 44, 8] },
      // Fill: alien tech cyan dari lab (B)
      { name: 'AlienFill', color: '#7cf0ff', intensity: 0.95, pos: [-18, 18, -12] },
      // Rim: breach luar angkasa — biru dingin dari utara (hangar jebol), orange dari selatan (reaktor)
      { name: 'BreachRim', color: '#6a6eff', intensity: 1.15, pos: [0, 14, -32] },
      { name: 'Bounce', color: '#8a6a4a', intensity: 0.32, pos: [0, -18, 12] },
      // Spark proxy: titik percikan hybrid — akan di-trigger oleh cable_spark roles, tapi light ini kasih ambient flicker
      { name: 'SparkFlicker', color: '#ff7a1e', intensity: 0.55, pos: [8, 6, -6] },
    ],
    hemi: { sky: '#5a6a78', ground: '#0c1116', intensity: 0.85 },
    // Steel desaturasi, ground lift sedang — lantai station kusam, bukan licin es
    kit: { steel: '#3a444e', warm: '#5a4a32', targetLight: 0.12, targetSat: 0.11, rough: 0.72, metal: 0.22 },
    ground: { tint: [0.42, 0.44, 0.46], lift: 1.45, rough: 0.94, metal: 0.0 },
    accent: '#ff7a1e',
    hazard: '#ffd166',
    atmosphere: { dustDensity: 0.015, dustColor: '#ff7a1e', bloom: 0.38, vignette: 0.36 },
  },
};

/** The order the launcher lists them in: easiest mission first. */
export const THEME_ORDER = ['frostline', 'verdant', 'emberfall', 'titans'];
