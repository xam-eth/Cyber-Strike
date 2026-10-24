#!/usr/bin/env node
/**
 * run_gate.mjs — build every catalogued model in a real browser, measure it,
 * export it, and write the receipts.
 *
 *   node tools/asset-forge/gate/run_gate.mjs                 # all built models
 *   node tools/asset-forge/gate/run_gate.mjs --only reactor_core,pulse_rifle
 *   node tools/asset-forge/gate/run_gate.mjs --no-glb        # skip export
 *
 * What it does per model, in order:
 *   1. load `src/<category>/<id>.js` in pinned Chromium (SwiftShader) via
 *      `gallery.html?capture=1`;
 *   2. read measured stats back out of the page (triangles, meshes, bbox,
 *      materials, node names, clip tracks);
 *   3. rebuild the module from a cache-busted URL and compare geometry hashes
 *      (determinism is measured, not asserted in a comment);
 *   4. render front / three-quarter / side at 720² on the flat navy backdrop;
 *   5. export a GLB with GLTFExporter and validate its chunks;
 *   6. run `checks.mjs` over all of the above.
 *
 * Outputs (all git-ignored except the reports, which are committed):
 *   tools/asset-forge/build/renders/<id>/*.png
 *   tools/asset-forge/build/glb/<category>/<id>.glb
 *   tools/asset-forge/build/quality-report.json
 *   tools/asset-forge/build/contact-<category>.png
 *   tools/asset-forge/results.json          (committed summary, no images)
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import * as C from './checks.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..', '..');
const FORGE = path.join(ROOT, 'tools', 'asset-forge');
const BUILD = path.join(FORGE, 'build');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const has = (n) => argv.includes(n);
const flag = (n, d) => { const i = argv.indexOf(n); return i === -1 ? d : argv[i + 1]; };

const catalog = JSON.parse(fs.readFileSync(path.join(FORGE, 'catalog.json'), 'utf8'));
const only = flag('--only', '') ? flag('--only', '').split(',').map((s) => s.trim()) : null;
const SIZES = Number(flag('--size', '720'));
// Front, three-quarter and an elevated side view. The elevated view is what
// makes roof detail count: without it a near-cubic building projects almost the
// same silhouette from the side and the `views-differ` check would be measuring
// the aspect ratio rather than the depth.
const VIEWS = [
  { az: 0, el: 8 },
  { az: 34, el: 16 },
  { az: 90, el: 42 },
];

const outDir = path.join(BUILD, 'renders');
const glbDir = path.join(BUILD, 'glb');
fs.mkdirSync(outDir, { recursive: true });
fs.mkdirSync(glbDir, { recursive: true });

/* --------------------------------------------------- chromium + server ---- */

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))), '..', 'bin', 'al2023.tar.br');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

const port = Number(flag('--port', '8161'));
const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 900));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 600000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

// A syntax error in a model module kills the whole page, which then reads as a
// 60 s timeout with no useful message. Parse every module first so the failure
// is one line naming the file.
const moduleFiles = [];
for (const dir of ['world', 'heroes', 'weapons', 'enemies', 'vfx']) {
  const abs = path.join(FORGE, 'src', dir);
  if (!fs.existsSync(abs)) continue;
  for (const f of fs.readdirSync(abs)) if (f.endsWith('.js')) moduleFiles.push(path.join(abs, f));
}
for (const f of moduleFiles) {
  const out = spawnSync('node', ['--check', f], { encoding: 'utf8' });
  if (out.status !== 0) {
    console.error(`syntax error in ${path.relative(ROOT, f)}\n${out.stderr}`);
    process.exit(2);
  }
}

const page = await browser.newPage();
await page.setViewport({ width: SIZES, height: SIZES, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.error('  pageerror:', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.error('  console:', m.text()); });
await page.goto(`http://127.0.0.1:${port}/tools/asset-forge/gallery.html?capture=1&nospin=1`, { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.__api, { timeout: 60000 });

const registered = await page.evaluate(() => window.__api.list());

/* ------------------------------------------------------------------ run --- */

const entries = catalog.entries.filter((e) => (only ? only.includes(e.id) : true));
const results = [];
const paletteCheck = C.checkPaletteSource();
console.log(`palette-source: ${paletteCheck.pass ? 'ok' : 'FAIL'} — ${paletteCheck.detail}`);
console.log(`catalog: ${catalog.entries.length} entries, ${registered.length} models wired, ${SIZES}px views\n`);

for (const entry of entries) {
  const started = Date.now();
  const checks = [];
  let stats = null;
  let meta = null;
  let error = null;

  if (!registered.includes(entry.id)) {
    results.push({
      id: entry.id, category: entry.category, name: entry.name,
      status: 'not-built',
      checks: [C.verdict('model-exists', false, `no src/${entry.category}/${entry.id}.js yet`)],
      referenceImage: entry.reference_image ?? null,
    });
    console.log(`· ${entry.id.padEnd(24)} NOT BUILT (no module yet)`);
    continue;
  }

  try {
    await page.evaluate((id) => window.__api.load(id), entry.id);
    stats = await page.evaluate(() => window.__api.stats());
    meta = await page.evaluate(async (id) => {
      const mod = await window.__registryLookup(id);
      return mod?.meta ?? null;
    }, entry.id);

    await page.evaluate((s) => window.__api.resize(s), SIZES);

    // determinism: second build from a cache-busted module URL
    const second = await page.evaluate((id, nonce) => window.__api.rebuild(id, nonce), entry.id, Date.now());

    // renders
    // A rifle is 1 m long and 0.2 m tall: a muzzle-on "front" view is a sliver
    // of pixels and measuring it says nothing. Entries may declare their own
    // useful views; everything else uses the kit default.
    const views = entry.views ?? VIEWS;
    const shots = await page.evaluate((v, size) => window.__api.shots(v, size), views, SIZES);
    const shotBuffers = shots.map((s) => ({
      view: s.view,
      buffer: Buffer.from(s.dataUrl.split(',')[1], 'base64'),
    }));
    const dir = path.join(outDir, entry.id);
    fs.mkdirSync(dir, { recursive: true });
    for (const s of shotBuffers) {
      fs.writeFileSync(path.join(dir, `view-${String(s.view.az).padStart(3, '0')}-${s.view.el}.png`), s.buffer);
    }

    // per-clip pose frames, so an animation can be reviewed as a still
    for (const clipName of entry.animations ?? []) {
      const played = await page.evaluate((n) => window.__api.playClip(n, 0.4), clipName);
      if (played) {
        const one = await page.evaluate(() => window.__api.shots([{ az: 34, el: 14 }], 480));
        fs.writeFileSync(
          path.join(dir, `clip-${clipName}.png`),
          Buffer.from(one[0].dataUrl.split(',')[1], 'base64'),
        );
      }
    }

    // GLB export
    let glbBytes = null;
    if (!has('--no-glb')) {
      const b64 = await page.evaluate(() => window.__api.glb());
      glbBytes = Buffer.from(b64, 'base64');
      const catDir = path.join(glbDir, entry.category);
      fs.mkdirSync(catDir, { recursive: true });
      fs.writeFileSync(path.join(catDir, `${entry.id}.glb`), glbBytes);
    }

    checks.push(C.checkCatalogSource(entry));
    checks.push(C.checkMeta(entry, stats, meta ?? {}));
    checks.push(C.checkNormalisation(stats));
    checks.push(C.checkHeight(entry, stats));
    checks.push(C.checkOrigin(entry, stats, meta ?? {}));
    checks.push(...C.checkBudgets(entry, stats));
    checks.push(C.checkSockets(entry, stats));
    checks.push(C.checkClips(entry, stats));
    checks.push(C.checkClipTargets(stats));
    checks.push(C.checkUniqueNames(stats));
    checks.push(C.checkGeometryFinite(stats));
    checks.push(C.checkMaterials(stats));
    checks.push(C.checkDeterminism(stats, second));
    if (glbBytes) checks.push(C.checkGlb(glbBytes, stats, entry));
    const renderChecks = C.checkRenders(entry, shotBuffers);
    checks.push(...renderChecks.results);

    const failed = checks.filter((c) => !c.pass);
    results.push({
      id: entry.id,
      category: entry.category,
      name: entry.name,
      status: failed.length ? 'fail' : 'pass',
      reference: meta?.reference ?? null,
      measured: {
        height_m: Number(stats.size.y.toFixed(3)),
        width_m: Number(stats.size.x.toFixed(3)),
        depth_m: Number(stats.size.z.toFixed(3)),
        triangles: stats.triangles,
        meshes: stats.meshes,
        materials: stats.materialCount,
        nodes: stats.nodeCount,
        sockets: stats.socketNames,
        clips: (stats.clips ?? []).map((c) => c.name),
        coverage: Number((renderChecks.analyses.find((a) => a.view.az === 34)?.stats.coverage ?? 0).toFixed(3)),
        lumaSpread: Number((renderChecks.analyses.find((a) => a.view.az === 34)?.stats.lumaSpread ?? 0).toFixed(3)),
        viewDistance: Number((renderChecks.results.find((c) => c.check === 'views-differ')?.viewDistance ?? 0).toFixed(3)),
        geometryHash: stats.geometryHash,
        glbBytes: glbBytes ? glbBytes.length : null,
      },
      failing: failed.map((c) => `${c.check}: ${c.detail}`),
      checks,
      ms: Date.now() - started,
    });
    const mark = failed.length ? 'FAIL' : 'pass';
    console.log(`· ${entry.id.padEnd(24)} ${mark.padEnd(4)} ${stats.triangles.toString().padStart(6)} tris  ${stats.meshes.toString().padStart(3)} mesh  ${stats.size.y.toFixed(2)} m  ${(Date.now() - started)} ms`);
    for (const f of failed) console.log(`    ✗ ${f.check}: ${f.detail}`);
  } catch (e) {
    error = e.message;
    results.push({
      id: entry.id, category: entry.category, name: entry.name,
      status: 'error', error,
      checks: [C.verdict('build-runs', false, error)],
    });
    console.log(`· ${entry.id.padEnd(24)} ERROR ${error}`);
  }
}

await browser.close();
server.kill();

/* --------------------------------------------------------------- reports -- */

const built = results.filter((r) => r.status === 'pass' || r.status === 'fail');
const summary = {
  generated: new Date().toISOString(),
  tool: 'tools/asset-forge/gate/run_gate.mjs',
  renderer: 'pinned Chromium, SwiftShader (software) — frame rate is not representative',
  palette: paletteCheck,
  catalogEntries: catalog.entries.length,
  modelsWired: registered.length,
  modelsMeasured: built.length,
  passed: built.filter((r) => r.status === 'pass').length,
  failed: built.filter((r) => r.status === 'fail').length,
  notBuilt: results.filter((r) => r.status === 'not-built').map((r) => r.id),
  errored: results.filter((r) => r.status === 'error').map((r) => ({ id: r.id, error: r.error })),
  totals: {
    triangles: built.reduce((a, r) => a + (r.measured?.triangles ?? 0), 0),
    meshes: built.reduce((a, r) => a + (r.measured?.meshes ?? 0), 0),
    glbBytes: built.reduce((a, r) => a + (r.measured?.glbBytes ?? 0), 0),
  },
  results,
};
fs.writeFileSync(path.join(BUILD, 'quality-report.json'), `${JSON.stringify(summary, null, 2)}\n`);
fs.writeFileSync(path.join(FORGE, 'results.json'), `${JSON.stringify(summary, null, 2)}\n`);
console.log(`\n${summary.passed} pass · ${summary.failed} fail · ${summary.notBuilt.length} not built · ${summary.errored.length} error`);
console.log(`report: tools/asset-forge/build/quality-report.json`);
const exitCode = summary.failed || summary.errored.length ? 1 : 0;
process.exit(exitCode);
