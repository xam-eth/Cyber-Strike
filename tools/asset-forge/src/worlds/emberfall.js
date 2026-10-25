/**
 * emberfall.js — STELLAR HORIZON / EMBERFALL FOUNDRY — NIGHT — ONE WORLD (foto ref).
 *
 * Foto: floating islands di langit, central tower dengan beam biru, jembatan melengkung,
 * air terjun, canyon, interior base. Level Layout: central tower hub, 4 spawns, main/secondary routes,
 * cover tiap 5-6m. Environment & Mood: EMBERFALL FOUNDRY — NIGHT — Night at the foundry — city lights and interior base glow, tower beam dominates dark sky.
 * Geometry SAMA untuk semua 4 worlds — hanya sky/fog/lights dan dressing berbeda.
 * Satu jalur world konsisten, bukan 4 dimensi terpisah — survival adventure.
 */
import { THEMES } from './themes.js';

export default {
  id: 'emberfall_foundry',
  name: 'EMBERFALL FOUNDRY — NIGHT',
  mission: 'extraction',
  tagline: 'Night at the foundry — city lights and interior base glow, tower beam dominates dark sky.',
  width: 180,
  depth: 180,
  centreZ: 0,
  theme: THEMES.emberfall,
  scatterDistrict: 'central',

  terrain: {
    floor: { tile: 12 },
    deck: { width: 36, depth: 36, tile: 6, lift: 0.18 },
    roads: [
      // Main Route solid — Level Layout: hub central tower ke 4 spawns
      { name: 'MainNorth', from: [0, 8], to: [0, 62] },
      { name: 'MainSouth', from: [0, -8], to: [0, -62] },
      { name: 'MainEast', from: [8, 0], to: [62, 0] },
      { name: 'MainWest', from: [-8, 0], to: [-62, 0] },
      // Outer loop — Level Layout outer ring
      { name: 'OuterNorth', from: [-58, 58], to: [58, 58] },
      { name: 'OuterSouth', from: [-58, -58], to: [58, -58] },
      { name: 'OuterEast', from: [58, -58], to: [58, 58] },
      { name: 'OuterWest', from: [-58, -58], to: [-58, 58] },
      // Secondary dashed — alternative flanking via islands
      { name: 'SecondaryNE', from: [22, 22], to: [52, 42] },
      { name: 'SecondaryNW', from: [-22, 22], to: [-52, 42] },
      { name: 'SecondarySE', from: [22, -22], to: [52, -42] },
      { name: 'SecondarySW', from: [-22, -22], to: [-52, -42] },
    ],
    perimeter: {
      spacing: 3.4,
      height: 3.6,
      corner: 'column',
      cornerHeight: 11,
      gaps: [
        { axis: 'z', at: 90, gap: 14 },
        { axis: 'z', at: -90, gap: 14 },
        { axis: 'x', at: -90, gap: 14 },
        { axis: 'x', at: 90, gap: 14 },
      ],
    },
    dressing: { count: 18, centre: [0, 0], radius: 28, squash: 0.85, craterScale: 8, rockScale: 2.4 },
  },

  layout: [
    /* ===================================================== STELLAR HORIZON — ONE WORLD */
    // Central landmark — the blue beam tower from foto top (01 MAIN VIEW), height 28m, visible dari semua pulau
    { role: 'stellar_tower', name: 'CentralTower', pos: [0, 0, 0], yaw: 0, district: 'central' },
    // Floating islands — tebing curam + platform atas + waterfall (foto floating islands), tiap 40m dari center, y +8-10
    { role: 'stellar_island', name: 'Island_NE', pos: [42, 9, 32], yaw: 12, district: 'islands' },
    { role: 'stellar_island', name: 'Island_NW', pos: [-38, 11, 28], yaw: -18, district: 'islands' },
    { role: 'stellar_island', name: 'Island_SE', pos: [40, 7, -30], yaw: 22, district: 'islands' },
    { role: 'stellar_island', name: 'Island_SW', pos: [-42, 10, -34], yaw: -8, district: 'islands' },
    { role: 'stellar_island', name: 'Island_E', pos: [58, 6, 8], yaw: 90, district: 'islands' },
    { role: 'stellar_island', name: 'Island_W', pos: [-56, 8, -6], yaw: -90, district: 'islands' },
    // Sky bridges — jembatan melengkung antar pulau seperti foto jembatan utama (foto top, curving bridge)
    { role: 'stellar_bridge', name: 'Bridge_E', pos: [22, 6, 0], yaw: 0, district: 'bridges' },
    { role: 'stellar_bridge', name: 'Bridge_W', pos: [-22, 6, 0], yaw: 180, district: 'bridges' },
    { role: 'stellar_bridge', name: 'Bridge_N', pos: [0, 6, 22], yaw: 90, district: 'bridges' },
    { role: 'stellar_bridge', name: 'Bridge_S', pos: [0, 6, -22], yaw: -90, district: 'bridges' },
    // Canyon — tebing dalam di sisi, seperti foto 02 CANYON ROUTE, dengan shadows
    { role: 'stellar_canyon', name: 'Canyon_N', pos: [0, 0, 58], yaw: 0, district: 'canyon' },
    { role: 'stellar_canyon', name: 'Canyon_S', pos: [0, 0, -62], yaw: 180, district: 'canyon' },
    { role: 'stellar_canyon', name: 'Canyon_E', pos: [68, 0, 0], yaw: 90, district: 'canyon' },
    { role: 'stellar_canyon', name: 'Canyon_W', pos: [-66, 0, 0], yaw: -90, district: 'canyon' },
    // Interior Base — lab gelap, console biru, seperti foto 02 FACILITY INSIDE + 4 INTERIOR BASE
    { role: 'stellar_interior', name: 'InteriorBase_South', pos: [0, 0, -38], yaw: 180, district: 'interior' },
    { role: 'stellar_interior', name: 'InteriorBase_North', pos: [0, 0, 42], yaw: 0, district: 'interior' },
    // Cover tiap 5-6m — survival, bukan arena kosong, seperti Level Layout COVER/BARRICADE
    { role: 'stellar_cover', name: 'Cover_A', pos: [12, 0, 8], yaw: 22, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_B', pos: [28, 0, -6], yaw: -14, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_C', pos: [-18, 0, 14], yaw: 42, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_D', pos: [-32, 0, -10], yaw: -28, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_E', pos: [0, 0, 34], yaw: 8, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_F', pos: [0, 0, -24], yaw: -12, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_G', pos: [48, 0, 22], yaw: 68, district: 'cover' },
    { role: 'stellar_cover', name: 'Cover_H', pos: [-48, 0, -22], yaw: -68, district: 'cover' },
    // Enemy spawns — segitiga merah di Level Layout, dekat central dan key locations
    { role: 'enemy_spawn_gate', name: 'EnemyGate_North', pos: [0, 0, 72], yaw: 180, scale: [1.35,1.3,1.2], district: 'spawns' },
    { role: 'enemy_spawn_gate', name: 'EnemyGate_South', pos: [0, 0, -74], yaw: 0, scale: [1.35,1.3,1.2], district: 'spawns' },
    { role: 'enemy_spawn_gate', name: 'EnemyGate_East', pos: [76, 0, 0], yaw: -90, scale: [1.35,1.3,1.2], district: 'spawns' },
    { role: 'enemy_spawn_gate', name: 'EnemyGate_West', pos: [-76, 0, 0], yaw: 90, scale: [1.35,1.3,1.2], district: 'spawns' },
    { role: 'enemy_spawn_gate', name: 'EnemyGate_Center', pos: [18, 0, 18], yaw: 42, scale: [1.1,1.1,1.0], district: 'spawns' },
    // Defense & key locations — kuning di Level Layout
    { role: 'defense_turret', name: 'Turret_N', pos: [14, 0, 44], yaw: -12, district: 'guard' },
    { role: 'defense_turret', name: 'Turret_S', pos: [-12, 0, -44], yaw: 168, district: 'guard' },
    { role: 'defense_turret', name: 'Turret_E', pos: [44, 0, 12], yaw: 82, district: 'guard' },
    { role: 'defense_turret', name: 'Turret_W', pos: [-42, 0, -14], yaw: -82, district: 'guard' },

    // Night variant — foundry, slag, crane (glow di night)
    { role: 'smelter_tower', name: 'Smelter_A', pos: [32, 0, -42], yaw: 0, district: 'dressing' },
    { role: 'crane_gantry', name: 'Crane_A', pos: [-28, 0, 52], yaw: 90, district: 'dressing' },
    { role: 'slag_pool', name: 'Slag_A', pos: [-36, 0, -36], yaw: 0, district: 'dressing' },
  ],

  landmarks: [
    // Central tower is the landmark itself — not a separate powerplant
  ],

  scatter: {
    rock_cluster: [
      [-70, -70, 0.9], [70, -70, 0.9], [-70, 70, 0.9], [70, 70, 0.9], [0, 58, 0.8], [0, -58, 0.8],
    ],
    cover_module: [
      [12, 12, 0.9], [-12, 12, 0.9], [12, -12, 0.9], [-12, -12, 0.9],
    ],
  },

  spawns: [
    { name: 'spawn_emberfall_north', pos: [0, 0.1, 62] },
    { name: 'spawn_emberfall_south', pos: [0, 0.1, -62] },
    { name: 'spawn_emberfall_east', pos: [62, 0.1, 0] },
    { name: 'spawn_emberfall_west', pos: [-62, 0.1, 0] },
    { name: 'spawn_emberfall_tower', pos: [0, 0.1, 8] },
    { name: 'spawn_emberfall_interior', pos: [0, 0.1, -32] },
  ],
};
