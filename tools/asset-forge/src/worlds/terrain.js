/**
 * terrain.js — the ground the whole world stands on.
 *
 * Procedural, like every other asset: no heightmap files, no downloaded art.
 * The layout is a direct transcription of `zones/routes.gd` and the ground slabs
 * in `zones/arena.gd` / `zones/wilds.gd`, so the visual world and the playable
 * Godot world are the same place.
 *
 * Everything is grouped so the reviewer can hide a layer:
 *   Ground / Routes / Deck / Perimeter / Markings
 */
import * as THREE from 'three';
import { PALETTE } from '../runtime/palette.js';
import { applyPbr } from '../runtime/textures.js';
import { WORLD, SCATTER } from './layout.js';

const DECK_Y = 0.2;

/** A dedicated material — the shared cache keys on token only, not on tiling. */
function groundMaterial(token, { roughness, metalness, repeat, emissive = 0x000000, emissiveIntensity = 0 }) {
  const m = new THREE.MeshStandardMaterial({
    color: new THREE.Color(PALETTE[token]),
    roughness,
    metalness,
    emissive: new THREE.Color(emissive),
    emissiveIntensity,
  });
  return applyPbr(m, { repeat, emissiveMap: emissiveIntensity > 0 });
}

function slab(w, d, h, material, { x = 0, y = 0, z = 0, ry = 0, name = 'Slab' } = {}) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  mesh.position.set(x, y, z);
  mesh.rotation.y = (ry * Math.PI) / 180;
  mesh.name = name;
  mesh.receiveShadow = true;
  return mesh;
}

/** Roads that connect every district to the arena — coordinates from routes.gd. */
function routes(materials) {
  const g = new THREE.Group();
  g.name = 'Routes';
  const road = materials.road;
  const cyan = materials.routeSignal;
  const amber = materials.routeEdge;

  const legs = [
    // West leg + its north spur (arena → outpost)
    { name: 'WestRouteLeg', w: 22, d: 8, x: -29, z: 0 },
    { name: 'WestRouteNorthLeg', w: 8, d: 28, x: -38, z: -14 },
    // East leg (arena → landing platform / extraction)
    { name: 'EastRouteLeg', w: 22, d: 8, x: 30, z: 1 },
    // North leg + causeway (arena → docking gate)
    { name: 'NorthRouteLeg', w: 8, d: 24, x: 0, z: -31 },
    { name: 'NorthRouteCauseway', w: 10, d: 18, x: 0, z: -51 },
    // South leg (arena → wilds)
    { name: 'SouthRouteLeg', w: 9, d: 26, x: 2, z: 31 },
  ];
  for (const leg of legs) {
    g.add(slab(leg.w, leg.d, 0.08, road, { x: leg.x, y: 0.04, z: leg.z, name: leg.name }));
  }

  const signals = [
    ['WestRouteSignal', 19, 0.3, -29, 0.1, 0],
    ['WestRouteSignalNorth', 0.3, 25, -38, 0.1, -14],
    ['EastRouteSignal', 20, 0.28, 30, 0.1, 1],
    ['NorthRouteSignal', 0.26, 36, 0, 0.1, -42],
    ['SouthRouteSignal', 0.26, 24, 2, 0.1, 31],
  ];
  for (const [name, w, d, x, y, z] of signals) {
    g.add(slab(w, d, 0.06, cyan, { x, y, z, name }));
  }

  // Amber lane edges: the reason the ground reads as a *route* and not a slab.
  const edges = [
    ['WestRouteEdgeYellow', 20, 0.14, -29, -3.75],
    ['WestRouteEdgeYellowSouth', 20, 0.14, -29, 3.75],
    ['EastRouteEdgeNorth', 21, 0.14, 30, -2.75],
    ['EastRouteEdgeSouth', 21, 0.14, 30, 4.75],
  ];
  for (const [name, w, d, x, z] of edges) {
    g.add(slab(w, d, 0.05, amber, { x, y: 0.1, z, name }));
  }
  return g;
}

/** The central combat deck: 38 × 38 m slab with a hazard ring and corner lamps. */
function deck(materials) {
  const g = new THREE.Group();
  g.name = 'ArenaDeck';
  const { width, depth } = WORLD.deck;
  g.add(slab(width, depth, DECK_Y, materials.deck, { y: DECK_Y / 2, name: 'ArenaDeckSlab' }));
  g.add(slab(width - 1.2, depth - 1.2, 0.06, materials.deckInlay, { y: DECK_Y + 0.02, name: 'ArenaDeckInlay' }));

  // Hazard ring around the reactor footing, the visual anchor of the arena.
  const ringGeo = new THREE.TorusGeometry(13.4, 0.16, 8, 96);
  const ring = new THREE.Mesh(ringGeo, materials.hazardRing);
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = DECK_Y + 0.06;
  ring.name = 'ArenaHazardRing';
  g.add(ring);

  // Four corner light pucks: an easy, honest read of the deck's extent at night.
  const puckGeo = new THREE.CylinderGeometry(0.55, 0.7, 0.16, 16);
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      const puck = new THREE.Mesh(puckGeo, materials.deckLamp);
      puck.position.set((sx * width) / 2 - sx * 1.2, DECK_Y + 0.08, (sz * depth) / 2 - sz * 1.2);
      puck.name = `ArenaDeckLamp_${sx > 0 ? 'E' : 'W'}${sz > 0 ? 'S' : 'N'}`;
      g.add(puck);
    }
  }
  return g;
}

/**
 * Dressings: the small stuff that gives a 190 m plate a sense of scale.
 * Pads under each district, cargo boxes by the depot, bollards along the routes
 * and cable ducts crossing the ground. All box/cylinder primitives — the point
 * is rhythm and silhouette, not detail nobody can see from the sky.
 */
function dressings(materials) {
  const g = new THREE.Group();
  g.name = 'Dressing';

  // District pads: a lighter apron with an emissive edge, so each district has
  // a footprint instead of floating on the same ground as everything else.
  const pads = [
    { name: 'OutpostApron', x: -52, z: -3, w: 54, d: 62, yaw: 0 },
    { name: 'ExtractionApron', x: 54, z: -37, w: 34, d: 30, yaw: 0 },
    { name: 'WildsApron', x: -42, z: 52, w: 62, d: 46, yaw: 6 },
  ];
  for (const p of pads) {
    g.add(slab(p.w, p.d, 0.12, materials.apron, { x: p.x, y: 0.06, z: p.z, ry: p.yaw, name: p.name }));
    g.add(slab(p.w - 1.6, 0.16, 0.1, materials.apronEdge, { x: p.x, y: 0.12, z: p.z - p.d / 2 + 0.8, ry: p.yaw, name: `${p.name}EdgeN` }));
    g.add(slab(p.w - 1.6, 0.16, 0.1, materials.apronEdge, { x: p.x, y: 0.12, z: p.z + p.d / 2 - 0.8, ry: p.yaw, name: `${p.name}EdgeS` }));
  }

  // Cargo boxes by the depot, on a seeded lattice so the stack looks used.
  const crateGeo = new THREE.BoxGeometry(1, 1, 1);
  for (let i = 0; i < 14; i += 1) {
    const a = i * 2.4;
    const x = -40 + Math.sin(a) * 5.5;
    const z = 24 + Math.cos(a * 1.3) * 4.5;
    const s = 1.1 + ((i * 37) % 5) * 0.12;
    const m = new THREE.Mesh(crateGeo, i % 3 === 0 ? materials.crateAccent : materials.crate);
    m.position.set(x, s / 2, z);
    m.scale.set(s * 1.5, s, s);
    m.rotation.y = i * 0.37;
    m.name = `CargoCrate_${String(i).padStart(2, '0')}`;
    m.castShadow = true;
    m.receiveShadow = true;
    g.add(m);
  }

  // Bollards mark the route edges; 40 of them make the roads read as roads.
  const bollardGeo = new THREE.CylinderGeometry(0.16, 0.22, 1.05, 8);
  let b = 0;
  const bollards = [
    [-40, -4.6], [-34, -4.6], [-28, -4.6], [-22, -4.6],
    [-40, 4.6], [-34, 4.6], [-28, 4.6], [-22, 4.6],
    [21, -3.6], [27, -3.6], [33, -3.6], [39, -3.6],
    [21, 5.6], [27, 5.6], [33, 5.6], [39, 5.6],
    [-4.8, -22], [-4.8, -28], [-4.8, -34], [4.8, -22], [4.8, -28], [4.8, -34],
  ];
  for (const [x, z] of bollards) {
    const m = new THREE.Mesh(bollardGeo, materials.bollard);
    m.position.set(x, 0.52, z);
    m.name = `RouteBollard_${String(b).padStart(2, '0')}`;
    b += 1;
    g.add(m);
  }

  // Cable ducts: low runs crossing the open ground, tying districts together.
  const ducts = [
    ['West', -30, 0, 46, 0.5, 0.28],
    ['East', 30, 1, 44, 0.5, 0.28],
    ['North', 0, -40, 0.5, 30, 0.26],
    ['South', 2, 30, 0.4, 26, 0.24],
  ];
  for (const [name, x, z, w, d, r] of ducts) {
    const geo = new THREE.BoxGeometry(w, r, d);
    const m = new THREE.Mesh(geo, materials.duct);
    m.position.set(x + 6, r / 2, z + 1);
    m.name = `CableDuct_${name}`;
    g.add(m);
  }

  return g;
}

/** Perimeter: a low wall with emissive cap rail, broken by the four gate openings. */
function perimeter(materials) {
  const g = new THREE.Group();
  g.name = 'Perimeter';
  const halfW = WORLD.width / 2;
  const centreZ = WORLD.centreZ;
  const halfD = WORLD.depth / 2;
  const openings = [
    { x: -83, z: 1, side: 'x' },
    { x: 83, z: 1, side: 'x' },
    { x: 0, z: 39, side: 'z' },
    { x: 0, z: -59, side: 'z' },
  ];
  const GAP = 11; // gate opening width, generous enough for the 1.45× scaled gate
  const wallH = 2.6;

  const buildRun = (axis, fixed, from, to, names) => {
    const mid = (from + to) / 2;
    const len = Math.abs(to - from);
    if (len < 0.5) return;
    const w = axis === 'x' ? len : 0.8;
    const d = axis === 'x' ? 0.8 : len;
    g.add(slab(w, d, wallH, materials.wall, { x: axis === 'x' ? mid : fixed, y: wallH / 2, z: axis === 'x' ? fixed : mid, name: names[0] }));
    g.add(slab(axis === 'x' ? len : 1.0, axis === 'x' ? 1.0 : len, 0.16, materials.wallCap, {
      x: axis === 'x' ? mid : fixed, y: wallH + 0.08, z: axis === 'x' ? fixed : mid, name: names[1],
    }));
  };

  // East and west walls run the full depth, split around each gate.
  for (const side of [-1, 1]) {
    const x = side * halfW;
    const gate = openings.find((o) => o.side === 'x' && Math.sign(o.x) === side);
    buildRun('z', x, centreZ - halfD, gate.z - GAP, [`PerimeterWall_${side > 0 ? 'E' : 'W'}_S`, `PerimeterCap_${side > 0 ? 'E' : 'W'}_S`]);
    buildRun('z', x, gate.z + GAP, centreZ + halfD, [`PerimeterWall_${side > 0 ? 'E' : 'W'}_N`, `PerimeterCap_${side > 0 ? 'E' : 'W'}_N`]);
  }
  // North and south walls, split around their gates.
  for (const side of [-1, 1]) {
    const z = centreZ + side * halfD;
    const gate = openings.find((o) => o.side === 'z' && Math.sign(o.z - centreZ) === side);
    buildRun('x', z, -halfW, gate.x - GAP, [`PerimeterWall_${side > 0 ? 'S' : 'N'}_W`, `PerimeterCap_${side > 0 ? 'S' : 'N'}_W`]);
    buildRun('x', z, gate.x + GAP, halfW, [`PerimeterWall_${side > 0 ? 'S' : 'N'}_E`, `PerimeterCap_${side > 0 ? 'S' : 'N'}_E`]);
  }

  // Corner pylons: mass at the four corners so the boundary does not float.
  const pylon = new THREE.CylinderGeometry(1.1, 1.5, 7.2, 12);
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      const m = new THREE.Mesh(pylon, materials.wall);
      m.position.set(sx * halfW, 3.6, centreZ + sz * halfD);
      m.name = `PerimeterPylon_${sx > 0 ? 'E' : 'W'}${sz > 0 ? 'S' : 'N'}`;
      g.add(m);
    }
  }
  return g;
}

/** Bare rock shelf outside the walls, so the horizon is not a cut edge. */
function shelf(materials) {
  const g = new THREE.Group();
  g.name = 'OuterShelf';
  const geo = new THREE.RingGeometry(WORLD.width / 2, WORLD.width / 2 + 46, 64, 1);
  const mesh = new THREE.Mesh(geo, materials.shelf);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(0, -0.35, WORLD.centreZ);
  mesh.name = 'OuterShelfRing';
  g.add(mesh);
  return g;
}

export function buildTerrain() {
  const materials = {
    // The ground plane: coarse, near-black basalt with faint grain.
    ground: groundMaterial('panel', { roughness: 0.94, metalness: 0.06, repeat: 64 }),
    shelf: groundMaterial('panel2', { roughness: 0.9, metalness: 0.08, repeat: 40 }),
    road: groundMaterial('panel3', { roughness: 0.42, metalness: 0.35, repeat: 14 }),
    deck: groundMaterial('panel3', { roughness: 0.46, metalness: 0.3, repeat: 16 }),
    deckInlay: groundMaterial('line', { roughness: 0.55, metalness: 0.45, repeat: 12 }),
    wall: groundMaterial('panel2', { roughness: 0.68, metalness: 0.3, repeat: 8 }),
    wallCap: groundMaterial('lineHi', { roughness: 0.4, metalness: 0.5, repeat: 6, emissive: PALETTE.info, emissiveIntensity: 0.9 }),
    hazardRing: groundMaterial('accent', { roughness: 0.5, metalness: 0.3, repeat: 6, emissive: PALETTE.accent, emissiveIntensity: 0.55 }),
    deckLamp: groundMaterial('ink2', { roughness: 0.35, metalness: 0.2, repeat: 2, emissive: PALETTE.info, emissiveIntensity: 1.6 }),
    routeSignal: groundMaterial('info', { roughness: 0.36, metalness: 0.25, repeat: 8, emissive: PALETTE.info, emissiveIntensity: 0.85 }),
    routeEdge: groundMaterial('accent', { roughness: 0.6, metalness: 0.2, repeat: 8, emissive: PALETTE.accent, emissiveIntensity: 0.35 }),
    crackedPad: groundMaterial('panel2', { roughness: 0.9, metalness: 0.1, repeat: 18 }),
    apron: groundMaterial('panel3', { roughness: 0.8, metalness: 0.16, repeat: 12 }),
    apronEdge: groundMaterial('lineHi', { roughness: 0.5, metalness: 0.3, repeat: 8, emissive: PALETTE.info, emissiveIntensity: 0.5 }),
    crate: groundMaterial('panel3', { roughness: 0.72, metalness: 0.24, repeat: 2 }),
    crateAccent: groundMaterial('line', { roughness: 0.6, metalness: 0.3, repeat: 2 }),
    bollard: groundMaterial('lineHi', { roughness: 0.55, metalness: 0.4, repeat: 1, emissive: PALETTE.accent, emissiveIntensity: 0.4 }),
    duct: groundMaterial('panel2', { roughness: 0.9, metalness: 0.2, repeat: 10 }),
  };

  const root = new THREE.Group();
  root.name = 'Terrain';

  const ground = new THREE.Mesh(new THREE.PlaneGeometry(320, 300, 64, 60), materials.ground);
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(0, 0, WORLD.centreZ);
  ground.receiveShadow = true;
  ground.name = 'Ground';
  root.add(ground);

  root.add(shelf(materials));
  root.add(dressings(materials));
  root.add(routes(materials));
  root.add(deck(materials));
  root.add(perimeter(materials));

  // The cracked pavement pad under the crashed-sector props (wilds.gd).
  const pad = WORLD.crackedPad;
  root.add(slab(pad.size[0], pad.size[1], 0.22, materials.crackedPad, {
    x: pad.centre[0], y: 0.11, z: pad.centre[1], ry: pad.yaw, name: 'CrackedSectorPavement',
  }));

  // Extraction pipe run, straight from settlement.gd so the district reads as industrial.
  const pipes = new THREE.Group();
  pipes.name = 'ExtractionPipes';
  const pipeGeo = new THREE.CylinderGeometry(0.42, 0.42, 25, 10).rotateZ(Math.PI / 2);
  const glowGeo = new THREE.BoxGeometry(25, 0.1, 0.12);
  for (let i = 0; i < 5; i += 1) {
    const z = -48 + i * 6;
    const p = new THREE.Mesh(pipeGeo, materials.road);
    p.position.set(34, 0.62, z);
    p.name = `ExtractionGroundPipe_${String(i).padStart(2, '0')}`;
    pipes.add(p);
    const glow = new THREE.Mesh(glowGeo, materials.routeSignal);
    glow.position.set(34, 0.9, z);
    glow.name = `ExtractionPipeGlow_${String(i).padStart(2, '0')}`;
    pipes.add(glow);
  }
  root.add(pipes);

  // Silhouette rocks outside the wall — cheap mass that kills the "floating island" look.
  const rocks = new THREE.Group();
  rocks.name = 'OuterRocks';
  const rockGeo = new THREE.IcosahedronGeometry(1, 1);
  for (const [x, z, s] of SCATTER.rocks) {
    const m = new THREE.Mesh(rockGeo, materials.shelf);
    m.position.set(x, 0.2 * s, z);
    m.scale.set(s * 2.6, s * 1.8, s * 2.2);
    m.rotation.set(s * 0.7, x * 0.11, z * 0.07);
    m.name = `OuterRock_${x}_${z}`;
    rocks.add(m);
  }
  root.add(rocks);

  return { root, materials };
}
