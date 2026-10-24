/**
 * alien_drone_wreck — insect chassis, luminous sensor core, broken arms
 * (`game/scenes/worlds/components/alien_drone_wreck.tscn`).
 */
import { at, box, bevelBox, cyl, cone, sphere, torus, strut, greebles, group, cable, rng } from '../runtime/kit.js';
import { std } from '../runtime/parts.js';
import { socket, finalize, pulseClip, sweepClip } from '../runtime/rig.js';

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

  /* chassis: tapered carapace, half-rolled onto one side ---------------- */
  const chassis = group('Chassis');
  chassis.rotation.set(0.12, 0.5, 0.22);
  chassis.position.y = 0.62;
  chassis.add(at(bevelBox(1.5, 0.62, 2.3, m.bright, { radius: 0.09 }), {}));
  chassis.add(at(box(1.54, 0.16, 1.2, m.dark), { y: 0.1, z: -0.4 }));
  // ridged spines along the top
  for (let i = 0; i < 5; i += 1) {
    const ridge = at(cone(0.16, 0.4 + 0.1 * Math.sin(i), 4, m.bright), { y: 0.34, z: -0.9 + i * 0.45 });
    ridge.rotation.set(0.3, 0.78, 0);
    chassis.add(ridge);
  }
  chassis.add(at(bevelBox(1.1, 0.4, 0.8, m.dark, { radius: 0.05 }), { y: 0.1, z: 1.15 }));
  chassis.add(at(torus(0.34, 0.05, m.bright, { radial: 5, tubular: 16 }), { y: 0.28, z: 0.55, rx: Math.PI / 2 }));
  // organic under-plate
  chassis.add(at(sphere(0.52, m.mid, { widthSegments: 12, heightSegments: 6 }), { y: -0.2, z: 0.2, sy: 0.5 }));
  chassis.add(greebles({ w: 1.3, h: 0.5, d: 2.1, face: '+x', count: 8, seed: 121, materials: [m.dark, m.bright], centre: [0, 0, 0] }));
  root.add(chassis);

  /* sensor core --------------------------------------------------------- */
  const core = group('SensorCore');
  core.position.set(0.1, 1.0, 0.6);
  core.add(at(cyl(0.22, 0.26, 0.14, 10, m.dark), {}));
  core.add(at(sphere(0.2, m.cyan, { widthSegments: 12, heightSegments: 8 }), { y: 0.16 }));
  core.add(at(torus(0.24, 0.02, m.green, { radial: 4, tubular: 14 }), { y: 0.16, rx: Math.PI / 2 }));
  root.add(core);

  /* broken arms --------------------------------------------------------- */
  const arm = (side) => {
    const g = group(side < 0 ? 'ArmL' : 'ArmR');
    const shoulder = [side * 0.72, 0.68, 0.35];
    g.add(strut(shoulder, [side * 1.15, 0.9, 0.55], 0.07, m.bright, { segments: 6 }));
    g.add(at(sphere(0.1, m.mid, { widthSegments: 8, heightSegments: 5 }), { x: side * 0.72, y: 0.68, z: 0.35 }));
    g.add(at(sphere(0.09, m.dark, { heightSegments: 6 }), { x: side * 1.15, y: 0.9, z: 0.55 }));
    // forearm bends the wrong way because it is broken
    g.add(strut([side * 1.15, 0.9, 0.55], [side * 1.5, 1.05, 0.1], 0.055, m.mid, { segments: 6 }));
    g.add(at(sphere(0.075, m.dark, { heightSegments: 6 }), { x: side * 1.5, y: 1.05, z: 0.1 }));
    // claw plates
    for (let i = 0; i < 3; i += 1) {
      const a = -0.5 + i * 0.5;
      g.add(strut([side * 1.5, 1.05, 0.1], [side * (1.72 + 0.1 * Math.cos(a)), 0.82 + 0.16 * Math.sin(a), -0.16 + i * 0.12], 0.03, m.bright, { segments: 4 }));
    }
    // second arm lolls on the ground
    g.add(strut([side * 0.7, 0.4, -0.3], [side * 1.25, 0.12, -0.75], 0.06, m.mid, { segments: 6 }));
    g.add(at(cone(0.1, 0.34, 5, m.bright), { x: side * 1.35, y: 0.14, z: -0.9, rz: Math.PI / 2 }));
    return g;
  };
  root.add(arm(-1), arm(1));

  /* severed cable + scorch plate --------------------------------------- */
  root.add(cable([0.45, 0.9, -0.6], [1.3, 0.1, -1.5], 0.035, m.gap, { sag: 0.35 }));
  root.add(cable([-0.5, 0.85, 0.9], [-1.1, 0.08, 1.7], 0.03, m.gap, { sag: 0.3 }));
  for (let i = 0; i < 5; i += 1) {
    root.add(at(box(0.24 + rand() * 0.3, 0.05, 0.2 + rand() * 0.3, i % 2 ? m.dark : m.bright), {
      x: (rand() - 0.5) * 3.4, y: 0.03, z: (rand() - 0.5) * 3.4, ry: rand() * 3.14,
    }));
  }

  const sensorSocket = socket(core, 'sensor_core', { y: 0.16 });
  const armL = socket(root, 'arm_l', { x: -0.72, y: 0.68, z: 0.35 });
  const armR = socket(root, 'arm_r', { x: 0.72, y: 0.68, z: 0.35 });

  return finalize(root, {
    meta,
    sockets: { sensor_core: sensorSocket, arm_l: armL, arm_r: armR },
    clips: [pulseClip('sensor_fade', 'SensorCore', { from: 0.45, to: 1.0, duration: 4.2 })],
  });
}

void sweepClip; void box; void bevelBox;
