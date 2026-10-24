/**
 * Palette — read from the game, not invented.
 *
 * The values below are copies of `game/scripts/ui/aegis_tokens.gd` (which is
 * itself the contract in docs/ART_DIRECTION.md §1). The 3D kit is locked to the
 * same hexes so a generated prop cannot arrive on the NEON FRONTIER floor with a
 * hue family the HUD has never trained the player to read.
 *
 * `tools/asset-forge/gate/run_gate.mjs` re-reads the `.gd` file and fails if
 * this table and the engine token file ever disagree — the copy is safe only
 * because something checks it.
 */

export const PALETTE = {
  void: '#05080c',
  panel: '#0b131b',
  panel2: '#111c26',
  panel3: '#16232e',
  line: '#27384a',
  lineHi: '#4e6a7e',
  ink: '#edf5fb',
  ink2: '#a9bccb',
  ink3: '#7c94a6',
  accent: '#ffb020',
  ok: '#37e08c',
  info: '#54c8ff',
  danger: '#ff5a5a',
  ability: '#b79cff',
};

/** Families the art direction allows in a shipped surface. */
export const FAMILIES = ['void', 'panel', 'panel2', 'panel3', 'line', 'lineHi', 'ink', 'ink2', 'ink3', 'accent', 'ok', 'info', 'danger', 'ability'];

/** Structural neutrals a renderer may produce from shading; never authored colours. */
export const AUTHORED = ['void', 'panel', 'panel2', 'panel3', 'line', 'lineHi', 'ink', 'ink2', 'ink3', 'accent', 'ok', 'info', 'danger', 'ability'];

function hexToRgb(hex) {
  const n = parseInt(hex.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** Largest per-channel distance (0..255) between a colour and the nearest palette entry. */
export function paletteDistance(hex) {
  const [r, g, b] = hexToRgb(hex);
  let best = { name: null, d: Infinity };
  for (const [name, value] of Object.entries(PALETTE)) {
    const [pr, pg, pb] = hexToRgb(value);
    const d = Math.max(Math.abs(r - pr), Math.abs(g - pg), Math.abs(b - pb));
    if (d < best.d) best = { name, d };
  }
  return best;
}

export function nearestFamily(hex, tolerance = 6) {
  const { name, d } = paletteDistance(hex);
  return d <= tolerance ? name : null;
}

/** Documented roles, so a model cannot pick "whichever cyan looked nice". */
export const ROLE = {
  structure: 'line',
  structureDark: 'panel3',
  structureLight: 'lineHi',
  plating: 'ink2',
  platingBright: 'ink',
  energy: 'info',
  friendly: 'ok',
  warning: 'accent',
  hostile: 'danger',
  ability: 'ability',
  shadow: 'void',
};
