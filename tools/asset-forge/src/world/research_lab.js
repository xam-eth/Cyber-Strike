/**
 * research_lab — ceramic lab shell with a glass sampling vessel
 * (`game/scenes/worlds/components/research_lab.tscn`).
 *
 * Reference features: pale ceramic shell with rounded corners, a cut-out bay
 * holding a tall glass vessel around a luminous cyan sample core, two service
 * wings, roof vent stacks, equipment pods on the roof, one maintenance arm.
 */
import { at, box, bevelBox, cyl, cone, sphere, torus, plate, greebles, group, vent, railing } from '../runtime/kit.js';
import { std, beacon, hvac, mast, crate, tank, armourWall } from '../runtime/parts.js';
import { socket, finalize, pulseClip, sweepClip, spinClip } from '../runtime/rig.js';

export const meta = {
  id: 'research_lab',
  category: 'world',
  name: 'Research Laboratory',
  reference: 'references/world/research_lab.png',
  source: 'game/scenes/worlds/components/research_lab.tscn',
  targetHeight: 5.5,
  heightTolerance: 0.9,
  triangleBudget: 60000,
  meshBudget: 600,
  sockets: ['vessel'],
  animations: ['sample'],
};

export function build() {
  const m = std();
  const root = group('ResearchLab');

  /* plinth ------------------------------------------------------------ */
  root.add(at(box(5.6, 0.32, 4.3, m.dark), { y: 0.16 }));
  root.add(at(box(5.2, 0.1, 3.9, m.bright), { y: 0.37 }));

  /* ceramic shell ----------------------------------------------------- */
  const shell = group('Shell');
  // Two-tone instead of all-white: a silver shell with graphite reveals and a
  // ceramic-white crown plate. All-white read as an untextured box in review.
  shell.add(at(bevelBox(4.2, 2.5, 3.2, m.bright, { radius: 0.14, segments: 3 }), { y: 1.67 }));
  shell.add(at(box(4.24, 0.9, 3.24, m.dark), { y: 0.92 }));
  shell.add(at(box(4.22, 0.5, 3.22, m.ink), { y: 2.5 }));
  shell.add(at(bevelBox(4.3, 0.16, 3.3, m.bright, { radius: 0.05 }), { y: 2.95 }));
  // ceramic panel seams
  for (let i = 0; i < 3; i += 1) {
    shell.add(at(box(4.22, 0.035, 3.22, m.mid), { y: 1.0 + i * 0.6 }));
  }
  shell.add(at(box(4.0, 0.1, 3.02, m.gap), { y: 2.4 }));
  root.add(shell);

  /* service wings ----------------------------------------------------- */
  for (const sx of [-1, 1]) {
    const wing = group('Wing');
    wing.add(at(bevelBox(1.0, 1.7, 2.2, m.bright, { radius: 0.05 }), { x: sx * 2.55, y: 1.05 }));
    wing.add(at(box(1.04, 0.09, 2.24, m.dark), { x: sx * 2.55, y: 1.94 }));
    wing.add(at(vent(0.5, 0.5, 4, m.dark, m.cyan), { x: sx * 3.06, y: 1.2, ry: Math.PI / 2 }));
    root.add(wing);
  }

  /* sampling bay: cut-out wall + glass vessel -------------------------- */
  const bay = group('SamplingBay');
  bay.add(at(box(2.1, 2.5, 0.9, m.gap), { y: 1.67, z: 1.6 }));
  bay.add(at(box(2.2, 0.18, 1.0, m.dark), { y: 2.95, z: 1.6 }));
  for (const sx of [-1, 1]) bay.add(at(box(0.16, 2.6, 1.0, m.dark), { x: sx * 1.05, y: 1.65, z: 1.58 }));
  bay.add(at(box(2.3, 0.08, 0.12, m.cyan), { y: 3.0, z: 2.05 }));

  const vessel = group('Vessel');
  vessel.add(at(cyl(0.48, 0.52, 0.16, 16, m.dark), { y: 0.66 }));
  vessel.add(at(cyl(0.38, 0.38, 1.95, 20, m.glass, { open: true }), { y: 1.68 }));
  const sample = group('SampleCore');
  sample.add(at(cyl(0.24, 0.24, 1.76, 14, m.greenDim), { y: 1.68 }));
  sample.add(at(cyl(0.12, 0.12, 1.7, 10, m.cyan), { y: 1.68 }));
  vessel.add(sample);
  for (const y of [1.0, 1.68, 2.36]) {
    vessel.add(at(torus(0.4, 0.03, m.mid, { radial: 5, tubular: 18 }), { y, rx: Math.PI / 2 }));
  }
  vessel.add(at(cyl(0.46, 0.42, 0.16, 16, m.dark), { y: 2.68 }));
  vessel.add(at(sphere(0.12, m.cyan, { heightSegments: 6 }), { y: 2.82 }));
  at(vessel, { z: 1.7 });
  bay.add(vessel);
  root.add(bay);

  /* roof: vents, pods, radome ----------------------------------------- */
  const roof = group('Roof');
  roof.add(at(hvac(m, { w: 1.1, d: 0.8, h: 0.36, seed: 61 }), { x: -1.2, y: 3.05, z: -0.7 }));
  for (let i = 0; i < 3; i += 1) {
    roof.add(at(cyl(0.13, 0.15, 0.8, 10, m.bright), { x: 0.6 + i * 0.34, y: 3.45, z: -1.1 }));
    roof.add(at(cyl(0.15, 0.15, 0.06, 10, m.dark), { y: 3.87 }));
    roof.children[roof.children.length - 1].position.set(0.6 + i * 0.34, 3.87, -1.1);
    roof.add(at(cyl(0.14, 0.14, 0.04, 10, m.cyan), { x: 0.6 + i * 0.34, y: 3.9, z: -1.1 }));
  }
  // equipment pods
  for (const [x, z, r] of [[1.55, -0.55, 0.34], [1.55, 0.35, 0.26]]) {
    const pod = group('Pod');
    pod.add(at(cyl(r, r, 0.56, 12, m.bright), { y: 3.34 }));
    pod.add(at(cyl(r * 1.08, r * 1.08, 0.07, 12, m.dark), { y: 3.6 }));
    pod.add(at(cyl(r * 0.55, r * 0.55, 0.03, 10, m.cyan), { y: 3.64 }));
    at(pod, { x, z });
    roof.add(pod);
  }
  // small radome on the back-left corner
  roof.add(at(sphere(0.4, m.bright, { widthSegments: 16, heightSegments: 8 }), { x: -1.7, y: 3.3, z: 1.0, sy: 0.62 }));
  roof.add(at(cyl(0.42, 0.44, 0.12, 14, m.dark), { x: -1.7, y: 3.06, z: 1.0 }));
  root.add(roof);

  /* maintenance arm --------------------------------------------------- */
  const arm = group('MaintenanceArm');
  arm.add(at(cyl(0.1, 0.12, 0.5, 8, m.dark), { y: 0.25 }));
  const armA = at(box(0.1, 1.5, 0.12, m.mid), { y: 0.86 });
  armA.rotation.z = 0.32;
  arm.add(armA);
  const armB = at(box(0.09, 1.1, 0.1, m.bright), { x: -0.62, y: 1.62 });
  armB.rotation.z = -0.85;
  arm.add(armB);
  arm.add(at(cyl(0.09, 0.09, 0.16, 8, m.cyan), { x: -0.98, y: 1.42 }));
  at(arm, { x: 2.3, y: 0.37, z: 1.3 });
  root.add(arm);

  /* signage plate + beacon -------------------------------------------- */
  root.add(at(armourWall(m, { w: 1.2, h: 1.1, d: 0.16, windows: 1, seed: 63 }), { x: -1.6, y: 0.42, z: 1.62 }));
  root.add(at(beacon(m, { y: 3.02, r: 0.08, name: 'Beacon' }), { x: -2.55, z: 1.7 }));
  root.add(at(box(3.2, 0.06, 0.12, m.cyan), { y: 0.42, z: 1.98 }));
  root.add(at(crate(m, { w: 0.8, h: 0.6, d: 0.6, seed: 64 }), { x: 2.5, y: 0.32, z: 1.8, ry: 0.4 }));

  const vesselSocket = socket(vessel, 'vessel', { y: 1.68 });

  return finalize(root, {
    meta,
    sockets: { vessel: vesselSocket },
    clips: [pulseClip('sample', 'SampleCore', { from: 0.9, to: 1.08, duration: 3.4 })],
  });
}

void plate; void cone; void railing; void mast; void tank; void spinClip; void sweepClip; void greebles;
