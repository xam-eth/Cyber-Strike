/**
 * shots.js — STELLAR HORIZON review cameras. ONE WORLD — same layout for all 4 moods.
 *
 * Foto ref: 01 MAIN VIEW (wide), 02 CANYON ROUTE, 02 FACILITY INSIDE, Key Areas 1-4.
 * Semua 4 worlds pakai posisi sama — yang beda hanya atmosphere (day/sunset/night/storm).
 */

export const SHOTS = {
  frostline: {
    overview: { pos: [140, 82, 130], target: [0, 10, 0] }, // 01 MAIN VIEW
    central: { pos: [28, 16, 28], target: [0, 12, 0] }, // 1 CENTRAL TOWER
    canyon: { pos: [46, 14, 62], target: [0, 6, 58] }, // 3 CANYON PATH
    interior: { pos: [14, 8, -32], target: [0, 4, -38] }, // 4 INTERIOR BASE
    platform: { pos: [22, 18, 44], target: [0, 12, 36] }, // 2 UPPER PLATFORM
    night: { pos: [140, 82, 130], target: [0, 10, 0] },
  },
  verdant: {
    overview: { pos: [140, 82, 130], target: [0, 10, 0] },
    central: { pos: [28, 16, 28], target: [0, 12, 0] },
    canyon: { pos: [46, 14, 62], target: [0, 6, 58] },
    interior: { pos: [14, 8, -32], target: [0, 4, -38] },
    platform: { pos: [22, 18, 44], target: [0, 12, 36] },
    night: { pos: [140, 82, 130], target: [0, 10, 0] },
  },
  emberfall: {
    overview: { pos: [140, 82, 130], target: [0, 10, 0] },
    central: { pos: [28, 16, 28], target: [0, 12, 0] },
    canyon: { pos: [46, 14, 62], target: [0, 6, 58] },
    interior: { pos: [14, 8, -32], target: [0, 4, -38] },
    platform: { pos: [22, 18, 44], target: [0, 12, 36] },
    night: { pos: [140, 82, 130], target: [0, 10, 0] },
  },
  titans: {
    overview: { pos: [140, 82, 130], target: [0, 10, 0] },
    central: { pos: [28, 16, 28], target: [0, 12, 0] },
    canyon: { pos: [46, 14, 62], target: [0, 6, 58] },
    interior: { pos: [14, 8, -32], target: [0, 4, -38] },
    platform: { pos: [22, 18, 44], target: [0, 12, 36] },
    night: { pos: [140, 82, 130], target: [0, 10, 0] },
  },
};

export const SHOT_ORDER = ['overview', 'central', 'canyon', 'interior', 'platform'];
