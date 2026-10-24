/**
 * pulse_rifle — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `pulse_rifle`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'pulse_rifle',
  'Pulse Rifle',
  'references/weapons/pulse_rifle.png',
  'game/resources/weapons/pulse_rifle.tres',
  'Fast, accurate energy bolts for reliable single-target damage. 5.0 shots/s, 24 rounds, 18 damage.',
  {
    targetLength: 1.0,
    animations: ['idle', 'fire_recoil', 'reload'],
  },
);

export function build() {
  const weapon = buildWeapon('pulse_rifle', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
