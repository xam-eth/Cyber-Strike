/**
 * checks.mjs — the deterministic half of the quality gate.
 *
 * Every function here is pure: it takes data already collected (catalog entry,
 * in-page stats, rendered PNGs, GLB bytes) and returns a verdict with the
 * measured value. Nothing in this file has an opinion about whether a model
 * "looks right" — that is the visual review recorded in
 * `tools/asset-forge/review/`, and the two are kept separate on purpose so a
 * green gate can never be mistaken for an art review.
 */
import fs from 'node:fs';
import path from 'node:path';
import { decodePng, analyse, gridDistance } from './png.mjs';

export const REPO = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..', '..');

const PALETTE = {
  void: '#05080c', panel: '#0b131b', panel2: '#111c26', panel3: '#16232e',
  line: '#27384a', lineHi: '#4e6a7e', ink: '#edf5fb', ink2: '#a9bccb', ink3: '#7c94a6',
  accent: '#ffb020', ok: '#37e08c', info: '#54c8ff', danger: '#ff5a5a', ability: '#b79cff',
};

function rgb(hex) {
  const n = parseInt(hex.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** Nearest palette token and its max-channel distance. */
export function nearest(hex) {
  const [r, g, b] = rgb(hex);
  let best = { token: null, distance: Infinity };
  for (const [token, value] of Object.entries(PALETTE)) {
    const [pr, pg, pb] = rgb(value);
    const d = Math.max(Math.abs(r - pr), Math.abs(g - pg), Math.abs(b - pb));
    if (d < best.distance) best = { token, distance: d };
  }
  return best;
}

/**
 * Re-read the engine's own token file and compare it with the gate's copy.
 * A palette that drifts between the game and the forge is the failure this
 * whole exercise exists to prevent, so it is checked rather than documented.
 */
export function checkPaletteSource() {
  const file = path.join(REPO, 'game/scripts/ui/aegis_tokens.gd');
  const text = fs.readFileSync(file, 'utf8');
  const found = {};
  const re = /const\s+([A-Z][A-Z0-9_]*)\s*:=\s*Color\("([0-9a-fA-F]{6})"\)/g;
  let m;
  while ((m = re.exec(text))) found[m[1]] = `#${m[2].toLowerCase()}`;
  const wanted = {
    VOID: 'void', PANEL: 'panel', PANEL_2: 'panel2', PANEL_3: 'panel3',
    LINE: 'line', LINE_HI: 'lineHi', INK: 'ink', INK_2: 'ink2', INK_3: 'ink3',
    ACCENT: 'accent', OK: 'ok', INFO: 'info', DANGER: 'danger', ABILITY: 'ability',
  };
  const mismatches = [];
  for (const [token, key] of Object.entries(wanted)) {
    if (!found[token]) mismatches.push(`${token} missing in aegis_tokens.gd`);
    else if (found[token] !== PALETTE[key]) mismatches.push(`${token} engine ${found[token]} vs forge ${PALETTE[key]}`);
  }
  return verdict(
    'palette-source',
    mismatches.length === 0,
    mismatches.length ? mismatches.join('; ') : `14 tokens match game/scripts/ui/aegis_tokens.gd`,
  );
}

export function verdict(check, pass, detail, extra = {}) {
  return { check, pass, detail, ...extra };
}

/* --------------------------------------------------------------- structure */

export function checkCatalogSource(entry) {
  const abs = path.join(REPO, entry.source.split('#')[0]);
  const ok = fs.existsSync(abs);
  return verdict('catalog-source-exists', ok, ok ? entry.source : `missing ${entry.source}`);
}

export function checkMeta(entry, stats, meta) {
  const problems = [];
  if (meta.id !== entry.id) problems.push(`id ${meta.id} != catalog ${entry.id}`);
  if (meta.category !== entry.category) problems.push(`category ${meta.category} != ${entry.category}`);
  if (meta.name !== entry.name) problems.push(`name "${meta.name}" != catalog "${entry.name}"`);
  if (meta.source !== entry.source) problems.push(`source ${meta.source} != catalog ${entry.source}`);
  if (!meta.reference) problems.push('no reference image recorded');
  else if (!fs.existsSync(path.join(REPO, 'tools/asset-forge', meta.reference))) problems.push(`reference ${meta.reference} missing on disk`);
  return verdict('meta-matches-catalog', problems.length === 0, problems.length ? problems.join('; ') : `${meta.id} / ${meta.category}`);
}

export function checkHeight(entry, stats) {
  const byLength = entry.target_length_m != null && entry.target_height_m == null;
  const target = Number(byLength ? entry.target_length_m : entry.target_height_m);
  const actual = byLength ? Math.max(stats.size.x, stats.size.y, stats.size.z) : stats.size.y;
  const tolerance = Math.max(0.06, target * 0.12);
  const ok = Math.abs(actual - target) <= tolerance;
  return verdict(
    'height-within-tolerance', ok,
    `${byLength ? 'length' : 'height'} ${actual.toFixed(3)} m vs target ${target} m (±${tolerance.toFixed(3)})`,
    { measured: actual, target, tolerance },
  );
}

export function checkOrigin(entry, stats, meta) {
  const mode = meta.origin ?? 'ground';
  if (mode === 'centre') {
    const centre = (stats.minY + stats.maxY) / 2;
    const ok = Math.abs(centre) <= Math.max(0.05, stats.size.y * 0.12);
    return verdict('origin-sane', ok, `centred, y-centre ${centre.toFixed(3)} m (${mode})`);
  }
  if (mode === 'none') {
    // Hand-held props keep their authored origin (the grip). The check is that
    // the origin sits inside the object's own bounding sphere — a grip 3 m away
    // from its weapon would make every attachment point a lie.
    const extent = Math.max(stats.size.x, stats.size.y, stats.size.z);
    const cx = stats.centre?.x ?? 0;
    const cy = stats.centre?.y ?? 0;
    const cz = stats.centre?.z ?? 0;
    const dist = Math.hypot(cx, cy, cz);
    const ok = dist <= extent * 1.1;
    return verdict('origin-sane', ok, `authored origin (${mode}), centre is ${dist.toFixed(3)} m from it within ${extent.toFixed(2)} m extent`);
  }
  const ok = Math.abs(stats.minY) <= Math.max(0.05, stats.size.y * 0.06);
  return verdict('origin-sane', ok, `ground-contact, minY ${stats.minY.toFixed(3)} m (${mode})`);
}

export function checkBudgets(entry, stats) {
  const tris = entry.triangle_budget ?? 120000;
  const meshes = entry.mesh_budget ?? 900;
  const out = [];
  out.push(verdict('triangle-budget', stats.triangles <= tris, `${stats.triangles} / ${tris} triangles`, { measured: stats.triangles, budget: tris }));
  out.push(verdict('mesh-budget', stats.meshes <= meshes, `${stats.meshes} / ${meshes} meshes`, { measured: stats.meshes, budget: meshes }));
  return out;
}

/**
 * The catalog declares the sockets a *consumer* needs (a muzzle, a grip). A
 * model may expose more than that — the Arc Shooter also has a fore-grip — so
 * the rule is "everything declared exists", not "nothing else exists".
 */
export function checkSockets(entry, stats) {
  const declared = entry.sockets ?? [];
  const present = stats.socketNames ?? [];
  const missing = declared.filter((s) => !present.includes(s));
  const extra = present.filter((s) => !declared.includes(s));
  return verdict(
    'sockets-declared', missing.length === 0,
    missing.length
      ? `missing [${missing.join(', ')}]`
      : `${declared.length}/${declared.length} declared sockets present${extra.length ? ` (+${extra.length} extra: ${extra.join(', ')})` : ''}`,
  );
}

export function checkClips(entry, stats) {
  const declared = entry.animations ?? [];
  const present = (stats.clips ?? []).map((c) => c.name);
  const missing = declared.filter((s) => !present.includes(s));
  if (missing.length) return verdict('clips-declared', false, `missing clips [${missing.join(', ')}]`);
  return verdict('clips-declared', true, declared.length ? `${declared.length} clips: ${declared.join(', ')}` : 'static asset (no clips)');
}

export function checkClipTargets(stats) {
  const nodeSet = new Set(stats.nodeNames ?? []);
  const bad = [];
  for (const clip of stats.clips ?? []) {
    for (const target of clip.targets ?? []) {
      if (!nodeSet.has(target)) bad.push(`${clip.name} → ${target}`);
    }
    if (!(clip.targets ?? []).length) bad.push(`${clip.name} declares no target`);
  }
  return verdict('clip-targets-exist', bad.length === 0, bad.length ? `dangling targets: ${bad.join('; ')}` : 'every clip target exists in the graph');
}

/**
 * A clip target can exist and still animate nothing. three.js resolves tracks
 * as `nodeName.propertyName[propertyIndex]`; `ArmR.rotation.x` is parsed as
 * node `ArmR.rotation`, which never exists, and the mixer only logs a warning.
 * Every model in this set shipped with that bug for a while and every other
 * check stayed green, so the binding is now verified explicitly.
 */
export function checkClipBindings(stats) {
  const bad = [];
  for (const clip of stats.clipBindings ?? []) {
    for (const track of clip.unresolved ?? []) bad.push(`${clip.name} → ${track}`);
  }
  if (!(stats.clipBindings ?? []).length) {
    return verdict('clip-bindings-resolve', true, 'static asset (no clips)');
  }
  return verdict(
    'clip-bindings-resolve',
    bad.length === 0,
    bad.length ? `tracks that bind to nothing: ${bad.join('; ')}` : 'every track resolves to a node property',
  );
}

export function checkUniqueNames(stats) {
  const dupes = stats.duplicatedNames ?? [];
  return verdict('unique-node-names', dupes.length === 0, dupes.length ? `duplicated: ${[...new Set(dupes)].join(', ')}` : `${stats.nodeCount} named nodes, no duplicates`);
}

export function checkGeometryFinite(stats) {
  const s = stats.size;
  const ok = Number.isFinite(s.x) && Number.isFinite(s.y) && Number.isFinite(s.z)
    && s.x > 0.001 && s.y > 0.001 && s.z > 0.001
    && stats.vertices > 0;
  return verdict('geometry-finite', ok, `bbox ${s.x.toFixed(2)}×${s.y.toFixed(2)}×${s.z.toFixed(2)} m, ${stats.vertices} vertices`);
}

/** The normaliser is allowed to adjust scale, not to rescue bad proportions. */
export function checkNormalisation(stats) {
  const n = stats.forge?.normalisation;
  if (!n) return verdict('normalisation-recorded', false, 'no normalisation record on the root');
  const ok = n.scale >= 0.5 && n.scale <= 2.0;
  return verdict(
    'normalisation-recorded', ok,
    `authored ${n.authoredHeight.toFixed(2)} m × ${n.scale.toFixed(3)} = target, ground offset ${n.groundOffset.toFixed(3)} m (factor must stay in 0.5–2.0)`,
    { scale: n.scale, authoredHeight: n.authoredHeight, groundOffset: n.groundOffset },
  );
}

export function checkDeterminism(first, second) {
  const ok = first.geometryHash === second.geometryHash && first.triangles === second.triangles;
  return verdict(
    'deterministic-rebuild', ok,
    ok ? `rebuild hash ${first.geometryHash} matches` : `hash ${first.geometryHash} vs ${second.geometryHash}, tris ${first.triangles} vs ${second.triangles}`,
  );
}

/** Materials: authored colours must be palette tokens; glow may exceed the token in intensity only. */
export function checkMaterials(stats, tolerance = 6) {
  const offenders = [];
  for (const mat of stats.materials) {
    for (const field of ['color', 'emissive']) {
      const hex = mat[field];
      if (!hex) continue;
      // A standard material with no emission reports #000000; that is the
      // absence of a colour, not an off-palette one.
      if (field === 'emissive' && (hex === '#000000' || hex === '#000')) continue;
      const { token, distance } = nearest(hex);
      if (distance > tolerance) offenders.push(`${field} ${hex} (nearest ${token} Δ${distance})`);
    }
  }
  const uniques = new Set(stats.materials.map((m) => `${m.type}|${m.color}|${m.emissive}|${m.emissiveIntensity}`));
  return verdict(
    'materials-on-palette', offenders.length === 0,
    offenders.length ? offenders.slice(0, 6).join('; ') : `${stats.materialCount} materials, ${uniques.size} unique, all on palette`,
    { materialCount: stats.materialCount },
  );
}

/* ------------------------------------------------------------------- glTF */

export function checkGlb(bytes, stats, entry) {
  if (!bytes || bytes.length < 20) return verdict('glb-valid', false, 'no bytes exported');
  const magic = bytes.toString('ascii', 0, 4);
  if (magic !== 'glTF') return verdict('glb-valid', false, `bad magic "${magic}"`);
  const version = bytes.readUInt32LE(4);
  const declaredLength = bytes.readUInt32LE(8);
  const chunkLength = bytes.readUInt32LE(12);
  const chunkType = bytes.toString('ascii', 16, 20);
  if (version !== 2) return verdict('glb-valid', false, `glTF version ${version}`);
  if (chunkType !== 'JSON') return verdict('glb-valid', false, `first chunk ${chunkType}`);
  if (declaredLength !== bytes.length) return verdict('glb-valid', false, `length field ${declaredLength} != ${bytes.length}`);
  let json;
  try {
    json = JSON.parse(bytes.toString('utf8', 20, 20 + chunkLength).replace(/\0+$/, '').trim());
  } catch (e) {
    return verdict('glb-valid', false, `JSON chunk unparsable: ${e.message}`);
  }
  const meshes = json.meshes?.length ?? 0;
  if (!meshes) return verdict('glb-valid', false, 'GLB contains no meshes');
  const clips = json.animations?.map((a) => a.name) ?? [];
  const declaredAnimations = entry.animations ?? [];
  const missing = declaredAnimations.filter((a) => !clips.includes(a));
  if (missing.length) return verdict('glb-valid', false, `GLB missing animations [${missing.join(', ')}] (has [${clips.join(', ')}])`);
  const nodeNames = (json.nodes ?? []).map((n) => n.name).filter(Boolean);
  const missingSockets = (entry.sockets ?? []).filter((s) => !nodeNames.includes(s));
  if (missingSockets.length) return verdict('glb-valid', false, `GLB missing socket nodes [${missingSockets.join(', ')}]`);
  return verdict(
    'glb-valid', true,
    `glTF 2.0, ${(bytes.length / 1024).toFixed(0)} kB, ${meshes} meshes, ${nodeNames.length} nodes, ${clips.length} animations`,
    { bytes: bytes.length, meshes, nodes: nodeNames.length, animations: clips },
  );
}

/* ---------------------------------------------------------------- renders */

/**
 * Khronos glTF 2.0 conformance — the contract an engine importer actually
 * consumes. Structural checks ("magic, version, length") passed while 17 of the
 * 36 exports were invalid: hero clips exported with **zero channels**
 * (`EMPTY_ENTITY`), scale tracks exported as `SCALAR` where glTF requires
 * `VEC3`, and two channels targeting one node (`ANIMATION_DUPLICATE_TARGETS`).
 * Godot's importer reads exactly these rules, so this check is the closest thing
 * to an engine-side answer that can run without launching the engine.
 */
export async function checkGltfConformance(bytes) {
  const mod = await import('gltf-validator');
  const validator = mod.default?.validateBytes ? mod.default : mod;
  const report = await validator.validateBytes(new Uint8Array(bytes), { maxIssues: 40 });
  const { numErrors, numWarnings } = report.issues;
  const first = report.issues.messages.filter((m) => m.severity <= 1).slice(0, 3)
    .map((m) => `${m.code} ${m.pointer}: ${m.message}`);
  return verdict(
    'gltf-conformance',
    numErrors === 0 && numWarnings === 0,
    numErrors || numWarnings
      ? `${numErrors} error(s), ${numWarnings} warning(s) — ${first.join(' | ')}`
      : `Khronos validator clean (${report.validatorVersion ? `validator ${report.validatorVersion}` : '0 errors, 0 warnings'})`,
  );
}

export function checkRenders(entry, shots) {
  // A long thin prop legitimately covers less of the frame than a building; the
  // floor is per-entry so the check measures "is it framed", not "is it bulky".
  const minCoverage = entry.render_coverage_min ?? 0.05;
  const results = [];
  const backdrop = rgb('#05080c');
  const decoded = shots.map((s) => ({ view: s.view, img: decodePng(s.buffer) }));
  const analyses = decoded.map((d) => ({ view: d.view, stats: analyse(d.img, backdrop) }));

  for (const a of analyses) {
    const s = a.stats;
    results.push(verdict(
      `render-coverage@${a.view.az}/${a.view.el}`, s.coverage >= minCoverage && s.coverage <= 0.9,
      `coverage ${(s.coverage * 100).toFixed(1)}% (needs ${(minCoverage * 100).toFixed(0)}–90%)`,
      { coverage: s.coverage },
    ));
    results.push(verdict(
      `render-luma@${a.view.az}/${a.view.el}`, s.lumaSpread >= 0.30 && s.stdLuma >= 0.045,
      `luma spread ${s.lumaSpread.toFixed(2)}, std ${s.stdLuma.toFixed(3)} (needs ≥0.30 / ≥0.045)`,
      { lumaSpread: s.lumaSpread, stdLuma: s.stdLuma },
    ));
  }

  // Views of a real 3D object must not all project to the same silhouette.
  // The rule is: at least one view pair differs a lot (the object has depth),
  // and no pair is *identical* (nothing collapsed). A box-shaped building
  // legitimately has a small front/three-quarter difference, so the strict
  // threshold is on the best pair, not the worst.
  const pairs = [];
  for (let i = 0; i < analyses.length; i += 1) {
    for (let j = i + 1; j < analyses.length; j += 1) {
      pairs.push({
        d: gridDistance(analyses[i].stats.grid, analyses[j].stats.grid),
        pair: `${analyses[i].view.az}\u00b0 vs ${analyses[j].view.az}\u00b0`,
      });
    }
  }
  const strongest = pairs.reduce((a, b) => (b.d > a.d ? b : a), pairs[0]);
  const weakest = pairs.reduce((a, b) => (b.d < a.d ? b : a), pairs[0]);
  // Some shapes are genuinely rotationally symmetric: a domed wreck photographs
  // almost the same from every side, which is a property of the subject, not a
  // defect in the model. Such an entry may declare a lower floor in the catalog
  // (`views_differ_min`), the same way thin props declare `render_coverage_min`.
  // The floor is printed in the message so a review can see it was relaxed.
  const differMin = entry.views_differ_min ?? 0.12;
  results.push(verdict(
    'views-differ', strongest.d >= differMin && weakest.d >= 0.005,
    `best pair ${strongest.pair} differs by ${strongest.d.toFixed(3)} (needs ≥${differMin}), closest ${weakest.pair} by ${weakest.d.toFixed(3)} (needs ≥0.005 — a symmetric hero legitimately differs little front-to-three-quarter)`,
    { viewDistance: strongest.d, viewDistanceMin: weakest.d },
  ));

  return { results, analyses };
}
