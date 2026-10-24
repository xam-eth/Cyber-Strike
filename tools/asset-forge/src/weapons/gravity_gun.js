/**
 * gravity_gun — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `gravity_gun`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'gravity_gun',
  'Gravity Gun',
  'references/weapons/gravity_gun.png',
  'IAP_CONCEPT.md#pillar-1--weapon-collection',
  'Documented working name in IAP_CONCEPT.md: pull/manipulation effect with energy distortion.',
  {
    targetLength: 1.0,
    animations: ['idle', 'charge', 'fire_recoil'],
  },
);

export function build() {
  const weapon = buildWeapon('gravity_gun', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
