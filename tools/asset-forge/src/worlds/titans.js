/**
 * titans.js — WORLD 4 / mission: THE TITANS — 3D station interior.
 *
 * BUKAN 2D. Ini station 3D sempit 64x64 yang sudah diserang alien robot.
 * Semua benda 3D, semua dari GLB real. Zona tidak luas: jarak antar benda 4.5-6m,
 * bukan arena kosong tapi Kantong A→B→C berurutan via Koridor Utama 3m.
 * Luar angkasa hanya di 3 breach, bukan skybox 360.
 *
 * Hidup = kabel putus percikan hybrid (orange human / biru alien), konsol api,
 * dinding sobek/penyok abstract (Blender forced break — patah paksa tidak sempurna).
 * Lantai bolong abstract, bekas tembakan, puing.
 *
 * Data only. `compose.js` builds it; `roles.js` says what each role is made of.
 */
import { THEMES } from './themes.js';

export default {
  id: 'titans',
  name: 'THE TITANS',
  mission: 'titans',
  tagline: 'Masuk station yang baru dibantai — kabel masih percikan, lantai bolong, breach menganga ke luar angkasa.',
  width: 64,
  depth: 64,
  centreZ: 0,
  theme: THEMES.titans,
  scatterDistrict: 'debris_field',

  terrain: {
    floor: { tile: 8 },
    // Deck station interior — bukan ice, tapi metal kusam station
    deck: { width: 24, depth: 24, tile: 6, lift: 0.12 },
    roads: [
      // Koridor Utama 3m — tulang punggung A→B→C, satu-satunya jalur lurus yang masih utuh 40%
      { name: 'MainSpine', from: [0, -24], to: [0, 24] },
      { name: 'WestBranch', from: [-10, 0], to: [-24, 0] },
      { name: 'EastBranch', from: [10, 0], to: [24, 0] },
    ],
    perimeter: {
      spacing: 3.2,
      height: 3.4,
      corner: 'column',
      cornerHeight: 7.2,
      // Station walls — 3 breach celah luar angkasa (bukan tembok penuh)
      gaps: [
        { axis: 'z', at: -32, gap: 9 }, // Hangar door utara jebol — view space A
        { axis: 'z', at: 32, gap: 11 },  // Reactor breach selatan — view space C
        { axis: 'x', at: -32, gap: 7 },  // Lab viewport barat — view space B
      ],
    },
    dressing: { count: 12, centre: [0, 0], radius: 18, squash: 0.85, craterScale: 4, rockScale: 1.6 },
  },

  layout: [
    /* ===================================================== KANTONG A — HANGAR (utara, 10x12m, paling terang) */
    // Hangar door jebol — breach pertama ke luar angkasa
    { role: 'station_breach', name: 'HangarBreach_North', pos: [0, 0, -28], yaw: 0, district: 'hangar' },
    { role: 'wall_torn', name: 'HangarWall_TornA', pos: [-6, 0, -24], yaw: 0, district: 'hangar' },
    { role: 'wall_dented', name: 'HangarWall_DentedA', pos: [6, 0, -24], yaw: 0, district: 'hangar' },
    // Kabel: 1 utuh di atas koridor, 2 putus hybrid di hangar
    { role: 'cable_intact', name: 'HangarCable_Intact', pos: [0, 0, -20], yaw: 0, district: 'hangar' },
    { role: 'cable_spark_orange', name: 'HangarSpark_OrangeA', pos: [-4, 0, -18], yaw: 18, district: 'hangar' },
    { role: 'cable_spark_blue', name: 'HangarSpark_BlueA', pos: [4, 0, -16], yaw: -12, district: 'hangar' },
    { role: 'floor_hole', name: 'HangarHole_Small', pos: [-3, 0, -14], yaw: 22, district: 'hangar' },
    { role: 'console_fire', name: 'HangarConsole_Fire', pos: [5, 0, -12], yaw: -28, district: 'hangar' }, // api orange human
    { role: 'cover_module', name: 'HangarCover_A', pos: [-7, 0, -10], yaw: 42, district: 'hangar' },
    { role: 'wrecked_transport', name: 'HangarRover_Wreck', pos: [7, 0, -8], yaw: 118, district: 'hangar' },

    /* ===================================================== KORIDOR UTAMA (3m, penghubung, masih 40% utuh) */
    { role: 'modular_corridor', name: 'SpineCorridor_North', pos: [0, 0, -8], yaw: 0, district: 'spine' },
    { role: 'cable_intact', name: 'SpineCable_Intact', pos: [0, 0, -4], yaw: 0, district: 'spine' },
    { role: 'modular_corridor', name: 'SpineCorridor_South', pos: [0, 0, 4], yaw: 0, district: 'spine' },
    { role: 'cable_greeble', name: 'SpineGreeble', pos: [0, 0, 8], yaw: 0, district: 'spine' },

    /* ===================================================== KANTONG B — LAB (tengah, 12x12m, paling padat, 50% hancur) */
    { role: 'wall_torn', name: 'LabWall_TornA', pos: [-8, 0, -2], yaw: 90, district: 'lab' },
    { role: 'wall_torn', name: 'LabWall_TornB', pos: [8, 0, -1], yaw: -90, district: 'lab' },
    { role: 'wall_dented', name: 'LabWall_DentedA', pos: [-5, 0, 2], yaw: 18, district: 'lab' },
    // Hybrid percikan: lab dominan biru (alien tech)
    { role: 'cable_spark_blue', name: 'LabSpark_BlueA', pos: [-6, 0, 0], yaw: 0, district: 'lab' },
    { role: 'cable_spark_blue', name: 'LabSpark_BlueB', pos: [6, 0, 1], yaw: 90, district: 'lab' },
    { role: 'cable_spark_orange', name: 'LabSpark_OrangeA', pos: [0, 0, 3], yaw: 45, district: 'lab' },
    { role: 'floor_hole', name: 'LabHole_Large', pos: [0, 0, -2], yaw: 0, district: 'lab' }, // bulat ledakan alien
    { role: 'floor_hole', name: 'LabHole_Small', pos: [3, 0, 5], yaw: 38, district: 'lab' }, // sobek memanjang cakar
    { role: 'console_fire', name: 'LabConsole_BlueFire', pos: [-4, 0, 4], yaw: 62, district: 'lab' }, // api biru alien
    { role: 'station_dressing', name: 'LabDressing', pos: [4, 0, -4], yaw: -22, district: 'lab' },
    { role: 'station_breach', name: 'LabViewport_West', pos: [-24, 0, 0], yaw: 90, district: 'lab' }, // viewport barat, view space kedua

    /* ===================================================== KANTONG C — REAKTOR (selatan, 10x14m, paling hancur, breach besar) */
    { role: 'station_breach', name: 'ReactorBreach_South', pos: [0, 0, 28], yaw: 180, district: 'reactor' }, // breach besar ke luar angkasa, lihat planet
    { role: 'wall_torn', name: 'ReactorWall_TornA', pos: [-7, 0, 20], yaw: 0, district: 'reactor' },
    { role: 'wall_torn', name: 'ReactorWall_TornB', pos: [7, 0, 22], yaw: -18, district: 'reactor' },
    { role: 'wall_dented', name: 'ReactorWall_DentedA', pos: [0, 0, 18], yaw: 42, district: 'reactor' },
    // Hybrid percikan tabrakan orange+biru
    { role: 'cable_spark_orange', name: 'ReactorSpark_OrangeA', pos: [-5, 0, 16], yaw: -22, district: 'reactor' },
    { role: 'cable_spark_blue', name: 'ReactorSpark_BlueC', pos: [5, 0, 17], yaw: 24, district: 'reactor' },
    { role: 'cable_spark_orange', name: 'ReactorSpark_OrangeB', pos: [0, 0, 14], yaw: 90, district: 'reactor' },
    { role: 'floor_hole', name: 'ReactorHole_Huge', pos: [0, 0, 20], yaw: 12, district: 'reactor' }, // lubang besar reaktor bocor
    { role: 'console_fire', name: 'ReactorConsole_Orange', pos: [-6, 0, 12], yaw: 132, district: 'reactor' },
    { role: 'console_fire', name: 'ReactorConsole_Blue', pos: [6, 0, 13], yaw: -58, district: 'reactor' },
    { role: 'cover_module', name: 'ReactorCover_A', pos: [-4, 0, 10], yaw: -38, district: 'reactor' },
    { role: 'defense_turret', name: 'ReactorTurret_Wreck', pos: [8, 0, 10], yaw: 78, district: 'reactor' }, // turret roboh

    /* ===================================================== KANTONG BERTINGKAT — bukti foto refs: tidak flat, tapi pit -2.5m + walkway +3m + launch +4.5m */
    // Pit bawah -1.2 di Lab (foto 1 cekungan melingkar bercahaya — lower floor, bagian bawah)
    { role: 'titans_pit', name: 'LabPit_Lower', pos: [0, -1.2, 0], yaw: 0, district: 'lab' },
    // Walkway ring +2.8 NARROW 2m mengelilingi pit — foto 1 ring bercahaya diameter 70ft, kini sempit biar pit terlihat
    { role: 'titans_walkway', name: 'LabWalkway_North', pos: [0, 2.8, -6], yaw: 0, district: 'lab' },
    { role: 'titans_walkway', name: 'LabWalkway_South', pos: [0, 2.8, 6], yaw: 180, district: 'lab' },
    { role: 'titans_walkway', name: 'LabWalkway_East', pos: [6, 2.8, 0], yaw: 90, district: 'lab' },
    { role: 'titans_walkway', name: 'LabWalkway_West', pos: [-6, 2.8, 0], yaw: -90, district: 'lab' },
    // Tangga menghubungkan pit → walkway dan koridor → walkway — bukti foto 2 tangga kuning
    { role: 'titans_stairs', name: 'LabStairs_North', pos: [0, 0.6, -4], yaw: 0, district: 'lab' },
    { role: 'titans_stairs', name: 'LabStairs_South', pos: [0, 0.6, 4], yaw: 180, district: 'lab' },
    // Launch pad +4.5 di Reactor — foto 2 pedestal peluncuran kuning di atas, dengan ramp
    { role: 'titans_launch', name: 'ReactorLaunch_Pad', pos: [0, 4.5, 24], yaw: 0, district: 'reactor' },
    { role: 'titans_stairs', name: 'ReactorStairs_Up', pos: [0, 2.2, 20], yaw: 0, district: 'reactor' },
  ],

  landmarks: [
    // Reaktor core sebagai landmark垂直 — tapi hancur, bukan utuh
    { id: 'reactor_core', model: 'cooling_tower', scale: 0.22, pos: [0, 0, 24], yaw: 0 },
  ],

  scatter: {
    // Puing kecil tersebar — bekas tembakan, selongsong
    rock_cluster: [
      [-10, -10, 0.6], [10, -10, 0.7], [-9, 6, 0.5], [9, 7, 0.6], [0, -18, 0.65], [0, 14, 0.7],
    ],
    cable_greeble: [
      [ -2, -22, 0.9, 12], [3, -6, 0.8, -18], [-3, 12, 0.85, 42],
    ],
  },

  spawns: [
    { name: 'spawn_titans_hangar', pos: [0, 0.1, -20] }, // start A
    { name: 'spawn_titans_lab', pos: [0, 0.1, 0] },      // start B
    { name: 'spawn_titans_reactor', pos: [0, 0.1, 12] }, // start C
    { name: 'spawn_titans_spine', pos: [0, 0.1, -8] },
  ],
};
