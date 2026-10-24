/**
 * exo_rogue_engineer — one hero card.
 *
 * The body, the rig hierarchy and the four clips come from `humanoid.js`; this
 * file only chooses a skin. That is the whole point of the skin system: a new
 * character is a palette + prop decision, not a second anatomy.
 */
import { buildHumanoid, heroMeta } from './humanoid.js';
import { finalize } from '../runtime/rig.js';

export const meta = heroMeta(
  'exo_rogue_engineer',
  'Exo Operative — Rogue Engineer',
  'rogue_engineer',
  'references/heroes/exo_rogue_engineer.png',
  'IAP_CONCEPT.md#pillar-2--character-identity',
  'Rogue Engineer skin theme from IAP_CONCEPT.md: combat technician with a tool harness.',
);

export function build() {
  const hero = buildHumanoid('rogue_engineer', meta);
  return finalize(hero.root, {
    meta,
    sockets: hero.sockets,
    clips: [hero.clips[0], hero.clips[1], hero.clips[2]],
  });
}
