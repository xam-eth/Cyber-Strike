/**
 * terrainReal.js — the ground, also real.
 *
 * The floor is the real photographed stone-tile plate (`ground/tile_floor.glb`,
 * 1920 px baked PBR maps) tiled on a grid, with the kit's own road tiles along
 * the routes. No plane is created by code and no texture is generated: the tiles
 * *are* the floor.
 *
 *   192 × 180 m at 12 m per tile  →  16 × 15 = 240 tiles, one parsed file.
 *
 * Around the playfield the same kit supplies the shell: `structure` frames and
 * `supports` columns mark the boundary, `platform-*` pieces form the arena deck,
 * and the crashed sector gets `crater`/`rocks` scatter.
 */
import * as THREE from 'three';
import { makePart } from './realModels.js';
import { WORLD, SCATTER } from './layout.js';

const TILE = 12;                 // metres per terrain tile
const DECK_TILE = 6.4;           // arena deck plate size
const DEG = Math.PI / 180;

function seeded(index) {
  const x = Math.sin(index * 127.1) * 43758.5453;
  return x - Math.floor(x);
}

/** The floor: real terrain tiles, with the road tiles laid along the routes. */
async function floorTiles() {
  const g = new THREE.Group();
  g.name = 'Ground';
  const cols = Math.ceil(WORLD.width / TILE);
  const rows = Math.ceil(WORLD.depth / TILE);
  const x0 = -((cols - 1) * TILE) / 2;
  const z0 = WORLD.centreZ - ((rows - 1) * TILE) / 2;

  const terrain = await makePart({ model: 'tile_floor', scale: TILE, name: 'GroundTileTemplate' });
  const template = terrain.group;

  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      const i = r * cols + c;
      const tile = template.clone(true);
      tile.name = `GroundTile_${String(i).padStart(3, '0')}`;
      tile.position.set(x0 + c * TILE, 0, z0 + r * TILE);
      // A deterministic quarter-turn per tile hides the repetition of one mesh
      // without introducing randomness that would change between exports.
      tile.rotation.y = Math.floor(seeded(i) * 4) * (Math.PI / 2);
      g.add(tile);
    }
  }
  return g;
}

/** Road plates along the routes in `layout.js`, from the kit's own road tile. */
async function roads() {
  const g = new THREE.Group();
  g.name = 'Routes';
  const road = await makePart({ model: 'terrain-roadstraight', scale: TILE, name: 'RoadTemplate' });
  const template = road.group;

  const legs = [
    { name: 'WestRoute', from: [-40, 0], to: [-18, 0] },
    { name: 'WestRouteNorth', from: [-38, -28], to: [-38, 0] },
    { name: 'EastRoute', from: [19, 1], to: [41, 1] },
    { name: 'NorthRoute', from: [0, -43], to: [0, -19] },
    { name: 'SouthRoute', from: [2, 18], to: [2, 44] },
  ];
  let n = 0;
  for (const leg of legs) {
    const [ax, az] = leg.from;
    const [bx, bz] = leg.to;
    const length = Math.hypot(bx - ax, bz - az);
    const steps = Math.max(1, Math.round(length / TILE));
    const yaw = Math.atan2(bx - ax, bz - az) / DEG;
    for (let i = 0; i < steps; i += 1) {
      const t = (i + 0.5) / steps;
      const tile = template.clone(true);
      tile.name = `${leg.name}_${String(i).padStart(2, '0')}`;
      tile.position.set(ax + (bx - ax) * t, 0.02, az + (bz - az) * t);
      tile.rotation.y = yaw * DEG;
      g.add(tile);
      n += 1;
    }
  }
  g.userData.tiles = n;
  return g;
}

/** Arena deck: platform plates, ringed with supports so it reads as built. */
async function arenaDeck() {
  const g = new THREE.Group();
  g.name = 'ArenaDeck';
  const { width, depth } = WORLD.deck;
  const cols = Math.round(width / DECK_TILE);
  const rows = Math.round(depth / DECK_TILE);
  const plate = await makePart({ model: 'platform-center', scale: DECK_TILE, name: 'DeckTemplate' });
  const template = plate.group;

  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      const tile = template.clone(true);
      tile.name = `DeckPlate_${String(r * cols + c).padStart(2, '0')}`;
      tile.position.set(
        -width / 2 + DECK_TILE / 2 + c * DECK_TILE,
        0.18,
        -depth / 2 + DECK_TILE / 2 + r * DECK_TILE,
      );
      g.add(tile);
    }
  }

  const edge = await makePart({ model: 'platform-long', scale: 6.0, name: 'DeckEdgeTemplate' });
  const perSide = 3;
  for (let i = 0; i < perSide; i += 1) {
    const offset = -width / 2 + 6 + i * 6;
    for (const [x, z, yaw] of [[offset, -depth / 2, 0], [offset, depth / 2, 0]]) {
      const piece = edge.group.clone(true);
      piece.name = `DeckEdgeN_${i}_${z > 0 ? 'S' : 'N'}`;
      piece.position.set(x, 0.18, z);
      piece.rotation.y = yaw;
      g.add(piece);
    }
  }
  return g;
}

/** Boundary: real `structure` frames and `supports` columns around the playfield. */
async function perimeter() {
  const g = new THREE.Group();
  g.name = 'Perimeter';
  const halfW = WORLD.width / 2;
  const halfD = WORLD.depth / 2;
  const frame = await makePart({ model: 'structure', height: 3.4, name: 'FrameTemplate' });
  const mast = await makePart({ model: 'supports-high', height: 6.5, name: 'PylonTemplate' });

  const gateGaps = [
    { axis: 'x', at: 1, gap: 12 },
    { axis: 'z', at: 39, gap: 12 },
    { axis: 'z', at: -59, gap: 12 },
  ];
  const insideGap = (axis, fixed, coord) => gateGaps.some((gg) => {
    if (gg.axis !== axis) return false;
    if (axis === 'x' && Math.sign(fixed) !== Math.sign(gg.at)) return false;
    return Math.abs(coord - gg.at) < gg.gap;
  });

  let i = 0;
  for (let z = -halfD; z <= halfD; z += 3.3) {
    for (const side of [-1, 1]) {
      const fixed = side * halfW;
      if (insideGap('x', fixed, z)) { i += 1; continue; }
      const piece = frame.group.clone(true);
      piece.name = `PerimeterFrameX_${String(i).padStart(2, '0')}`;
      piece.position.set(fixed, 0, WORLD.centreZ + z);
      piece.rotation.y = 90 * DEG;
      g.add(piece);
      i += 1;
    }
  }
  for (let x = -halfW + 3.3; x < halfW; x += 3.3) {
    for (const side of [-1, 1]) {
      const fixed = WORLD.centreZ + side * halfD;
      if (insideGap('z', fixed, x)) { i += 1; continue; }
      const piece = frame.group.clone(true);
      piece.name = `PerimeterFrameZ_${String(i).padStart(2, '0')}`;
      piece.position.set(x, 0, fixed);
      g.add(piece);
      i += 1;
    }
  }

  let p = 0;
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      const pylon = mast.group.clone(true);
      pylon.name = `PerimeterPylon_${p}`;
      pylon.position.set(sx * halfW, 0, WORLD.centreZ + sz * halfD);
      g.add(pylon);
      p += 1;
    }
  }
  return g;
}

/** Crashed sector surface: craters and rock scatter, all real models. */
async function wildsDressing() {
  const g = new THREE.Group();
  g.name = 'WildsDressing';
  const crater = await makePart({ model: 'craterlarge', scale: 9, name: 'CraterTemplate' });
  const scatter = await makePart({ model: 'rocks-smallb', scale: 2.4, name: 'ScatterTemplate' });
  for (let i = 0; i < SCATTER.crystal.length + 4; i += 1) {
    const piece = (i % 3 === 0 ? crater : scatter).group.clone(true);
    piece.name = `WildsDressing_${String(i).padStart(2, '0')}`;
    const a = seeded(i + 40) * Math.PI * 2;
    const r = 14 + seeded(i + 7) * 22;
    piece.position.set(-44 + Math.cos(a) * r, 0.01, 50 + Math.sin(a) * r * 0.6);
    piece.rotation.y = a;
    g.add(piece);
  }
  return g;
}

/**
 * Build every ground layer.
 * @returns {Promise<{ root: THREE.Group, sources: string[] }>}
 */
export async function buildTerrain() {
  const root = new THREE.Group();
  root.name = 'Terrain';
  const layers = [await floorTiles(), await roads(), await arenaDeck(), await perimeter(), await wildsDressing()];
  for (const layer of layers) root.add(layer);

  const sources = [];
  root.traverse((node) => {
    if (node.isMesh && node.userData.realSource) sources.push(node.userData.realSource);
  });
  return { root, sources: [...new Set(sources)] };
}
