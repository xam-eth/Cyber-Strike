#!/usr/bin/env node
/*
 * tools/qa_vision.mjs — look at the build before anyone merges it.
 *
 *   node tools/qa_vision.mjs                       # latest successful CI build
 *   node tools/qa_vision.mjs --run 39917593324     # a specific run
 *   node tools/qa_vision.mjs --serve /tmp/build --page /index.html
 *   node tools/qa_vision.mjs --views 390x844,360x640 --stages DASHBOARD,HERO
 *
 * Why this exists: this repository has no Godot binary in the development
 * sandbox, so "does the UI actually show the thing" could only be answered
 * after a CI run finished *and* the bot had committed the rebuilt payload —
 * two waits, per edit. CI already uploads the built web payload as the
 * `web-preview` artifact, so the honest loop is:
 *
 *   edit -> push -> CI builds the payload -> download the artifact ->
 *   photograph every stage at every viewport -> read the frames
 *
 * which is this tool. The committed payload is still the source of truth for
 * what ships; this is the same payload, one commit earlier.
 *
 * Output: exports/vision/<tag>/ with
 *   - one PNG per stage per viewport,
 *   - contact-<viewport>.png  (every stage on one sheet),
 *   - index.html             (flip through the frames in a browser),
 *   - manifest.json          (per-frame statistics and the run it came from).
 */
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv.slice(2);
const flag = (name, def) => {
  const i = argv.indexOf(name);
  return i === -1 ? def : argv[i + 1];
};
const has = (name) => argv.includes(name);
const list = (name) => argv.reduce((acc, a, i) => (a === name ? [...acc, argv[i + 1]] : acc), []);

const tag = flag('--tag', 'vision');
const runId = flag('--run', '');
const serveDir = flag('--serve', '');
const page = flag('--page', '/index.html');
const stages = flag('--stages', 'DASHBOARD,HERO,WORLD');
const views = list('--viewport').length
  ? list('--viewport')
  : ['1280x720', '390x844', '360x640', '844x390'];
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'vision', tag)));
const transientDelay = flag('--transient-delay', '2500');

function sh(command, args, options = {}) {
  return execFileSync(command, args, { cwd: ROOT, encoding: 'utf8', ...options });
}

/** The newest run whose `web-preview` artifact exists. */
function latestBuildRun() {
  if (runId) return runId;
  const json = sh('gh', [
    'run', 'list', '--limit', '12', '--json', 'databaseId,conclusion,headSha,workflowName',
  ]);
  const runs = JSON.parse(json).filter((r) => r.conclusion === 'success');
  for (const run of runs) {
    try {
      const artifacts = JSON.parse(
        sh('gh', ['api', `repos/:owner/:repo/actions/runs/${run.databaseId}/artifacts`])
      );
      const found = (artifacts.artifacts || []).find((a) => a.name === 'web-preview');
      if (found && !found.expired) return String(run.databaseId);
    } catch {
      // A run without artifacts is not a build; keep looking.
    }
  }
  throw new Error('no successful run with a web-preview artifact in the last 12 runs');
}

function download(run, destination) {
  fs.rmSync(destination, { recursive: true, force: true });
  fs.mkdirSync(destination, { recursive: true });
  sh('gh', ['run', 'download', run, '-n', 'web-preview', '-D', destination], { stdio: 'inherit' });
  return destination;
}

/** The artifact lands either at the root or inside `web/`; find index.pck. */
function findPageRoot(dir) {
  for (const candidate of [dir, path.join(dir, 'web')]) {
    if (fs.existsSync(path.join(dir === candidate ? candidate : candidate, 'index.pck'))) return candidate;
  }
  const stack = [dir];
  while (stack.length) {
    const current = stack.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(full);
      else if (entry.name === 'index.pck') return current;
    }
  }
  return dir;
}

function main() {
  fs.mkdirSync(outDir, { recursive: true });
  let buildDir = serveDir ? path.resolve(ROOT, serveDir) : '';
  let usedRun = runId || 'local';
  if (!buildDir) {
    usedRun = latestBuildRun();
    buildDir = download(usedRun, path.join(ROOT, 'exports', 'vision', '.build'));
    console.log(`downloaded web-preview from run ${usedRun}`);
  }
  buildDir = findPageRoot(buildDir);

  for (const viewport of views) {
    console.log(`\n=== ${viewport} ===`);
    sh('node', [
      'tools/qa_flow_shots.mjs',
      '--tag', `${tag}-${viewport}`,
      '--stages', stages,
      '--viewport', viewport,
      '--serve', buildDir,
      '--page', page,
      '--transient-delay', transientDelay,
      '--out', path.join('exports', 'vision', tag, viewport),
    ], { stdio: 'inherit' });

    sh(path.join(ROOT, '.venv', 'bin', 'python'), [
      'tools/contact_sheet.py',
      path.join(outDir, viewport),
      path.join(outDir, `contact-${viewport}.png`),
      viewport,
    ], { stdio: 'inherit' });
  }

  writeIndex(buildDir, usedRun);
  console.log(`\nframes: ${path.relative(ROOT, outDir)}`);
  console.log(`build: run ${usedRun}  (${path.relative(ROOT, buildDir) || '.'})`);
}

/** A page that just flips through what was captured, so a reviewer scrolls
 *  once instead of opening twelve files. */
function writeIndex(buildDir, run) {
  const sheets = views
    .filter((v) => fs.existsSync(path.join(outDir, `contact-${v}.png`)))
    .map((v) => `<section><h2>${v}</h2><img src="contact-${v}.png" alt="${v}"></section>`)
    .join('\n');
  const html = `<!doctype html><meta charset="utf-8">
<title>Vision QA — ${tag}</title>
<style>
 body{margin:0;background:#080b10;color:#dbe7f2;font:15px/1.5 system-ui,sans-serif}
 h1{font-size:18px;padding:16px 20px;margin:0;border-bottom:1px solid #1d2a36}
 h2{font-size:14px;padding:12px 20px 0;color:#ffb020;text-transform:uppercase;letter-spacing:.08em}
 img{display:block;max-width:100%;margin:8px 20px 24px;border:1px solid #1d2a36}
 p{padding:0 20px;color:#8fa6b8}
</style>
<h1>Vision QA — ${tag} · build ${run}</h1>
<p>${stages} · ${views.join(', ')} · ${new Date().toISOString()}</p>
${sheets}`;
  fs.writeFileSync(path.join(outDir, 'index.html'), html);
}

main();
