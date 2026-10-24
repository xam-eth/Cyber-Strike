/**
 * layout.js — where every prop stands in the world, as data.
 *
 * These numbers are not invented here: they mirror the authoritative placement in
 * `game/scripts/worlds/neon_frontier/zones/*.gd`, which is the script the shipped
 * game actually runs. Keeping the 3D world on the same coordinates means a forged
 * prop can be dropped into the Godot scene at the same transform and land exactly
 * where this world shows it.
 *
 * Districts (same names the game uses):
 *   arena       — central combat bowl around the reactor
 *   outpost     — friendly settlement: command, lab, depot, sensors, landing pad
 *   extraction  — energy bank east of the deck
 *   boss        — the colossal docking gate and its approach
 *   perimeter   — six turrets, four gates, two sensors around the boundary
 *   wilds       — crashed sector: drone wreck, dead turret, crystals, flora
 */

/** Everything the world needs to exist. Order is build order and draw intent. */
export const WORLD = {
  width: 192,
  depth: 180,
  centreZ: -10,
  deck: { width: 38, depth: 38 },       // central combat deck, as in arena.gd
  crackedPad: { centre: [-47, 47], size: [37, 26], yaw: 12 },
};

/**
 * One entry per placed prop.
 *  id     — catalog id of the component
 *  name   — instance name; also the animation-track prefix
 *  pos    — [x, y, z] in metres
 *  yaw    — degrees, matching Godot's `rotation.y`
 *  scale  — uniform or [x, y, z]
 *  pitch/roll — degrees, for the props the game lays on their side
 *  district — grouping, used by the review renderer and the docs
 */
export const PLACEMENTS = [
  /* ---------------------------------------------------------------- arena */
  { id: 'reactor_core', name: 'CentralReactor', pos: [0, 0, 0], district: 'arena' },
  { id: 'cover_module', name: 'CoverWest', pos: [-10, 0, 1.5], yaw: -8, district: 'arena' },
  { id: 'cover_module', name: 'CoverEast', pos: [4, 0, -3], yaw: 90, district: 'arena' },
  { id: 'cover_module', name: 'CoverNorthWest', pos: [-7, 0, -11], yaw: 22, scale: 0.8, district: 'arena' },
  { id: 'cover_module', name: 'CoverSouthEast', pos: [8, 0, 9], yaw: -16, scale: 0.75, district: 'arena' },
  { id: 'enemy_spawn_gate', name: 'WaveEntry_North', pos: [0, 0, -18.2], yaw: 0, district: 'arena' },
  { id: 'enemy_spawn_gate', name: 'WaveEntry_South', pos: [0, 0, 18.2], yaw: 180, district: 'arena' },
  { id: 'enemy_spawn_gate', name: 'WaveEntry_West', pos: [-18.2, 0, 0], yaw: 90, district: 'arena' },
  { id: 'enemy_spawn_gate', name: 'WaveEntry_East', pos: [18.2, 0, 0], yaw: -90, district: 'arena' },

  /* -------------------------------------------------------------- outpost */
  { id: 'command_center', name: 'OutpostCommandCenter', pos: [-52, 0, -4], yaw: 90, district: 'outpost' },
  { id: 'research_lab', name: 'WeaponResearchLaboratory', pos: [-47, 0, -28], yaw: 90, district: 'outpost' },
  { id: 'equipment_depot', name: 'FieldEquipmentDepot', pos: [-49, 0, 19], yaw: -90, district: 'outpost' },
  { id: 'sensor_tower', name: 'WestObservationTower', pos: [-72, 0, -22], yaw: 18, scale: [0.9, 1, 0.9], district: 'outpost' },
  { id: 'sensor_tower', name: 'SouthwestSignalTower', pos: [-69, 0, 31], yaw: -14, scale: [0.82, 0.88, 0.82], district: 'outpost' },
  { id: 'landing_pad', name: 'EastVehicleLandingPlatform', pos: [52, 0, 5], yaw: -12, scale: [1, 0.28, 1], district: 'outpost' },

  /* ----------------------------------------------------------- extraction */
  { id: 'generator_bank', name: 'FrontierEnergyExtractionBank', pos: [43, 0, -35], yaw: 180, district: 'extraction' },
  { id: 'sensor_tower', name: 'ExtractionSensorMast', pos: [66, 0, -43], yaw: 42, scale: [0.72, 0.8, 0.72], district: 'extraction' },

  /* ----------------------------------------------------------------- boss */
  { id: 'boss_gate', name: 'ColossalDockingGate', pos: [0, 0, -83], district: 'boss' },

  /* ------------------------------------------------------------ perimeter */
  { id: 'defense_turret', name: 'PerimeterDefenseTurret_0', pos: [-78, 0, -47], yaw: 0, scale: 1.2, district: 'perimeter' },
  { id: 'defense_turret', name: 'PerimeterDefenseTurret_1', pos: [78, 0, -48], yaw: 53, scale: 1.2, district: 'perimeter' },
  { id: 'defense_turret', name: 'PerimeterDefenseTurret_2', pos: [-80, 0, 30], yaw: 106, scale: 1.2, district: 'perimeter' },
  { id: 'defense_turret', name: 'PerimeterDefenseTurret_3', pos: [80, 0, 31], yaw: 159, scale: 1.2, district: 'perimeter' },
  { id: 'defense_turret', name: 'PerimeterDefenseTurret_4', pos: [-42, 0, 62], yaw: 212, scale: 1.2, district: 'perimeter' },
  { id: 'defense_turret', name: 'PerimeterDefenseTurret_5', pos: [43, 0, 62], yaw: 265, scale: 1.2, district: 'perimeter' },
  { id: 'enemy_spawn_gate', name: 'WestPerimeter', pos: [-83, 0, 1], yaw: 90, scale: [1.45, 1.35, 1.2], district: 'perimeter' },
  { id: 'enemy_spawn_gate', name: 'EastPerimeter', pos: [83, 0, 1], yaw: -90, scale: [1.45, 1.35, 1.2], district: 'perimeter' },
  { id: 'enemy_spawn_gate', name: 'SouthPerimeter', pos: [0, 0, 39], yaw: 180, scale: [1.45, 1.35, 1.2], district: 'perimeter' },
  { id: 'enemy_spawn_gate', name: 'NorthPerimeter', pos: [0, 0, -59], yaw: 0, scale: [1.45, 1.35, 1.2], district: 'perimeter' },
  { id: 'sensor_tower', name: 'EastPerimeterSensor', pos: [79, 0, 6], yaw: -15, scale: [0.9, 1.1, 0.9], district: 'perimeter' },
  { id: 'sensor_tower', name: 'NorthPerimeterSensor', pos: [41, 0, -73], yaw: 26, scale: [0.78, 0.9, 0.78], district: 'perimeter' },

  /* ---------------------------------------------------------------- wilds */
  { id: 'wrecked_transport', name: 'CrashedFrontierTransport', pos: [-48, 0, 46], yaw: 33, scale: [1.2, 1, 1.1], district: 'wilds' },
  { id: 'alien_drone_wreck', name: 'AlienDroneWreck', pos: [-28, 0, 47], yaw: -18, scale: [1.2, 1, 1.1], district: 'wilds' },
  { id: 'defense_turret', name: 'DisabledCheckpointTurret', pos: [-64, 0, 47], yaw: 42, scale: [0.9, 0.72, 0.9], roll: 72, district: 'wilds' },
  { id: 'equipment_depot', name: 'AbandonedLoadingModule', pos: [-34, 0, 64], yaw: -14, scale: 0.82, district: 'wilds' },
];

/** Vegetation and geology, generated deterministically from the game's own lists. */
export const SCATTER = {
  crystal: [
    [57, 70], [18, 61], [-4, 67], [57, 16],
  ],
  flora: [
    [-70, -47], [-62, -12], [-73, 12], [-65, 58], [-36, 68], [-8, 59],
    [15, 66], [38, 60], [66, 58], [69, 29], [72, 5], [72, -60],
    [57, -66], [6, -77], [-38, -68], [31, 19], [-28, 35], [17, 43],
  ],
  rocks: [
    [-88, 20, 1.1], [-84, -58, 0.9], [88, 44, 1.0], [70, 78, 1.2],
    [-60, 78, 1.0], [12, 82, 0.8], [-20, -70, 1.1], [86, -20, 0.9],
  ],
};

/** Where the player can spawn / respawn — exported as sockets for the game. */
export const PLAYER_SPAWNS = [
  { name: 'spawn_arena_north', pos: [0, 0.1, -12] },
  { name: 'spawn_arena_south', pos: [0, 0.1, 12] },
  { name: 'spawn_outpost', pos: [-44, 0.1, 2] },
  { name: 'spawn_extraction', pos: [30, 0.1, -30] },
];
