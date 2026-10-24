/**
 * humanoid.js — the hero body, built once and re-skinned.
 *
 * This is deliberately *not* a skinned mesh and does not pretend to be one. It
 * is a named hierarchy — Hips → Torso → Head / ArmL / ArmR and Hips → LegL /
 * LegR — animated by object transforms, which is what a three.js
 * `AnimationMixer` drives natively and what survives a GLB export without a
 * skinning pipeline. The limits are stated in docs/3D_ASSET_FORGE.md:
 * shoulders and knees rotate rigidly, so no soft deformation, and the mesh is
 * low-poly on purpose (the game is mobile-first).
 *
 * Proportions are 7.5 heads over 1.8 m, matching the shipped rig height in
 * `game/assets/characters/hero/hero.glb` (measured 1.78 m in
 * HERO_RIG_PIPELINE.md), so a forged hero and the shipped hero can stand in the
 * same lineup without rescaling.
 */
import * as THREE from 'three';
import { metal, paint, glow, glass, hazard } from '../runtime/materials.js';
import { at, box, bevelBox, cyl, cone, sphere, torus, plate, strut, greebles, group, named } from '../runtime/kit.js';
import { socket, clip, pulseClip, sweepClip } from '../runtime/rig.js';

export const HEIGHT = 1.8;

/**
 * Skin definitions. `skin_of` in the catalog binds these to
 * `IAP_CONCEPT.md` §Pillar 2, which is where the five premium character themes
 * are actually documented — none of these names is invented here.
 */
export const SKINS = {
  operative: {
    label: 'Exo Operative',
    plating: 'ink2',
    secondary: 'lineHi',
    under: 'line',
    energy: 'info',
    trim: 'accent',
    backpack: false,
    hood: false,
    cape: false,
    shoulderRig: false,
    pouches: 2,
    antennas: 0,
    monocular: false,
    organic: false,
    glowIntensity: 1.6,
  },
  combat_tech: {
    label: 'Combat Tech',
    plating: 'ink2',
    secondary: 'lineHi',
    under: 'line',
    energy: 'info',
    trim: 'accent',
    backpack: true,
    hood: false,
    cape: false,
    shoulderRig: false,
    pouches: 6,
    antennas: 2,
    monocular: true,
    organic: false,
    glowIntensity: 1.5,
  },
  void_runner: {
    label: 'Void Runner',
    // Dark, but "dark" has to survive a navy backdrop: graphite plating over a
    // near-black bodysuit, not black on black.
    plating: 'line',
    secondary: 'lineHi',
    under: 'panel2',
    energy: 'ability',
    trim: 'ability',
    backpack: false,
    hood: true,
    cape: true,
    shoulderRig: false,
    pouches: 2,
    antennas: 0,
    monocular: false,
    organic: false,
    glowIntensity: 1.35,
  },
  neon_phantom: {
    label: 'Neon Phantom',
    plating: 'ink2',
    secondary: 'line',
    under: 'panel3',
    energy: 'info',
    trim: 'info',
    backpack: false,
    hood: true,
    cape: true,
    shoulderRig: false,
    pouches: 1,
    antennas: 0,
    monocular: false,
    organic: false,
    glowIntensity: 1.7,
  },
  rogue_engineer: {
    label: 'Rogue Engineer',
    plating: 'ink2',
    secondary: 'line',
    under: 'lineHi',
    energy: 'ok',
    trim: 'accent',
    backpack: true,
    hood: false,
    cape: false,
    shoulderRig: true,
    pouches: 4,
    antennas: 1,
    monocular: true,
    organic: false,
    glowIntensity: 1.4,
  },
  trooper: {
    // Not a hero skin: the Shooter enemy's body uses the same hierarchy with a
    // hostile palette, which is why the enemy reads as the same army.
    label: 'Hostile Trooper',
    plating: 'line',
    secondary: 'panel3',
    under: 'panel2',
    energy: 'danger',
    trim: 'danger',
    backpack: true,
    hood: false,
    cape: false,
    shoulderRig: false,
    pouches: 3,
    antennas: 1,
    monocular: true,
    organic: false,
    glowIntensity: 1.6,
  },
  alien_hunter: {
    label: 'Alien Hunter',
    plating: 'line',
    secondary: 'panel2',
    under: 'panel3',
    energy: 'ok',
    trim: 'ok',
    backpack: false,
    hood: false,
    cape: false,
    shoulderRig: true,
    pouches: 2,
    antennas: 0,
    monocular: false,
    organic: true,
    glowIntensity: 1.9,
  },
};

/** Build one hero body for a skin key. Returns { root, sockets, clips }. */
export function buildHumanoid(skinKey, meta) {
  const skin = SKINS[skinKey];
  if (!skin) throw new Error(`unknown hero skin ${skinKey}`);
  const plating = paint(skin.plating, { roughness: 0.46, metalness: 0.3 });
  const secondary = metal(skin.secondary, { roughness: 0.5, metalness: 0.6 });
  const under = paint(skin.under, { roughness: 0.78, metalness: 0.12 });
  const energy = glow(skin.energy, skin.glowIntensity);
  const energyDim = glow(skin.energy, skin.glowIntensity * 0.45);
  const trim = paint(skin.trim, { roughness: 0.55, metalness: 0.06 });
  const visor = glow(skin.trim === 'ok' ? 'ok' : skin.energy, skin.glowIntensity * 0.9);

  const root = named(group('Hero'), 'Hero');
  const body = group('Body');

  /* ---------------------------------------------------------------- legs */
  const leg = (side) => {
    const g = group(side < 0 ? 'LegL' : 'LegR');
    g.position.set(side * 0.105, 0.95, 0);
    // thigh: tapered cylinder reads as anatomy, a box reads as a block
    g.add(at(cyl(0.082, 0.062, 0.46, 10, under, {}), { y: -0.23 }));
    g.add(at(bevelBox(0.15, 0.26, 0.16, plating, { radius: 0.03 }), { y: -0.16, z: 0.005 }));
    g.add(at(box(0.11, 0.1, 0.03, secondary), { y: -0.06, z: 0.075 }));
    // knee
    g.add(at(sphere(0.062, secondary, { widthSegments: 10, heightSegments: 6 }), { y: -0.47 }));
    g.add(at(bevelBox(0.13, 0.1, 0.08, plating, { radius: 0.025 }), { y: -0.47, z: 0.06 }));
    // shin
    g.add(at(cyl(0.062, 0.048, 0.42, 10, under, {}), { y: -0.7 }));
    g.add(at(bevelBox(0.125, 0.34, 0.05, plating, { radius: 0.02 }), { y: -0.7, z: 0.07 }));
    g.add(at(box(0.028, 0.26, 0.02, energyDim), { y: -0.7, z: 0.098 }));
    g.add(at(box(0.11, 0.05, 0.13, secondary), { y: -0.9 }));
    // boot: long sole, raised heel
    g.add(at(bevelBox(0.14, 0.1, 0.3, secondary, { radius: 0.025 }), { y: -0.94, z: 0.05 }));
    g.add(at(box(0.145, 0.03, 0.31, paint('ink3', { roughness: 0.8, metalness: 0.1 })), { y: -0.985, z: 0.05 }));
    g.add(at(box(0.11, 0.05, 0.1, under), { y: -0.92, z: -0.08 }));
    return g;
  };
  const legL = leg(-1);
  const legR = leg(1);
  body.add(legL, legR);

  /* ---------------------------------------------------------------- hips */
  const hips = group('Hips');
  hips.position.y = 0.95;
  hips.add(at(bevelBox(0.3, 0.17, 0.21, secondary, { radius: 0.03 }), { y: 0.03 }));
  hips.add(at(box(0.24, 0.05, 0.22, trim), { y: 0.13 }));
  // belt pouches + hip armour skirts
  for (let i = 0; i < skin.pouches; i += 1) {
    const a = -0.5 + (i / Math.max(1, skin.pouches - 1)) * 1.0;
    hips.add(at(bevelBox(0.075, 0.1, 0.06, under, { radius: 0.015 }), {
      x: Math.sin(a) * 0.17, y: 0.0, z: Math.cos(a) * 0.11 + 0.02,
    }));
  }
  for (const sx of [-1, 1]) {
    const skirt = at(bevelBox(0.1, 0.18, 0.19, plating, { radius: 0.025 }), { x: sx * 0.16, y: -0.06 });
    skirt.rotation.z = sx * 0.12;
    hips.add(skirt);
  }

  /* --------------------------------------------------------------- torso */
  const torso = group('Torso');
  torso.position.y = 0.13;
  // tapered waist, not a stack of boxes
  torso.add(at(cyl(0.125, 0.135, 0.22, 12, under, {}), { y: 0.1 }));
  for (let i = 0; i < 3; i += 1) torso.add(at(box(0.19, 0.028, 0.02, secondary), { y: 0.03 + i * 0.06, z: 0.115 }));
  // chest: bevelled plate angled forward at the top, with a visible core recess
  const chest = group('Chest');
  chest.add(at(bevelBox(0.38, 0.3, 0.23, plating, { radius: 0.05, segments: 2 }), { y: 0.33 }));
  const upper = at(bevelBox(0.34, 0.14, 0.2, secondary, { radius: 0.04 }), { y: 0.47, z: -0.005 });
  upper.rotation.x = -0.12;
  chest.add(upper);
  chest.add(at(box(0.3, 0.13, 0.04, under), { y: 0.31, z: 0.105 }));
  // glowing chest core, recessed in its own housing
  const core = group('ChestCore');
  core.add(at(cyl(0.075, 0.075, 0.025, 14, secondary, { axis: 'z' }), { y: 0.31, z: 0.115 }));
  const coreMesh = at(cyl(0.055, 0.055, 0.02, 14, energy, { axis: 'z' }), { y: 0.31, z: 0.13 });
  core.add(coreMesh);
  core.add(at(torus(0.058, 0.008, secondary, { radial: 4, tubular: 16 }), { y: 0.31, z: 0.135, rx: 0 }));
  chest.add(core);
  // collar ring and shoulder yoke
  chest.add(at(cyl(0.085, 0.1, 0.06, 12, secondary, {}), { y: 0.55 }));
  chest.add(at(box(0.34, 0.05, 0.17, secondary), { y: 0.52 }));
  // chest vents and side ribs
  for (const sx of [-1, 1]) {
    chest.add(at(box(0.03, 0.08, 0.1, under), { x: sx * 0.16, y: 0.36, z: 0.075 }));
    for (let i = 0; i < 3; i += 1) {
      chest.add(at(box(0.02, 0.05, 0.16, secondary), { x: sx * 0.19, y: 0.26 + i * 0.07 }));
    }
  }
  torso.add(chest);

  /* ---------------------------------------------------------------- arms */
  const arm = (side) => {
    const g = group(side < 0 ? 'ArmL' : 'ArmR');
    g.position.set(side * 0.235, 0.45, 0);
    // pauldron: overlaps the yoke, flares outward
    const pauldron = at(bevelBox(0.15, 0.13, 0.19, plating, { radius: 0.04, segments: 2 }), { x: side * 0.03, y: 0.02 });
    pauldron.rotation.z = side * 0.2;
    g.add(pauldron);
    g.add(at(box(0.11, 0.02, 0.16, secondary), { x: side * 0.04, y: 0.085 }));
    // upper arm
    g.add(at(cyl(0.048, 0.042, 0.3, 10, under, {}), { y: -0.19 }));
    g.add(at(bevelBox(0.055, 0.16, 0.06, plating, { radius: 0.015 }), { x: side * 0.035, y: -0.17 }));
    // elbow
    g.add(at(sphere(0.045, secondary, { widthSegments: 8, heightSegments: 5 }), { y: -0.35 }));
    // forearm: wider at the wrist guard
    g.add(at(cyl(0.042, 0.05, 0.26, 10, under, {}), { y: -0.49 }));
    g.add(at(bevelBox(0.075, 0.2, 0.075, plating, { radius: 0.02 }), { y: -0.5 }));
    g.add(at(box(0.018, 0.13, 0.018, energyDim), { x: side * 0.042, y: -0.5 }));
    // hand
    g.add(at(bevelBox(0.07, 0.1, 0.09, secondary, { radius: 0.02 }), { y: -0.68 }));
    g.add(at(box(0.06, 0.03, 0.02, trim), { y: -0.65, z: 0.05 }));
    return g;
  };
  const armL = arm(-1);
  const armR = arm(1);
  torso.add(armL, armR);

  /* ---------------------------------------------------------------- head */
  const head = group('Head');
  head.position.y = 0.62;
  head.add(at(cyl(0.045, 0.055, 0.09, 8, under), { y: -0.04 }));
  // skull shell, narrower at the crown
  head.add(at(bevelBox(0.185, 0.21, 0.21, plating, { radius: 0.055, segments: 2 }), { y: 0.09 }));
  // jaw / rebreather block
  head.add(at(bevelBox(0.15, 0.07, 0.16, secondary, { radius: 0.025 }), { y: -0.01, z: 0.03 }));
  head.add(at(box(0.1, 0.03, 0.02, under), { y: -0.01, z: 0.115 }));
  // visor band set into the face, angled
  const visorBar = at(box(0.165, 0.028, 0.02, visor), { y: 0.1, z: 0.1 });
  visorBar.rotation.x = -0.1;
  head.add(visorBar);
  head.add(at(box(0.19, 0.018, 0.03, secondary), { y: 0.145, z: 0.095 }));
  // cheek guards
  for (const sx of [-1, 1]) head.add(at(box(0.03, 0.12, 0.12, secondary), { x: sx * 0.085, y: 0.055, z: 0.04 }));
  // crest fin
  head.add(at(box(0.026, 0.045, 0.16, secondary), { y: 0.2, z: -0.015 }));
  head.add(at(box(0.11, 0.03, 0.03, secondary), { y: 0.19, z: 0.08 }));
  if (skin.monocular) {
    head.add(at(box(0.045, 0.07, 0.055, under), { x: 0.085, y: 0.12, z: 0.075 }));
    head.add(at(cyl(0.02, 0.02, 0.02, 8, energy, { axis: 'z' }), { x: 0.085, y: 0.12, z: 0.108 }));
  }
  if (skin.hood) {
    const cloth = paint(skin.plating === 'panel3' ? 'panel3' : 'line', { roughness: 0.9, metalness: 0.02 });
    const hood = at(bevelBox(0.27, 0.3, 0.29, cloth, { radius: 0.09, segments: 2 }), { y: 0.09, z: -0.06 });
    hood.rotation.x = 0.12;
    head.add(hood);
    head.add(at(box(0.2, 0.06, 0.2, cloth), { y: 0.235, z: -0.04 }));
    // hood opening, so the visor still reads from the front
    head.add(at(box(0.17, 0.19, 0.06, paint('void', { roughness: 0.95 })), { y: 0.1, z: 0.075 }));
  }
  torso.add(head);

  /* --------------------------------------------------------- skin extras */
  if (skin.backpack) {
    const pack = group('Backpack');
    pack.add(at(bevelBox(0.3, 0.32, 0.16, secondary, { radius: 0.03 }), { y: 0.32, z: -0.19 }));
    pack.add(at(box(0.24, 0.08, 0.04, trim), { y: 0.42, z: -0.27 }));
    for (let i = 0; i < skin.antennas; i += 1) {
      pack.add(at(cyl(0.008, 0.008, 0.34 + i * 0.08, 4, secondary), { x: -0.1 + i * 0.2, y: 0.62 }));
      pack.add(at(sphere(0.018, energy, { widthSegments: 6, heightSegments: 4 }), { x: -0.1 + i * 0.2, y: 0.8 + i * 0.04 }));
    }
    pack.add(at(cyl(0.05, 0.05, 0.16, 8, under, { axis: 'z' }), { x: 0.08, y: 0.24, z: -0.28 }));
    torso.add(pack);
  }
  if (skin.cape) {
    // A cape has to change the outline from the front three-quarter view or it
    // is not worth the triangles: these panels flare outward and hang below the
    // hip line, so the silhouette reads "shrouded" instead of "armoured".
    const cape = group('Cape');
    const cloth = paint(skin.plating === 'panel3' ? 'panel2' : 'line', { roughness: 0.94, metalness: 0.02 });
    for (let i = 0; i < 4; i += 1) {
      const w = 0.16 + i * 0.01;
      const panel = at(box(w, 0.66 - i * 0.05, 0.025, cloth), {
        x: -0.21 + i * 0.14, y: -0.04 + i * 0.02, z: -0.17,
      });
      panel.rotation.set(0.16 + i * 0.02, 0, (i - 1.5) * 0.06);
      cape.add(panel);
    }
    cape.add(at(box(0.5, 0.04, 0.07, secondary), { y: 0.33, z: -0.16 }));
    for (const sx of [-1, 1]) {
      const clasp = at(box(0.06, 0.1, 0.05, secondary), { x: sx * 0.2, y: 0.3, z: -0.13 });
      clasp.rotation.z = sx * 0.3;
      cape.add(clasp);
    }
    torso.add(cape);
  }
  if (skin.shoulderRig) {
    const rigG = group('ShoulderRig');
    rigG.add(at(box(0.1, 0.08, 0.24, secondary), { x: -0.2, y: 0.5, z: -0.02 }));
    rigG.add(at(cyl(0.03, 0.03, 0.2, 6, under, { axis: 'z' }), { x: -0.26, y: 0.44, z: 0.06 }));
    rigG.add(at(box(0.05, 0.12, 0.03, trim), { x: -0.26, y: 0.44, z: 0.17 }));
    torso.add(rigG);
  }
  if (skin.organic) {
    for (const side of [-1, 1]) {
      for (let i = 0; i < 3; i += 1) {
        const spike = at(cone(0.03, 0.12, 4, energyDim), { x: side * (0.2 + i * 0.02), y: 0.42 - i * 0.09, z: -0.04 });
        spike.rotation.z = side * (0.5 + i * 0.2);
        torso.add(spike);
      }
    }
    // carapace plates over the shoulders instead of a blob on the chest
    for (const side of [-1, 1]) {
      for (let i = 0; i < 2; i += 1) {
        const shell = at(cone(0.05, 0.2, 5, energyDim), { x: side * (0.24 + i * 0.03), y: 0.5 - i * 0.08, z: -0.04 });
        shell.rotation.z = side * (0.9 + i * 0.2);
        torso.add(shell);
      }
    }
  }

  hips.add(torso);
  body.add(hips);
  root.add(body);

  /* --------------------------------------------------------------- clips */
  const animationClips = [
    // idle: weight shift + breathing core
    clip('idle', 3.2, [
      { node: 'Body', property: 'position.y', keys: [[0, 0], [1.6, 0.012], [3.2, 0]] },
      { node: 'ArmL', property: 'rotation.z', keys: [[0, 0], [1.6, 0.03], [3.2, 0]] },
      { node: 'ArmR', property: 'rotation.z', keys: [[0, 0], [1.6, -0.03], [3.2, 0]] },
      { node: 'Head', property: 'rotation.y', keys: [[0, -0.05], [1.6, 0.05], [3.2, -0.05]] },
    ]),
    // aim: both arms up, torso squared to the camera, weapon hand forward
    clip('aim', 1.6, [
      { node: 'ArmR', property: 'rotation.x', keys: [[0, -0.02], [0.5, -1.42], [1.6, -1.42]] },
      { node: 'ArmR', property: 'rotation.z', keys: [[0, 0], [0.5, -0.18], [1.6, -0.18]] },
      { node: 'ArmL', property: 'rotation.x', keys: [[0, -0.02], [0.5, -1.2], [1.6, -1.2]] },
      { node: 'ArmL', property: 'rotation.z', keys: [[0, 0], [0.5, 0.34], [1.6, 0.34]] },
      { node: 'Torso', property: 'rotation.y', keys: [[0, 0], [0.5, -0.16], [1.6, -0.16]] },
      { node: 'Head', property: 'rotation.y', keys: [[0, 0], [0.5, 0.12], [1.6, 0.12]] },
    ]),
    // fire: the recoil kick layered on the aim pose
    clip('fire', 0.4, [
      { node: 'ArmR', property: 'rotation.x', keys: [[0, -1.42], [0.06, -1.56], [0.4, -1.42]] },
      { node: 'Torso', property: 'rotation.x', keys: [[0, 0], [0.06, 0.05], [0.4, 0]] },
      { node: 'ChestCore', property: 'scale.x', keys: [[0, 1], [0.08, 1.35], [0.4, 1]] },
    ]),
    // run: alternating limb swing, used by the locomotion blend
    clip('run', 0.7, [
      { node: 'LegL', property: 'rotation.x', keys: [[0, 0.55], [0.35, -0.5], [0.7, 0.55]] },
      { node: 'LegR', property: 'rotation.x', keys: [[0, -0.5], [0.35, 0.55], [0.7, -0.5]] },
      { node: 'ArmL', property: 'rotation.x', keys: [[0, 0.5], [0.35, -0.45], [0.7, 0.5]] },
      { node: 'ArmR', property: 'rotation.x', keys: [[0, -0.45], [0.35, 0.5], [0.7, -0.45]] },
      { node: 'Body', property: 'position.y', keys: [[0, 0], [0.35, 0.03], [0.7, 0]] },
    ]),
  ];

  const handR = socket(armR, 'hand_r', { y: -0.74, z: 0.04 });
  const muzzle = socket(armR, 'muzzle', { y: -0.74, z: 0.42 });
  const chestSocket = socket(core, 'chest_core', { y: 0.31, z: 0.16 });

  return {
    root,
    clips: animationClips,
    sockets: { hand_r: handR, muzzle, chest_core: chestSocket },
    skin,
  };
}

/** Shared meta builder so six hero files cannot drift in fields that matter. */
export function heroMeta(id, name, skinKey, reference, source, role) {
  return {
    id,
    category: 'hero',
    name,
    reference,
    source,
    targetHeight: HEIGHT,
    heightTolerance: 0.1,
    triangleBudget: 60000,
    meshBudget: 400,
    sockets: ['hand_r', 'muzzle', 'chest_core'],
    animations: ['idle', 'aim', 'fire'],
    skin: skinKey,
    role,
  };
}

void THREE; void metal; void glass; void hazard; void plate; void strut; void pulseClip; void sweepClip;
