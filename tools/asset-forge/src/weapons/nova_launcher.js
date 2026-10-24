/**
 * nova_launcher — one weapon card.
 *
 * Geometry comes from `weapon.js` (form `nova_launcher`); this file pins the identity
 * fields, the sockets and the animation set for this specific weapon so the
 * catalog, the WEAPON screen numbers and the model cannot disagree.
 */
import { buildWeapon, weaponMeta } from './weapon.js';
import { finalize } from '../runtime/rig.js';

export const meta = weaponMeta(
  'nova_launcher',
  'Nova Launcher',
  'references/weapons/nova_launcher.png',
  'game/resources/weapons/nova_launcher.tres',
  'A slower explosive projectile that damages enemies around its impact point. 0.8 shots/s, 6 rounds.',
  {
    targetLength: 1.05,
    animations: ['idle', 'fire_recoil', 'reload'],
  },
);

export function build() {
  const weapon = buildWeapon('nova_launcher', meta);
  return finalize(weapon.root, {
    meta: { ...meta, sockets: Object.keys(weapon.sockets) },
    sockets: weapon.sockets,
    clips: weapon.clips.filter((c) => meta.animations.includes(c.name)),
  });
}
