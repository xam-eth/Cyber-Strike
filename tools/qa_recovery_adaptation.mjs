#!/usr/bin/env node
/*
 * Real-input Website QA for the Verdant Recovery adaptation vertical slice.
 *
 *   python -m http.server 800 --bind 0.0.0.0
 *   npm ci --prefix tools
 *   node tools/qa_recovery_adaptation.mjs --url=http://127.0.0.1:800/ --lang=en
 *   node tools/qa_recovery_adaptation.mjs --url=http://127.0.0.1:800/ --lang=id --visual-only
 *
 * No Godot state, reward, profile, target health, or upgrade is injected. The
 * driver uses the ordinary shell, keyboard/mouse, CDP touch look, and a real
 * touchscreen tap on the rendered card. Read-only QA logs provide fresh target
 * projections and measured Control rectangles. A timeout is a failure.
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const value = (name, fallback) => args.find((arg) => arg.startsWith(`${name}=`))?.slice(name.length + 1) || fallback;
const LANG = value('--lang', 'en') === 'id' ? 'id' : 'en';
const VISUAL_ONLY = args.includes('--visual-only');
const URL = value('--url', 'http://127.0.0.1:800/');
const OUT = path.resolve(ROOT, value('--out', `exports/qa-recovery-adaptation-${LANG}`));
const LIB_DIR = path.join(ROOT, 'tools', '.cache', 'al2023-lib', 'lib');
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const entry = path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium')));
  const compressed = path.join(entry, '..', 'bin', 'al2023.tar.br');
  const tar = path.join(ROOT, 'tools', '.cache', 'al2023.tar');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(compressed)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

fs.mkdirSync(OUT, { recursive: true });
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const clamp = (number, low, high) => Math.max(low, Math.min(high, number));
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

const lines = [];
const errors = [];
const frames = [];
const checks = {};
const layouts = {};
let completed = false;
let failure = '';
const page = await browser.newPage();
await page.setViewport({ width: 1280, height: 720, hasTouch: false, isMobile: false, deviceScaleFactor: 1 });
page.on('console', (message) => {
  const text = message.text();
  lines.push({ text, at: Date.now() });
  if (/Encounter:|Recovery:|Run upgrade:|Progression:|HUD:/.test(text)) console.log(text);
  if (/SCRIPT ERROR:|Parse Error:/.test(text)) errors.push(text);
});
page.on('pageerror', (error) => errors.push(String(error)));

const texts = () => lines.map((line) => line.text);
const has = (text, from = 0) => texts().slice(from).some((line) => line.includes(text));
const lastLogs = () => texts().slice(-35).join('\n');
const check = (name, condition, detail = '') => {
  checks[name] = Boolean(condition);
  console.log(`${condition ? 'PASS' : 'FAIL'} ${name}${detail ? ` · ${detail}` : ''}`);
  if (!condition) throw new Error(`${name}${detail ? `: ${detail}` : ''}`);
};
const until = async (predicate, timeoutMs) => {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (errors.length) throw new Error(errors.join('\n'));
    if (predicate()) return true;
    await delay(250);
  }
  return false;
};
const waitFor = async (text, timeoutMs = 180000, from = 0) => {
  if (!await until(() => has(text, from), timeoutMs)) {
    throw new Error(`Timeout waiting for ${text}\n${lastLogs()}`);
  }
};
const shot = async (name) => {
  await delay(350);
  const file = path.join(OUT, `${name}.png`);
  await page.screenshot({ path: file });
  frames.push(path.relative(ROOT, file));
  console.log(`FRAME ${path.relative(ROOT, file)}`);
};
const canvasMetrics = () => page.evaluate(() => {
  const canvas = document.querySelector('canvas');
  if (!canvas) return null;
  const rect = canvas.getBoundingClientRect();
  return {
    x: rect.x, y: rect.y, width: rect.width, height: rect.height,
    bufferWidth: canvas.width, bufferHeight: canvas.height,
  };
});
const latestRecovery = () => {
  const line = texts().reverse().find((entry) => entry.includes('Recovery QA:'));
  if (!line) return null;
  return {
    action: line.match(/\baction=([a-z]+)/)?.[1] || 'none',
    guards: Number(line.match(/\bguards=(\d+)/)?.[1] || 0),
    line,
  };
};
const latestTarget = (id) => {
  const line = texts().reverse().find((entry) => entry.includes(`Recovery Target QA: id=${id} `));
  if (!line) return null;
  return {
    id,
    x: Number(line.match(/\bx=(-?[\d.]+)/)?.[1]),
    y: Number(line.match(/\by=(-?[\d.]+)/)?.[1]),
    behind: line.includes('behind=yes'),
    line,
  };
};
const parseRects = (line) => {
  const rects = {};
  for (const match of line?.matchAll(/([A-Z_]+)=(-?\d+),(-?\d+),(-?\d+)x(-?\d+)/g) || []) {
    rects[match[1]] = { x: Number(match[2]), y: Number(match[3]), width: Number(match[4]), height: Number(match[5]) };
  }
  return rects;
};
const latestRects = (prefix) => parseRects(texts().reverse().find((line) => line.startsWith(prefix)));
const rectPoint = async (rect) => {
  const canvas = await canvasMetrics();
  if (!canvas || !rect) return null;
  return {
    x: canvas.x + (rect.x + rect.width / 2) * canvas.width / canvas.bufferWidth,
    y: canvas.y + (rect.y + rect.height / 2) * canvas.height / canvas.bufferHeight,
  };
};
const checkLayout = (name, rects, canvas) => {
  const inside = (rect) => rect && rect.width > 0 && rect.height > 0
    && rect.x >= 0 && rect.y >= 0
    && rect.x + rect.width <= canvas.bufferWidth + 1
    && rect.y + rect.height <= canvas.bufferHeight + 1;
  check(`${name} panel is inside the rendered canvas`, inside(rects.PANEL), JSON.stringify(rects.PANEL || null));
  for (const id of ['OVERCHARGE', 'QUICK_CYCLE']) {
    check(`${name} ${id} card is a visible touch target`, inside(rects[id]) && rects[id].height >= 44,
      JSON.stringify(rects[id] || null));
  }
  if (rects.OVERCHARGE && rects.QUICK_CYCLE) {
    const a = rects.OVERCHARGE;
    const b = rects.QUICK_CYCLE;
    const overlap = a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y;
    check(`${name} cards do not overlap`, !overlap);
  }
};

const cdp = await page.target().createCDPSession();
const dragLook = async (dx, dy) => {
  const canvas = await canvasMetrics();
  if (!canvas) throw new Error('Cannot look without a canvas');
  const scaleX = canvas.width / canvas.bufferWidth;
  const scaleY = canvas.height / canvas.bufferHeight;
  const start = { x: canvas.x + canvas.width * 0.56, y: canvas.y + canvas.height * 0.60, id: 17 };
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [start] });
  await delay(35);
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchMove',
    touchPoints: [{ ...start, x: start.x + dx * scaleX, y: start.y + dy * scaleY }],
  });
  await delay(65);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await delay(260);
};
const alignTarget = async (id) => {
  for (let iteration = 0; iteration < 45; iteration += 1) {
    const target = latestTarget(id);
    const canvas = await canvasMetrics();
    if (!canvas) throw new Error('Canvas disappeared during aim');
    if (!target) {
      await delay(300);
      continue;
    }
    if (target.behind) {
      await dragLook(70, 0);
      continue;
    }
    const errorX = target.x - canvas.bufferWidth / 2;
    const errorY = target.y - canvas.bufferHeight / 2;
    if (Math.abs(errorX) <= 12 && Math.abs(errorY) <= 24) {
      console.log(`AIM ${id} ${target.line}`);
      return target;
    }
    await dragLook(clamp(errorX, -55, 55), clamp(errorY * 0.3, -30, 30));
  }
  throw new Error(`Could not align ${id}\n${lastLogs()}`);
};
const eliminateGuard = async (id) => {
  for (let burst = 0; burst < 9; burst += 1) {
    if (has('Run upgrade: primary guards cleared')) return;
    await alignTarget(id);
    const before = latestRecovery()?.guards ?? 2;
    await page.mouse.down({ button: 'left' });
    const dropped = await until(() => {
      const guards = latestRecovery()?.guards ?? before;
      return guards < before || has('Run upgrade: primary guards cleared');
    }, 1450);
    await page.mouse.up({ button: 'left' });
    await delay(300);
    if (dropped || (latestRecovery()?.guards ?? before) < before) {
      console.log(`GUARD CLEAR ${id}`);
      return;
    }
  }
  throw new Error(`Real Pulse fire did not eliminate ${id}\n${lastLogs()}`);
};

try {
  const url = new URL(URL);
  url.searchParams.set('qa_recovery', '1');
  url.searchParams.set('qa_touch', '1');
  url.searchParams.set('qa_camera', '1');
  url.searchParams.set('lang', LANG);
  await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 90000 });
  await page.waitForFunction(() => {
    const enter = document.getElementById('opening-enter');
    return enter && !enter.disabled;
  }, { timeout: 180000 });
  await page.click('#opening-enter');
  await page.waitForFunction(() => document.body.dataset.screen === 'hero', { timeout: 20000 });
  await page.waitForFunction(() => window.AegisHeroStage?.describe()?.ready, { timeout: 60000 });
  await page.click('#hero-next');
  await page.waitForFunction(() => document.body.dataset.screen === 'hub', { timeout: 20000 });
  await page.click('#world-card-verdant-bloom');
  await page.waitForFunction(() => document.getElementById('world-card-verdant-bloom')?.getAttribute('aria-selected') === 'true');
  await shot(`01-hub-${LANG}`);
  await page.click('#hub-deploy');
  await waitFor('Encounter: Explore safe', 300000);
  await delay(800);
  check('Verdant gameplay boots through the ordinary shell', latestRecovery() !== null);
  await shot(`02-landing-${LANG}`);

  const canvas = await canvasMetrics();
  await page.mouse.click(canvas.x + canvas.width / 2, canvas.y + canvas.height / 2);
  await page.keyboard.down('KeyW');
  await delay(1500);
  await page.keyboard.up('KeyW');
  await page.keyboard.down('KeyD');
  await delay(2500);
  await page.keyboard.up('KeyD');
  if (latestRecovery()?.action !== 'engage') {
    await page.keyboard.down('KeyW');
    const offered = await until(() => latestRecovery()?.action === 'engage', 60000);
    await page.keyboard.up('KeyW');
    check('Seed Vault offers Engage after real movement', offered);
  }
  await shot(`03-engage-${LANG}`);
  await page.keyboard.press('KeyB');
  check('Engage spawns two live guards', await until(() => latestRecovery()?.guards === 2, 20000));
  await waitFor('Recovery Target QA: id=Guard_verdant_seed_vault_01', 20000);
  await waitFor('Recovery Target QA: id=Guard_verdant_seed_vault_02', 20000);
  const models = new Set(texts().map((line) => line.match(/EnemyVisual\[(Guard_verdant_seed_vault_[^\]]+)\].*fallback=no/)?.[1]).filter(Boolean));
  check('Both guards attach real GLB visuals', models.size === 2, [...models].join(', '));
  await shot(`04-guarded-${LANG}`);

  const metrics = await canvasMetrics();
  await page.mouse.move(metrics.x + metrics.width / 2, metrics.y + metrics.height / 2);
  await page.mouse.down({ button: 'right' });
  check('ADS engages through real mouse input', await until(() => texts().some((line) => {
    const match = line.match(/Camera QA: aim=true blend=([\d.]+)/);
    return match && Number(match[1]) >= 0.95;
  }), 30000));
  await eliminateGuard('Guard_verdant_seed_vault_01');
  await eliminateGuard('Guard_verdant_seed_vault_02');
  await waitFor('Run upgrade: primary guards cleared', 20000);
  await page.mouse.up({ button: 'left' }).catch(() => {});
  await page.mouse.up({ button: 'right' }).catch(() => {});
  check('Guard clear earns the adaptation offer', has('Run upgrade: primary guards cleared'));

  check('Desktop adaptation layout is reported', await until(() => {
    const rects = latestRects('RunUpgrade QA:');
    return rects.PANEL && rects.OVERCHARGE && rects.QUICK_CYCLE;
  }, 15000));
  layouts.desktop = latestRects('RunUpgrade QA:');
  await checkLayout('Desktop', layouts.desktop, await canvasMetrics());
  await shot(`05-adaptation-desktop-${LANG}`);

  const mobileMark = lines.length;
  await page.setViewport({ width: 844, height: 390, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  check('Phone adaptation layout is reported after resize', await until(() => {
    if (lines.length <= mobileMark) return false;
    const rects = latestRects('RunUpgrade QA:');
    return rects.PANEL && rects.OVERCHARGE?.width > 100 && rects.QUICK_CYCLE?.width > 100;
  }, 20000));
  await delay(700);
  layouts.phone = latestRects('RunUpgrade QA:');
  await checkLayout('Phone', layouts.phone, await canvasMetrics());
  await shot(`06-adaptation-phone-${LANG}`);

  const quickCyclePoint = await rectPoint(layouts.phone.QUICK_CYCLE);
  check('QUICK CYCLE has a measured phone tap point', quickCyclePoint !== null);
  await page.touchscreen.tap(quickCyclePoint.x, quickCyclePoint.y);
  await waitFor('Run upgrade: selected quick_cycle', 20000);
  const selection = texts().reverse().find((line) => line.includes('Run upgrade: selected quick_cycle'));
  check('Real phone tap applies Quick Cycle reload scaling', /reload=1\.08/.test(selection || ''), selection || 'missing');
  check('Card selection restores earned Secure', await until(() => latestRecovery()?.action === 'secure', 15000));
  await shot(`07-secure-phone-${LANG}`);

  const startPoint = await rectPoint(latestRects('Touch QA:').START);
  check('Secure has a measured phone control', startPoint !== null);
  await page.touchscreen.tap(startPoint.x, startPoint.y);
  await waitFor('Recovery: secured verdant_seed_vault', 20000);
  check('Secure grants the real permanent Arc transaction', has('Recovery: secured verdant_seed_vault · reward verdant_arc_blueprint'));
  await shot(`08-extraction-phone-${LANG}`);

  if (!VISUAL_ONLY) {
    // Extraction's primary Extract button owns focus; the next control is Continue.
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await waitFor('Encounter: Preparing Defense', 20000);
    await waitFor('Encounter: Defense started', 300000);
    check('Continue enters real Endless Defense', has('Encounter: Defense started'));
    await shot(`09-endless-phone-${LANG}`);

    await page.keyboard.press('Escape');
    await waitFor('HUD: paused', 15000);
    await shot(`10-pause-run-only-${LANG}`);
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await waitFor('Encounter: Results after wave 1', 30000);
    check('Finishing Endless reaches actual Results', has('Encounter: Results after wave 1'));
    check('The existing run banks exactly once', texts().filter((line) => line.includes('Progression: banked +')).length === 1);
    await shot(`11-results-run-only-${LANG}`);

    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await waitFor('Encounter: Returned to Explore', 20000);
    await page.keyboard.press('Escape');
    await waitFor('HUD: paused', 15000);
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.body.dataset.screen === 'hub', { timeout: 90000 });
    check('Pause Home returns to the real hub', true);
    await shot(`12-hub-after-run-${LANG}`);

    await page.waitForFunction(() => {
      const deploy = document.getElementById('hub-deploy');
      return deploy && !deploy.disabled;
    }, { timeout: 180000 });
    const redeployMark = lines.length;
    await page.click('#hub-deploy');
    await waitFor('Encounter: Explore safe', 300000, redeployMark);
    check('Redeploy starts a fresh playable deployment', has('Encounter: Explore safe', redeployMark));
    check('Redeploy does not inherit the old selection', !has('Run upgrade: selected', redeployMark));
    await page.keyboard.press('KeyU');
    await delay(1400);
    await shot(`13-armory-persistent-blueprint-${LANG}`);
    await page.keyboard.press('Escape');
    await delay(400);
    await page.keyboard.press('Escape');
    await waitFor('HUD: paused', 15000, redeployMark);
    await shot(`14-redeploy-reset-${LANG}`);
  }

  check('No Godot script or browser page errors', errors.length === 0, errors.join(' | '));
  completed = true;
  console.log(`PASS: ${LANG} ${VISUAL_ONLY ? 'adaptation visual route' : 'complete Recovery adaptation route'}`);
} catch (error) {
  failure = String(error.stack || error);
  console.error(failure);
  console.error(lastLogs());
  await shot('failure').catch(() => {});
} finally {
  await page.mouse.up({ button: 'left' }).catch(() => {});
  await page.mouse.up({ button: 'right' }).catch(() => {});
  await browser.close();
  const report = {
    ok: completed && errors.length === 0,
    lang: LANG,
    visualOnly: VISUAL_ONLY,
    url: URL,
    checks,
    layouts,
    frames,
    errors,
    failure,
    transitions: texts().filter((line) => /Encounter:|Recovery:|Run upgrade:|Progression:/.test(line)),
  };
  fs.writeFileSync(path.join(OUT, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
  if (!report.ok) process.exitCode = 1;
}
