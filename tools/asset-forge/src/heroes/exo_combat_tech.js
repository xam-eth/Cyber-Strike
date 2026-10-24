/**
 * exo_combat_tech — one hero card.
 *
 * The body, the rig hierarchy and the four clips come from `humanoid.js`; this
 * file only chooses a skin. That is the whole point of the skin system: a new
 * character is a palette + prop decision, not a second anatomy.
 */
import { buildHumanoid, heroMeta } from './humanoid.js';
import { finalize } from '../runtime/rig.js';

export const meta = heroMeta(
  'exo_combat_tech',
  'Exo Operative — Combat Tech',
  'combat_tech',
  'references/heroes/exo_combat_tech.png',
  'IAP_CONCEPT.md#pillar-2--character-identity',
  'Combat Tech skin theme from IAP_CONCEPT.md: modern tech soldier with a comms pack and pouches.',
);

export function build() {
  const hero = buildHumanoid('combat_tech', meta);
  return finalize(hero.root, {
    meta,
    sockets: hero.sockets,
    clips: [hero.clips[0], hero.clips[1], hero.clips[2]],
  });
}
