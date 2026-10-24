/**
 * runner — the fast melee alien (`game/scenes/enemies/runner.tscn`).
 *
 * The scene fits its model at 1.72 m with a 180° yaw offset and a 7° run pitch,
 * so this model is authored the same way: upright, facing -Z, 1.72 m tall, with
 * a low forward-leaning stance and long arms — the silhouette a player has to
 * read as "this one closes distance" from across the arena.
 *
 * Four legs would be truer to the name, but the shipped scene drives the same
 * biped locomotion hooks (run pitch, bob, hit flash), so the body stays bipedal
 * and reads as an alien through proportion and material instead.
 */
import { metal, paint, glow } from '../runtime/materials.js';
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, greebles, group, named } from '../runtime/kit.js';
import { socket, finalize, clip } from '../runtime/rig.js';

export const meta = {
  id: 'runner',
  category: 'enemy',
  name: 'Runner',
  reference: 'references/enemies/runner.png',
  source: 'game/scenes/enemies/runner.tscn',
  targetHeight: 1.72,
  heightTolerance: 0.12,
  triangleBudget: 50000,
  meshBudget: 400,
  sockets: ['spine', 'claw_l', 'claw_r'],
  animations: ['idle', 'run', 'hit', 'death'],
};

export function build() {
  // Reference-led retone: near-black hide under graphite chitin. `line` hide
  // over `panel3` shell rendered as one black mass at thumbnail size.
  const hide = paint('panel2', { roughness: 0.82, metalness: 0.1 });
  const shell = metal('lineHi', { roughness: 0.6, metalness: 0.4 });
  const plateMat = paint('ink2', { roughness: 0.55, metalness: 0.2 });
  const glowMat = glow('ok', 1.0, { base: 'ok' });
  const eye = glow('danger', 1.25);
  const claw = paint('ink', { roughness: 0.35, metalness: 0.35 });

  const root = named(group('Runner'), 'Runner');
  const body = group('Body');
  body.position.y = 0.9;

  /* legs: digitigrade, bent back at the hock ------------------------------- */
  const leg = (side) => {
    const g = group(side < 0 ? 'LegL' : 'LegR');
    g.position.set(side * 0.13, 0, 0);
    // Joint-to-joint struts, so a segment can never float free of the one above
    // it: hip → knee → hock → ankle is one continuous digitigrade chain.
    const hip = [0, 0, 0];
    const knee = [side * 0.01, -0.4, 0.06];
    const hock = [side * 0.01, -0.62, -0.16];
    const ankle = [0, -0.82, 0.02];
    g.add(at(sphere(0.07, shell, { widthSegments: 8, heightSegments: 5 }), { x: hip[0], y: hip[1], z: hip[2] }));
    g.add(strut(hip, knee, 0.062, hide, { segments: 8, name: 'Thigh' }));
    g.add(strut([knee[0], knee[1] + 0.004, knee[2]], [hock[0], hock[1], hock[2]], 0.045, hide, { segments: 8, name: 'Shin' }));
    g.add(strut([hock[0], hock[1], hock[2]], [ankle[0], ankle[1], ankle[2]], 0.036, hide, { segments: 8, name: 'Pastern' }));
    g.add(at(sphere(0.055, shell, { widthSegments: 8, heightSegments: 5 }), { x: knee[0], y: knee[1], z: knee[2] }));
    g.add(at(sphere(0.042, shell, { widthSegments: 8, heightSegments: 5 }), { x: hock[0], y: hock[1], z: hock[2] }));
    // shin armour and exposed tendon
    g.add(at(box(0.05, 0.16, 0.03, plateMat), { x: side * 0.035, y: -0.5, z: -0.02, rx: -0.3 }));
    g.add(at(bevelBox(0.1, 0.06, 0.24, shell, { radius: 0.02 }), { y: -0.85, z: 0.06 }));
    for (let i = 0; i < 3; i += 1) {
      g.add(at(cone(0.016, 0.1, 4, claw), { x: (i - 1) * 0.032, y: -0.87, z: 0.17, rx: Math.PI / 2 }));
    }
    return g;
  };
  body.add(leg(-1), leg(1));

  /* core: hunched torso, exposed spine ------------------------------------ *
   * The reference is a coiled animal: the whole spine pitches forward, the
   * shoulder carapace sits above the hips, and a crest of spines runs from the
   * skull down the back into the tail. An upright box read as a robot. */
  const torso = group('Spine');
  torso.position.y = 0.02;
  torso.rotation.x = 0.3; // hunch: shoulders forward of the hips
  // narrow chest: the reference is a coiled, skeletal animal, not a torso slab
  const chest = at(bevelBox(0.27, 0.34, 0.22, hide, { radius: 0.06, segments: 2 }), { y: 0.28, z: 0.02 });
  chest.rotation.x = 0.18;
  torso.add(chest);
  // exposed vertebrae: bigger at the shoulders, tapering into the tail
  for (let i = 0; i < 5; i += 1) {
    const r = 0.028 + Math.sin((i / 4) * Math.PI) * 0.016;
    torso.add(at(sphere(r, plateMat, { widthSegments: 6, heightSegments: 4 }), { y: 0.1 + i * 0.085, z: -0.17 - i * 0.012 }));
    // dorsal crest spike on every second vertebra
    if (i % 2 === 0) {
      const spike = at(cone(0.02, 0.11 + i * 0.012, 4, plateMat), { y: 0.12 + i * 0.085, z: -0.21 - i * 0.012 });
      spike.rotation.x = -0.55;
      torso.add(spike);
    }
  }
  torso.add(at(bevelBox(0.26, 0.16, 0.2, shell, { radius: 0.03 }), { y: 0.44, z: -0.02, rx: 0.2 }));
  // chest slit instead of a glowing disc: a predator should not read as a
  // friendly machine with a status light on its sternum
  torso.add(at(box(0.16, 0.018, 0.02, glowMat), { y: 0.3, z: 0.15 }));
  torso.add(at(box(0.24, 0.03, 0.02, glowMat), { y: 0.22, z: -0.145 }));
  // rib spurs
  for (const sx of [-1, 1]) {
    for (let i = 0; i < 3; i += 1) {
      const spur = at(cone(0.022, 0.12, 4, plateMat), { x: sx * 0.16, y: 0.22 + i * 0.1, z: -0.02 });
      spur.rotation.z = sx * 1.1;
      torso.add(spur);
    }
  }
  /* shoulder carapace: two overlapping shells with outward spines */
  for (const sx of [-1, 1]) {
    const cowl = at(bevelBox(0.16, 0.14, 0.24, shell, { radius: 0.04, segments: 2 }), { x: sx * 0.19, y: 0.45, z: 0.0 });
    cowl.rotation.z = sx * 0.35;
    torso.add(cowl);
    for (let i = 0; i < 3; i += 1) {
      const s2 = at(cone(0.018, 0.1 + i * 0.02, 4, plateMat), { x: sx * (0.23 + i * 0.01), y: 0.5 - i * 0.04, z: -0.06 + i * 0.04 });
      s2.rotation.z = sx * (0.9 + i * 0.15);
      torso.add(s2);
    }
  }

  /* head: a long wedge skull with a swept crest and two forward eyes -------- */
  const head = group('Head');
  head.position.set(0, 0.56, 0.17);
  head.rotation.x = -0.26; // counter the hunch so the eyes stay level
  head.add(at(bevelBox(0.15, 0.14, 0.2, shell, { radius: 0.04, segments: 2 }), { z: 0.02 }));
  // snout: a tapered wedge, not a box, with a down-curved tip
  const snout = at(cyl(0.02, 0.07, 0.3, 5, shell), { y: -0.01, z: 0.2 });
  snout.rotation.x = Math.PI / 2;
  head.add(snout);
  head.add(at(bevelBox(0.1, 0.07, 0.1, hide, { radius: 0.02 }), { y: -0.02, z: 0.16 }));
  // brow ridge and recessed red eyes on the sides of the skull
  head.add(at(box(0.17, 0.024, 0.12, plateMat), { y: 0.06, z: 0.1 }));
  for (const sx of [-1, 1]) {
    head.add(at(bevelBox(0.03, 0.05, 0.09, plateMat, { radius: 0.01 }), { x: sx * 0.07, y: 0.01, z: 0.13 }));
    head.add(at(sphere(0.019, eye, { widthSegments: 8, heightSegments: 5 }), { x: sx * 0.076, y: 0.01, z: 0.15 }));
  }
  // swept crest: spines growing up and back off the skull
  for (let i = 0; i < 4; i += 1) {
    const crest = at(cone(0.016 + i * 0.004, 0.14 + i * 0.03, 4, plateMat), { y: 0.08 + i * 0.005, z: 0.02 - i * 0.075 });
    crest.rotation.x = -0.9 - i * 0.12;
    head.add(crest);
  }
  for (let i = 0; i < 4; i += 1) head.add(at(cone(0.011, 0.055, 4, claw), { x: -0.042 + i * 0.028, y: -0.055, z: 0.24, rx: Math.PI / 2 }));
  torso.add(head);

  /* arms: long, clawed, hanging past the knee ------------------------------ */
  const arm = (side) => {
    const g = group(side < 0 ? 'ArmL' : 'ArmR');
    g.position.set(side * 0.215, 0.42, 0.02);
    g.add(at(sphere(0.06, shell, { widthSegments: 8, heightSegments: 5 })));
    g.add(at(cyl(0.045, 0.035, 0.34, 8, hide, {}), { y: -0.18, z: -0.02 }));
    g.add(at(sphere(0.04, plateMat, { widthSegments: 8, heightSegments: 5 }), { y: -0.36 }));
    g.add(at(cyl(0.035, 0.028, 0.3, 8, hide, {}), { y: -0.52, z: 0.04 }));
    // hand: three hooked claws
    const hand = group(side < 0 ? 'ClawL' : 'ClawR');
    hand.position.set(0, -0.7, 0.06);
    hand.add(at(sphere(0.032, shell, { widthSegments: 8, heightSegments: 5 })));
    for (let i = 0; i < 3; i += 1) {
      const c = at(cone(0.014, 0.16, 4, claw), { x: (i - 1) * 0.03, y: -0.06, z: 0.04 });
      c.rotation.x = Math.PI / 2 + 0.5;
      hand.add(c);
    }
    g.add(hand);
    return g;
  };
  const armL = arm(-1);
  const armR = arm(1);
  torso.add(armL, armR);
  body.add(torso);
  root.add(body);

  /* tail ------------------------------------------------------------------- */
  const tail = group('Tail');
  let prev = [0, 0.78, -0.2];
  for (let i = 0; i < 6; i += 1) {
    const next = [prev[0] + 0.03 + i * 0.02, prev[1] - 0.065 - i * 0.015, prev[2] - 0.15];
    tail.add(strut(prev, next, 0.055 - i * 0.007, hide, { segments: 6 }));
    // dorsal barbs along the tail
    const barb = at(cone(0.014, 0.06, 4, plateMat), { x: prev[0], y: prev[1] + 0.03, z: prev[2] - 0.05 });
    barb.rotation.x = -0.5;
    tail.add(barb);
    prev = next;
  }

  root.add(tail);

  const clips = [
    clip('idle', 2.6, [
      { node: 'Body', property: 'position.y', keys: [[0, 0.9], [1.3, 0.93], [2.6, 0.9]] },
      { node: 'Spine', property: 'rotation.x', keys: [[0, 0], [1.3, 0.04], [2.6, 0]] },
      { node: 'Head', property: 'rotation.y', keys: [[0, -0.12], [1.3, 0.12], [2.6, -0.12]] },
      { node: 'Tail', property: 'rotation.y', keys: [[0, -0.16], [1.3, 0.16], [2.6, -0.16]] },
    ]),
    clip('run', 0.62, [
      { node: 'LegL', property: 'rotation.x', keys: [[0, 0.7], [0.31, -0.55], [0.62, 0.7]] },
      { node: 'LegR', property: 'rotation.x', keys: [[0, -0.55], [0.31, 0.7], [0.62, -0.55]] },
      { node: 'ArmL', property: 'rotation.x', keys: [[0, -0.6], [0.31, 0.5], [0.62, -0.6]] },
      { node: 'ArmR', property: 'rotation.x', keys: [[0, 0.5], [0.31, -0.6], [0.62, 0.5]] },
      { node: 'Body', property: 'position.y', keys: [[0, 0.9], [0.31, 0.96], [0.62, 0.9]] },
      { node: 'Spine', property: 'rotation.x', keys: [[0, 0.16], [0.31, 0.2], [0.62, 0.16]] },
    ]),
    clip('hit', 0.28, [
      { node: 'Spine', property: 'rotation.x', keys: [[0, 0], [0.08, -0.24], [0.28, 0]] },
      { node: 'Head', property: 'rotation.x', keys: [[0, 0], [0.08, 0.3], [0.28, 0]] },
    ]),
    clip('death', 0.7, [
      { node: 'Body', property: 'rotation.x', keys: [[0, 0], [0.7, -1.35]] },
      { node: 'Body', property: 'position.y', keys: [[0, 0.9], [0.7, 0.35]] },
      { node: 'ArmL', property: 'rotation.x', keys: [[0, 0], [0.7, 0.8]] },
      { node: 'ArmR', property: 'rotation.x', keys: [[0, 0], [0.7, 0.7]] },
    ]),
  ];

  const spine = socket(torso, 'spine', { y: 0.34 });
  const clawL = socket(armL, 'claw_l', { y: -0.7, z: 0.06 });
  const clawR = socket(armR, 'claw_r', { y: -0.7, z: 0.06 });

  return finalize(root, { meta, sockets: { spine, claw_l: clawL, claw_r: clawR }, clips });
}

void torus; void greebles; void box;
