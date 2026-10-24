/**
 * emberfall.js — WORLD 3 / mission: EXTRACTION.
 *
 * The foundry that feeds the frontier: smelters, silos, a drill rig working a
 * magma seam and a gantry crane that never stops. The Cinder Yard power station
 * itself stands at the east end of the yard — the landmark the whole map is built
 * around. The mood is volcanic industry: black basalt, molten seams, ash in the air.
 *
 * Data only — see `compose.js`. Every mesh is a licensed GLB.
 */
import { THEMES } from './themes.js';

export default {
  id: 'emberfall_foundry',
  name: 'EMBERFALL FOUNDRY',
  mission: 'extraction',
  tagline: 'Tap the seam, load the ore, get out before the floor opens.',
  width: 200,
  depth: 176,
  centreZ: -10,
  theme: THEMES.emberfall,
  scatterDistrict: 'slagfield',

  terrain: {
    floor: { tile: 12.5 },
    deck: { width: 34, depth: 26, tile: 6.5, lift: 0.12, model: 'platform-center', edge: false },
    roads: [
      { name: 'MainHaul', from: [-18, 0], to: [-76, -4] },
      { name: 'FurnaceRun', from: [18, -6], to: [68, -20] },
      { name: 'SeamRoad', from: [0, 16], to: [4, 62] },
      { name: 'NorthRail', from: [0, -18], to: [-6, -60] },
    ],
    perimeter: {
      spacing: 3.2,
      height: 3.2,
      frame: 'structure',
      corner: 'columns',
      cornerHeight: 13,
      gaps: [
        { axis: 'z', at: -10 - 88, gap: 12 },
        { axis: 'z', at: -10 + 88, gap: 12 },
        { axis: 'x', at: -100, gap: 12 },
        { axis: 'x', at: 100, gap: 12 },
      ],
    },
    dressing: { count: 20, centre: [40, 52], radius: 30, squash: 0.7, craterScale: 9, rockScale: 2.8 },
  },

  layout: [
    /* ------------------------------------------------------------- smelters */
    { role: 'smelter_tower', name: 'Smelter_A', pos: [-44, 0, -34], yaw: 0, district: 'smelter' },
    { role: 'smelter_tower', name: 'Smelter_B', pos: [-64, 0, 4], yaw: 18, district: 'smelter' },
    { role: 'smelter_tower', name: 'Smelter_C', pos: [-30, 0, 30], yaw: -12, district: 'smelter' },
    { role: 'ore_silo', name: 'OreSilo_A', pos: [-26, 0, -12], yaw: 0, district: 'smelter' },
    { role: 'ore_silo', name: 'OreSilo_B', pos: [-52, 0, -14], yaw: 40, district: 'smelter' },
    { role: 'ore_silo', name: 'OreSilo_C', pos: [-16, 0, 24], yaw: 75, district: 'smelter' },

    /* ---------------------------------------------------------- the yard */
    { role: 'crane_gantry', name: 'YardCrane_North', pos: [34, 0, -30], yaw: 0, district: 'yard' },
    { role: 'crane_gantry', name: 'YardCrane_South', pos: [30, 0, 26], yaw: 180, district: 'yard' },
    { role: 'drill_rig', name: 'SeamDrill', pos: [4, 0, 44], yaw: 8, district: 'yard' },
    { role: 'slag_pool', name: 'SlagPool_A', pos: [16, 0, 8], yaw: 0, district: 'yard' },
    { role: 'slag_pool', name: 'SlagPool_B', pos: [52, 0, -6], yaw: 40, district: 'yard' },
    { role: 'cover_module', name: 'YardCover_W', pos: [-4, 0, -4], yaw: 30, district: 'yard' },
    { role: 'cover_module', name: 'YardCover_E', pos: [10, 0, -2], yaw: -40, district: 'yard' },

    /* -------------------------------------------------------------- guard */
    { role: 'defense_turret', name: 'FoundryTurret_A', pos: [0, 0, -34], yaw: 0, district: 'guard' },
    { role: 'defense_turret', name: 'FoundryTurret_B', pos: [-78, 0, -18], yaw: 90, district: 'guard' },
    { role: 'defense_turret', name: 'FoundryTurret_C', pos: [64, 0, 30], yaw: -70, district: 'guard' },
    { role: 'enemy_spawn_gate', name: 'FoundryGate_West', pos: [-92, 0, 22], yaw: 90, scale: [1.4, 1.35, 1.25], district: 'guard' },
    { role: 'enemy_spawn_gate', name: 'FoundryGate_South', pos: [40, 0, 78], yaw: 180, scale: [1.4, 1.35, 1.25], district: 'guard' },
    { role: 'enemy_spawn_gate', name: 'FoundryGate_North', pos: [40, 0, -74], yaw: 0, scale: [1.4, 1.35, 1.25], district: 'guard' },

    /* ------------------------------------------------- the plant approach */
    // The east third of the field is the run-up to the Cinder Yard station: a
    // rail of silos and a second crane so the player has cover on the way in,
    // and so the largest empty rectangle in this world is not the one the
    // mission's objective stands behind.
    { role: 'ore_silo', name: 'ApproachSilo_A', pos: [88, 0, -34], yaw: 15, district: 'approach' },
    { role: 'ore_silo', name: 'ApproachSilo_B', pos: [104, 0, -6], yaw: 60, district: 'approach' },
    { role: 'ore_silo', name: 'ApproachSilo_C', pos: [86, 0, 24], yaw: 100, district: 'approach' },
    { role: 'crane_gantry', name: 'ApproachCrane', pos: [62, 0, -52], yaw: 90, district: 'approach' },
    { role: 'cover_module', name: 'ApproachCover_A', pos: [58, 0, 8], yaw: 10, district: 'approach' },
    { role: 'cover_module', name: 'ApproachCover_B', pos: [80, 0, 44], yaw: 75, district: 'approach' },
    { role: 'slag_pool', name: 'ApproachSlag', pos: [112, 0, 34], yaw: 55, district: 'approach' },
    { role: 'ash_statue', name: 'ApproachStack', pos: [120, 0, -46], yaw: 12, district: 'approach' },
    { role: 'defense_turret', name: 'ApproachTurret', pos: [52, 0, -20], yaw: -120, district: 'approach' },

    /* ------------------------------------------------------------ slagfield */
    { role: 'ash_statue', name: 'AshColumn_A', pos: [76, 0, -46], yaw: 0, district: 'slagfield' },
    { role: 'ash_statue', name: 'AshColumn_B', pos: [-70, 0, 52], yaw: 30, district: 'slagfield' },
    { role: 'slag_pool', name: 'SlagPool_C', pos: [70, 0, 48], yaw: 20, district: 'slagfield' },
    { role: 'wrecked_transport', name: 'SlaggedHauler', pos: [26, 0, 64], yaw: -40, district: 'slagfield' },
  ],

  landmarks: [
    {
      // The photographed Cinder Yard plant, standing at the east end of its own
      // yard: 245 m of real industrial scene, brought to a 24 m ridge.
      id: 'cinder_yard',
      model: 'powerplant',
      height: 24,
      pos: [166, 0, -18],
      yaw: 98,
    },
  ],

  scatter: {
    rock_cluster: [
      [-84, 46, 1.1], [84, 62, 0.95], [58, -62, 1.0], [-40, 68, 0.9], [10, -66, 0.85],
      [-88, -52, 0.95],
    ],
    wrecked_transport: [
      [-58, 62, 0.9, 40], [66, 6, 0.85, -25], [96, 60, 0.95, 130],
    ],
    slag_pool: [
      [-14, -54, 0.9, 10], [40, -44, 0.8, 70], [-96, -6, 0.85, 25],
    ],
    ash_statue: [
      [54, 52, 0.9, 0], [-22, 66, 0.85, 45], [122, 12, 0.9, 100],
    ],
  },

  spawns: [
    { name: 'spawn_foundry_yard', pos: [0, 0.1, 10] },
    { name: 'spawn_foundry_smelter', pos: [-38, 0.1, -6] },
    { name: 'spawn_foundry_drill', pos: [6, 0.1, 34] },
    { name: 'spawn_foundry_plant', pos: [78, 0.1, -18] },
  ],
};
