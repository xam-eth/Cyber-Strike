/**
 * roles.js — every role in the game, expressed as real parts.
 *
 * A role is a small assembly of licensed GLBs from `game/assets/world/real/`:
 * how tall each part should be, where it sits relative to the role origin, and
 * which parts move. No geometry, no texture, no material is authored here —
 * `realModels.makePart` loads the file, scales it to metres and grounds it.
 *
 * Two libraries supply the forms:
 *   setpieces/*  real structures cut from the photographed Cinder Yard plant
 *                (tank ring, tank pad, cooling tower, arch ribs, column, crane,
 *                drone) — CC-BY-4.0, Kammertonus.
 *   kenney/*     the CC0 Space Kit's modular hardware — form only, graded by the
 *                active theme.
 *
 * Motion rules: `spin`, `sweep`, `pulse`, `bob`. `emissive` adds a glowing edge
 * to a part's own material (a light, never new geometry).
 */
export const ROLES = {
  /* ================================================================ shared */
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
  cover_module: {
    title: 'Cover Module',
    parts: [
      { model: 'tank_ring', width: 2.6, pos: [0, 0, 0], name: 'RingBarrier' },
      { model: 'barrels-rail', height: 1.15, pos: [0.4, 0.2, 0], name: 'Barrier' },
      { model: 'barrel', height: 0.9, pos: [1.5, 0, 0.6], name: 'Crate' },
    ],
    anim: [],
  },
  enemy_spawn_gate: {
    title: 'Spawn Gate',
    parts: [
      { model: 'platform-low', height: 0.5, pos: [0, 0, 0], name: 'Base' },
      { model: 'gate-simple', height: 5.0, pos: [0, 0.2, 0], name: 'Gate' },
      { model: 'structure', height: 2.4, pos: [-2.6, 0, -0.6], name: 'PylonW' },
      { model: 'structure', height: 2.4, pos: [2.6, 0, -0.6], name: 'PylonE' },
      { model: 'satellitedish', height: 0.6, pos: [0, 5.2, 0], name: 'Beacon', emissive: { color: 0xff5a3c } },
    ],
    anim: [
      { node: 'Beacon', kind: 'spin', axis: 'y', speed: 2.0 },
      { node: 'Gate', kind: 'pulse', amount: 0.012, speed: 1.8 },
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
  crystal_cluster: {
    title: 'Crystal Cluster',
    parts: [
      { model: 'rock-crystalslargea', height: 3.2, pos: [0, 0, 0], name: 'Main', emissive: { color: 0x7b4bff } },
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
      { model: 'rock-crystals', height: 0.9, pos: [-0.8, 0, 0.4], yaw: 25, name: 'Bloom', emissive: { color: 0x8cff9e } },
    ],
    anim: [
      { node: 'Growth', kind: 'sweep', axis: 'z', amount: 0.05, speed: 1.5 },
      { node: 'Bloom', kind: 'pulse', amount: 0.04, speed: 2.0 },
    ],
  },
  sensor_tower: {
    title: 'Sensor Tower',
    parts: [
      { model: 'platform-low', height: 0.6, pos: [0, 0, 0], name: 'Base' },
      { model: 'column', height: 12.0, pos: [0, 0, 0], name: 'Mast' },
      { model: 'pipe-ring', height: 1.0, pos: [0, 4.6, 0], name: 'RingA' },
      { model: 'pipe-ring', height: 1.0, pos: [0, 7.4, 0], name: 'RingB' },
      { model: 'satellitedish-detailed', height: 2.2, pos: [0, 9.4, 0], name: 'Dish', emissive: { color: 0x54c8ff, intensity: 0.35 } },
      { model: 'satellitedish-large', height: 1.4, pos: [1.6, 8.2, 1.2], name: 'DishB' },
    ],
    anim: [
      { node: 'Dish', kind: 'spin', axis: 'y', speed: 1.3 },
      { node: 'DishB', kind: 'sweep', axis: 'y', amount: 0.5, speed: 0.8 },
      { node: 'RingA', kind: 'spin', axis: 'y', speed: -0.3 },
      { node: 'RingB', kind: 'spin', axis: 'y', speed: 0.3 },
    ],
  },
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

  /* ============================================================= frostline */
  comms_array: {
    title: 'Comms Array',
    parts: [
      { model: 'tank_pad', width: 9.0, pos: [0, 0, 0], name: 'Pad' },
      { model: 'column', height: 11.5, pos: [0, 0, 0], name: 'Mast' },
      { model: 'satellitedish-large', height: 3.4, pos: [0, 11.2, 0], yaw: 18, name: 'DishA', emissive: { color: 0x59e6ff, intensity: 0.5 } },
      { model: 'satellitedish-detailed', height: 2.0, pos: [2.6, 8.4, 1.4], name: 'DishB' },
      { model: 'pipe-ring', height: 0.6, pos: [0, 6.4, 0], name: 'Ring' },
    ],
    anim: [
      { node: 'DishA', kind: 'spin', axis: 'y', speed: 0.24 },
      { node: 'DishB', kind: 'sweep', axis: 'y', amount: 0.55, speed: 0.34 },
      { node: 'Ring', kind: 'spin', axis: 'y', speed: -0.5 },
    ],
  },
  relay_mast: {
    title: 'Relay Mast',
    parts: [
      { model: 'supports-low', height: 0.9, pos: [0, 0, 0], name: 'Foot' },
      { model: 'pipe-supporthigh', height: 13.0, pos: [0, 0, 0], name: 'Mast' },
      { model: 'pipe-ringhigh', height: 1.2, pos: [0, 4.2, 0], name: 'BandLow' },
      { model: 'pipe-ringhigh', height: 1.2, pos: [0, 8.6, 0], name: 'BandHigh' },
      { model: 'satellitedish', height: 1.1, pos: [0, 12.4, 0], name: 'Whip', emissive: { color: 0x59e6ff, intensity: 0.8 } },
    ],
    anim: [
      { node: 'Whip', kind: 'spin', axis: 'y', speed: 1.1 },
      { node: 'BandLow', kind: 'bob', amount: 0.05, speed: 0.4, duration: 7 },
    ],
  },
  cryo_condenser: {
    title: 'Cryo Condenser',
    parts: [
      { model: 'tank_pad', width: 14.0, pos: [0, 0, 0], name: 'Plinth' },
      { model: 'cooling_tower', scale: 0.34, pos: [0, 0, 0], name: 'Shell' },
      { model: 'tank_ring', width: 4.4, pos: [0, 3.4, 0], name: 'Collar', emissive: { color: 0x59e6ff, intensity: 0.6 } },
      { model: 'pipe-straight', height: 0.9, pos: [0, 5.2, 0], yaw: 90, name: 'Vent' },
    ],
    anim: [
      { node: 'Collar', kind: 'spin', axis: 'y', speed: 0.2 },
      { node: 'Vent', kind: 'bob', amount: 0.08, speed: 0.6, duration: 6 },
    ],
  },
  ice_crystal: {
    title: 'Ice Crystal',
    parts: [
      { model: 'rock-crystalslargea', height: 4.6, pos: [0, 0, 0], name: 'Spire', emissive: { color: 0x9ff0ff, intensity: 0.7 } },
      { model: 'rock-crystalslargeb', height: 3.0, pos: [2.2, 0, 1.0], yaw: 35, name: 'Second' },
      { model: 'rock-crystals', height: 1.6, pos: [-1.8, 0, 1.4], yaw: 70, name: 'Third' },
      { model: 'rocks-smallb', height: 0.7, pos: [0.4, 0, -2.0], name: 'Frost' },
    ],
    anim: [
      { node: 'Spire', kind: 'pulse', amount: 0.025, speed: 0.9 },
      { node: 'Second', kind: 'pulse', amount: 0.035, speed: 1.3 },
    ],
  },
  frozen_hauler: {
    title: 'Frozen Hauler',
    parts: [
      { model: 'tank_pad', width: 12.0, pos: [0, 0, 0], name: 'IceSheet' },
      { model: 'craft-cargob', height: 3.6, pos: [0, 0, 0], roll: -6, pitch: 3, name: 'Hull' },
      { model: 'drone', scale: 0.9, pos: [4.4, 0.9, 2.2], roll: -22, yaw: 40, name: 'Tender' },
      { model: 'rock-crystals', height: 1.2, pos: [-4.2, 0, 2.4], name: 'Frost' },
    ],
    anim: [{ node: 'Tender', kind: 'sweep', axis: 'z', amount: 0.02, speed: 0.5 }],
  },

  /* =============================================================== verdant */
  grove_tree: {
    title: 'Grove Tree',
    parts: [
      { model: 'nk_tree-pinerounda', height: 15.0, pos: [0, 0, 0], name: 'Canopy' },
      { model: 'nk_plant-bushlarge', height: 1.4, pos: [1.6, 0, 1.0], yaw: 40, name: 'BushA' },
      { model: 'nk_plant-bushsmall', height: 0.9, pos: [-1.4, 0, 1.2], yaw: -20, name: 'BushB' },
      { model: 'nk_mushroom-tangroup', height: 0.7, pos: [0.6, 0, -1.6], name: 'Fungi' },
    ],
    anim: [{ node: 'Canopy', kind: 'sweep', axis: 'z', amount: 0.012, speed: 0.35 }],
  },
  undergrowth: {
    title: 'Undergrowth',
    parts: [
      { model: 'nk_plant-bushdetailed', height: 1.5, pos: [0, 0, 0], name: 'Bush' },
      { model: 'nk_grass-large', height: 0.9, pos: [1.1, 0, 0.6], name: 'Grass' },
      { model: 'nk_flower-purplea', height: 0.5, pos: [-1.0, 0, 0.5], name: 'Bloom' },
      { model: 'nk_hanging-moss', height: 0.8, pos: [0.4, 0, -0.9], roll: 12, name: 'Moss' },
    ],
    anim: [
      { node: 'Bush', kind: 'sweep', axis: 'z', amount: 0.03, speed: 1.1 },
      { node: 'Bloom', kind: 'pulse', amount: 0.05, speed: 1.6 },
    ],
  },
  moss_rock: {
    title: 'Mossy Boulder',
    parts: [
      { model: 'nk_rock-tallb', height: 3.4, pos: [0, 0, 0], name: 'Stone' },
      { model: 'nk_plant-bushsmall', height: 1.0, pos: [1.5, 0.9, 0.8], name: 'Moss' },
      { model: 'nk_hanging-moss', height: 1.4, pos: [-1.2, 1.6, 0.6], roll: 8, name: 'Drape' },
    ],
    anim: [{ node: 'Drape', kind: 'sweep', axis: 'x', amount: 0.02, speed: 0.8 }],
  },
  mushroom_ring: {
    title: 'Fungal Ring',
    parts: [
      { model: 'nk_mushroom-redtall', height: 1.8, pos: [0, 0, 0], name: 'Stalk' },
      { model: 'nk_mushroom-red', height: 0.9, pos: [1.2, 0, 0.8], yaw: 30, name: 'CapA' },
      { model: 'nk_mushroom-red', height: 0.7, pos: [-1.1, 0, 0.9], yaw: 70, name: 'CapB' },
      { model: 'nk_mushroom-tangroup', height: 0.5, pos: [0.2, 0, -1.3], name: 'CapC' },
    ],
    anim: [{ node: 'Stalk', kind: 'pulse', amount: 0.03, speed: 0.9 }],
  },
  fallen_log: {
    title: 'Fallen Log',
    parts: [
      { model: 'nk_log-large', height: 1.2, pos: [0, 0, 0], roll: 88, yaw: 24, name: 'Trunk' },
      { model: 'nk_stump-oldtall', height: 1.3, pos: [3.0, 0, 1.4], name: 'Stump' },
      { model: 'nk_plant-bushsmall', height: 0.8, pos: [-1.6, 0, 1.0], name: 'Growth' },
    ],
    anim: [],
  },
  bio_dome: {
    title: 'Bio Dome',
    parts: [
      { model: 'tank_pad', width: 18.0, pos: [0, 0, 0], name: 'Footing' },
      { model: 'hangar-roundb', height: 8.4, pos: [0, 0, 0], name: 'Dome' },
      { model: 'tank_ring', width: 7.2, pos: [0, 8.2, 0], name: 'CrownBand' },
      { model: 'bones', height: 3.2, pos: [5.6, 0, 3.0], roll: 18, name: 'Overgrowth' },
      { model: 'pipe-ring', height: 2.2, pos: [-4.8, 0, 3.4], name: 'Vent' },
    ],
    anim: [
      { node: 'CrownBand', kind: 'spin', axis: 'y', speed: 0.12 },
      { node: 'Overgrowth', kind: 'sweep', axis: 'x', amount: 0.03, speed: 0.7 },
      { node: 'Vent', kind: 'spin', axis: 'y', speed: 0.6 },
    ],
  },
  giant_flora: {
    title: 'Giant Flora',
    parts: [
      { model: 'bones', height: 9.0, pos: [0, 0, 0], name: 'Trunk' },
      { model: 'rock-crystalslargea', height: 3.4, pos: [1.2, 2.4, 0.6], name: 'Canopy', emissive: { color: 0x9dff7a, intensity: 0.5 } },
      { model: 'rock-crystals', height: 1.8, pos: [-2.0, 0, 1.0], yaw: 60, name: 'Shoot' },
      { model: 'rocks-smallb', height: 0.9, pos: [1.4, 0, -1.6], name: 'Root' },
    ],
    anim: [
      { node: 'Trunk', kind: 'sweep', axis: 'z', amount: 0.02, speed: 0.45 },
      { node: 'Canopy', kind: 'pulse', amount: 0.02, speed: 0.8 },
      { node: 'Shoot', kind: 'sweep', axis: 'x', amount: 0.05, speed: 1.1 },
    ],
  },
  spore_vent: {
    title: 'Spore Vent',
    parts: [
      { model: 'crater', height: 0.5, pos: [0, 0, 0], name: 'Mouth' },
      { model: 'pipe-ringhigh', height: 2.6, pos: [0, 0.2, 0], name: 'Stalk' },
      { model: 'rock-crystals', height: 2.0, pos: [0, 2.2, 0], name: 'Spore', emissive: { color: 0xb07bff, intensity: 0.7 } },
      { model: 'bones', height: 1.4, pos: [1.8, 0, 1.0], roll: 28, name: 'Frond' },
    ],
    anim: [
      { node: 'Spore', kind: 'pulse', amount: 0.06, speed: 0.7 },
      { node: 'Frond', kind: 'sweep', axis: 'z', amount: 0.06, speed: 1.4 },
    ],
  },
  overgrown_arch: {
    title: 'Overgrown Arch',
    parts: [
      { model: 'tank_pad', width: 16.0, pos: [0, 0, 0], name: 'Foundation' },
      { model: 'tall_arch', scale: 0.62, pos: [0, 0, 0], name: 'Arch' },
      { model: 'bones', height: 4.2, pos: [-4.6, 0, 2.2], roll: 12, name: 'VineW' },
      { model: 'bones', height: 3.6, pos: [4.4, 0, -1.8], roll: -16, name: 'VineE' },
      { model: 'rock-crystalslargeb', height: 2.4, pos: [0, 0, 4.2], name: 'Bloom' },
    ],
    anim: [
      { node: 'VineW', kind: 'sweep', axis: 'x', amount: 0.02, speed: 0.5 },
      { node: 'Bloom', kind: 'pulse', amount: 0.03, speed: 1.0 },
    ],
  },
  crashed_lab: {
    title: 'Crashed Research Module',
    parts: [
      { model: 'craterlarge', height: 0.8, pos: [0, 0, 0], name: 'Scar' },
      { model: 'hangar-smallb', height: 3.8, pos: [0, 0, 0], roll: 14, yaw: 28, name: 'Module' },
      { model: 'drone', scale: 1.1, pos: [5.0, 0.8, 2.4], roll: -18, name: 'Scout' },
      { model: 'bones', height: 2.6, pos: [-4.4, 0, 2.0], name: 'Growth' },
    ],
    anim: [{ node: 'Scout', kind: 'sweep', axis: 'y', amount: 0.4, speed: 0.3 }],
  },

  /* ============================================================== emberfall */
  smelter_tower: {
    title: 'Smelter Tower',
    parts: [
      { model: 'tank_pad', width: 17.0, pos: [0, 0, 0], name: 'Plinth' },
      { model: 'cooling_tower', scale: 0.42, pos: [0, 0, 0], name: 'Shell' },
      { model: 'tank_ring', width: 5.6, pos: [0, 4.0, 0], name: 'GlowBand', emissive: { color: 0xff5a1e, intensity: 0.9 } },
      { model: 'column', height: 6.5, pos: [5.4, 0, -3.4], name: 'Stack' },
      { model: 'pipe-straight', height: 1.0, pos: [0, 6.6, 0], yaw: 90, name: 'Flue' },
    ],
    anim: [
      { node: 'GlowBand', kind: 'spin', axis: 'y', speed: 0.18 },
      { node: 'Flue', kind: 'bob', amount: 0.1, speed: 0.7, duration: 5 },
    ],
  },
  ore_silo: {
    title: 'Ore Silo',
    parts: [
      { model: 'tank_pad', width: 11.0, pos: [0, 0, 0], name: 'Base' },
      { model: 'tank_ring', width: 8.0, pos: [0, 4.6, 0], stretch: [1, 1.6, 1], name: 'Drum' },
      { model: 'tank_ring', width: 7.2, pos: [0, 8.4, 0], stretch: [1, 1.4, 1], name: 'DrumTop' },
      { model: 'column', height: 5.0, pos: [-4.6, 0, 2.6], name: 'Leg' },
    ],
    anim: [{ node: 'DrumTop', kind: 'spin', axis: 'y', speed: 0.1 }],
  },
  drill_rig: {
    title: 'Magma Drill Rig',
    parts: [
      { model: 'tank_pad', width: 15.0, pos: [0, 0, 0], name: 'Pad' },
      { model: 'columns', height: 13.0, pos: [0, 0, 0], name: 'Derrick' },
      { model: 'pipe-straight', height: 1.4, pos: [0, 12.4, 0], name: 'Crown', emissive: { color: 0xff7a1e, intensity: 0.8 } },
      { model: 'crane', scale: 0.16, pos: [0, 8.6, 0], name: 'Arm' },
    ],
    anim: [
      { node: 'Crown', kind: 'spin', axis: 'y', speed: 0.9 },
      { node: 'Arm', kind: 'sweep', axis: 'y', amount: 0.35, speed: 0.22 },
    ],
  },
  crane_gantry: {
    title: 'Crane Gantry',
    parts: [
      { model: 'column', height: 12.0, pos: [-7.4, 0, -6.0], name: 'LegW' },
      { model: 'column', height: 12.0, pos: [7.4, 0, -6.0], name: 'LegE' },
      { model: 'crane', scale: 0.22, pos: [0, 11.4, -6.0], name: 'Beam', emissive: { color: 0xff7a1e, intensity: 0.25 } },
      { model: 'column', height: 4.2, pos: [0, 0, -6.0], roll: 90, name: 'Rail' },
    ],
    anim: [{ node: 'Beam', kind: 'bob', amount: 0.16, speed: 0.3, duration: 11 }],
  },
  slag_pool: {
    title: 'Slag Pool',
    parts: [
      // A real crater basin with a molten floor plate sunk into it: the plate is
      // the kit's own flat deck piece, lit from inside, not a new surface.
      { model: 'craterlarge', height: 1.0, pos: [0, 0, 0], name: 'Basin' },
      { model: 'platform-small', width: 5.2, pos: [0, -0.12, 0], name: 'Melt', emissive: { color: 0xff5a1e, intensity: 0.85 } },
      { model: 'rocks-smallb', height: 0.9, pos: [4.2, 0, 2.0], name: 'Slag' },
    ],
    anim: [{ node: 'Melt', kind: 'pulse', amount: 0.01, speed: 0.3 }],
  },
  ash_statue: {
    title: 'Ash-Caked Column',
    parts: [
      { model: 'columns', height: 9.0, pos: [0, 0, 0], name: 'Shaft' },
      { model: 'meteor-detailed', height: 1.6, pos: [2.4, 0, 1.8], name: 'Cinder' },
    ],
    anim: [],
  },

  /* ========================================================== cinematic new — real GLB only, no procedural */
  monorail_spine: {
    title: 'Monorail Spine (Syd Mead transit)',
    parts: [
      { model: 'monorail-trackstraight', width: 12.0, pos: [0, 3.2, 0], name: 'Rail' },
      { model: 'monorail-tracksupport', height: 3.6, pos: [-5.4, 0, 0], name: 'SupportA' },
      { model: 'monorail-tracksupport', height: 3.6, pos: [5.4, 0, 0], name: 'SupportB' },
      { model: 'monorail-trackstraight', width: 12.0, pos: [0, 3.2, 0], yaw: 90, name: 'Tie', scale: 0.22 },
    ],
    anim: [],
  },
  monorail_train: {
    title: 'Monorail Train — alive',
    parts: [
      { model: 'monorail-trackstraight', width: 8.0, pos: [0, 3.2, 0], name: 'Rail' },
      { model: 'monorail-tracksupport', height: 3.6, pos: [0, 0, 0], name: 'Support' },
      { model: 'monorail-trainfront', height: 2.2, pos: [-2.6, 3.9, 0], name: 'Engine' },
      { model: 'monorail-trainbox', height: 1.9, pos: [1.2, 3.9, 0], name: 'CarA' },
      { model: 'monorail-trainend', height: 1.9, pos: [4.2, 3.9, 0], name: 'CarB' },
    ],
    anim: [
      { node: 'Engine', kind: 'sweep', axis: 'z', amount: 0.02, speed: 0.6 },
      { node: 'CarA', kind: 'bob', amount: 0.04, speed: 0.9, duration: 5 },
    ],
  },
  rocket_stack: {
    title: 'Rocket Stack — megastructure vertical landmark',
    parts: [
      { model: 'platform-low', height: 0.5, pos: [0, 0, 0], name: 'Pad' },
      { model: 'rocket-basea', height: 3.2, pos: [0, 0.5, 0], name: 'Base' },
      { model: 'rocket-sidesa', height: 7.5, pos: [0, 3.6, 0], name: 'Body' },
      { model: 'rocket-fuela', height: 2.2, pos: [-1.9, 6.2, 0], name: 'TankA' },
      { model: 'rocket-fuelb', height: 2.2, pos: [1.9, 6.2, 0], name: 'TankB' },
      { model: 'rocket-finsa', height: 2.8, pos: [-1.4, 1.2, 1.2], yaw: 0, name: 'FinL' },
      { model: 'rocket-finsb', height: 2.8, pos: [1.4, 1.2, -1.2], yaw: 180, name: 'FinR' },
      { model: 'rocket-topa', height: 2.4, pos: [0, 11.0, 0], name: 'Nose', emissive: { color: 0xff3b30, intensity: 0.4 } },
    ],
    anim: [
      { node: 'Nose', kind: 'pulse', amount: 0.02, speed: 1.2 },
    ],
  },
  rover_outrider: {
    title: 'Rover Outrider — lived-in vehicle',
    parts: [
      { model: 'terrain-roadstraight', width: 3.2, pos: [0, 0, 0], name: 'Tracks' },
      { model: 'rover', height: 2.0, pos: [0, 0.4, 0], yaw: -12, name: 'Rover' },
      { model: 'barrel', height: 0.8, pos: [-1.2, 0.3, 0.8], name: 'Supply' },
    ],
    anim: [{ node: 'Rover', kind: 'sweep', axis: 'y', amount: 0.03, speed: 0.5 }],
  },
  rail_line: {
    title: 'Ore Rail Line — industrial plumbing',
    parts: [
      { model: 'rail-middle', width: 6.0, pos: [0, 0.15, 0], name: 'Rail' },
      { model: 'rail-middle', width: 6.0, pos: [6.0, 0.15, 0], name: 'RailB' },
      { model: 'supports-low', height: 0.4, pos: [-3.0, 0, 0], name: 'TieA' },
      { model: 'supports-low', height: 0.4, pos: [3.0, 0, 0], name: 'TieB' },
    ],
    anim: [],
  },
  modular_corridor: {
    title: 'Modular Corridor — dramatic sci-fi gate',
    parts: [
      { model: 'modular-corridor', height: 3.4, pos: [0, 0, 0], name: 'Corridor' },
      { model: 'modular-gate-lasers', height: 3.6, pos: [0, 0, 2.2], name: 'Gate', emissive: { color: 0x59e6ff, intensity: 0.9 } },
      { model: 'modular-cables', height: 0.8, pos: [0, 2.8, 0], name: 'Cables' },
    ],
    anim: [
      { node: 'Gate', kind: 'pulse', amount: 0.025, speed: 1.4 },
      { node: 'Cables', kind: 'sweep', axis: 'z', amount: 0.01, speed: 0.9 },
    ],
  },
  station_dressing: {
    title: 'Station Dressing — lived-in yard (space-kit, self-contained)',
    parts: [
      { model: 'platform-low', height: 0.4, pos: [0, 0, 0], name: 'Pallet' },
      { model: 'barrels', height: 1.2, pos: [-1.4, 0.5, 0.2], name: 'CrateA' },
      { model: 'barrels-rail', height: 1.1, pos: [1.0, 0.5, 0.6], name: 'CrateB' },
      { model: 'desk-computer', height: 1.0, pos: [0.3, 0.5, -0.9], name: 'Terminal', emissive: { color: 0x59e6ff, intensity: 0.45 } },
      { model: 'barrel', height: 0.9, pos: [-1.8, 0.5, -0.6], name: 'Drum' },
    ],
    anim: [{ node: 'Terminal', kind: 'pulse', amount: 0.02, speed: 1.6 }],
  },
  cable_greeble: {
    title: 'Cable Greeble — Vitaly Bulgarov detail',
    parts: [
      { model: 'modular-cables', height: 0.6, pos: [0, 0.2, 0], name: 'Cables' },
      { model: 'pipe-supporthigh', height: 1.0, pos: [-1.4, 0, 0.6], name: 'BracketA' },
      { model: 'pipe-supporthigh', height: 1.0, pos: [1.4, 0, -0.6], name: 'BracketB' },
    ],
    anim: [{ node: 'Cables', kind: 'pulse', amount: 0.015, speed: 1.8 }],
  },

  /* ========================================================== THE TITANS — 3D station interior, setengah hancur, hybrid spark, Blender forced break targeting */
  // CATATAN: Semua benda di sini 3D, bukan 2D. Varian utuh mudah drag-drop, varian sobek/penyok abstract akan di-Blender retargeting (hapus bagian, patah paksa, bukan potong tajam).
  cable_intact: {
    title: 'Cable Intact — menyambung rapi (Koridor Utama)',
    parts: [
      { model: 'modular-cables', height: 0.6, pos: [0, 2.4, 0], name: 'Cables' },
      { model: 'pipe-supporthigh', height: 2.4, pos: [-2.2, 0, 0], name: 'BracketA' },
      { model: 'pipe-supporthigh', height: 2.4, pos: [2.2, 0, 0], name: 'BracketB' },
    ],
    anim: [{ node: 'Cables', kind: 'sweep', axis: 'z', amount: 0.008, speed: 0.7 }],
  },
  cable_spark_orange: {
    title: 'Cable Putus Percikan ORANGE — Human tech hidup',
    parts: [
      // Kabel putus: ujung menggantung, bracket bengkok, percikan orange
      { model: 'modular-cables', height: 0.6, pos: [0, 2.2, 0], name: 'Cables' },
      { model: 'pipe-supporthigh', height: 2.0, pos: [-1.6, 0, 0.4], roll: 14, name: 'BracketA' },
      { model: 'pipe-supporthigh', height: 1.2, pos: [1.2, 0, -0.3], roll: -18, name: 'BracketB' },
      // Spark proxy: pipe-straight kecil dengan emissive orange sebagai titik percikan — Blender nanti ganti dengan spark particle + armature
      { model: 'pipe-straight', height: 0.32, pos: [0.8, 2.2, 0.2], name: 'Spark', emissive: { color: 0xff7a1e, intensity: 1.6 } },
    ],
    anim: [
      { node: 'Cables', kind: 'sweep', axis: 'z', amount: 0.018, speed: 1.4 },
      { node: 'Spark', kind: 'pulse', amount: 0.04, speed: 3.2 },
    ],
  },
  cable_spark_blue: {
    title: 'Cable Putus Percikan BIRU — Alien tech hidup',
    parts: [
      { model: 'modular-cables', height: 0.6, pos: [0, 2.2, 0], name: 'Cables' },
      { model: 'pipe-supporthigh', height: 2.0, pos: [-1.4, 0, -0.4], roll: -12, name: 'BracketA' },
      { model: 'pipe-supporthigh', height: 1.2, pos: [1.4, 0, 0.3], roll: 16, name: 'BracketB' },
      { model: 'pipe-straight', height: 0.32, pos: [-0.6, 2.2, -0.1], name: 'Spark', emissive: { color: 0x59e6ff, intensity: 1.5 } },
    ],
    anim: [
      { node: 'Cables', kind: 'sweep', axis: 'x', amount: 0.015, speed: 1.7 },
      { node: 'Spark', kind: 'pulse', amount: 0.035, speed: 4.1 },
    ],
  },
  wall_torn: {
    title: 'Dinding Sobek Abstract — patah paksa bergerigi (Blender: torn variant)',
    parts: [
      // Placeholder: modular wall + cables menggantung + bracket miring — Blender nanti: Boolean abstract + Displace biar sobek tidak sempurna
      { model: 'modular-template-wall', height: 3.2, pos: [0, 0, 0], name: 'Wall' },
      { model: 'modular-cables', height: 0.7, pos: [0, 2.0, 0.35], yaw: 12, name: 'TornCable' },
      { model: 'pipe-supporthigh', height: 1.6, pos: [-1.2, 0, 0.6], roll: 22, name: 'FrameA' },
    ],
    anim: [{ node: 'TornCable', kind: 'sweep', axis: 'z', amount: 0.012, speed: 1.1 }],
  },
  wall_dented: {
    title: 'Dinding Penyok Bengkok — cekung tidak sobek (Blender: dented variant)',
    parts: [
      // Placeholder: corridor utuh tapi dengan barrel penyok di depan + dent illusion via scale
      { model: 'modular-corridor', height: 3.0, pos: [0, 0, 0], name: 'Wall' },
      { model: 'barrel', height: 1.1, pos: [0.6, 0, 0.8], roll: -14, name: 'Dent' },
      { model: 'barrels', height: 1.0, pos: [-1.0, 0, 0.5], yaw: 18, name: 'Clutter' },
    ],
    anim: [],
  },
  floor_hole: {
    title: 'Lantai Bolong Hancur — lubang abstract + rebar bengkok (Blender: hole variant)',
    parts: [
      // Placeholder: crater sebagai lubang + platform kecil sebagai lantai bawah + rocks sebagai puing — Blender nanti: Boolean abstract + rebar bengkok manual
      { model: 'craterlarge', height: 0.35, pos: [0, 0, 0], name: 'Hole' },
      { model: 'platform-small', width: 2.2, pos: [0, -0.55, 0], name: 'LowerFloor' },
      { model: 'rocks-smalla', height: 0.6, pos: [1.4, 0, 0.9], name: 'RubbleA' },
      { model: 'rocks-smallb', height: 0.45, pos: [-1.2, 0, -0.8], name: 'RubbleB' },
    ],
    anim: [],
  },
  console_fire: {
    title: 'Konsol Terbakar — api kecil + asap tipis (hybrid orange/biru)',
    parts: [
      { model: 'desk-computer', height: 1.05, pos: [0, 0, 0], name: 'Console' },
      { model: 'barrel', height: 0.7, pos: [0.9, 0, 0.6], roll: 22, name: 'Debris' },
      // Api proxy: barrel kecil dengan emissive sebagai api — Blender nanti ganti dengan plane api + smoke
      { model: 'barrel', height: 0.42, pos: [0, 0.95, 0], name: 'Flame', emissive: { color: 0xff4a0a, intensity: 0.95 } },
    ],
    anim: [{ node: 'Flame', kind: 'pulse', amount: 0.045, speed: 2.4 }],
  },
  // Viewport luar angkasa — hanya di 3 breach, bukan skybox 360
  station_breach: {
    title: 'Station Breach — viewport luar angkasa (kaca retak / sobek)',
    parts: [
      { model: 'station-door-double', height: 3.2, pos: [0, 0, 0], name: 'Frame' },
      { model: 'station-display-wall', height: 1.6, pos: [0, 1.2, -0.4], yaw: 90, name: 'Glass', emissive: { color: 0x0a1a2a, intensity: 0.25 } },
      { model: 'modular-cables', height: 0.5, pos: [0, 2.6, 0], name: 'Sparks' },
    ],
    anim: [{ node: 'Sparks', kind: 'pulse', amount: 0.02, speed: 2.8 }],
  },

  /* ========================================================== THE TITANS — BERTINGKAT (foto 1 & 2) — semua GLB real, bukan procedural */
  // Lower pit seperti foto 1: lubang bundar bercahaya di tengah — pakai crater + platform + rocks
  titans_pit: {
    title: 'TITANS Pit — lower level -2.5m, dinding melingkar bercahaya',
    parts: [
      { model: 'craterlarge', height: 0.45, pos: [0, 0, 0], name: 'PitWall' },
      { model: 'platform-small', width: 6.2, pos: [0, -0.9, 0], name: 'PitFloor', emissive: { color: 0xff7a1e, intensity: 0.35 } },
      { model: 'barrels', height: 1.1, pos: [-2.2, -0.7, 1.4], name: 'CrateA' },
      { model: 'rocks-smalla', height: 0.55, pos: [2.0, -0.7, -1.2], name: 'Rubble' },
    ],
    anim: [{ node: 'PitFloor', kind: 'pulse', amount: 0.012, speed: 0.9 }],
  },
  // Walkway ring +3m mengelilingi pit — NARROW 2m wide, bukan solid platform, seperti foto 1 ring bercahaya
  titans_walkway: {
    title: 'TITANS Walkway Ring — +3m elevated, NARROW 2m, bercahaya',
    parts: [
      // Pakai platform-side yang sempit (lebar 2m) bukan platform-high yang besar, biar pit tetap terlihat di tengah
      { model: 'platform-side', width: 4.0, pos: [0, 0, 0], name: 'Deck' },
      { model: 'platform-cornerround', height: 0.9, pos: [1.2, 0.2, 0.6], yaw: 12, name: 'RailingA' },
      { model: 'barrel', height: 0.6, pos: [-1.0, 0.2, 0.4], name: 'Light', emissive: { color: 0xffd166, intensity: 0.35 } },
    ],
    anim: [{ node: 'Light', kind: 'pulse', amount: 0.02, speed: 1.4 }],
  },
  // Stairs penghubung antar level — foto 1 & 2 semua pakai tangga
  titans_stairs: {
    title: 'TITANS Stairs — penghubung vertikal pit ↔ walkway ↔ launch',
    parts: [
      { model: 'stairs', height: 2.4, pos: [0, 0, 0], name: 'Stairs' },
      { model: 'pipe-supporthigh', height: 1.8, pos: [-0.9, 0, 0.6], name: 'PillarA' },
      { model: 'pipe-supporthigh', height: 1.8, pos: [0.9, 0, -0.6], name: 'PillarB' },
    ],
    anim: [],
  },
  // Launch platform +4.5m seperti foto 2 — pedestal roket dengan asap
  titans_launch: {
    title: 'TITANS Launch Platform — +4.5m, pedestal dengan smoke',
    parts: [
      { model: 'platform-high', height: 2.2, pos: [0, 0, 0], name: 'Pedestal' },
      { model: 'terrain-ramplarge', height: 1.4, pos: [-2.8, 0, 1.2], yaw: -22, name: 'Ramp' },
      { model: 'barrel', height: 0.85, pos: [1.2, 0.8, -0.8], name: 'Tank', emissive: { color: 0xff7a1e, intensity: 0.45 } },
      { model: 'rocks-smallb', height: 0.4, pos: [-1.4, 0, -1.0], name: 'SmokeBase' },
    ],
    anim: [{ node: 'Tank', kind: 'pulse', amount: 0.02, speed: 1.6 }],
  },

  /* ========================================================== STELLAR HORIZON — ONE WORLD (foto ref) — floating islands, central tower, canyon, interior — semua GLB real, tidak datar */
  stellar_tower: {
    title: 'STELLAR Tower — central landmark 28m, beam biru, jembatan melengkung',
    parts: [
      { model: 'column', height: 22.0, pos: [0, 0, 0], name: 'Core' },
      { model: 'tank_ring', width: 6.2, pos: [0, 8.5, 0], name: 'RingA', emissive: { color: 0x59e6ff, intensity: 0.85 } },
      { model: 'tank_ring', width: 4.8, pos: [0, 16.2, 0], name: 'RingB', emissive: { color: 0x59e6ff, intensity: 1.0 } },
      { model: 'platform-center', scale: 14.0, pos: [0, 0, 0], name: 'Base' },
      { model: 'modular-gate-lasers', height: 3.2, pos: [0, 1.2, 3.8], name: 'Beam', emissive: { color: 0x59e6ff, intensity: 1.2 } },
      { model: 'tall_arch', scale: 1.4, pos: [-4.2, 0, 2.4], name: 'ArchA' },
      { model: 'tall_arch', scale: 1.4, pos: [4.2, 0, -2.4], yaw: 180, name: 'ArchB' },
    ],
    anim: [
      { node: 'RingA', kind: 'spin', axis: 'y', speed: 0.18 },
      { node: 'RingB', kind: 'spin', axis: 'y', speed: -0.22 },
      { node: 'Beam', kind: 'pulse', amount: 0.025, speed: 1.15 },
    ],
  },
  stellar_island: {
    title: 'Floating Island — tebing curam + platform atas + air terjun',
    parts: [
      { model: 'craterlarge', height: 0.85, pos: [0, 0, 0], name: 'CliffBase' },
      { model: 'terrain-sidecliff', height: 5.2, pos: [-3.2, 2.4, 1.2], yaw: -22, name: 'CliffA' },
      { model: 'terrain-side', height: 4.6, pos: [2.8, 2.2, -1.0], yaw: 34, name: 'CliffB' },
      { model: 'platform-large', scale: 10.0, pos: [0, 5.8, 0], name: 'TopDeck' },
      { model: 'rocks-smallb', height: 1.1, pos: [3.2, 5.6, 2.4], name: 'RockA' },
      { model: 'barrel', height: 0.7, pos: [-2.4, 6.0, -1.2], name: 'Crate' },
    ],
    anim: [],
  },
  stellar_bridge: {
    title: 'Sky Bridge — melengkung antar pulau, seperti foto jembatan utama',
    parts: [
      { model: 'platform-long', scale: 14.0, pos: [0, 6.4, 0], name: 'Span' },
      { model: 'platform-side', width: 3.6, pos: [0, 6.8, 1.4], name: 'RailingA' },
      { model: 'platform-side', width: 3.6, pos: [0, 6.8, -1.4], name: 'RailingB' },
      { model: 'barrel', height: 0.5, pos: [0, 6.6, 0], name: 'Light', emissive: { color: 0xffd166, intensity: 0.35 } },
    ],
    anim: [{ node: 'Light', kind: 'pulse', amount: 0.02, speed: 1.4 }],
  },
  stellar_canyon: {
    title: 'Canyon Wall — tebing dalam dengan shadows, jalur canyon',
    parts: [
      { model: 'terrain-sidecliff', height: 7.2, pos: [-4.2, 0, 0], yaw: 0, name: 'WallA' },
      { model: 'terrain-side', height: 6.4, pos: [4.2, 0, 0], yaw: 180, name: 'WallB' },
      { model: 'rocks-smallb', height: 1.4, pos: [0, 0, 2.2], name: 'Rubble' },
      { model: 'structure', height: 3.2, pos: [0, 1.2, -2.4], name: 'Support' },
    ],
    anim: [],
  },
  stellar_interior: {
    title: 'Interior Base — lab gelap, console biru, seperti foto Facility Inside',
    parts: [
      { model: 'modular-corridor', height: 3.4, pos: [0, 0, 0], name: 'Corridor' },
      { model: 'modular-room-small', height: 3.6, pos: [0, 0, 3.2], name: 'Room' },
      { model: 'station-computer', height: 1.1, pos: [-1.2, 0.4, 1.4], name: 'Console', emissive: { color: 0x59e6ff, intensity: 0.55 } },
      { model: 'station-container', height: 1.4, pos: [1.4, 0.4, -1.2], name: 'Crate' },
      { model: 'modular-gate-lasers', height: 2.8, pos: [0, 0.2, -3.4], name: 'Door', emissive: { color: 0x59e6ff, intensity: 0.85 } },
    ],
    anim: [
      { node: 'Console', kind: 'pulse', amount: 0.02, speed: 1.8 },
      { node: 'Door', kind: 'pulse', amount: 0.02, speed: 1.2 },
    ],
  },
  stellar_cover: {
    title: 'Cover Barricade — tiap 5-6m, bukan arena kosong, survival',
    parts: [
      { model: 'barrels', height: 1.2, pos: [0, 0, 0], name: 'Barricade' },
      { model: 'platform-small', width: 2.4, pos: [0, 0.2, 0.8], name: 'Plate' },
      { model: 'rocks-smalla', height: 0.6, pos: [1.2, 0, -0.4], name: 'Rock' },
    ],
    anim: [],
  },
};

/** Roles per world: which of the library each mission actually uses.
 * Cinematic additions marked — all real GLB, dramatic silhouettes + lived-in greeble. */
export const WORLD_ROLES = {
  frostline: [
    // ONE WORLD base — stellar horizon floating archipelago (foto ref) — central tower + islands + canyon + interior + cover tiap 5m
    'stellar_tower', 'stellar_island', 'stellar_bridge', 'stellar_canyon', 'stellar_interior', 'stellar_cover',
    // legacy: keep for variation but now secondary — polar relay dressing as daytime variant
    'comms_array', 'relay_mast', 'cryo_condenser', 'ice_crystal', 'frozen_hauler',
    'defense_turret', 'sensor_tower', 'cover_module', 'enemy_spawn_gate',
    'rock_cluster', 'wrecked_transport',
    'monorail_spine', 'monorail_train', 'rocket_stack', 'rover_outrider', 'rail_line', 'cable_greeble',
  ],
  verdant: [
    // ONE WORLD base — same layout as frostline, sunset mood
    'stellar_tower', 'stellar_island', 'stellar_bridge', 'stellar_canyon', 'stellar_interior', 'stellar_cover',
    'bio_dome', 'giant_flora', 'spore_vent', 'overgrown_arch', 'crashed_lab',
    'grove_tree', 'undergrowth', 'moss_rock', 'mushroom_ring', 'fallen_log',
    'crystal_cluster', 'alien_flora', 'rock_cluster', 'defense_turret', 'cover_module',
    'modular_corridor', 'station_dressing', 'rover_outrider', 'cable_greeble',
  ],
  emberfall: [
    // ONE WORLD base — same layout, night mood
    'stellar_tower', 'stellar_island', 'stellar_bridge', 'stellar_canyon', 'stellar_interior', 'stellar_cover',
    'smelter_tower', 'ore_silo', 'drill_rig', 'crane_gantry', 'slag_pool',
    'ash_statue', 'defense_turret', 'cover_module', 'enemy_spawn_gate',
    'wrecked_transport', 'rock_cluster',
    'monorail_spine', 'monorail_train', 'rocket_stack', 'rover_outrider', 'rail_line', 'modular_corridor', 'station_dressing', 'cable_greeble',
  ],
  // THE TITANS — now STELLAR HORIZON storm variant, exterior + interior base (bukan dimensi terpisah)
  titans: [
    // ONE WORLD base — same layout, storm mood + interior facility
    'stellar_tower', 'stellar_island', 'stellar_bridge', 'stellar_canyon', 'stellar_interior', 'stellar_cover',
    'cover_module', 'defense_turret', 'enemy_spawn_gate', 'wrecked_transport', 'rock_cluster',
    'cable_intact', 'cable_spark_orange', 'cable_spark_blue',
    'wall_torn', 'wall_dented', 'floor_hole', 'console_fire', 'station_breach',
    'station_dressing', 'cable_greeble', 'modular_corridor',
    'titans_pit', 'titans_walkway', 'titans_stairs', 'titans_launch',
  ],
};
