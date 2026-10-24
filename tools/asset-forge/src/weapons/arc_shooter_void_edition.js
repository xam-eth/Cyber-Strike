/**
 * arc_shooter_void_edition — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `arc_shooter_void_edition`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'arc_shooter_void_edition',
  'Arc Shooter — Void Edition',
  'references/weapons/arc_shooter_void_edition.png',
  'IAP_CONCEPT.md#pillar-1--weapon-collection',
  'Documented skin in IAP_CONCEPT.md: dark material with energy accents and its own muzzle flash. Same gameplay stats as the Arc Shooter.',
  {
    targetLength: 1.0,
    animations: ['idle', 'fire_recoil', 'reload'],
  },
);

export function build() {
  const weapon = buildWeapon('arc_shooter_void_edition', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
