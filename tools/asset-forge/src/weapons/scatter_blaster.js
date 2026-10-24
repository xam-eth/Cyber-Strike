/**
 * scatter_blaster — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `scatter_blaster`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'scatter_blaster',
  'Scatter Blaster',
  'references/weapons/scatter_blaster.png',
  'IAP_CONCEPT.md#pillar-1--weapon-collection',
  'Documented working name in IAP_CONCEPT.md: spread projectiles with a unique muzzle flash.',
  {
    targetLength: 0.85,
    animations: ['idle', 'fire_recoil', 'reload'],
  },
);

export function build() {
  const weapon = buildWeapon('scatter_blaster', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
