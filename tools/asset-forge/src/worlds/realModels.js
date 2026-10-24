/**
 * realModels.js — the only bridge between the project and a visible mesh.
 *
 * Every mesh in the world comes from a file in `game/assets/world/real/`. This
 * module loads them; it never creates geometry. That is the rule this branch is
 * built on, and it is enforced mechanically:
 *
 *   - `loadModel()` is the only place a GLTFLoader is constructed;
 *   - every mesh it returns is tagged `userData.realSource = <file>`;
 *   - `gate/real_asset_checks.mjs` fails the build if the assembled world
 *     contains a single mesh without that tag.
 *
 * Models are cached, so the four sensor towers share one parsed `satellitedish`
 * and the terrain tiles share one `terrain` file instead of 240 downloads.
 */
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

/** Where the real files live, relative to the repository root (served path). */
export const REAL_ROOT = '/game/assets/world/real';

const loader = new GLTFLoader();
const cache = new Map();

/** Resolve a short id to its file. `kenney` is the CC0 kit, `powerplant` the CC-BY hero. */
export function modelPath(id) {
  if (id === 'powerplant') return `${REAL_ROOT}/powerplant.glb`;
  if (id === 'tile_floor') return `${REAL_ROOT}/ground/tile_floor.glb`;
  if (SETPIECES.includes(id)) return `${REAL_ROOT}/setpieces/${id}.glb`;
  // Nature Kit models carry an `nk_` prefix so one id space covers both CC0 kits.
  if (id.startsWith('nk_')) return `${REAL_ROOT}/nature/${id.slice(3)}.glb`;
  return `${REAL_ROOT}/kenney/${id}.glb`;
}

/** Pieces cut out of the Power Plant file by `real/slice_setpieces.mjs`. */
export const SETPIECES = [
  'tank_ring', 'tank_pad', 'cooling_tower', 'tall_arch', 'columns', 'column', 'drone', 'crane',
];

/**
 * Kit grading — one-time surface response, never a replacement mesh.
 *
 * The CC0 kit ships untextured flat colours on painted-metal shapes. At dusk,
 * next to the photographed Power Plant maps, raw kit pastel reads as plastic.
 * This pass keeps the geometry untouched and grades the *existing* material
 * colours onto the installation's steel-and-amber ramp, so the two libraries
 * share a light response. Textured materials (the real tile floor, every
 * Power Plant map) are left exactly as authored.
 */
const DEFAULT_KIT = {
  steel: '#5d6a74',
  warm: '#8f6b3c',
  targetLight: 0.22,
  targetSat: 0.12,
  rough: 0.64,
  metal: 0.34,
};

/**
 * Organics are graded differently from hardware, on purpose.
 *
 * A tree has its own authored greens; running it through the metal ramp turned
 * every canopy into a black silhouette. `nature` therefore only *shifts* toward
 * the world's palette — a lerp, a roughness and a value multiplier — instead of
 * replacing the hue. Both are still grades on existing colours, not new maps.
 */
const DEFAULT_NATURE = {
  tint: '#7fae72',
  tintLerp: 0.28,
  valueMul: 1.0,
  satMul: 1.0,
  rough: 0.92,
  metal: 0.0,
};

/**
 * The grade in force. A world sets it once, before it builds, and the loader
 * reads it when it parses a kit file. Module-level on purpose: one file's
 * materials are shared by every instance cloned from it, so grading happens per
 * file — running it per instance would compound the shift.
 */
let kitGrade = { ...DEFAULT_KIT };
let natureGrade = { ...DEFAULT_NATURE };
let groundTint = [2.4, 2.35, 2.2];
let groundRough = 0.92;
let groundMetal = 0;

/** Called by a world module before `buildWorld`. */
export function setWorldGrade({ kit, nature, ground } = {}) {
  kitGrade = { ...DEFAULT_KIT, ...(kit ?? {}) };
  natureGrade = { ...DEFAULT_NATURE, ...(nature ?? {}) };
  if (ground) {
    groundTint = ground.tint ?? groundTint;
    groundRough = ground.rough ?? groundRough;
    groundMetal = ground.metal ?? groundMetal;
  }
}

/** What the loader is currently applying, for the build report. */
export function currentGrade() {
  return {
    kit: { ...kitGrade },
    nature: { ...natureGrade },
    ground: { tint: [...groundTint], rough: groundRough, metal: groundMetal },
  };
}

/** Organics: shift toward the world's plant colour, never replace the hue. */
function gradeNature(root) {
  const tint = new THREE.Color(natureGrade.tint);
  root.traverse((node) => {
    if (!node.isMesh) return;
    const materials = Array.isArray(node.material) ? node.material : [node.material];
    const graded = materials.map((m) => {
      if (!m || m.map) return m;
      const next = m.clone();
      const hsl = { h: 0, s: 0, l: 0 };
      next.color.getHSL(hsl, THREE.SRGBColorSpace);
      next.color.lerp(tint, natureGrade.tintLerp * (0.5 + hsl.s));
      next.color.multiplyScalar(natureGrade.valueMul);
      next.color.offsetHSL(0, (natureGrade.satMul - 1) * hsl.s, 0);
      next.roughness = natureGrade.rough;
      next.metalness = natureGrade.metal;
      next.envMapIntensity = 1.0;
      next.needsUpdate = true;
      return next;
    });
    node.material = Array.isArray(node.material) ? graded : graded[0];
  });
}

function gradeKit(root) {
  const steel = new THREE.Color(kitGrade.steel);
  const warmColor = new THREE.Color(kitGrade.warm);
  root.traverse((node) => {
    if (!node.isMesh) return;
    const materials = Array.isArray(node.material) ? node.material : [node.material];
    const graded = materials.map((m) => {
      if (!m || m.map) return m;
      // GLTF material colours arrive in the linear working space; grading has to
      // be judged in sRGB or every value reads far lighter than it looks.
      const hsl = { h: 0, s: 0, l: 0 };
      m.color.getHSL(hsl, THREE.SRGBColorSpace);
      const next = m.clone();
      const warm = hsl.s > 0.42 && hsl.h > 0.075 && hsl.h < 0.145;
      if (warm) {
        next.color.copy(warmColor).multiplyScalar(0.75 + hsl.l * 0.45);
        next.roughness = kitGrade.rough - 0.1;
        next.metalness = kitGrade.metal;
      } else {
        // Pull every kit part onto one painted-steel ramp: keep a trace of the
        // original hue, take the value from the source lightness, and let the
        // ambient do the rest. A pastel hangar and a grey pylon then share a
        // light response instead of looking like they came from two games.
        const target = new THREE.Color().setHSL(
          hsl.h,
          Math.min(hsl.s, kitGrade.targetSat),
          kitGrade.targetLight * (0.55 + hsl.l * 1.1),
          THREE.SRGBColorSpace,
        );
        next.color.copy(m.color).lerp(target, 0.86);
        next.color.lerp(steel, 0.25);
        next.roughness = kitGrade.rough;
        next.metalness = kitGrade.metal;
      }
      next.envMapIntensity = 1.15;
      next.needsUpdate = true;
      return next;
    });
    node.material = Array.isArray(node.material) ? graded : graded[0];
  });
}

/**
 * Load one real model and return a *clone-ready* template.
 * @returns {Promise<{ scene: THREE.Group, path: string, clips: THREE.AnimationClip[] }>}
 */
export async function loadModel(id) {
  const path = modelPath(id);
  if (!cache.has(path)) {
    cache.set(path, loader.loadAsync(path).then((gltf) => {
      const scene = gltf.scene;
      const isKit = path.includes('/kenney/');
      const isNature = path.includes('/nature/');
      scene.traverse((node) => {
        if (!node.isMesh) return;
        node.castShadow = true;
        node.receiveShadow = true;
        // The source GLBs are the visual truth: nothing here recolours a
        // surface. Only render-state that a headless capture needs is set.
        const materials = Array.isArray(node.material) ? node.material : [node.material];
        for (const m of materials) {
          if (m.map) m.map.colorSpace = THREE.SRGBColorSpace;
          if (m.normalMap) m.normalScale.set(1, 1);
          m.side = THREE.FrontSide;
        }
        node.userData.realSource = path;
      });
      if (isKit) gradeKit(scene);
      if (isNature) gradeNature(scene);
      // The photographed ground plate is authored for bright daylight; at dusk it
      // needs its value lifted or the whole field reads as black asphalt.
      // The scanned stone plate and the Nature Kit's grass tiles are both *floor*:
      // they get the theme's ground exposure, not the hardware or foliage grade.
      if (path.includes('/ground/') || /\/nature\/ground-/.test(path)) {
        scene.traverse((node) => {
          if (!node.isMesh) return;
          const m = node.material;
          if (!m) return;
          // The plate is photographed under noon sun; its albedo is far too dark
          // for a dusk field. Lift the tint above 1.0 (a legal multiplier on the
          // map) and kill the metalness, so it reads as worn concrete.
          // Tint is authored in sRGB, like every other colour in the theme.
          // Setting it as linear made a "dark moss" multiplier render pale green.
          if (m.color) m.color.setRGB(groundTint[0], groundTint[1], groundTint[2], THREE.SRGBColorSpace);
          m.roughness = groundRough;
          m.metalness = groundMetal;
          m.envMapIntensity = 0.7;
          m.needsUpdate = true;
        });
      }
      return { scene, path, clips: gltf.animations ?? [] };
    }));
  }
  return cache.get(path);
}

/**
 * A placed part: one real model, scaled to real-world metres, with its own
 * transform. Cloning shares geometry and materials, so a 240-tile ground costs
 * one parsed file and one set of buffers.
 *
 * @param {object} spec
 * @param {string} spec.model      real model id
 * @param {number} [spec.height]   desired height in metres (uniform scale)
 * @param {number} [spec.width]    desired footprint width in metres (for pads)
 * @param {number} [spec.scale]    explicit uniform scale, overrides both
 * @param {[number,number,number]} [spec.stretch] per-axis multiplier on top
 * @param {[number,number,number]} [spec.pos]
 * @param {number} [spec.yaw]      degrees
 * @param {number} [spec.pitch]    degrees (X)
 * @param {number} [spec.roll]     degrees (Z)
 * @param {string} [spec.name]
 * @returns {Promise<{ group: THREE.Group, size: THREE.Vector3, source: string }>}
 */
export async function makePart({ model, height, width, scale, stretch = [1, 1, 1], pos = [0, 0, 0], yaw = 0, pitch = 0, roll = 0, name }) {
  const { scene, path } = await loadModel(model);
  const group = new THREE.Group();
  group.name = name ?? `${model}_part`;

  const holder = scene.clone(true);
  holder.traverse((node) => {
    if (!node.isMesh) return;
    node.userData.realSource = path;
    node.castShadow = true;
    node.receiveShadow = true;
  });

  const box = new THREE.Box3().setFromObject(holder);
  const size = box.getSize(new THREE.Vector3());

  // Size by whatever the spec names: a height for uprights, a width for the flat
  // pads (a 34 m concrete disc has almost no height, so normalising on y would
  // blow it up by two orders of magnitude), or an explicit uniform scale.
  let uniform = 1;
  if (scale != null) uniform = scale;
  else if (height && size.y > 1e-6) uniform = height / size.y;
  else if (width) uniform = width / Math.max(size.x, size.z);

  const sx = uniform * stretch[0];
  const sy = uniform * stretch[1];
  const sz = uniform * stretch[2];
  holder.scale.set(sx, sy, sz);

  // Sit the part on y = 0 by its own bounds and centre it on the role origin, so
  // a file authored anywhere in its own space still lands like a placed prop.
  holder.position.set(
    -((box.min.x + box.max.x) / 2) * sx,
    -box.min.y * sy,
    -((box.min.z + box.max.z) / 2) * sz,
  );

  group.position.set(pos[0], pos[1], pos[2]);
  group.rotation.set(THREE.MathUtils.degToRad(pitch), THREE.MathUtils.degToRad(yaw), THREE.MathUtils.degToRad(roll), 'YXZ');
  group.add(holder);

  return { group, size: size.multiply(new THREE.Vector3(sx, sy, sz)), source: path, scale: uniform };
}

/** Every real file a composition refers to, for the provenance check. */
export function libraryIndex() {
  return [...cache.keys()];
}
