/**
 * alien_drone_wreck — the downed reconnaissance drone
 * (`game/scenes/worlds/components/alien_drone_wreck.tscn`).
 *
 * Built from the reference image, not from a generic "crashed robot": the
 * reference is a **domed hull rolled onto one side**, half-buried in dark soil,
 * with overlapping armour petals peeled open at the crown, a broken segmented
 * ring hoop standing off the back, two ringed emerald sensor ports facing the
 * camera, and exposed ribs and cabling in the gap. The first pass was a grey box
 * on four thin legs — a table, not a wreck — and the reference review rejected
 * it outright.
 */
import * as THREE from 'three';
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, greebles, group, cable, rng } from '../runtime/kit.js';
import { std } from '../runtime/parts.js';
import { socket, finalize, pulseClip } from '../runtime/rig.js';

export const meta = {
  id: 'alien_drone_wreck',
  category: 'world',
  name: 'Alien Drone Wreck',
  reference: 'references/world/alien_drone_wreck.png',
  source: 'game/scenes/worlds/components/alien_drone_wreck.tscn',
  targetHeight: 2.4,
  heightTolerance: 0.45,
  triangleBudget: 40000,
  meshBudget: 400,
  sockets: ['sensor_core', 'arm_l', 'arm_r'],
  animations: ['sensor_fade'],
};

export function build() {
  const m = std();
  const rand = rng(777);
  const root = group('AlienDroneWreck');
  const hull = group('Hull');
  hull.rotation.set(-0.12, 0.42, 0.3); // rolled onto one side, nose up
  root.add(hull);

  /* soil bed: the wreck is buried, not standing on a floor ------------------ */
  const soil = group('Soil');
  soil.add(at(sphere(1.22, m.dark, { widthSegments: 14, heightSegments: 6 }), { y: 0.06, sy: 0.26 }));
  soil.add(at(sphere(0.72, m.dark, { widthSegments: 10, heightSegments: 5 }), { x: -0.7, y: 0.05, z: 0.5, sy: 0.3 }));
  for (let i = 0; i < 7; i += 1) {
    const shard = at(bevelBox(0.3 + rand() * 0.34, 0.06, 0.22 + rand() * 0.26, i % 2 ? m.mid : m.dark, { radius: 0.01 }), {
      x: (rand() - 0.5) * 3.0, y: 0.04, z: (rand() - 0.5) * 2.8, ry: rand() * 3.14,
    });
    shard.rotation.z = (rand() - 0.5) * 0.3;
    soil.add(shard);
  }
  root.add(soil);

  /* domed hull shell -------------------------------------------------------- */
  hull.position.y = 0.62;
  const R = 1.0;
  const SQUASH = 0.78;
  const shell = at(sphere(R, m.mid, { widthSegments: 16, heightSegments: 10 }), { y: 0.16 });
  shell.scale.set(1.0, SQUASH, 1.14);
  hull.add(shell);
  // the dark belly, exposed where the plates have gone
  const belly = at(sphere(R * 0.94, m.dark, { widthSegments: 14, heightSegments: 8 }), { y: 0.1, z: -0.02 });
  belly.scale.set(1.0, SQUASH, 1.1);
  hull.add(belly);

  /* overlapping armour petals, seated ON the dome --------------------------- *
   * The previous version placed them at 0.5 of the radius, i.e. entirely
   * inside the shell, so the render showed a smooth ball. Each plate is now
   * dropped onto the ellipsoid and rotated so its face lies along the surface
   * normal. */
  const normal = new THREE.Vector3();
  const plateW = 0.5;
  const plateH = 0.42;
  for (let i = 0; i < 12; i += 1) {
    const theta = 0.75 + (i % 3) * 0.35;                 // crown band, overlapping
    const phi = (i / 12) * Math.PI * 2 + (i % 2) * 0.26; // around the dome
    normal.set(Math.sin(theta) * Math.cos(phi), Math.cos(theta), Math.sin(theta) * Math.sin(phi)).normalize();
    // scale: sunk into the shell so the plate edges overlap, not hover
    const plateMesh = at(bevelBox(plateW, 0.05, plateH, i % 4 === 0 ? m.bright : m.mid, { radius: 0.012 }), {});
    plateMesh.position.set(
      normal.x * R * 1.0,
      normal.y * R * SQUASH + 0.16,
      normal.z * R * 1.06,
    );
    // the plate's large face is its +Y (thickness is the 0.05 axis), so map
    // +Y onto the surface normal — mapping +Z left every plate standing on edge
    plateMesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), normal);
    hull.add(plateMesh);
    // dark seam just under the plate edge, so the plating reads as layers
    const seam = at(box(plateW * 0.94, 0.02, 0.05, m.dark), {});
    seam.position.copy(plateMesh.position).addScaledVector(normal, -0.03);
    seam.quaternion.copy(plateMesh.quaternion);
    hull.add(seam);
  }

  /* peeled petals at the crown: the reason this reads as a wreck ------------ */
  const peel = group('PeeledPlates');
  for (let i = 0; i < 3; i += 1) {
    const p = at(bevelBox(0.42 - i * 0.07, 0.035, 0.34, m.ink, { radius: 0.01 }), {
      x: -0.24 + i * 0.24, y: 0.86 + i * 0.04, z: -0.18 - i * 0.1,
    });
    p.rotation.set(-0.42 - i * 0.08, 0.28 + i * 0.18, 0.18);
    peel.add(p);
  }
  // torn lip where the petal broke away
  peel.add(at(box(0.5, 0.06, 0.1, m.dark), { x: -0.05, y: 0.9, z: -0.02, rx: -0.4 }));
  hull.add(peel);

  /* sensor ports: two ringed emerald eyes on the exposed face -------------- */
  const port = (name, x, y, z, r) => {
    const g = group(name);
    g.add(at(cyl(r, r * 1.08, 0.12, 12, m.dark, { axis: 'z' }), { x, y, z }));
    g.add(at(cyl(r * 0.92, r * 0.92, 0.04, 12, m.mid, { axis: 'z' }), { x, y, z: z + 0.06 }));
    g.add(at(sphere(r * 0.8, m.greenDim, { widthSegments: 12, heightSegments: 8 }), { x, y, z: z + 0.07 }));
    g.add(at(sphere(r * 0.42, m.green, { widthSegments: 10, heightSegments: 6 }), { x, y, z: z + 0.11 }));
    // retaining ring + 6 bolt lugs, as in the reference
    g.add(at(torus(r * 0.98, 0.02, m.bright, { radial: 4, tubular: 18 }), { x, y, z: z + 0.09 }));
    for (let i = 0; i < 6; i += 1) {
      const a = (i / 6) * Math.PI * 2;
      g.add(at(box(0.035, 0.035, 0.05, m.bright), { x: x + Math.cos(a) * r * 0.82, y: y + Math.sin(a) * r * 0.82, z: z + 0.1 }));
    }
    return g;
  };
  hull.add(port('PortA', 0.36, 0.1, 0.86, 0.26));
  const corePort = port('PortB', -0.2, 0.42, 0.9, 0.3);
  hull.add(corePort);

  /* exposed ribs between hull and ring ------------------------------------- */
  for (let i = 0; i < 4; i += 1) {
    const rib = at(torus(0.5 + i * 0.06, 0.022, m.dark, { radial: 4, tubular: 16 }), {
      x: 0.1 + i * 0.02, y: 0.3, z: -0.35 - i * 0.08, rx: Math.PI / 2,
    });
    rib.scale.set(1, 1, 0.55);
    hull.add(rib);
  }

  /* broken ring hoop: segmented, with a missing arc ------------------------- */
  const hoop = group('RingHoop');
  hoop.position.set(0.55, 0.5, -0.45);
  const RR = 0.92;
  const segs = 18;
  for (let i = 0; i < segs; i += 1) {
    // skip three segments — the break in the ring
    if (i >= 11 && i <= 13) continue;
    const a = (i / segs) * Math.PI * 2;
    const seg = at(bevelBox(0.3, 0.16, 0.16, i % 3 === 0 ? m.mid : m.bright, { radius: 0.02 }), {
      x: Math.cos(a) * RR, y: Math.sin(a) * RR, z: 0,
    });
    seg.rotation.z = a + Math.PI / 2;
    hoop.add(seg);
    if (i === 6) hoop.add(at(box(0.3, 0.05, 0.17, m.warn), { x: Math.cos(a) * RR, y: Math.sin(a) * RR, z: 0.01, rz: a + Math.PI / 2 }));
  }
  hoop.rotation.set(0.1, -0.55, 0.15);
  hull.add(hoop);

  /* torn stubs and cabling ------------------------------------------------- */
  const stub = (side) => {
    const g = group(side < 0 ? 'ArmL' : 'ArmR');
    const base = [side * 0.62, 0.12, 0.2];
    g.add(strut(base, [side * 0.98, -0.06, 0.42], 0.075, m.mid, { segments: 6 }));
    g.add(at(cone(0.09, 0.26, 5, m.bright), { x: side * 1.05, y: -0.1, z: 0.5, rz: Math.PI / 2, ry: side * 0.5 }));
    g.add(strut(base, [side * 0.8, 0.16, -0.1], 0.05, m.dark, { segments: 5 }));
    return g;
  };
  const armL = stub(-1);
  const armR = stub(1);
  hull.add(armL, armR);
  root.add(cable([0.5, 0.5, 0.2], [1.2, 0.06, -0.7], 0.03, m.gap, { sag: 0.28 }));
  root.add(cable([-0.4, 0.55, 0.4], [-1.15, 0.05, 0.9], 0.026, m.gap, { sag: 0.24 }));

  /* vents on the surviving skirt ------------------------------------------- */
  hull.add(greebles({ w: 1.4, h: 0.3, d: 0.4, face: '+z', count: 5, seed: 121, materials: [m.dark, m.mid], centre: [0, 0.0, 0.72] }));

  const sensorSocket = socket(corePort, 'sensor_core', { y: 0.0, z: 0.16 });
  const armLSocket = socket(armL, 'arm_l', { x: -1.05, y: -0.1, z: 0.5 });
  const armRSocket = socket(armR, 'arm_r', { x: 1.05, y: -0.1, z: 0.5 });

  return finalize(root, {
    meta,
    sockets: { sensor_core: sensorSocket, arm_l: armLSocket, arm_r: armRSocket },
    clips: [pulseClip('sensor_fade', 'PortB', { from: 0.45, to: 1.0, duration: 4.2 })],
  });
}

void box; void bevelBox; void cyl; void sphere; void torus; void cone;
