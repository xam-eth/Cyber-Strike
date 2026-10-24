/**
 * Materials — one small registry, shared between every model.
 *
 * Two rules that matter for the mobile budget and for the palette gate:
 *  1. Materials are created once and cached by key, so 40 crates in a depot
 *     share one material and the GLB export does not carry 40 copies.
 *  2. A material's base colour must be a palette token. Emission is allowed to
 *     be brighter than the token (a cyan strip is emissive cyan, not a new
 *     colour), which is what `emissiveIntensity` is for.
 */
import * as THREE from 'three';
import { PALETTE } from './palette.js';

const cache = new Map();

function key(parts) {
  return parts.map((p) => (typeof p === 'number' ? p.toFixed(3) : String(p))).join('|');
}

/** Brushed/painted structural metal. */
export function metal(token = 'line', { roughness = 0.55, metalness = 0.55 } = {}) {
  const k = key(['metal', token, roughness, metalness]);
  if (!cache.has(k)) {
    cache.set(k, new THREE.MeshStandardMaterial({
      color: new THREE.Color(PALETTE[token]),
      roughness,
      metalness,
      flatShading: false,
    }));
  }
  return cache.get(k);
}

/** Painted / ceramic / polymer surface — low metalness, higher roughness. */
export function paint(token = 'ink2', { roughness = 0.72, metalness = 0.16 } = {}) {
  const k = key(['paint', token, roughness, metalness]);
  if (!cache.has(k)) {
    cache.set(k, new THREE.MeshStandardMaterial({
      color: new THREE.Color(PALETTE[token]),
      roughness,
      metalness,
    }));
  }
  return cache.get(k);
}

/** Emissive energy surface. `intensity` is the glow strength, not a new hue. */
export function glow(token = 'info', intensity = 1.6, { base = 'panel' } = {}) {
  const k = key(['glow', token, intensity, base]);
  if (!cache.has(k)) {
    cache.set(k, new THREE.MeshStandardMaterial({
      color: new THREE.Color(PALETTE[base]),
      emissive: new THREE.Color(PALETTE[token]),
      emissiveIntensity: intensity,
      roughness: 0.35,
      metalness: 0.1,
    }));
  }
  return cache.get(k);
}

/** Transparent armour glass / containment sleeve. */
export function glass(token = 'info', { opacity = 0.14, roughness = 0.08 } = {}) {
  const k = key(['glass', token, opacity, roughness]);
  if (!cache.has(k)) {
    cache.set(k, new THREE.MeshStandardMaterial({
      color: new THREE.Color(PALETTE[token]),
      emissive: new THREE.Color(PALETTE[token]),
      emissiveIntensity: 0.1,
      roughness,
      metalness: 0.0,
      transparent: true,
      opacity,
      depthWrite: false,
      side: THREE.DoubleSide,
    }));
  }
  return cache.get(k);
}

/** Hazard paint: amber, still the warning colour, just sprayed on a surface. */
export function hazard() {
  // Saturated, barely metallic: at metalness 0.2 the amber picks up enough of
  // the cold environment that it reads olive instead of warning-orange.
  return paint('accent', { roughness: 0.62, metalness: 0.04 });
}

/** The one material every model is allowed for pure shadow gaps. */
export function shadowGap() {
  return paint('void', { roughness: 0.9, metalness: 0.1 });
}

export function clearCache() {
  cache.clear();
}

/** Every cached material, for the gate's palette audit. */
export function inspectMaterials(root) {
  const seen = new Map();
  root.traverse((o) => {
    if (!o.isMesh || !o.material) return;
    const list = Array.isArray(o.material) ? o.material : [o.material];
    for (const m of list) {
      seen.set(m.uuid, {
        type: m.type,
        color: m.color ? m.color.getHexString() : null,
        emissive: m.emissive ? m.emissive.getHexString() : null,
        emissiveIntensity: m.emissiveIntensity ?? null,
        transparent: !!m.transparent,
        opacity: m.opacity,
      });
    }
  });
  return [...seen.values()];
}
