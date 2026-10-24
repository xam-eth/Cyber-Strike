/**
 * exo_neon_phantom — one hero card.
 *
 * The body, the rig hierarchy and the four clips come from `humanoid.js`; this
 * file only chooses a skin. That is the whole point of the skin system: a new
 * character is a palette + prop decision, not a second anatomy.
 */
import { buildHumanoid, heroMeta } from './humanoid.js';
import { finalize } from '../runtime/rig.js';

export const meta = heroMeta(
  'exo_neon_phantom',
  'Exo Operative — Neon Phantom',
  'neon_phantom',
  'references/heroes/exo_neon_phantom.png',
  'IAP_CONCEPT.md#pillar-2--character-identity',
  'Neon Phantom skin theme from IAP_CONCEPT.md: cyan seams on a dark bodysuit, hood and cape.',
);

export function build() {
  const hero = buildHumanoid('neon_phantom', meta);
  return finalize(hero.root, {
    meta,
    sockets: hero.sockets,
    clips: [hero.clips[0], hero.clips[1], hero.clips[2]],
  });
}
