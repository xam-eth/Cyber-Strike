/**
 * exo_operative — one hero card.
 *
 * The body, the rig hierarchy and the four clips come from `humanoid.js`; this
 * file only chooses a skin. That is the whole point of the skin system: a new
 * character is a palette + prop decision, not a second anatomy.
 */
import { buildHumanoid, heroMeta } from './humanoid.js';
import { finalize } from '../runtime/rig.js';

export const meta = heroMeta(
  'exo_operative',
  'Exo Operative (default)',
  'operative',
  'references/heroes/exo_operative.png',
  'game/resources/heroes/exo_operative.tres',
  'Field-ready AEGIS operative: silver plating, cyan chest core, amber visor trim.',
);

export function build() {
  const hero = buildHumanoid('operative', meta);
  return finalize(hero.root, {
    meta,
    sockets: hero.sockets,
    clips: [hero.clips[0], hero.clips[1], hero.clips[2]],
  });
}
