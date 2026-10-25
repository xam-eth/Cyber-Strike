/**
 * frostline.js — WORLD 1 / mission: DEFENCE.
 *
 * A polar relay station holding the last uplink on a frozen shelf. Everything in
 * it is ice-locked hardware: masts, dishes, cryo condensers, frozen haulers, and
 * the crystal fields that grow through the permafrost. The mood is polar dusk —
 * white ground, cyan light, air you can see.
 *
 * Data only. `compose.js` builds it; `roles.js` says what each role is made of;
 * every mesh in it is a licensed GLB.
 */
import { THEMES } from './themes.js';

export default {
  id: 'frostline_relay',
  name: 'FROSTLINE RELAY',
  mission: 'defence',
  tagline: 'Hold the uplink until the last wave breaks on the ice.',
  width: 168,
  depth: 156,
  centreZ: -8,
  theme: THEMES.frostline,
  scatterDistrict: 'icefield',

  terrain: {
    floor: { tile: 12 },
    deck: { width: 30, depth: 30, tile: 6, lift: 0.15 },
    roads: [
      { name: 'NorthCauseway', from: [0, -16], to: [0, -58] },
      { name: 'SouthApproach', from: [0, 14], to: [0, 52] },
      { name: 'WestRun', from: [-16, 0], to: [-56, 0] },
      { name: 'EastRun', from: [16, 0], to: [56, 0] },
    ],
    perimeter: {
      spacing: 3.4,
      height: 3.6,
      corner: 'column',
      cornerHeight: 9.5,
      gaps: [
        { axis: 'z', at: -8 - 78, gap: 11 },
        { axis: 'z', at: -8 + 78, gap: 11 },
        { axis: 'x', at: -84, gap: 11 },
        { axis: 'x', at: 84, gap: 11 },
      ],
    },
    dressing: { count: 16, centre: [-46, 44], radius: 26, squash: 0.65, craterScale: 8, rockScale: 2.6 },
  },

  layout: [
    /* ---------------------------------------------------- the uplink core */
    { role: 'comms_array', name: 'PrimaryUplink', pos: [0, 0, 0], yaw: 12, district: 'core' },
    // The masts frame the uplink from outside the spawn ring. At ±13 they stood
    // within two metres of the north-west and north-east spawn markers, which
    // left the wave director with no valid flank to send the second tutorial
    // Runner down.
    { role: 'relay_mast', name: 'RelayMast_North', pos: [-20, 0, -17], yaw: 0, district: 'core' },
    { role: 'relay_mast', name: 'RelayMast_South', pos: [20, 0, -17], yaw: 0, district: 'core' },
    { role: 'relay_mast', name: 'RelayMast_SouthFront', pos: [0, 0, 13], yaw: 0, district: 'core' },
    { role: 'cover_module', name: 'CoverWest', pos: [-8, 0, 3], yaw: -12, district: 'core' },
    { role: 'cover_module', name: 'CoverEast', pos: [8, 0, 4], yaw: 78, district: 'core' },

    /* --------------------------------------------------------- the station */
    { role: 'cryo_condenser', name: 'CryoCondenser_A', pos: [-46, 0, -26], yaw: 0, district: 'station' },
    { role: 'cryo_condenser', name: 'CryoCondenser_B', pos: [-44, 0, 22], yaw: 24, district: 'station' },
    { role: 'comms_array', name: 'StationDish', pos: [-52, 0, -2], yaw: -30, district: 'station' },
    { role: 'sensor_tower', name: 'WestSentry', pos: [-70, 0, 30], yaw: 20, scale: 0.95, district: 'station' },
    { role: 'frozen_hauler', name: 'FrozenHauler_A', pos: [-30, 0, 44], yaw: 62, district: 'station' },

    /* ------------------------------------------------------------- defene */
    // The turrets flank the north and south lanes rather than sit in them: the
    // causeway from the arena to the boss gate is the one route the player has
    // to be able to run, and a 3 m turret at x = 0 closed it.
    { role: 'defense_turret', name: 'Turret_North', pos: [-24, 0, -40], yaw: 32, district: 'defence' },
    { role: 'defense_turret', name: 'Turret_West', pos: [-38, 0, -6], yaw: 90, district: 'defence' },
    { role: 'defense_turret', name: 'Turret_East', pos: [38, 0, -6], yaw: -90, district: 'defence' },
    { role: 'defense_turret', name: 'Turret_South', pos: [24, 0, 34], yaw: 148, district: 'defence' },
    { role: 'sensor_tower', name: 'NorthWatch', pos: [30, 0, -52], yaw: -18, district: 'defence' },
    { role: 'enemy_spawn_gate', name: 'BreachNorth', pos: [0, 0, -70], yaw: 0, scale: [1.35, 1.3, 1.2], district: 'defence' },
    { role: 'enemy_spawn_gate', name: 'BreachSouth', pos: [0, 0, 64], yaw: 180, scale: [1.35, 1.3, 1.2], district: 'defence' },
    { role: 'enemy_spawn_gate', name: 'BreachWest', pos: [-76, 0, -8], yaw: 90, scale: [1.35, 1.3, 1.2], district: 'defence' },
    { role: 'enemy_spawn_gate', name: 'BreachEast', pos: [76, 0, -8], yaw: -90, scale: [1.35, 1.3, 1.2], district: 'defence' },

    /* --------------------------------------------------------------- ice */
    { role: 'ice_crystal', name: 'IceSpire_A', pos: [30, 0, 30], yaw: 0, district: 'icefield' },
    { role: 'ice_crystal', name: 'IceSpire_B', pos: [-24, 0, -44], yaw: 40, scale: 0.85, district: 'icefield' },
    { role: 'ice_crystal', name: 'IceSpire_C', pos: [50, 0, -30], yaw: 70, district: 'icefield' },
    { role: 'frozen_hauler', name: 'FrozenHauler_B', pos: [34, 0, 46], yaw: -28, district: 'icefield' },
    { role: 'wrecked_transport', name: 'IceboundWreck', pos: [-58, 0, 50], yaw: 14, district: 'icefield' },

    /* ------------------------------------------ cinematic — alive & dramatic */
    // Syd Mead transit spine: monorail cutting the icefield east-west, 3.2 m elevated.
    // Placed south of the polar gate causeway so the critical north lane (0,-16 → 0,-58) stays clear.
    { role: 'monorail_spine', name: 'IceMonorail_East', pos: [44, 0, 44], yaw: 90, district: 'icefield' },
    { role: 'monorail_train', name: 'IceMonorail_Train', pos: [18, 0, 44], yaw: 90, district: 'icefield' },
    // Rocket frozen on its pad behind the station — 18 m vertical silhouette against aurora, Vitaly Bulgarov megastructure beat.
    { role: 'rocket_stack', name: 'FrozenRocket', pos: [-68, 0, 12], yaw: -18, district: 'station' },
    // Rover outrider left by previous team, half-buried beside hauler — lived-in story.
    { role: 'rover_outrider', name: 'IceRover', pos: [22, 0, 46], yaw: 118, district: 'icefield' },
    // Ore rail ghost — supply rail frozen over in front of east breach, hints the relay was once a port.
    { role: 'rail_line', name: 'IceRail_East', pos: [64, 0, -8], yaw: 90, district: 'defence' },
    { role: 'cable_greeble', name: 'PolarGreeble', pos: [0, 0, -80], yaw: 0, district: 'defence' },
  ],

  landmarks: [
    {
      id: 'polar_gate',
      model: 'tall_arch',
      scale: 1.05,
      stretch: [1, 1.3, 1],
      pos: [0, 0, -88],
      yaw: 0,
    },
  ],

  scatter: {
    ice_crystal: [
      [62, 20, 0.7, 15], [-66, -50, 0.65, 40], [44, -56, 0.8, 0], [-40, 58, 0.7, 70],
      [14, 62, 0.6, 20], [-72, 10, 0.55, 55],
    ],
    rock_cluster: [
      [-62, 30, 0.9], [64, -34, 1.0], [-30, -60, 0.8], [56, 54, 0.95], [-10, 70, 0.7],
    ],
  },

  spawns: [
    { name: 'spawn_relay_core', pos: [0, 0.1, 8] },
    { name: 'spawn_relay_station', pos: [-40, 0.1, 6] },
    { name: 'spawn_relay_north', pos: [0, 0.1, -30] },
    { name: 'spawn_relay_south', pos: [12, 0.1, 40] },
  ],
};
