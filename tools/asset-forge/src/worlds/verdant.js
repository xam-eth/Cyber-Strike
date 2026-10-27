/**
 * verdant.js — WORLD 2 / mission: RECOVERY.
 *
 * A bio-research station that lost the fight with the planet. The domes are still
 * running, the modules are down in the canopy, and the growth has been climbing
 * the hardware for decades. The mood is humid overgrowth: moss, spore light and a
 * warm green sun coming through the canopy.
 *
 * Data only — see `compose.js`. Every mesh is a licensed GLB.
 */
import { THEMES } from './themes.js';

export default {
  id: 'verdant_bloom',
  name: 'VERDANT BLOOM',
  mission: 'recovery',
  tagline: 'Recover the seed vault before the bloom closes over it.',
  width: 176,
  depth: 164,
  centreZ: -6,
  theme: THEMES.verdant,
  scatterDistrict: 'canopy',

  terrain: {
    // Real grass tiles and a real dirt path for the floor and routes.
    floor: { tile: 11, model: 'nk_ground-grass' },
    roadModel: 'nk_ground-pathstraight',
    // A shallow mossy plinth under the shrine; no hard deck, the ground is soil.
    deck: { width: 26, depth: 26, tile: 6.5, lift: 0.08, model: 'nk_platform-grass', edge: false },
    roads: [
      { name: 'NurseryPath', from: [-12, 2], to: [-52, 26] },
      { name: 'DomePath', from: [10, -4], to: [48, -30] },
      { name: 'CanopyPath', from: [0, 14], to: [6, 54] },
    ],
    // The fence lost. Sparse, low, and mostly gone: the boundary is suggested.
    perimeter: {
      spacing: 6.2,
      height: 2.6,
      frame: 'supports-low',
      gaps: [
        { axis: 'z', at: -6 - 82, gap: 34 },
        { axis: 'z', at: -6 + 82, gap: 30 },
        { axis: 'x', at: -88, gap: 40 },
        { axis: 'x', at: 88, gap: 44 },
      ],
    },
    dressing: { count: 22, centre: [-34, -34], radius: 30, squash: 0.8, crater: 'crater', craterScale: 7, rockScale: 2.2 },
  },

  layout: [
    /* ------------------------------------------------------------- shrine */
    { role: 'overgrown_arch', name: 'SeedVaultArch', pos: [0, 0, 0], yaw: 0, district: 'shrine' },
    { role: 'spore_vent', name: 'VaultVent_W', pos: [-9, 0, 4], yaw: 0, district: 'shrine' },
    { role: 'spore_vent', name: 'VaultVent_E', pos: [9, 0, 4], yaw: 0, district: 'shrine' },
    { role: 'cover_module', name: 'RootCover_W', pos: [-7, 0, -7], yaw: 20, district: 'shrine' },
    { role: 'cover_module', name: 'RootCover_E', pos: [7, 0, -7], yaw: -30, district: 'shrine' },

    /* --------------------------------------------------------- the station */
    { role: 'bio_dome', name: 'BioDome_North', pos: [-46, 0, -30], yaw: 0, district: 'station' },
    { role: 'bio_dome', name: 'BioDome_East', pos: [52, 0, -30], yaw: 45, district: 'station' },
    { role: 'bio_dome', name: 'BioDome_South', pos: [40, 0, 36], yaw: 110, scale: 0.9, district: 'station' },
    { role: 'crashed_lab', name: 'CrashedModule_West', pos: [-38, 0, 30], yaw: -22, district: 'station' },
    { role: 'crashed_lab', name: 'CrashedModule_South', pos: [16, 0, 52], yaw: 140, district: 'station' },
    { role: 'crashed_lab', name: 'CrashedModule_North', pos: [-18, 0, -44], yaw: 62, scale: 0.85, district: 'station' },
    { role: 'spore_vent', name: 'StationVent', pos: [-30, 0, -4], yaw: 0, district: 'station' },
    { role: 'spore_vent', name: 'StationVent_B', pos: [-52, 0, 8], yaw: 0, district: 'station' },
    { role: 'overgrown_arch', name: 'StationGate', pos: [-26, 0, 14], yaw: 74, scale: 0.85, district: 'station' },

    /* --------------------------------------------------------------- grove */
    { role: 'giant_flora', name: 'GroveTree_A', pos: [-60, 0, 22], yaw: 10, district: 'grove' },
    { role: 'giant_flora', name: 'GroveTree_B', pos: [64, 0, 14], yaw: 50, district: 'grove' },
    { role: 'giant_flora', name: 'GroveTree_C', pos: [-20, 0, -58], yaw: 80, district: 'grove' },
    { role: 'giant_flora', name: 'GroveTree_D', pos: [30, 0, -54], yaw: 120, district: 'grove' },
    { role: 'giant_flora', name: 'GroveTree_E', pos: [8, 0, 60], yaw: 30, district: 'grove' },
    { role: 'giant_flora', name: 'GroveTree_F', pos: [46, 0, -62], yaw: 20, district: 'grove' },
    { role: 'grove_tree', name: 'Pine_A', pos: [-72, 0, 46], yaw: 0, district: 'grove' },
    { role: 'grove_tree', name: 'Pine_B', pos: [72, 0, 50], yaw: 35, district: 'grove' },
    { role: 'grove_tree', name: 'Pine_C', pos: [-72, 0, -50], yaw: 70, district: 'grove' },
    { role: 'grove_tree', name: 'Pine_D', pos: [64, 0, -54], yaw: 15, district: 'grove' },
    { role: 'grove_tree', name: 'Pine_E', pos: [4, 0, 72], yaw: 50, district: 'grove' },
    { role: 'grove_tree', name: 'Pine_F', pos: [-30, 0, 66], yaw: 90, scale: 0.85, district: 'grove' },
    { role: 'fallen_log', name: 'FallenLog_A', pos: [-50, 0, 44], yaw: 40, district: 'grove' },
    { role: 'fallen_log', name: 'FallenLog_B', pos: [34, 0, -34], yaw: -60, district: 'grove' },
    { role: 'mushroom_ring', name: 'FungalRing_A', pos: [-14, 0, 26], yaw: 0, district: 'grove' },
    { role: 'mushroom_ring', name: 'FungalRing_B', pos: [22, 0, 12], yaw: 45, district: 'grove' },
    { role: 'moss_rock', name: 'MossBoulder_A', pos: [-40, 0, -46], yaw: 20, district: 'grove' },
    { role: 'moss_rock', name: 'MossBoulder_B', pos: [58, 0, 26], yaw: 65, district: 'grove' },
    { role: 'giant_flora', name: 'GroveTree_G', pos: [-40, 0, 58], yaw: 100, district: 'grove' },
    { role: 'overgrown_arch', name: 'GroveArch', pos: [30, 0, 18], yaw: -34, scale: 0.7, district: 'grove' },
    { role: 'spore_vent', name: 'GroveVent_A', pos: [-40, 0, -56], yaw: 0, district: 'grove' },
    { role: 'spore_vent', name: 'GroveVent_B', pos: [54, 0, 44], yaw: 0, district: 'grove' },

    /* ----------------------------------------------------------- security */
    { role: 'defense_turret', name: 'OvergrownTurret_A', pos: [-24, 0, 10], yaw: 60, district: 'security' },
    { role: 'defense_turret', name: 'OvergrownTurret_B', pos: [28, 0, -12], yaw: -55, district: 'security' },
    { role: 'defense_turret', name: 'OvergrownTurret_C', pos: [4, 0, 38], yaw: 180, district: 'security' },
    { role: 'defense_turret', name: 'OvergrownTurret_D', pos: [-58, 0, -12], yaw: 95, district: 'security' },
    { role: 'defense_turret', name: 'OvergrownTurret_E', pos: [62, 0, 12], yaw: -120, district: 'security' },
    { role: 'cover_module', name: 'RootWall_North', pos: [0, 0, -16], yaw: 0, district: 'security' },
    // Frame the shrine approach instead of closing the authored spawn →
    // MainNorth route; at x = 0 this wall stopped traversal near z = 16.3.
    { role: 'cover_module', name: 'RootWall_South', pos: [10, 0, 18], yaw: 90, district: 'security' },
    { role: 'cover_module', name: 'RootWall_East', pos: [18, 0, 4], yaw: 45, district: 'security' },
    { role: 'sensor_tower', name: 'MossSensor_A', pos: [-66, 0, 6], yaw: 22, scale: 0.9, district: 'security' },
    { role: 'sensor_tower', name: 'MossSensor_B', pos: [68, 0, -16], yaw: -40, scale: 0.85, district: 'security' },
  ],

  landmarks: [
    {
      id: 'fallen_scout',
      model: 'drone',
      scale: 3.4,
      pos: [66, 1.6, -58],
      yaw: -28,
    },
  ],

  scatter: {
    undergrowth: [
      [-64, -14, 1.2], [-52, 12, 1.0], [-30, 44, 1.1], [-6, 40, 0.9], [18, 30, 1.0],
      [38, 14, 0.9], [60, -34, 1.1], [44, -52, 0.9], [-46, -34, 1.0], [-70, 22, 0.9],
      [12, -26, 1.0], [-22, -8, 0.85], [56, 58, 1.0], [-56, 62, 0.9], [30, -6, 0.8],
      [-36, 4, 0.95],
    ],
    moss_rock: [
      [-80, -30, 1.0, 10], [76, 4, 0.9, 60], [-14, -70, 1.1, 30], [50, 70, 0.95, 0],
      [-66, -66, 0.85, 45],
    ],
    alien_flora: [
      [-70, -20, 1.1], [-56, 46, 1.0], [-18, 26, 0.9], [16, 18, 1.0], [40, 30, 0.9],
      [62, -6, 1.1], [72, -44, 0.8], [-74, 34, 0.9], [-8, -30, 1.0], [36, -70, 0.85],
      [-46, -70, 0.9], [20, 66, 0.95], [-62, 62, 0.8], [56, 62, 0.9], [-30, 8, 0.85],
      [10, -16, 0.8],
    ],
    crystal_cluster: [
      [44, -46, 0.8, 20], [-64, -46, 0.9, 60], [70, 34, 0.7, 0], [-14, 48, 0.75, 40],
    ],
    rock_cluster: [
      [-78, 4, 0.9], [80, 56, 1.0], [-40, 74, 0.8], [24, -76, 0.9], [72, -74, 0.85],
    ],
  },

  spawns: [
    { name: 'spawn_bloom_shrine', pos: [0, 0.1, 12] },
    { name: 'spawn_bloom_nursery', pos: [-44, 0.1, -12] },
    { name: 'spawn_bloom_grove', pos: [-54, 0.1, 30] },
    { name: 'spawn_bloom_east', pos: [44, 0.1, 4] },
  ],
};
