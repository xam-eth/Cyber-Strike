#!/usr/bin/env node
/*
 * tools/operative_evidence.mjs — photograph the operative page doing its job.
 *
 *   node tools/operative_evidence.mjs                     # 844x390 and 667x375
 *   node tools/operative_evidence.mjs --viewport 844x390
 *
 * Round 13 turns the hero screen into an operative page with two card groups and
 * two pieces of motion that carry meaning, so a still of the resting page is not
 * evidence of anything. This drives the real page in the routed shell and takes
 * five frames per viewport and language:
 *
 *   resting      the page at rest (what the screen looks like when you arrive)
 *   hero         a press on the other operative -> the body enters from the RIGHT
 *   tier         a press on a higher rank    -> the body drops from the TOP,
 *                                               under the beam, with the banner
 *   rack         the weapon modal, opened from LOADOUT
 *   locked       a press on an in-development slot -> refused, page unchanged
 *
 * `?lang=` selects the language and each frame records `document.documentElement
 * .lang`, so a frame cannot silently belong to the other language.
 */
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const argv = process.argv.slice(2);
const flag = (name, def) => {
  const index = argv.indexOf(name);
  return index === -1 ? def : argv[index + 1];
};
const root = process.cwd();
const outDir = path.resolve(root, flag('--out', 'qa-evidence/ui/round-13/operative'));
const viewports = flag('--viewport') ? [flag('--viewport')] : ['844x390', '667x375'];
const port = Number(flag('--port', '8177'));
fs.mkdirSync(outDir, { recursive: true });

const types = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.glb': 'model/gltf-binary',
};

const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    res.end();
    return;
  }
  res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((resolve) => server.listen(port, '0.0.0.0', resolve));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 420000,
});

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const frames = [];
let failures = 0;

/* Wait for the stage to have a body on it. Every capture is taken from a state
   the page reports, never from a guessed delay. */
async function stageReady(page) {
  await page
    .waitForFunction(
      () => {
        const stage = window.AegisHeroStage?.describe?.();
        return (
          document.querySelector('#hero-canvas')?.dataset.state === 'ready' &&
          stage?.ready &&
          stage?.rifleVisible &&
          stage?.socketParent === 'R_Hand'
        );
      },
      { timeout: 60000 },
    )
    .catch(() => null);
}

for (const viewport of viewports) {
  const [width, height] = viewport.split('x').map(Number);
  for (const locale of ['en', 'id']) {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', (error) => errors.push(String(error).split('\n')[0]));
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(message.text().slice(0, 160));
    });
    await page.setViewport({ width, height, deviceScaleFactor: 1, hasTouch: true });
    await page.goto(`http://127.0.0.1:${port}/index.html?lang=${locale}&ui=hero&ui_hold=1`, {
      waitUntil: 'domcontentloaded',
    });
    await page.waitForFunction(
      () =>
        document.querySelector('#screen-hero')?.dataset.active === 'true' &&
        document.querySelector('#screen-hero')?.dataset.ready === 'true',
      { timeout: 30000 },
    );
    await stageReady(page);
    // The arrival beat is 0.62 s; wait it out so "resting" is the resting page.
    await sleep(1200);

    const shot = async (name) => {
      const file = path.join(outDir, `${name}-${viewport}-${locale}.png`);
      await page.screenshot({ path: file });
      const evidence = await page.evaluate(() => {
        const rect = (selector) => {
          const element = document.querySelector(selector);
          if (!element) return null;
          const box = element.getBoundingClientRect();
          return {
            x: box.x,
            y: box.y,
            width: box.width,
            height: box.height,
            right: box.right,
            bottom: box.bottom,
          };
        };
        return {
          lang: document.documentElement.lang,
          stage: window.AegisHeroStage?.describe?.() || null,
          horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
          weaponTier: document.querySelector('#hero-weapon-tier')?.textContent || '',
          weaponNext: document.querySelector('#hero-weapon-next')?.textContent || '',
          layout: {
            sable: rect('#hero-roster .card[data-hero="sable"]'),
            tier: rect('#hero-tiers .card[data-tier="1"]'),
            heroGroup: rect('.op__group--heroes'),
            tierGroup: rect('.op__group--tiers'),
            weapon: rect('.op__weapon'),
            groups: rect('.op__groups'),
            role: document.querySelector('#hero-roster .card[data-hero="sable"] .card__role')?.textContent || '',
          },
        };
      });
      if (name === 'resting') {
        const layout = evidence.layout;
        const valid = layout.sable && layout.tier && layout.heroGroup && layout.tierGroup
          && layout.weapon && layout.groups
          && layout.tierGroup.x < layout.heroGroup.x
          && layout.heroGroup.width > layout.tierGroup.width
          && layout.sable.width > layout.tier.width * 1.5
          && layout.sable.height > layout.tier.height
          && layout.tier.height >= 44
          && layout.weapon.bottom <= layout.groups.y + 1
          && layout.role.length > 0;
        if (!valid) {
          failures += 1;
          console.error(`FAIL operative hierarchy ${viewport} ${locale}: ${JSON.stringify(layout)}`);
        }
      }
      if (evidence.horizontalOverflow || (name !== 'tier-top' && !evidence.stage?.rifleVisible)) {
        failures += 1;
        console.error(`FAIL ${name} ${viewport} ${locale}: ${JSON.stringify(evidence)}`);
      }
      frames.push({ name, viewport, locale, ...evidence, file: path.relative(root, file) });
      console.log(`FRAME ${name.padEnd(9)} ${viewport} lang=${locale}`);
    };

    await shot('resting');

    /* Wait for a beat to be in flight rather than sleeping and hoping. The
       stage reports the body's own offset in model units (the rig is 1.0 tall),
       so "it moved" is a measurement, not an impression. A frame taken with the
       body already home would be a picture of nothing happening. */
    const inFlight = (axis, minimum) =>
      page.waitForFunction(
        ([index, floor]) => {
          const entrance = window.AegisHeroStage?.describe?.().entrance;
          const offset = entrance?.offset;
          return Boolean(offset) && Math.abs(offset[index]) >= floor;
        },
        { timeout: 6000, polling: 16 },
        [axis, minimum],
      );

    // --- a hero press: enters from the RIGHT ------------------------------
    // Only SABLE is fieldable, so pressing its own card replays the entrance --
    // which is exactly what a player gets when they press the operative they
    // already have. The locked slot is checked separately below.
    await page.click('#hero-roster .card[data-hero="sable"]');
    await inFlight(0, 0.12).catch(() => null);
    const heroBeat = await page.evaluate(() => ({
      entrance: window.AegisHeroStage.describe().entrance,
      enter: document.querySelector('#screen-hero').dataset.enter,
    }));
    await shot('hero-right');
    if (!(heroBeat.entrance.offset[0] >= 0.12)) {
      failures += 1;
      console.error(`FAIL ${viewport} ${locale}: the hero press did not slide in (${JSON.stringify(heroBeat)})`);
    }

    // --- a tier press: drops from the TOP --------------------------------
    await page.click('#hero-tiers .card[data-tier="3"]');
    await inFlight(1, 0.2).catch(() => null);
    const tierBeat = await page.evaluate(() => ({
      entrance: window.AegisHeroStage.describe().entrance,
      enter: document.querySelector('#screen-hero').dataset.enter,
      celebrating: document.querySelector('#screen-hero').dataset.celebrate,
    }));
    await shot('tier-top');
    if (!(tierBeat.entrance.offset[1] >= 0.2) || tierBeat.enter !== 'top') {
      failures += 1;
      console.error(`FAIL ${viewport} ${locale}: the tier press did not drop from the top (${JSON.stringify(tierBeat)})`);
    }
    await sleep(2600);
    await stageReady(page);
    await shot('tier-settled');
    const settled = await page.evaluate(() => window.AegisHeroStage.describe());
    if (settled.tier !== 3 || !settled.modelUrl.includes('tier_3') || !settled.rifleVisible) {
      failures += 1;
      console.error(`FAIL ${viewport} ${locale}: tier/weapon did not settle (${JSON.stringify(settled)})`);
    }

    // --- a locked slot is refused ----------------------------------------
    const before = await page.evaluate(() => ({
      tier: document.querySelector('#hero-tier-number').textContent,
    }));
    await page.click('#hero-roster .card[data-hero="kestrel"]', { force: true }).catch(() => null);
    await sleep(160);
    const after = await page.evaluate(() => ({
      tier: document.querySelector('#hero-tier-number').textContent,
      name: document.querySelector('#hero-name').textContent,
    }));
    if (after.name !== 'Mara Voss') {
      failures += 1;
      console.error(`FAIL ${viewport} ${locale}: a locked slot changed the operative to ${after.name}`);
    }
    frames.push({ name: 'locked-refused', viewport, locale, before, after });

    // --- the rack --------------------------------------------------------
    await page.click('#hero-loadout');
    await page.waitForSelector('#weapon-modal:not([hidden])', { timeout: 5000 });
    await sleep(220);
    await shot('rack');
    await page.keyboard.press('Escape');
    await sleep(220);

    if (errors.length) {
      failures += 1;
      console.error(`FAIL ${viewport} ${locale}: ${JSON.stringify(errors.slice(0, 3))}`);
    }
    await page.close();
  }
}

fs.writeFileSync(
  path.join(outDir, 'manifest.json'),
  JSON.stringify({ tag: 'round-13-operative', frames, failures, generatedAt: new Date().toISOString() }, null, 2) + '\n',
);

await browser.close();
server.close();
console.log(`${frames.length} frame(s) written to ${path.relative(root, outDir)} (${failures} failed)`);
process.exit(failures === 0 ? 0 : 1);
