#!/usr/bin/env node
/*
 * tools/qa_avatar_shot.mjs — photograph the real browser build for avatar QA.
 *
 *   node tools/qa_avatar_shot.mjs
 *   node tools/qa_avatar_shot.mjs --viewport 1280x720 --viewport 390x844
 *   node tools/qa_avatar_shot.mjs --page "/web/index.html?qa_camera=1"
 *
 * Why this exists: the headless Godot runner has no rasteriser, so no smoke
 * test can say whether the avatar is *drawn*. This opens the committed Web
 * payload in the pinned headless Chromium (SwiftShader), waits for a real
 * engine frame, writes screenshots, and prints every console line the game
 * emits — including the opt-in `?qa_camera=1` trace that reports the camera
 * and player world positions behind each frame.
 *
 * The frames it writes are the only evidence for pixel claims; the console
 * trace is what lets a frame be tied to a known camera transform instead of
 * a guessed one.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, def) => {
    const i = argv.indexOf(name);
    return i === -1 ? def : argv[i + 1];
};
const pageTarget = flag('--page', '/web/index.html?qa_camera=1');
const viewportArgs = argv.reduce(
    (list, arg, i) => (arg === '--viewport' ? [...list, argv[i + 1]] : list),
    []
);
const viewports = (viewportArgs.length ? viewportArgs : ['1280x720']).map((spec) => {
    const [w, h] = spec.split('x').map(Number);
    return { spec, width: w || 1280, height: h || 720 };
});
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'avatar-qa')));
const settleMs = Number(flag('--settle', '8000'));
const frames = Math.max(1, Number(flag('--frames', '1')) || 1);
const frameGapMs = Number(flag('--gap', '2500'));
const port = Number(flag('--port', '8131'));
// Serve a different directory so a locally built .pck can be photographed
// without touching the committed payload.
const serveDir = path.resolve(ROOT, flag('--serve', '.'));

let chromium;
let puppeteer;
for (const [name, mod] of [['@sparticuz/chromium', 'chromium'], ['puppeteer-core', 'puppeteer']]) {
    const imported = (await import(name)).default;
    if (mod === 'chromium') chromium = imported;
    else puppeteer = imported;
}

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
    const br = path.join(
        path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))),
        '..',
        'bin',
        'al2023.tar.br'
    );
    fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
    const tar = path.join(CACHE, 'al2023.tar');
    fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
    execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
    fs.rmSync(tar);
}

const server = spawn(
    'python3',
    ['-m', 'http.server', String(port), '--bind', '127.0.0.1'],
    { cwd: serveDir, stdio: 'ignore' }
);
const baseUrl = `http://127.0.0.1:${port}`;
await new Promise((resolve) => setTimeout(resolve, 800));

fs.mkdirSync(outDir, { recursive: true });
const browser = await puppeteer.launch({
    executablePath: await chromium.executablePath(),
    args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
    headless: true,
    protocolTimeout: 300000,
    env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

// Any of these means the engine is running and rendering. Gameplay prints
// "Encounter:", the front end prints "Menu QA:" or "MenuLoading:", the rig and
// camera probes print their own banners.
const BOOT_MARKER = /Encounter:|Menu QA:|MenuLoading:|MenuCinematic:|Camera QA:|Touch QA:|Rig QA:|UI art/;

const results = [];
for (const viewport of viewports) {
    const page = await browser.newPage();
    await page.setViewport({
        width: viewport.width,
        height: viewport.height,
        hasTouch: Math.min(viewport.width, viewport.height) < 600,
        isMobile: Math.min(viewport.width, viewport.height) < 600,
        deviceScaleFactor: 1,
    });
    const lines = [];
    page.on('console', (message) => lines.push(String(message.text())));
    page.on('pageerror', (error) => lines.push(`PAGEERROR ${error.message}`));
    await page.goto(`${baseUrl}${pageTarget}`, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForFunction(
        () => document.querySelector('canvas') !== null,
        { timeout: 180000 }
    );
    // Wait for the engine to be *up* rather than for a fixed sleep: a software
    // rasteriser can take tens of seconds to produce the first frame. The
    // marker has to match the page under test -- waiting only for "Encounter:"
    // (the gameplay banner) silently waits the full 240 s on menu pages, which
    // means every menu screenshot was taken minutes after the state it was
    // meant to capture.
    const deadline = Date.now() + 240000;
    while (Date.now() < deadline && !lines.some((line) => BOOT_MARKER.test(line))) {
        await new Promise((resolve) => setTimeout(resolve, 200));
    }
    if (!lines.some((line) => BOOT_MARKER.test(line))) {
        console.log(`  !! no boot marker from ${viewport.spec} -- timings below are unreliable`);
    }
    await new Promise((resolve) => setTimeout(resolve, settleMs));
    const shots = [];
    for (let index = 0; index < frames; index += 1) {
        const suffix = frames > 1 ? `-${index + 1}` : '';
        const file = path.join(outDir, `avatar-${viewport.spec}${suffix}.png`);
        await page.screenshot({ path: file });
        shots.push(path.relative(ROOT, file));
        if (index + 1 < frames) {
            await new Promise((resolve) => setTimeout(resolve, frameGapMs));
        }
    }
    results.push({ viewport: viewport.spec, file: shots.join(', '), lines: lines.slice() });
    await page.close();
}

await browser.close();
server.kill();

for (const result of results) {
    console.log(`\n=== ${result.viewport} -> ${result.file}`);
    for (const line of result.lines) {
        if (/Camera QA:|Touch QA:|FrontEnd:|Menu QA:|MenuLoading:|MenuCinematic:|UI art|CharacterVisual:|Rig QA:|Encounter:|PAGEERROR|SCRIPT ERROR|ERROR:|WARNING:/.test(line)) {
            console.log(`  ${line}`);
        }
    }
}
