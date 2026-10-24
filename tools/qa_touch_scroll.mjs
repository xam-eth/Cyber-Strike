#!/usr/bin/env node
/*
 * tools/qa_touch_scroll.mjs — drag the landscape card row with a real thumb.
 *
 *   node tools/qa_touch_scroll.mjs --serve web
 *   node tools/qa_touch_scroll.mjs --serve web --viewport 844x390 --drag 240
 *
 * The landscape card row is the one interaction the rest of the QA stack cannot
 * reach. `ScrollContainer` gates touch panning on
 * `DisplayServer::is_touchscreen_available()`
 * (scene/gui/scroll_container.cpp:237), and every headless display server
 * answers false: a synthetic drag in a smoke test moves the row 0 px, so the
 * suite can only prove the row *has* a range, not that a finger can use it.
 *
 * A browser with touch emulation does report a touchscreen, so this probe:
 *
 *   1. opens the exported Web payload at a landscape viewport with touch
 *      emulation on;
 *   2. reads the row's rectangle out of the engine's own `?qa_menu=1` report,
 *      so the drag lands on the row instead of a guessed point;
 *   3. performs real touch drags (touchStart -> touchMove x N -> touchEnd)
 *      through the DevTools input domain, not a synthetic
 *      `InputEventScreenDrag` — once starting on a card, which is where a thumb
 *      lands, and once starting in the row's empty space, which is the control;
 *   4. prints every `MenuScroll:` line the game emits. Those numbers come from
 *      the live scroll bar via the `?qa_scroll=1` hook in
 *      stage_weapon_select.gd, and they separate the three ways this can fail:
 *      the row cannot scroll (no range), the gesture never arrives (a tap on a
 *      card also does nothing), or the row scrolls but a card eats the drag.
 *
 * Silence is never reported as a pass.
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
const serveDir = path.resolve(ROOT, flag('--serve', 'web'));
const stage = flag('--stage', 'WEAPON');
const viewportSpec = flag('--viewport', '844x390');
const dragPx = Number(flag('--drag', '240'));
const steps = Math.max(2, Number(flag('--steps', '12')) || 2);
const settleMs = Number(flag('--settle', '6000'));
const port = Number(flag('--port', '8137'));

const [width, height] = viewportSpec.split('x').map(Number);

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
await new Promise((resolve) => setTimeout(resolve, 800));

const browser = await puppeteer.launch({
    executablePath: await chromium.executablePath(),
    args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
    headless: true,
    protocolTimeout: 300000,
    env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

const lines = [];
try {
    const page = await browser.newPage();
    await page.setViewport({ width, height, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
    page.on('console', (message) => lines.push(String(message.text())));
    page.on('pageerror', (error) => lines.push(`PAGEERROR ${error.message}`));

    const url = `http://127.0.0.1:${port}/index.html?qa_stage=${stage}&qa_menu=1&qa_scroll=1`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });

    // The engine's own banner, not a fixed sleep: see the note in
    // qa_avatar_shot.mjs about what waiting on the wrong line costs.
    const BOOT_MARKER = /Menu QA:|MenuScroll:|FrontEnd:|Encounter:|PAGEERROR/;
    const deadline = Date.now() + 240000;
    while (Date.now() < deadline && !lines.some((line) => BOOT_MARKER.test(line))) {
        await new Promise((resolve) => setTimeout(resolve, 200));
    }
    await new Promise((resolve) => setTimeout(resolve, settleMs));

    const report = lines.filter((line) => line.startsWith('Menu QA:')).pop() || '';
    const scrollRect = /CardScroll=(-?\d+),(-?\d+),(\d+)x(\d+)/.exec(report);
    const cardRect = /(\w+Card)=(-?\d+),(-?\d+),(\d+)x(\d+)/.exec(report);
    const touchPoints = await page.evaluate(() => navigator.maxTouchPoints);

    console.log(`\n=== ${viewportSpec} · ${serveDir}`);
    console.log(`  card row    : ${scrollRect ? scrollRect[0] : 'not reported'}`);
    console.log(`  first card  : ${cardRect ? cardRect[0] : 'not reported'}`);
    console.log(`  touchscreen : navigator.maxTouchPoints = ${touchPoints}`);

    if (!scrollRect) {
        console.log('  NOT TESTED: the engine never reported the row, so there is nothing to drag.');
    } else {
        const [, rx, ry, rw, rh] = scrollRect.map(Number);
        const [cx, cy, cw, ch] = cardRect
            ? [Number(cardRect[2]), Number(cardRect[3]), Number(cardRect[4]), Number(cardRect[5])]
            : [rx, ry, rw, rh];
        const midY = Math.round(cy + ch / 2);
        const emptyY = Math.min(ry + rh - 10, cy + ch + 20);

        const drag = async (fromX, y, label) => {
            const before = lines.length;
            await page.touchscreen.touchStart(fromX, y);
            for (let index = 1; index <= steps; index += 1) {
                await page.touchscreen.touchMove(Math.round(fromX - (dragPx * index) / steps), y);
                await new Promise((resolve) => setTimeout(resolve, 24));
            }
            await new Promise((resolve) => setTimeout(resolve, 400));
            await page.touchscreen.touchEnd();
            await new Promise((resolve) => setTimeout(resolve, 1000));
            const values = lines
                .slice(before)
                .map((line) => /MenuScroll: offset ([-\d.]+)/.exec(line))
                .filter((match) => match !== null)
                .map((match) => Number(match[1]));
            const moved = values.length
                ? Math.max(...values.map((value) => Math.abs(value - values[0])))
                : 0;
            console.log(
                `  ${label.padEnd(12)}: ${fromX} -> ${fromX - dragPx} px at y=${y} — moved ${moved.toFixed(1)} px`
            );
            return moved;
        };

        // Tap first: it is the control that proves touch reaches the engine at
        // all, and the drags below move the card out from under the pointer.
        const tapBefore = lines.length;
        await page.touchscreen.tap(Math.round(cx + cw / 2), midY);
        await new Promise((resolve) => setTimeout(resolve, 800));
        const tapped = lines.slice(tapBefore).filter((line) => line.includes('card pressed')).length;
        console.log(`  tap         : ${tapped ? 'reached the engine (card pressed)' : 'did not reach the engine'}`);

        const onCard = await drag(Math.round(cx + cw * 0.8), midY, 'from a card');
        const onGap = await drag(Math.round(rx + rw / 2), emptyY, 'from empty');

        const wheelBefore = lines.length;
        await page.mouse.move(Math.round(cx + cw * 0.8), midY);
        await page.mouse.wheel({ deltaX: dragPx });
        await new Promise((resolve) => setTimeout(resolve, 1200));
        const wheelMoved = lines
            .slice(wheelBefore)
            .filter((line) => line.includes('MenuScroll: offset')).length;

        const states = lines.filter((line) => line.startsWith('MenuScroll:') && line.includes(' row '));
        const range = Math.max(0, ...states.map((line) => Number(/range ([-\d.]+)/.exec(line)?.[1] ?? 0)));
        const pageWidth = Math.max(0, ...states.map((line) => Number(/page ([-\d.]+)/.exec(line)?.[1] ?? 0)));

        const gate = lines.find((line) => line.includes('is_touchscreen_available')) || 'not reported';
        const events = lines.filter((line) => line.includes('MenuScroll: input'));
        // `as_text()` writes "Screen Drag" / "Screen Touch" with a space.
        const drags = events.filter((line) => /input Screen\s*Drag/i.test(line)).length;
        const touches = events.filter((line) => /input Screen\s*Touch/i.test(line)).length;
        const kinds = [...new Set(events.map((line) => (/input ([A-Za-z ]+?)(:|$)/.exec(line)?.[1] ?? '?').trim()).values())];
        console.log(`  input       : ${events.length} events seen by the engine (${touches} touch, ${drags} drag)`);
        console.log(`  event kinds : ${kinds.join(', ') || 'none'}`);
        for (const sample of events.filter((line) => /Screen\s*Drag/i.test(line)).slice(0, 3)) {
            console.log(`    ${sample.replace('MenuScroll: input ', '')}`);
        }
        console.log(`  wheel       : ${wheelMoved ? 'moved the row' : 'did not move the row'}`);
        console.log(`  gate        : ${gate.trim()}`);
        console.log(`  range       : ${range.toFixed(1)} px of content, ${pageWidth.toFixed(1)} px visible`);

        if (onCard > 8) {
            console.log(`  PASS: a real touch drag scrolled the row ${onCard.toFixed(1)} px.`);
        } else if (onGap > 8) {
            console.log(
                '  FAIL: the row pans only when the drag starts off a card, and a thumb lands on a card.'
            );
        } else if (range <= 0) {
            console.log('  NOT TESTED: the row reports no scroll range at this viewport.');
        } else {
            console.log(
                '  NOT TESTED: the row has range and taps reach the engine, but no touch drag panned it.'
            );
        }
    }

    for (const line of lines) {
        if (/PAGEERROR|SCRIPT ERROR|ERROR:/.test(line)) {
            console.log(`  ${line}`);
        }
    }
    await page.close();
} finally {
    await browser.close();
    server.kill();
}
