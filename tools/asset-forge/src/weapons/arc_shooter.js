/**
 * arc_shooter — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `arc_shooter`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'arc_shooter',
  'Arc Shooter',
  'references/weapons/arc_shooter.png',
  'game/resources/weapons/arc_shooter.tres',
  'A focused energy beam that chains to 2 nearby targets in a 5 m radius.',
  {
    targetLength: 1.0,
    animations: ['idle', 'fire_recoil', 'reload'],
  },
);

export function build() {
  const weapon = buildWeapon('arc_shooter', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
