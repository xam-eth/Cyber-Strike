/**
 * rail_cannon — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `rail_cannon`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'rail_cannon',
  'Rail Cannon',
  'references/weapons/rail_cannon.png',
  'IAP_CONCEPT.md#pillar-1--weapon-collection',
  'Documented working name in IAP_CONCEPT.md: precision shot with a charge effect.',
  {
    targetLength: 1.25,
    animations: ['idle', 'charge', 'fire_recoil'],
  },
);

export function build() {
  const weapon = buildWeapon('rail_cannon', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
