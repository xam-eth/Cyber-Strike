/**
 * weapon.js — one parametric small-arms builder, seven weapons.
 *
 * The game's own weapon system is modular (`WeaponDefinition` + a config per
 * weapon), so the models are modular the same way: a receiver, a grip, a stock,
 * a magazine and a barrel assembly are chosen by the definition in this file.
 * Nothing here re-implements "a gun"; it assembles one from named parts, which
 * is why the Arc Shooter and its Void Edition share geometry and differ only in
 * material — exactly the promise IAP_CONCEPT.md makes for that skin.
 *
 * Barrel length, receiver mass and the muzzle device are what make the seven
 * silhouettes distinguishable at a glance, which is the actual requirement.
 */
import { metal, paint, glow, glass, hazard } from '../runtime/materials.js';
import { at, box, bevelBox, cyl, cone, sphere, torus, plate, strut, greebles, boltRing, group, named, vent, ring } from '../runtime/kit.js';
import { socket, clip, pulseClip } from '../runtime/rig.js';

/** Weapon shape language, one entry per authored weapon. */
export const FORMS = {
  pulse_rifle: {
    label: 'Pulse Rifle',
    receiver: { w: 0.1, h: 0.13, d: 0.5 },
    barrel: { len: 0.42, r: 0.028, shroud: true, vents: 5 },
    muzzle: 'emitter',
    stock: 'solid',
    mag: { type: 'box', drop: 0.2, curve: 0.05 },
    rail: 'long',
    extra: ['charge_cell'],
    energy: 'info',
  },
  nova_launcher: {
    label: 'Nova Launcher',
    receiver: { w: 0.15, h: 0.17, d: 0.44 },
    barrel: { len: 0.34, r: 0.062, shroud: false, vents: 3 },
    muzzle: 'bell',
    stock: 'braced',
    mag: { type: 'drum', drop: 0.16, curve: 0 },
    rail: 'short',
    extra: ['blast_shield'],
    energy: 'accent',
  },
  arc_shooter: {
    label: 'Arc Shooter',
    receiver: { w: 0.11, h: 0.13, d: 0.46 },
    barrel: { len: 0.36, r: 0.024, shroud: false, vents: 0 },
    muzzle: 'prongs',
    stock: 'solid',
    mag: { type: 'cell', drop: 0.22, curve: 0 },
    rail: 'scope',
    extra: ['coil_wrap'],
    energy: 'info',
  },
  arc_shooter_void_edition: {
    label: 'Arc Shooter — Void Edition',
    // Identical geometry to the Arc Shooter; only the materials change.
    sameAs: 'arc_shooter',
    energy: 'ability',
    dark: true,
  },
  scatter_blaster: {
    label: 'Scatter Blaster',
    receiver: { w: 0.14, h: 0.15, d: 0.4 },
    barrel: { len: 0.3, r: 0.05, shroud: false, vents: 0, twins: true },
    muzzle: 'choke',
    stock: 'grip_only',
    mag: { type: 'cell', drop: 0.14, curve: 0 },
    rail: 'short',
    extra: ['shell_rack'],
    energy: 'accent',
  },
  rail_cannon: {
    label: 'Rail Cannon',
    receiver: { w: 0.12, h: 0.15, d: 0.6 },
    barrel: { len: 0.66, r: 0.03, shroud: false, vents: 0, rails: 4 },
    muzzle: 'rails',
    stock: 'solid',
    mag: { type: 'cell', drop: 0.18, curve: 0 },
    rail: 'scope',
    extra: ['coil_wrap', 'charge_cell'],
    energy: 'info',
  },
  gravity_gun: {
    label: 'Gravity Gun',
    receiver: { w: 0.16, h: 0.17, d: 0.42 },
    barrel: { len: 0.26, r: 0.07, shroud: false, vents: 0, rings: 2 },
    muzzle: 'gravity_core',
    stock: 'braced',
    mag: { type: 'cell', drop: 0.2, curve: 0 },
    rail: 'short',
    extra: ['blast_shield'],
    energy: 'ability',
  },
};

function resolved(formKey) {
  const form = FORMS[formKey];
  if (!form) throw new Error(`unknown weapon form ${formKey}`);
  if (!form.sameAs) return { key: formKey, ...form };
  return { key: formKey, ...FORMS[form.sameAs], energy: form.energy, dark: form.dark, label: form.label };
}

/** Build one weapon. `meta.id` selects the form unless `formOverride` is given. */
export function buildWeapon(formKey, meta) {
  const form = resolved(formKey);
  const dark = !!form.dark;
  const structural = dark ? metal('panel3', { roughness: 0.62, metalness: 0.5 }) : metal('line', { roughness: 0.55, metalness: 0.55 });
  const body = dark ? paint('panel2', { roughness: 0.7, metalness: 0.15 }) : paint('ink2', { roughness: 0.45, metalness: 0.25 });
  const accents = dark ? metal('lineHi', { roughness: 0.5, metalness: 0.6 }) : metal('lineHi', { roughness: 0.5, metalness: 0.6 });
  const energy = glow(form.energy, dark ? 2.2 : 1.6);
  const energyDim = glow(form.energy, dark ? 0.9 : 0.6);
  const warn = hazard();
  const rubber = paint('void', { roughness: 0.92, metalness: 0.04 });

  const root = named(group('Weapon'), 'Weapon');
  // Weapon points down -Z (muzzle forward), Y up, origin at the pistol grip.
  const r = form.receiver;

  /* ------------------------------------------------------------- receiver */
  const receiver = group('Receiver');
  receiver.add(at(bevelBox(r.w, r.h, r.d, body, { radius: 0.012 }), { z: 0.02 }));
  receiver.add(at(box(r.w * 1.02, 0.022, r.d * 0.96, structural), { y: r.h / 2 - 0.01, z: 0.02 }));
  receiver.add(at(box(r.w * 0.9, 0.02, r.d * 0.9, structural), { y: -r.h / 2 + 0.01, z: 0.02 }));
  receiver.add(at(box(0.014, r.h * 0.5, r.d * 0.7, energyDim), { x: r.w / 2, z: 0.02 }));
  receiver.add(at(box(0.014, r.h * 0.5, r.d * 0.7, energyDim), { x: -r.w / 2, z: 0.02 }));
  receiver.add(at(box(r.w * 0.5, 0.04, 0.06, structural), { y: r.h / 2 + 0.02, z: 0.02 }));
  // ejection port / status lamp
  receiver.add(at(box(0.05, 0.03, 0.09, rubber), { x: r.w / 2 - 0.005, y: 0.02, z: 0.06 }));
  receiver.add(at(box(0.012, 0.012, 0.03, energy), { x: -r.w / 2 - 0.006, y: 0.03, z: -0.1 }));
  root.add(receiver);

  /* ----------------------------------------------------------------- rail */
  const railY = r.h / 2 + 0.035;
  if (form.rail !== 'none') {
    const railLen = form.rail === 'long' ? r.d * 0.92 : form.rail === 'scope' ? r.d * 0.6 : r.d * 0.45;
    const rail = group('Rail');
    rail.add(at(box(0.03, 0.016, railLen, structural), { y: railY, z: 0.02 }));
    for (let i = 0; i < 7; i += 1) {
      rail.add(at(box(0.038, 0.012, 0.012, structural), { y: railY + 0.012, z: 0.02 - railLen / 2 + (railLen / 7) * (i + 0.5) }));
    }
    root.add(rail);
  }
  if (form.rail === 'scope') {
    const scope = group('Scope');
    scope.add(at(cyl(0.028, 0.028, 0.2, 12, structural, { axis: 'z' }), { y: railY + 0.055, z: 0.0 }));
    scope.add(at(cyl(0.036, 0.03, 0.04, 12, structural, { axis: 'z' }), { y: railY + 0.055, z: -0.11 }));
    scope.add(at(cyl(0.028, 0.028, 0.012, 12, energy, { axis: 'z' }), { y: railY + 0.055, z: -0.135 }));
    for (const z of [-0.06, 0.06]) scope.add(at(box(0.03, 0.035, 0.02, structural), { y: railY + 0.02, z }));
    root.add(scope);
  }

  /* ----------------------------------------------------------------- grip */
  const grip = group('Grip');
  const gripAngle = 0.22;
  const gripMesh = at(bevelBox(0.052, 0.2, 0.085, rubber, { radius: 0.014 }), { y: -0.17, z: 0.1 });
  gripMesh.rotation.x = -gripAngle;
  grip.add(gripMesh);
  grip.add(at(box(0.056, 0.03, 0.09, structural), { y: -0.075, z: 0.115 }));
  grip.add(at(box(0.02, 0.012, 0.02, energyDim), { y: -0.09, z: 0.145 }));
  // trigger guard
  grip.add(at(box(0.02, 0.012, 0.09, structural), { y: -0.1, z: 0.045 }));
  grip.add(at(box(0.02, 0.06, 0.014, structural), { y: -0.075, z: 0.005 }));
  grip.add(at(box(0.012, 0.035, 0.014, structural), { y: -0.075, z: 0.04, rx: 0.2 }));
  root.add(grip);

  /* ------------------------------------------------------------- magazine */
  const mag = group('Magazine');
  const frontGrip = form.stock === 'grip_only';
  const magZ = frontGrip ? 0.16 : 0.16;
  if (form.mag.type === 'drum') {
    mag.add(at(cyl(0.075, 0.075, 0.055, 14, body, { axis: 'x' }), { y: -0.11, z: magZ }));
    mag.add(at(cyl(0.05, 0.05, 0.06, 12, structural, { axis: 'x' }), { y: -0.11, z: magZ }));
    mag.add(at(torus(0.062, 0.008, energy, { radial: 4, tubular: 18 }), { y: -0.11, z: magZ, ry: Math.PI / 2 }));
  } else if (form.mag.type === 'box') {
    const m = at(bevelBox(0.048, form.mag.drop, 0.075, body, { radius: 0.012 }), { y: -0.1 - form.mag.drop / 2, z: magZ });
    m.rotation.x = -0.16;
    mag.add(m);
    mag.add(at(box(0.05, 0.02, 0.078, structural), { y: -0.09 - form.mag.drop, z: magZ + 0.01 }));
    mag.add(at(box(0.008, form.mag.drop * 0.6, 0.02, energyDim), { x: 0.026, y: -0.1 - form.mag.drop / 2, z: magZ }));
  } else {
    // energy cell: a glowing cylinder behind the grip
    mag.add(at(cyl(0.03, 0.03, 0.13, 10, structural, { axis: 'z' }), { y: -0.1, z: magZ }));
    mag.add(at(cyl(0.022, 0.022, 0.1, 10, energyDim, { axis: 'z' }), { y: -0.1, z: magZ }));
    mag.add(at(boltRing({ radius: 0.032, count: 6, size: 0.008, material: structural, axis: 'z' }), { y: -0.1, z: magZ + 0.07 }));
    mag.add(at(cyl(0.034, 0.026, 0.02, 10, structural, { axis: 'z' }), { y: -0.1, z: magZ - 0.075 }));
  }
  root.add(mag);

  /* ---------------------------------------------------------------- stock */
  if (form.stock === 'solid' || form.stock === 'braced') {
    const stock = group('Stock');
    stock.add(at(box(0.05, 0.09, 0.2, body), { y: 0.01, z: 0.34 }));
    stock.add(at(box(0.055, 0.12, 0.03, structural), { y: 0.0, z: 0.44 }));
    stock.add(at(box(0.06, 0.04, 0.06, structural), { y: 0.06, z: 0.4 }));
    if (form.stock === 'braced') {
      stock.add(strut([0.06, -0.02, 0.28], [0.06, -0.12, 0.4], 0.012, structural, { segments: 5 }));
      stock.add(strut([-0.06, -0.02, 0.28], [-0.06, -0.12, 0.4], 0.012, structural, { segments: 5 }));
    }
    root.add(stock);
  }

  /* --------------------------------------------------------------- barrel */
  const barrelZ = -r.d / 2 + 0.02;
  const barrel = group('Barrel');
  const b = form.barrel;
  const twin = !!b.twins;
  const offsets = twin ? [-0.036, 0.036] : [0];
  for (const off of offsets) {
    barrel.add(at(cyl(b.r, b.r, b.len, 12, structural, { axis: 'z' }), { x: off, y: 0.01, z: barrelZ - b.len / 2 }));
    if (b.rails) {
      for (let i = 0; i < b.rails; i += 1) {
        const a = (i / b.rails) * Math.PI * 2;
        barrel.add(at(box(0.008, 0.008, b.len * 0.92, accents), {
          x: off + Math.cos(a) * (b.r + 0.012), y: 0.01 + Math.sin(a) * (b.r + 0.012), z: barrelZ - b.len / 2,
        }));
      }
      for (let i = 0; i < 3; i += 1) {
        barrel.add(at(cyl(b.r + 0.02, b.r + 0.02, 0.016, 12, energyDim, { axis: 'z' }), {
          x: off, y: 0.01, z: barrelZ - 0.12 - i * (b.len * 0.28),
        }));
      }
    }
    if (b.rings) {
      for (let i = 0; i < b.rings; i += 1) {
        barrel.add(at(torus(b.r + 0.018, 0.014, accents, { radial: 4, tubular: 16 }), {
          x: off, y: 0.01, z: barrelZ - b.len * (0.35 + i * 0.4),
        }));
      }
    }
  }
  if (b.shroud) {
    const shroud = group('Shroud');
    shroud.add(at(cyl(b.r + 0.036, b.r + 0.036, b.len * 0.8, 12, body, { axis: 'z' }), { y: 0.01, z: barrelZ - b.len * 0.4 }));
    for (let i = 0; i < b.vents; i += 1) {
      shroud.add(at(box(0.02, 0.016, 0.03, rubber), { x: b.r + 0.038, y: 0.01, z: barrelZ - 0.06 - i * 0.06 }));
      shroud.add(at(box(0.02, 0.016, 0.03, rubber), { x: -(b.r + 0.038), y: 0.01, z: barrelZ - 0.06 - i * 0.06 }));
    }
    barrel.add(shroud);
  }
  barrel.add(at(box(0.06, 0.05, 0.08, structural), { y: 0.01, z: barrelZ + 0.02 }));
  root.add(barrel);

  /* --------------------------------------------------------- muzzle device */
  const muzzleZ = barrelZ - b.len - 0.02;
  const muzzleGroup = group('MuzzleDevice');
  if (form.muzzle === 'emitter') {
    muzzleGroup.add(at(cyl(0.036, 0.03, 0.06, 12, structural, { axis: 'z' }), { y: 0.01, z: muzzleZ + 0.03 }));
    muzzleGroup.add(at(cyl(0.024, 0.024, 0.012, 12, energy, { axis: 'z' }), { y: 0.01, z: muzzleZ }));
  } else if (form.muzzle === 'bell') {
    muzzleGroup.add(at(cyl(0.05, 0.09, 0.1, 14, structural, { axis: 'z' }), { y: 0.01, z: muzzleZ + 0.05 }));
    muzzleGroup.add(at(cyl(0.062, 0.062, 0.012, 14, energy, { axis: 'z' }), { y: 0.01, z: muzzleZ }));
    muzzleGroup.add(at(torus(0.09, 0.01, warn, { radial: 4, tubular: 16 }), { y: 0.01, z: muzzleZ + 0.1 }));
  } else if (form.muzzle === 'prongs') {
    for (const off of [-0.045, 0.045]) {
      const prong = at(cone(0.016, 0.16, 5, accents), { x: off, y: 0.01, z: muzzleZ + 0.07 });
      prong.rotation.x = -Math.PI / 2;
      muzzleGroup.add(prong);
    }
    muzzleGroup.add(at(cyl(0.03, 0.03, 0.05, 10, structural, { axis: 'z' }), { y: 0.01, z: muzzleZ + 0.04 }));
    muzzleGroup.add(at(sphere(0.03, energy, { widthSegments: 10, heightSegments: 6 }), { y: 0.01, z: muzzleZ + 0.02 }));
  } else if (form.muzzle === 'choke') {
    for (const off of offsets) {
      muzzleGroup.add(at(cyl(0.062, 0.052, 0.05, 12, structural, { axis: 'z' }), { x: off, y: 0.01, z: muzzleZ + 0.03 }));
      muzzleGroup.add(at(cyl(0.05, 0.05, 0.008, 12, energy, { axis: 'z' }), { x: off, y: 0.01, z: muzzleZ + 0.006 }));
    }
  } else if (form.muzzle === 'rails') {
    for (const off of [-0.05, 0.05]) {
      muzzleGroup.add(at(box(0.014, 0.05, 0.12, accents), { x: off, y: 0.01, z: muzzleZ + 0.06 }));
    }
    muzzleGroup.add(at(box(0.1, 0.014, 0.12, accents), { y: 0.045, z: muzzleZ + 0.06 }));
    muzzleGroup.add(at(box(0.1, 0.014, 0.12, accents), { y: -0.025, z: muzzleZ + 0.06 }));
    muzzleGroup.add(at(box(0.05, 0.03, 0.01, energy, { }), { y: 0.01, z: muzzleZ + 0.002 }));
  } else if (form.muzzle === 'gravity_core') {
    muzzleGroup.add(at(torus(0.075, 0.016, accents, { radial: 5, tubular: 18 }), { y: 0.01, z: muzzleZ + 0.05 }));
    muzzleGroup.add(at(torus(0.05, 0.01, energy, { radial: 4, tubular: 16 }), { y: 0.01, z: muzzleZ + 0.03 }));
    muzzleGroup.add(at(sphere(0.045, energyDim, { widthSegments: 12, heightSegments: 8 }), { y: 0.01, z: muzzleZ + 0.05 }));
  }
  root.add(muzzleGroup);

  /* ------------------------------------------------------------- extras */
  const extras = group('Extras');
  if (form.extra.includes('charge_cell')) {
    extras.add(at(cyl(0.026, 0.026, 0.12, 10, structural, { axis: 'z' }), { x: 0.075, y: -0.02, z: 0.1 }));
    extras.add(at(cyl(0.018, 0.018, 0.1, 10, energy, { axis: 'z' }), { x: 0.075, y: -0.02, z: 0.1 }));
  }
  if (form.extra.includes('blast_shield')) {
    const shield = at(box(0.16, 0.14, 0.02, structural), { y: 0.04, z: -0.16 });
    shield.rotation.x = 0.18;
    extras.add(shield);
    extras.add(at(box(0.14, 0.03, 0.026, warn), { y: 0.09, z: -0.16, rx: 0.18 }));
  }
  if (form.extra.includes('coil_wrap')) {
    for (let i = 0; i < 5; i += 1) {
      extras.add(at(torus(r.w * 0.62, 0.011, energyDim, { radial: 4, tubular: 14 }), { z: -0.06 - i * 0.055, ry: 0 }));
    }
  }
  if (form.extra.includes('shell_rack')) {
    for (let i = 0; i < 4; i += 1) {
      extras.add(at(cyl(0.012, 0.012, 0.05, 6, warn, { axis: 'z' }), { x: -0.07, y: 0.02, z: 0.06 + i * 0.038 }));
    }
  }
  root.add(extras);

  /* --------------------------------------------------------- fore-grip */
  // Every weapon gets a support-hand position. Rifles get a vertical fore-grip;
  // the grip-only forms get a horizontal pump under the barrel, which is what
  // the Scatter Blaster's silhouette needs anyway.
  const fore = group('ForeGrip');
  if (form.stock !== 'grip_only') {
    const fg = at(bevelBox(0.045, 0.12, 0.06, rubber, { radius: 0.012 }), { y: -0.1, z: -0.14 });
    fg.rotation.x = 0.12;
    fore.add(fg);
    fore.add(at(box(0.05, 0.02, 0.07, structural), { y: -0.04, z: -0.14 }));
  } else {
    fore.add(at(bevelBox(0.07, 0.05, 0.16, rubber, { radius: 0.012 }), { y: -0.05, z: -0.16 }));
    fore.add(at(box(0.075, 0.02, 0.17, structural), { y: -0.02, z: -0.16 }));
  }
  root.add(fore);

  /* --------------------------------------------------------------- clips */
  const animationClips = [
    clip('idle', 2.8, [
      { node: 'Weapon', property: 'position.y', keys: [[0, 0], [1.4, 0.004], [2.8, 0]] },
      { node: 'MuzzleDevice', property: 'scale.x', keys: [[0, 1], [1.4, 1.03], [2.8, 1]] },
    ]),
    clip('fire_recoil', 0.34, [
      { node: 'Weapon', property: 'position.z', keys: [[0, 0], [0.05, 0.055], [0.34, 0]] },
      { node: 'Weapon', property: 'rotation.x', keys: [[0, 0], [0.05, -0.1], [0.34, 0]] },
      { node: 'MuzzleDevice', property: 'scale.z', keys: [[0, 1], [0.05, 1.4], [0.34, 1]] },
    ]),
    clip('reload', 1.4, [
      { node: 'Magazine', property: 'position.y', keys: [[0, 0], [0.3, -0.16], [0.5, -0.16], [0.9, 0]] },
      { node: 'Weapon', property: 'rotation.z', keys: [[0, 0], [0.4, 0.22], [0.9, 0.22], [1.4, 0]] },
    ]),
  ];
  if (formKey === 'rail_cannon' || formKey === 'gravity_gun') {
    animationClips.push(clip('charge', 1.1, [
      { node: 'MuzzleDevice', property: 'scale.x', keys: [[0, 1], [0.9, 1.35], [1.1, 1]] },
      { node: 'MuzzleDevice', property: 'scale.y', keys: [[0, 1], [0.9, 1.35], [1.1, 1]] },
    ]));
  }

  const muzzleSocket = socket(root, 'muzzle', { y: 0.01, z: muzzleZ - 0.02 });
  const gripR = socket(root, 'grip_r', { y: -0.16, z: 0.1 });
  const gripL = socket(root, 'grip_l', { y: -0.1, z: -0.14 });
  const sockets = { muzzle: muzzleSocket, grip_r: gripR, grip_l: gripL };
  if (formKey === 'arc_shooter' || formKey === 'arc_shooter_void_edition') {
    sockets.prong_l = socket(muzzleGroup, 'prong_l', { x: -0.045, y: 0.01, z: muzzleZ + 0.14 });
    sockets.prong_r = socket(muzzleGroup, 'prong_r', { x: 0.045, y: 0.01, z: muzzleZ + 0.14 });
  }
  if (formKey === 'nova_launcher') sockets.drum = socket(mag, 'drum', { y: -0.11, z: 0.16 });
  if (formKey === 'pulse_rifle') sockets.scope = socket(root, 'scope', { y: railY + 0.02, z: 0 });
  if (formKey === 'rail_cannon') sockets.coil = socket(root, 'coil', { y: 0.01, z: barrelZ - 0.2 });
  if (formKey === 'gravity_gun') sockets.core = socket(muzzleGroup, 'core', { y: 0.01, z: muzzleZ + 0.05 });

  return { root, sockets, clips: animationClips, form };
}

/** Meta factory so the seven weapon files stay in lockstep. */
export function weaponMeta(id, name, reference, source, role, extra = {}) {
  return {
    id,
    category: 'weapon',
    name,
    reference,
    source,
    targetHeight: null,
    normaliseBy: 'length',
    origin: 'none',
    heightTolerance: 0.2,
    triangleBudget: 45000,
    meshBudget: 350,
    sockets: ['muzzle', 'grip_r'],
    animations: ['idle', 'fire_recoil', 'reload'],
    role,
    ...extra,
  };
}

void plate; void glass; void greebles; void vent; void ring; void pulseClip;
