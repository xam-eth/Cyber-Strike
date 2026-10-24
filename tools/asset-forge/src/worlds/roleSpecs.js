/**
 * roleSpecs.js — what each world role *is*, expressed in real models.
 *
 * One role = one or more real GLB parts from `game/assets/world/real/`. No
 * geometry is authored here: a spec says which licensed model to load, how tall
 * it should be in metres, where its parts sit relative to the role origin, and
 * which parts move.
 *
 * Two libraries supply the forms:
 *   setpieces/*  real pieces cut from the photographed Power Plant (CC-BY-4.0)
 *                — cooling tower, tank rings, arch ribs, columns, drone, crane.
 *   kenney/*     CC0 painted-metal kit, graded to the installation's palette by
 *                `realModels.gradeKit` (form only; surfaces are authored there).
 *
 * `anim` entries become animation clips on the real meshes (rotation / scale /
 * position tracks). Animation data is authored; the surfaces are not.
 *
 * Each role's total height is checked against `tools/asset-forge/references/world`
 * and the world gate — the design intent cannot drift from the build.
 */
export const ROLE_SPECS = {
  /* ------------------------------------------------------------- arena */
  reactor_core: {
    title: 'Reactor Core',
    parts: [
      // 50 × 28 × 48 m of real cooling-tower shell, brought down to 13 m so it
      // reads as the arena's reactor housing.
      { model: 'cooling_tower', scale: 0.40, pos: [0, 0, 0], name: 'Shell' },
      // 30 m real tank ring floating inside as the glowing collar.
      { model: 'tank_ring', width: 7.6, pos: [0, 6.0, 0], name: 'RingLow', emissive: { color: 0x2ee8ff, intensity: 0.55 } },
      { model: 'tank_ring', width: 5.4, pos: [0, 8.4, 0], name: 'RingHigh' },
      { model: 'tank_pad', width: 15.0, pos: [0, 0, 0], name: 'Plinth' },
      { model: 'rock-crystalslargea', height: 4.2, pos: [0, 4.6, 0], name: 'Core', emissive: { color: 0x39ffd0, intensity: 0.5 } },
      { model: 'satellitedish-large', height: 1.2, pos: [0, 11.0, 0], name: 'Crown', emissive: { color: 0xff9b3d, intensity: 0.28 } },
    ],
    anim: [
      { node: 'RingLow', kind: 'spin', axis: 'y', speed: 0.32 },
      { node: 'RingHigh', kind: 'spin', axis: 'y', speed: -0.26 },
      { node: 'Core', kind: 'pulse', amount: 0.05, speed: 2.1 },
      { node: 'Crown', kind: 'spin', axis: 'y', speed: 0.9 },
    ],
  },

  /* ----------------------------------------------------------- outpost */
  command_center: {
    title: 'Command Centre',
    parts: [
      { model: 'hangar-largea', height: 7.5, pos: [0, 0, 0], name: 'Hull' },
      { model: 'column', height: 6.5, pos: [-4.6, 0, -1.4], name: 'MastCol' },
      { model: 'satellitedish-large', height: 1.9, pos: [2.6, 7.5, 1.2], name: 'Dish' },
      { model: 'corridor-detailed', height: 2.4, pos: [0, 0, 6.2], name: 'Entry' },
    ],
    anim: [{ node: 'Dish', kind: 'spin', axis: 'y', speed: 0.45 }],
  },
  research_lab: {
    title: 'Research Lab',
    parts: [
      { model: 'hangar-roundb', height: 5.5, pos: [0, 0, 0], name: 'Hull' },
      { model: 'machine-wirelesscable', height: 1.6, pos: [4.2, 0, 2.4], name: 'Console' },
      { model: 'pipe-ringhigh', height: 2.4, pos: [3.6, 0.2, -2.8], name: 'Vessel' },
      { model: 'tank_ring', width: 6.0, pos: [0, 5.2, 0], name: 'Dome' },
      { model: 'satellitedish-detailed', height: 1.2, pos: [-2.4, 5.5, 0], name: 'Dish' },
    ],
    anim: [
      { node: 'Vessel', kind: 'spin', axis: 'y', speed: 0.7 },
      { node: 'Dome', kind: 'spin', axis: 'y', speed: 0.16 },
      { node: 'Dish', kind: 'spin', axis: 'y', speed: -0.3 },
    ],
  },
  equipment_depot: {
    title: 'Equipment Depot',
    parts: [
      { model: 'hangar-smallb', height: 4.6, pos: [0, 0, 0], name: 'Hull' },
      { model: 'barrels', height: 1.4, pos: [3.4, 0, 2.6], name: 'Crates' },
      { model: 'barrels-rail', height: 1.2, pos: [-3.6, 0, 2.2], name: 'CratesB' },
      { model: 'platform-low', height: 0.35, pos: [0, 0, 5.4], name: 'Apron' },
    ],
    anim: [{ node: 'CratesB', kind: 'bob', amount: 0.03, speed: 1.1 }],
  },

  /* -------------------------------------------------------- extraction */
  generator_bank: {
    title: 'Generator Bank',
    parts: [
      { model: 'tank_pad', width: 20.0, pos: [0, 0, 0], name: 'Deck' },
      { model: 'cooling_tower', scale: 0.21, pos: [-6.2, 0, 0], name: 'GeneratorA' },
      { model: 'cooling_tower', scale: 0.21, pos: [6.2, 0, 0], name: 'GeneratorB' },
      { model: 'tank_ring', width: 6.4, pos: [0, 0.1, 4.6], name: 'Tank' },
      { model: 'pipe-ringhigh', height: 1.8, pos: [-6.2, 5.4, 0], name: 'StackA' },
      { model: 'pipe-ringhigh', height: 1.8, pos: [6.2, 5.4, 0], name: 'StackB' },
      { model: 'pipe-straight', height: 0.9, pos: [0, 2.6, -3.0], yaw: 90, name: 'FeedPipe' },
    ],
    anim: [
      { node: 'GeneratorA', kind: 'pulse', amount: 0.03, speed: 2.4 },
      { node: 'GeneratorB', kind: 'pulse', amount: 0.03, speed: 2.4 },
      { node: 'StackA', kind: 'spin', axis: 'y', speed: 0.5 },
      { node: 'StackB', kind: 'spin', axis: 'y', speed: -0.5 },
    ],
  },

  /* ---------------------------------------------------------- landing */
  landing_pad: {
    title: 'Landing Pad',
    parts: [
      { model: 'tank_pad', width: 21.0, pos: [0, 0, 0], name: 'Deck' },
      { model: 'platform-corner', height: 0.25, pos: [-9.5, 1.2, -9.5], name: 'CornerNW' },
      { model: 'platform-corner', height: 0.25, pos: [9.5, 1.2, -9.5], yaw: 90, name: 'CornerNE' },
      { model: 'platform-corner', height: 0.25, pos: [9.5, 1.2, 9.5], yaw: 180, name: 'CornerSE' },
      { model: 'platform-corner', height: 0.25, pos: [-9.5, 1.2, 9.5], yaw: 270, name: 'CornerSW' },
      { model: 'chimney', height: 2.2, pos: [-9.0, 1.2, 0], name: 'PostW' },
      { model: 'chimney', height: 2.2, pos: [9.0, 1.2, 0], name: 'PostE' },
      { model: 'chimney', height: 2.2, pos: [0, 1.2, -9.0], name: 'PostN' },
      { model: 'chimney', height: 2.2, pos: [0, 1.2, 9.0], name: 'PostS' },
      { model: 'satellitedish', height: 0.9, pos: [6.0, 1.2, 6.0], name: 'Beacon', emissive: { color: 0x54ffe0, intensity: 0.9 } },
      // 84 m of real crane carriage, trimmed to a 16 m gantry across the apron.
      { model: 'crane', scale: 0.20, pos: [0, 1.0, -8.6], name: 'Gantry' },
    ],
    anim: [
      { node: 'Gantry', kind: 'bob', amount: 0.12, speed: 0.35, duration: 9 },
      { node: 'Beacon', kind: 'spin', axis: 'y', speed: 1.1 },
      { node: 'PostW', kind: 'pulse', amount: 0.04, speed: 2.2 },
      { node: 'PostE', kind: 'pulse', amount: 0.04, speed: 2.2 },
      { node: 'PostN', kind: 'pulse', amount: 0.04, speed: 2.2 },
      { node: 'PostS', kind: 'pulse', amount: 0.04, speed: 2.2 },
    ],
  },

  /* ------------------------------------------------------------- boss */
  boss_gate: {
    title: 'Docking Gate',
    parts: [
      { model: 'tank_pad', width: 24.0, pos: [0, 0, 0], name: 'Threshold' },
      // 22.5 m of real arch rib — the docking ribs of the Power Plant — stretched
      // vertically into the colossal gate the boss arena frames.
      { model: 'tall_arch', scale: 1.15, stretch: [1, 1.6, 1], pos: [0, 0, 0], name: 'Gate' },
      { model: 'column', height: 8.0, pos: [-9.0, 0, -2.0], name: 'ButtressW' },
      { model: 'column', height: 8.0, pos: [9.0, 0, -2.0], name: 'ButtressE' },
      { model: 'satellitedish-large', height: 1.8, pos: [6.4, 10.4, 2.0], name: 'Sentry', emissive: { color: 0xff3b6b, intensity: 0.22 } },
      { model: 'gate-simple', height: 7.5, pos: [0, 0, 1.2], name: 'LockFrame' },
    ],
    anim: [
      { node: 'Sentry', kind: 'spin', axis: 'y', speed: 0.6 },
      { node: 'Gate', kind: 'pulse', amount: 0.008, speed: 0.9 },
      { node: 'LockFrame', kind: 'pulse', amount: 0.03, speed: 1.4 },
    ],
  },

  /* -------------------------------------------------------- perimeter */
  defense_turret: {
    title: 'Defence Turret',
    parts: [
      { model: 'platform-low', height: 0.55, pos: [0, 0, 0], name: 'Base' },
      { model: 'pipe-supportlow', height: 0.9, pos: [0, 0.5, 0], name: 'Spine' },
      { model: 'turret-double', height: 2.3, pos: [0, 1.3, 0], name: 'Turret' },
      { model: 'satellitedish', height: 0.5, pos: [0, 2.6, -0.9], name: 'Sensor' },
    ],
    anim: [
      { node: 'Turret', kind: 'sweep', axis: 'y', amount: 0.8, speed: 0.5 },
      { node: 'Sensor', kind: 'spin', axis: 'y', speed: 1.4 },
    ],
  },
  sensor_tower: {
    title: 'Sensor Tower',
    parts: [
      { model: 'platform-low', height: 0.6, pos: [0, 0, 0], name: 'Base' },
      { model: 'column', height: 12.0, pos: [0, 0, 0], name: 'Mast' },
      { model: 'pipe-ring', height: 1.0, pos: [0, 4.6, 0], name: 'RingA' },
      { model: 'pipe-ring', height: 1.0, pos: [0, 7.4, 0], name: 'RingB' },
      { model: 'satellitedish-detailed', height: 2.2, pos: [0, 9.4, 0], name: 'Dish', emissive: { color: 0x54c8ff, intensity: 0.3 } },
      { model: 'satellitedish-large', height: 1.4, pos: [1.6, 8.2, 1.2], name: 'DishB' },
    ],
    anim: [
      { node: 'Dish', kind: 'spin', axis: 'y', speed: 1.3 },
      { node: 'DishB', kind: 'sweep', axis: 'y', amount: 0.5, speed: 0.8 },
      { node: 'RingA', kind: 'spin', axis: 'y', speed: -0.3 },
      { node: 'RingB', kind: 'spin', axis: 'y', speed: 0.3 },
    ],
  },
  enemy_spawn_gate: {
    title: 'Spawn Gate',
    parts: [
      { model: 'platform-low', height: 0.5, pos: [0, 0, 0], name: 'Base' },
      { model: 'gate-simple', height: 5.0, pos: [0, 0.2, 0], name: 'Gate' },
      { model: 'structure', height: 2.4, pos: [-2.6, 0, -0.6], name: 'PylonW' },
      { model: 'structure', height: 2.4, pos: [2.6, 0, -0.6], name: 'PylonE' },
      { model: 'satellitedish', height: 0.6, pos: [0, 5.2, 0], name: 'Beacon', emissive: { color: 0xff5a3c, intensity: 0.9 } },
    ],
    anim: [
      { node: 'Beacon', kind: 'spin', axis: 'y', speed: 2.0 },
      { node: 'Gate', kind: 'pulse', amount: 0.012, speed: 1.8 },
    ],
  },

  /* ------------------------------------------------------------ wilds */
  wrecked_transport: {
    title: 'Wrecked Transport',
    parts: [
      { model: 'drone', scale: 1.5, pos: [0, 1.1, 0], roll: -11, pitch: 5, yaw: 24, name: 'Hull' },
      { model: 'craft-cargob', height: 2.6, pos: [-6.2, 0, 3.4], roll: -14, yaw: 40, name: 'Wing' },
      { model: 'meteor-half', height: 1.1, pos: [-4.2, 0, 2.6], name: 'Debris' },
      { model: 'rocks-smalla', height: 0.5, pos: [3.6, 0, 3.2], name: 'Scatter' },
      { model: 'column', height: 3.4, pos: [5.4, 1.4, -3.0], roll: 86, name: 'TornColumn' },
    ],
    anim: [{ node: 'Hull', kind: 'sweep', axis: 'z', amount: 0.006, speed: 0.8 }],
  },
  alien_drone_wreck: {
    title: 'Alien Drone Wreck',
    parts: [
      { model: 'crater', height: 0.3, pos: [0, 0, 0], name: 'Impact' },
      { model: 'drone', scale: 1.1, pos: [0, 0.7, 0], roll: 26, pitch: -14, yaw: -34, name: 'Chassis' },
      { model: 'bones', height: 1.2, pos: [2.2, 0, 1.4], roll: 30, name: 'Remains' },
      { model: 'meteor-detailed', height: 0.8, pos: [-2.0, 0, 1.8], name: 'Fragment' },
    ],
    anim: [{ node: 'Chassis', kind: 'sweep', axis: 'x', amount: 0.02, speed: 0.6 }],
  },
  crystal_cluster: {
    title: 'Crystal Cluster',
    parts: [
      { model: 'rock-crystalslargea', height: 3.2, pos: [0, 0, 0], name: 'Main', emissive: { color: 0x7b4bff, intensity: 0.7 } },
      { model: 'rock-crystalslargeb', height: 2.2, pos: [2.4, 0, 1.1], yaw: 40, name: 'Second' },
      { model: 'rock-crystals', height: 1.3, pos: [-2.2, 0, 1.6], yaw: 70, name: 'Third' },
      { model: 'rocks-smallb', height: 0.6, pos: [0.6, 0, -2.2], name: 'Base' },
    ],
    anim: [
      { node: 'Main', kind: 'pulse', amount: 0.02, speed: 1.1 },
      { node: 'Second', kind: 'pulse', amount: 0.03, speed: 1.5 },
    ],
  },
  alien_flora: {
    title: 'Alien Flora',
    parts: [
      { model: 'bones', height: 1.8, pos: [0, 0, 0], name: 'Growth' },
      { model: 'rocks-smallb', height: 0.4, pos: [0.7, 0, 0.5], name: 'Base' },
      { model: 'rock-crystals', height: 0.9, pos: [-0.8, 0, 0.4], yaw: 25, name: 'Bloom' },
    ],
    anim: [
      { node: 'Growth', kind: 'sweep', axis: 'z', amount: 0.05, speed: 1.5 },
      { node: 'Bloom', kind: 'pulse', amount: 0.04, speed: 2.0 },
    ],
  },
  rock_cluster: {
    title: 'Rock Cluster',
    parts: [
      { model: 'rock-largea', height: 3.6, pos: [0, 0, 0], yaw: 12, name: 'Main' },
      { model: 'rock-largeb', height: 2.1, pos: [2.8, 0, 1.4], yaw: 60, name: 'Second' },
      { model: 'rocks-smalla', height: 0.8, pos: [-2.2, 0, 1.8], name: 'Scatter' },
    ],
    anim: [],
  },
  cover_module: {
    title: 'Cover Module',
    parts: [
      { model: 'tank_ring', width: 2.6, pos: [0, 0, 0], name: 'RingBarrier' },
      { model: 'barrels-rail', height: 1.15, pos: [0.4, 0.2, 0], name: 'Barrier' },
      { model: 'barrel', height: 0.9, pos: [1.5, 0, 0.6], name: 'Crate' },
      { model: 'barrel', height: 0.8, pos: [-1.4, 0, 0.8], yaw: 30, name: 'CrateB' },
    ],
    anim: [],
  },
};

/** Big real set pieces placed once, as landmarks rather than kit roles. */
export const LANDMARKS = {
  // 245 × 53 × 128 m of photographed power station, scaled to a 26 m ridge and
  // turned so its long axis runs with the field, standing outside the east wall
  // as the installation the outpost is built to serve.
  powerplant: {
    title: 'Cinder Yard Power Station',
    model: 'powerplant',
    height: 24.0,
    pos: [152, 0, -14],
    yaw: 96,
  },
};
