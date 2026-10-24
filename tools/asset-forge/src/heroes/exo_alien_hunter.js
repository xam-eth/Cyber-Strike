/**
 * exo_alien_hunter — one hero card.
 *
 * The body, the rig hierarchy and the four clips come from `humanoid.js`; this
 * file only chooses a skin. That is the whole point of the skin system: a new
 * character is a palette + prop decision, not a second anatomy.
 */
import { buildHumanoid, heroMeta } from './humanoid.js';
import { finalize } from '../runtime/rig.js';

export const meta = heroMeta(
  'exo_alien_hunter',
  'Exo Operative — Alien Hunter',
  'alien_hunter',
  'references/heroes/exo_alien_hunter.png',
  'IAP_CONCEPT.md#pillar-2--character-identity',
  'Alien Hunter skin theme from IAP_CONCEPT.md: armour grown from enemy technology.',
);

export function build() {
  const hero = buildHumanoid('alien_hunter', meta);
  return finalize(hero.root, {
    meta,
    sockets: hero.sockets,
    clips: [hero.clips[0], hero.clips[1], hero.clips[2]],
  });
}
