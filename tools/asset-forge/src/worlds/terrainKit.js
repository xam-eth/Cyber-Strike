/**
 * terrainKit.js — the ground, built from real files, for any world.
 *
 * Every layer here is made of licensed GLBs: the photographed stone plate for
 * the floor, the kit's road tiles for routes, `platform-*` plates for decks,
 * `structure` frames for fences and `crater`/`rock` pieces for dressing. The
 * module creates no plane and no texture — a world varies the *configuration*
 * (tile size, material choice, spacing, density) and the theme varies the light.
 *
 *   const terrain = await buildTerrainLayer({
 *     floor: { tile: 12 },
 *     deck: { width: 34, depth: 34 },
 *     roads: [{ from: [-40, 0], to: [-18, 0] }],
 *     perimeter: { spacing: 3.4, gaps: [...] },
 *     dressing: { count: 18, centre: [-44, 50], radius: 22 },
 *   });
 */
import * as THREE from 'three';
import { makePart } from './realModels.js';

const DEG = Math.PI / 180;

/** Deterministic hash: the same index always produces the same jitter. */
export function seeded(index, salt = 0) {
  const x = Math.sin(index * 127.1 + salt * 31.7) * 43758.5453;
  return x - Math.floor(x);
}

async function floorTiles(world, opts) {
  const group = new THREE.Group();
  group.name = 'Ground';
  const tile = opts.tile ?? 12;
  const cols = Math.ceil(world.width / tile);
  const rows = Math.ceil(world.depth / tile);
  const x0 = -((cols - 1) * tile) / 2;
  const z0 = world.centreZ - ((rows - 1) * tile) / 2;

  const source = await makePart({ model: opts.model ?? 'tile_floor', scale: tile, name: 'GroundTileTemplate' });
  const template = source.group;

  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      const i = r * cols + c;
      const piece = template.clone(true);
      piece.name = `GroundTile_${String(i).padStart(3, '0')}`;
      piece.position.set(x0 + c * tile, 0, z0 + r * tile);
      // A quarter turn per tile hides the repetition of one mesh without adding
      // randomness that would differ between two builds of the same commit.
      piece.rotation.y = Math.floor(seeded(i) * 4) * (Math.PI / 2);
      group.add(piece);
    }
  }
  return group;
}

async function roads(world, legs, tile, model = 'terrain-roadstraight') {
  const group = new THREE.Group();
  group.name = 'Routes';
  if (!legs?.length) return group;
  const source = await makePart({ model, scale: tile, name: 'RoadTemplate' });
  const template = source.group;
  let count = 0;
  for (const leg of legs) {
    const [ax, az] = leg.from;
    const [bx, bz] = leg.to;
    const length = Math.hypot(bx - ax, bz - az);
    const steps = Math.max(1, Math.round(length / tile));
    const yaw = Math.atan2(bx - ax, bz - az);
    for (let i = 0; i < steps; i += 1) {
      const t = (i + 0.5) / steps;
      const piece = template.clone(true);
      piece.name = `${leg.name}_${String(i).padStart(2, '0')}`;
      piece.position.set(ax + (bx - ax) * t, 0.02, az + (bz - az) * t);
      piece.rotation.y = yaw;
      group.add(piece);
      count += 1;
    }
  }
  group.userData.tiles = count;
  return group;
}

async function deck(world, opts) {
  const group = new THREE.Group();
  group.name = 'ArenaDeck';
  if (!opts) return group;
  const plateSize = opts.tile ?? 6.4;
  const { width, depth } = opts;
  const cols = Math.round(width / plateSize);
  const rows = Math.round(depth / plateSize);
  const plate = await makePart({ model: opts.model ?? 'platform-center', scale: plateSize, name: 'DeckTemplate' });

  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      const piece = plate.group.clone(true);
      piece.name = `DeckPlate_${String(r * cols + c).padStart(2, '0')}`;
      piece.position.set(
        -width / 2 + plateSize / 2 + c * plateSize,
        opts.lift ?? 0.18,
        -depth / 2 + plateSize / 2 + r * plateSize,
      );
      group.add(piece);
    }
  }

  if (opts.edge !== false) {
    const edge = await makePart({ model: 'platform-long', scale: 6.0, name: 'DeckEdgeTemplate' });
    const perSide = Math.floor(width / 6);
    for (let i = 0; i < perSide; i += 1) {
      const offset = -width / 2 + 3 + i * 6;
      for (const [x, z] of [[offset, -depth / 2], [offset, depth / 2]]) {
        const piece = edge.group.clone(true);
        piece.name = `DeckEdge_${i}_${z > 0 ? 'S' : 'N'}`;
        piece.position.set(x, opts.lift ?? 0.18, z);
        group.add(piece);
      }
    }
  }
  return group;
}

async function perimeter(world, opts) {
  const group = new THREE.Group();
  group.name = 'Perimeter';
  if (!opts) return group;
  const halfW = world.width / 2;
  const halfD = world.depth / 2;
  const spacing = opts.spacing ?? 3.6;
  const frame = await makePart({ model: opts.frame ?? 'structure', height: opts.height ?? 3.4, name: 'FrameTemplate' });
  const gaps = opts.gaps ?? [];

  const inGap = (axis, fixed, coord) => gaps.some((gap) => {
    if (gap.axis !== axis) return false;
    if (gap.side && Math.sign(fixed) !== gap.side) return false;
    return Math.abs(coord - gap.at) < (gap.gap ?? 12);
  });

  let index = 0;
  for (let z = -halfD; z <= halfD; z += spacing) {
    for (const side of [-1, 1]) {
      if (inGap('x', side * halfW, z)) { index += 1; continue; }
      const piece = frame.group.clone(true);
      piece.name = `FenceX_${String(index).padStart(3, '0')}`;
      piece.position.set(side * halfW, 0, world.centreZ + z);
      piece.rotation.y = 90 * DEG;
      group.add(piece);
      index += 1;
    }
  }
  for (let x = -halfW; x <= halfW; x += spacing) {
    for (const side of [-1, 1]) {
      if (inGap('z', world.centreZ + side * halfD, x)) { index += 1; continue; }
      const piece = frame.group.clone(true);
      piece.name = `FenceZ_${String(index).padStart(3, '0')}`;
      piece.position.set(x, 0, world.centreZ + side * halfD);
      group.add(piece);
      index += 1;
    }
  }

  if (opts.corner) {
    const corner = await makePart({ model: opts.corner, height: opts.cornerHeight ?? 11, name: 'CornerTemplate' });
    let n = 0;
    for (const sx of [-1, 1]) {
      for (const sz of [-1, 1]) {
        const piece = corner.group.clone(true);
        piece.name = `CornerPylon_${n}`;
        piece.position.set(sx * halfW, 0, world.centreZ + sz * halfD);
        group.add(piece);
        n += 1;
      }
    }
  }
  return group;
}

async function dressing(opts) {
  const group = new THREE.Group();
  group.name = 'Dressing';
  if (!opts?.count) return group;
  const crater = await makePart({ model: opts.crater ?? 'craterlarge', scale: opts.craterScale ?? 9, name: 'CraterTemplate' });
  const rock = await makePart({ model: opts.rock ?? 'rocks-smallb', scale: opts.rockScale ?? 2.4, name: 'RockTemplate' });
  const [cx, cz] = opts.centre;
  for (let i = 0; i < opts.count; i += 1) {
    const useCrater = seeded(i, 3) > 0.62;
    const piece = (useCrater ? crater : rock).group.clone(true);
    piece.name = `Dressing_${String(i).padStart(2, '0')}`;
    const angle = seeded(i, 7) * Math.PI * 2;
    const radius = (opts.radius ?? 20) * (0.35 + seeded(i, 11) * 0.65);
    piece.position.set(
      cx + Math.cos(angle) * radius,
      0.01,
      cz + Math.sin(angle) * radius * (opts.squash ?? 1),
    );
    piece.rotation.y = angle;
    group.add(piece);
  }
  return group;
}

/**
 * Build every ground layer for a world.
 * @returns {Promise<{ root: THREE.Group, sources: string[] }>}
 */
export async function buildTerrainLayer(world, config = {}) {
  const root = new THREE.Group();
  root.name = 'Terrain';
  const tile = config.floor?.tile ?? 12;
  const layers = [
    await floorTiles(world, config.floor ?? {}),
    await roads(world, config.roads, tile, config.roads?.[0]?.model ?? config.roadModel ?? 'terrain-roadstraight'),
    await deck(world, config.deck),
    await perimeter(world, config.perimeter),
    await dressing(config.dressing),
  ];
  for (const layer of layers) root.add(layer);

  const sources = [];
  root.traverse((node) => {
    if (node.isMesh && node.userData.realSource) sources.push(node.userData.realSource);
  });
  return { root, sources: [...new Set(sources)] };
}
