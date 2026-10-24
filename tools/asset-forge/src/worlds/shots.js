/**
 * shots.js — the review cameras, one set per world.
 *
 * These are not decoration: `gate/world_shot.mjs` fails if a named shot is
 * missing, so every world has to stay photographable from a wide view and from
 * each of its districts. Positions are world-space metres, matching `layout` in
 * the world modules.
 */
export const SHOTS = {
  frostline: {
    overview: { pos: [142, 84, 128], target: [0, 6, -10] },
    core: { pos: [24, 12, 26], target: [0, 8, 0] },
    station: { pos: [-20, 14, 22], target: [-50, 7, -4] },
    defence: { pos: [34, 22, -26], target: [0, 5, -46] },
    icefield: { pos: [-14, 13, 74], target: [-46, 3, 50] },
  },
  verdant: {
    overview: { pos: [150, 82, 134], target: [0, 6, -6] },
    shrine: { pos: [24, 9, 22], target: [0, 6, 0] },
    station: { pos: [-18, 14, 12], target: [-48, 6, -26] },
    grove: { pos: [20, 18, 84], target: [-24, 5, 24] },
    wreck: { pos: [104, 15, -30], target: [66, 4, -58] },
  },
  emberfall: {
    overview: { pos: [176, 92, 146], target: [24, 8, -10] },
    smelters: { pos: [-14, 16, 26], target: [-50, 8, -8] },
    yard: { pos: [74, 22, 64], target: [32, 6, 12] },
    drill: { pos: [-22, 15, 72], target: [4, 7, 44] },
    // The plant is 24 m tall and 200 m long: this camera has to stand back far
    // enough to photograph it rather than to stand inside it.
    plant: { pos: [30, 58, 96], target: [166, 14, -18] },
  },
};

/** A stable order for the gate's report. */
export const SHOT_ORDER = ['overview', 'core', 'station', 'defence', 'icefield', 'shrine', 'grove', 'wreck', 'smelters', 'yard', 'drill', 'plant'];
