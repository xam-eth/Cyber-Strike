/**
 * themes.js — art direction, as data. Stellar Horizon: ONE WORLD / MANY BATTLES.
 *
 * Foto referensi: floating islands di langit, central tower dengan beam biru,
 * jembatan melengkung antar tebing, air terjun dari pulau, interior base gelap.
 * Empat mood dari Environment & Mood panel: DAYTIME / SUNSET / NIGHT / STORM.
 * Geometry SAMA untuk semua — yang berbeda hanya light, fog, sky dan dressing.
 * Jalur world konsisten: canyon → central tower → upper platform → interior base,
 * bukan 4 dimensi terpisah. Survival adventure: cover tiap 5-6m, bukan arena kosong.
 */

export const THEMES = {
  /* ------------------------------------------------------------- frostline — DAYTIME (foto top, 01 Main View) */
  frostline: {
    id: 'frostline',
    label: 'STELLAR HORIZON — DAYTIME',
    mood: 'daytime floating archipelago — bright blue sky, white high clouds, sun from east, central tower beam cuts air, waterfalls off islands, ground readable, Blade Runner volumetrics but natural',
    sky: { top: '#0a2e5a', mid: '#2e7eb8', bottom: '#87c4ea', glow: '#ffffff', glowStrength: 0.52, horizonHaze: 0.22, sunWarmth: 0.18 },
    fog: { color: '#9cc6e8', density: 0.0016, height: 28, heightFalloff: 0.08, hazeColor: '#cfe9ff', hazeStrength: 0.06 },
    exposure: 1.18,
    environment: 1.05,
    lights: [
      { name: 'SunKey', color: '#fff7e0', intensity: 5.2, pos: [-120, 140, -80] },
      { name: 'SkyFill', color: '#8ec6ff', intensity: 1.35, pos: [90, 60, 40] },
      { name: 'TowerRim', color: '#59e6ff', intensity: 1.45, pos: [0, 32, 0] },
      { name: 'Bounce', color: '#d0e6ff', intensity: 0.42, pos: [0, -20, 20] },
      { name: 'CloudScatter', color: '#ffffff', intensity: 0.55, pos: [0, 80, 0] },
    ],
    hemi: { sky: '#8ec6ff', ground: '#3a4a5a', intensity: 1.05 },
    kit: { steel: '#4a5a6a', warm: '#7a6a52', targetLight: 0.18, targetSat: 0.14, rough: 0.62, metal: 0.28 },
    ground: { tint: [0.92, 0.92, 0.88], lift: 1.25, rough: 0.88, metal: 0.0 },
    accent: '#59e6ff',
    hazard: '#ff8a3d',
    atmosphere: { dustDensity: 0.008, dustColor: '#cfe9ff', bloom: 0.28, vignette: 0.18 },
  },

  /* --------------------------------------------------------------- verdant — SUNSET (Environment & Mood SUNSET) */
  verdant: {
    id: 'verdant',
    label: 'STELLAR HORIZON — SUNSET',
    mood: 'sunset golden hour — orange horizon, warm side light, long shadows, islands glow amber, tower beam still blue against warm sky, humid haze low',
    sky: { top: '#0f1020', mid: '#3a2040', bottom: '#ff8c52', glow: '#ffb86a', glowStrength: 0.48, horizonHaze: 0.52, sunWarmth: 0.52 },
    fog: { color: '#2a1a20', density: 0.0028, height: 22, heightFalloff: 0.14, hazeColor: '#ffb86a', hazeStrength: 0.18 },
    exposure: 1.28,
    environment: 1.12,
    lights: [
      { name: 'SunsetKey', color: '#ffb86a', intensity: 5.0, pos: [140, 40, -60] },
      { name: 'WarmFill', color: '#ff9a5a', intensity: 1.45, pos: [-80, 30, 40] },
      { name: 'TowerRim', color: '#59e6ff', intensity: 1.25, pos: [0, 32, 0] },
      { name: 'Bounce', color: '#8a5a3a', intensity: 0.38, pos: [0, -18, -10] },
      { name: 'HorizonGlow', color: '#ff6a2a', intensity: 0.72, pos: [0, 12, 80] },
    ],
    hemi: { sky: '#ff9a5a', ground: '#1e1510', intensity: 0.92 },
    kit: { steel: '#4a3a2e', warm: '#8a5a32', targetLight: 0.16, targetSat: 0.18, rough: 0.66, metal: 0.22 },
    ground: { tint: [0.88, 0.62, 0.42], lift: 1.35, rough: 0.90, metal: 0.0 },
    accent: '#59e6ff',
    hazard: '#ffd166',
    atmosphere: { dustDensity: 0.012, dustColor: '#ffb86a', bloom: 0.38, vignette: 0.26 },
  },

  /* -------------------------------------------------------------- emberfall — NIGHT (Environment & Mood NIGHT) */
  emberfall: {
    id: 'emberfall',
    label: 'STELLAR HORIZON — NIGHT',
    mood: 'night megacity — deep navy sky, city lights and tower beam dominate, interior base blue glow, canyon dark with rim lights, stars visible, ground readable via bounce',
    sky: { top: '#020208', mid: '#0a0f1e', bottom: '#1a2a4a', glow: '#59e6ff', glowStrength: 0.32, horizonHaze: 0.28, sunWarmth: 0.0 },
    fog: { color: '#0a1428', density: 0.0022, height: 18, heightFalloff: 0.12, hazeColor: '#59e6ff', hazeStrength: 0.10 },
    exposure: 1.35,
    environment: 1.18,
    lights: [
      { name: 'MoonKey', color: '#8eb8ff', intensity: 2.8, pos: [80, 90, -40] },
      { name: 'CityFill', color: '#59e6ff', intensity: 1.85, pos: [40, 20, 30] },
      { name: 'TowerRim', color: '#59e6ff', intensity: 2.2, pos: [0, 32, 0] },
      { name: 'InteriorGlow', color: '#2a6aff', intensity: 1.15, pos: [0, 4, -36] },
      { name: 'Bounce', color: '#1a2a4a', intensity: 0.28, pos: [0, -22, 10] },
    ],
    hemi: { sky: '#2a3a5a', ground: '#0a0f1e', intensity: 0.68 },
    kit: { steel: '#2a303a', warm: '#3a2a1e', targetLight: 0.10, targetSat: 0.12, rough: 0.68, metal: 0.32 },
    ground: { tint: [0.32, 0.36, 0.42], lift: 0.95, rough: 0.88, metal: 0.05 },
    accent: '#59e6ff',
    hazard: '#ffd166',
    atmosphere: { dustDensity: 0.010, dustColor: '#59e6ff', bloom: 0.42, vignette: 0.38 },
  },

  /* -------------------------------------------------------------- titans — STORM (Environment & Mood STORM) */
  titans: {
    id: 'titans',
    label: 'STELLAR HORIZON — STORM',
    mood: 'storm tempest — dark grey sky, low clouds, rain haze, tower beam cuts through storm, lightning rim, interior base shelter glow, waterfall heavy',
    sky: { top: '#0a0e14', mid: '#1a232e', bottom: '#2e3440', glow: '#8af2ff', glowStrength: 0.28, horizonHaze: 0.48, sunWarmth: 0.0 },
    fog: { color: '#1a222e', density: 0.0048, height: 14, heightFalloff: 0.18, hazeColor: '#8af2ff', hazeStrength: 0.14 },
    exposure: 1.15,
    environment: 1.02,
    lights: [
      { name: 'StormKey', color: '#c0d0e8', intensity: 3.6, pos: [-40, 80, 60] },
      { name: 'LightningRim', color: '#8af2ff', intensity: 2.0, pos: [60, 40, -30] },
      { name: 'TowerRim', color: '#59e6ff', intensity: 1.85, pos: [0, 32, 0] },
      { name: 'InteriorGlow', color: '#2a6aff', intensity: 0.92, pos: [0, 4, -36] },
      { name: 'Bounce', color: '#2a3440', intensity: 0.32, pos: [0, -16, 10] },
    ],
    hemi: { sky: '#5a6a7a', ground: '#0a0e14', intensity: 0.75 },
    kit: { steel: '#3a404a', warm: '#4a3a2e', targetLight: 0.13, targetSat: 0.10, rough: 0.72, metal: 0.26 },
    ground: { tint: [0.42, 0.44, 0.48], lift: 1.05, rough: 0.92, metal: 0.0 },
    accent: '#59e6ff',
    hazard: '#ffd166',
    atmosphere: { dustDensity: 0.018, dustColor: '#8af2ff', bloom: 0.32, vignette: 0.36 },
  },
};

export const THEME_ORDER = ['frostline', 'verdant', 'emberfall', 'titans'];
