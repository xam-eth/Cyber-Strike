#!/usr/bin/env node
/**
 * tools/hero_tier_sheet.mjs — render every tier of a hero from its own GLB.
 *
 *   node tools/hero_tier_sheet.mjs [--hero human_hero_tiers] [--tiers 1,2,3,4,5]
 *                                  [--out /tmp/tier-sheet] [--size 420]
 *
 * The operative screen claims a tier changes the operative's costume. That is a
 * claim about five files, so it is answered by five renders: one frame per tier,
 * shot from the same camera, the same lights and the same pose, so a difference
 * between two frames is a difference in the costume and nothing else.
 *
 * The lights and the camera are the stage's (ui/hero_stage.js), deliberately:
 * a contact sheet shot under other light would not show what the player sees.
 */

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(name);
  return i === -1 ? fallback : argv[i + 1];
};

const HERO_DIR = flag('--hero', 'human_hero_tiers');
const TIERS = flag('--tiers', '1,2,3,4,5')
  .split(',')
  .map((n) => Number(n.trim()))
  .filter((n) => Number.isFinite(n));
const OUT = path.resolve(ROOT, flag('--out', '/tmp/tier-sheet'));
const WIDTH = Number(flag('--width', flag('--size', 420)));
const HEIGHT = Number(flag('--height', flag('--size', 420)));
const PREFIX = flag('--prefix', 'tier');
const PORT = Number(flag('--port', '8188'));

const TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.glb': 'model/gltf-binary',
  '.json': 'application/json',
};

const HARNESS = `<!doctype html>
<html><head><meta charset="utf-8" />
<script type="importmap">
{ "imports": { "three": "/ui/vendor/three/three.module.min.js", "three/addons/": "/ui/vendor/three/addons/" } }
</script>
</head><body style="margin:0;background:#0a0e13">
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const W = ${WIDTH};
const H = ${HEIGHT};
const canvas = document.createElement('canvas');
canvas.width = W;
canvas.height = H;
document.body.appendChild(canvas);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(W, H, false);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.74;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0a0e13);
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.5;
pmrem.dispose();

// The stage's own white lights (ui/hero_stage.js), not a studio setup.
scene.add(new THREE.HemisphereLight(0xdfe6ee, 0x121417, 0.55));
const key = new THREE.DirectionalLight(0xffffff, 1.5);
key.position.set(2.2, 3.4, 3.2);
scene.add(key);
const rim = new THREE.DirectionalLight(0xf2f6ff, 1.35);
rim.position.set(-2.6, 2.4, -2.2);
scene.add(rim);
const fill = new THREE.DirectionalLight(0xe8eef6, 0.5);
fill.position.set(-2.8, 1.4, 2.4);
scene.add(fill);

const camera = new THREE.PerspectiveCamera(27, W / H, 0.01, 100);

window.__render = (url) =>
  new Promise((resolve) => {
    new GLTFLoader().load(
      url,
      (gltf) => {
        const model = gltf.scene;
        model.traverse((node) => {
          if (!node.isMesh) return;
          node.frustumCulled = false;
          for (const material of [].concat(node.material)) {
            if (material && material.isMeshStandardMaterial) {
              material.envMapIntensity = 0.9;
              material.roughness = Math.min(material.roughness ?? 0.7, 0.55);
              material.metalness = Math.max(material.metalness ?? 0.1, 0.35);
            }
          }
        });
        if (gltf.animations.length) {
          const mixer = new THREE.AnimationMixer(model);
          const idle = gltf.animations.find((clip) => clip.name === 'idle') || gltf.animations[0];
          const action = mixer.clipAction(idle);
          action.play();
          mixer.update(0.4);
        }
        scene.add(model);
        const box = new THREE.Box3().setFromObject(model);
        const centre = box.getCenter(new THREE.Vector3());
        const size = box.getSize(new THREE.Vector3());
        const visible = Math.max(size.y, size.x) * 1.16;
        const distance = visible / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2));
        camera.position.set(centre.x, box.min.y + size.y * 0.5, centre.z + distance);
        camera.lookAt(centre.x, box.min.y + size.y * 0.48, centre.z);
        camera.updateProjectionMatrix();
        renderer.render(scene, camera);
        resolve({
          height: Number(size.y.toFixed(3)),
          width: Number(size.x.toFixed(3)),
          depth: Number(size.z.toFixed(3)),
          clips: gltf.animations.map((clip) => clip.name),
          image: canvas.toDataURL('image/png'),
        });
      },
      undefined,
      (error) => resolve({ error: String(error && error.message ? error.message : error) }),
    );
  });
window.__harnessReady = true;
</script></body></html>`;

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/__sheet') {
    res.writeHead(200, { 'content-type': 'text/html' });
    res.end(HARNESS);
    return;
  }
  const file = path.join(ROOT, url);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    res.end('missing');
    return;
  }
  res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

await new Promise((resolve) => server.listen(PORT, '0.0.0.0', resolve));
fs.mkdirSync(OUT, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 420000,
});
const page = await browser.newPage();
page.on('pageerror', (error) => console.warn('PAGEERROR', String(error).split('\n')[0]));
await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: 1 });
await page.goto(`http://127.0.0.1:${PORT}/__sheet`, { waitUntil: 'domcontentloaded', timeout: 90000 });
await page.waitForFunction('window.__harnessReady === true', { timeout: 60000 });

const report = [];
for (const tier of TIERS) {
  const file = `/game/assets/characters/${HERO_DIR}/hero_human_tier_${tier}.glb`;
  const result = await page.evaluate((url) => window.__render(url), file);
  if (result.error) {
    console.error(`tier ${tier}: ${result.error}`);
    continue;
  }
  const out = path.join(OUT, `${PREFIX}-${tier}.png`);
  fs.writeFileSync(out, Buffer.from(result.image.split(',')[1], 'base64'));
  report.push({ tier, file, out, ...result, image: undefined });
  console.log(
    `tier ${tier}: ${result.width}x${result.height}x${result.depth} units, ` +
      `${result.clips.length} clips -> ${path.relative(ROOT, out)}`,
  );
}

await page.evaluate(() => window.__dispose && window.__dispose());
await browser.close();
server.close();
fs.writeFileSync(path.join(OUT, 'sheet.json'), JSON.stringify(report, null, 2));
console.log(`TIER SHEET OK: ${report.length} frames in ${path.relative(ROOT, OUT)}`);
