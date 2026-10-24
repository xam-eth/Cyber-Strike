/**
 * shooter — the ranged humanoid trooper (`game/scenes/enemies/shooter.tscn`).
 *
 * Built from the same hierarchy as the hero (`humanoid.js`) with the hostile
 * `trooper` skin, which is deliberate: the enemy is the same army the player is
 * not, and reusing the anatomy keeps the two silhouettes comparable at range.
 * The scene fits it at 1.62 m — slightly shorter than the 1.8 m hero, so the
 * player can tell themselves apart from their target without looking at colour.
 */
import { buildHumanoid } from '../heroes/humanoid.js';
import { finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'shooter',
  category: 'enemy',
  name: 'Shooter',
  reference: 'references/enemies/shooter.png',
  source: 'game/scenes/enemies/shooter.tscn',
  targetHeight: 1.62,
  heightTolerance: 0.12,
  triangleBudget: 50000,
  meshBudget: 400,
  sockets: ['hand_r', 'chest'],
  animations: ['idle', 'run', 'aim', 'death'],
  origin: 'ground',
};

export function build() {
  const enemy = buildHumanoid('trooper', { ...meta, targetHeight: 1.62 });
  const root = enemy.root;
  root.name = 'Shooter';

  const clips = [
    ...enemy.clips,
    // death is the one motion the hero rig does not carry
    clip('death', 0.8, [
      { node: 'Body', property: 'rotation.x', keys: [[0, 0], [0.8, -1.4]] },
      { node: 'Body', property: 'position.y', keys: [[0, 0], [0.8, 0.42]] },
      { node: 'ArmL', property: 'rotation.z', keys: [[0, 0], [0.8, 0.9]] },
      { node: 'ArmR', property: 'rotation.z', keys: [[0, 0], [0.8, -0.9]] },
    ]),
  ];

  return finalize(root, {
    meta,
    sockets: { hand_r: enemy.sockets.hand_r, chest: enemy.sockets.chest_core },
    clips: clips.filter((c) => meta.animations.includes(c.name)),
  });
}
