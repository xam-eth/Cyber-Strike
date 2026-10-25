#!/usr/bin/env node
/**
 * tools/hero_portrait.mjs — bake the roster portrait from the rig itself.
 *
 *   node tools/hero_portrait.mjs [--out ui/art/web/hero-portrait.png] [--size 512]
 *
 * The roster card next to the hero's name used to show a painted half-body of a
 * woman in grey armour. That picture is not the player's character: the rig in
 * game/assets/characters/hero/hero.glb is a white-and-cyan exo-suit, so the card
 * and the stage disagreed about who the player was looking at -- and the card
 * kept disagreeing after every re-export. The card is now a frame of the model,
 * shot from the same light rig as the live stage (ui/hero_stage.js), so the two
 * can never drift apart.
 *
 * It is a render, not a screenshot of the page: the harness below loads the GLB
 * in the pinned Chromium with three.js, frames the head and shoulders by the
 * model's own bounds, and hands back a transparent PNG. Re-run it after a rig
 * change; nothing else has to know.
 *
 * Deliberately not used for the stage itself. The stage renders live, because a
 * character screen that shows a picture cannot answer a livery change, and the
 * whole point of a hero page is that it answers.
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

const OUT = path.resolve(ROOT, flag('--out', 'ui/art/web/hero-portrait.png'));
const SIZE = Number(flag('--size', 512));
const PORT = Number(flag('--port', '8137'));

const TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.glb': 'model/gltf-binary',
  '.json': 'application/json',
};

const HARNESS = `<!doctype html>
<html><head><meta charset="utf-8" />
<script type="importmap">
{ "imports": { "three": "/ui/vendor/three/three.module.min.js", "three/addons/": "/ui/vendor/three/addons/" } }
</script>
</head><body style="margin:0;background:transparent">
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const SIZE = ${SIZE};
const canvas = document.createElement('canvas');
canvas.width = SIZE;
canvas.height = SIZE;
document.body.appendChild(canvas);

const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(SIZE, SIZE, false);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.74;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.42;
pmrem.dispose();

// Same three lights as the live stage: the card must not be a different photo.
scene.add(new THREE.HemisphereLight(0xa8dcff, 0x0a1218, 0.5));
const key = new THREE.DirectionalLight(0xdff1ff, 1.35);
key.position.set(2.2, 3.4, 3.2);
scene.add(key);
const rim = new THREE.DirectionalLight(0x6fd8ff, 2.1);
rim.position.set(-2.6, 2.4, -2.2);
scene.add(rim);
const warm = new THREE.DirectionalLight(0xffb056, 0.75);
warm.position.set(-2.8, 1.4, 2.4);
scene.add(warm);

const camera = new THREE.PerspectiveCamera(24, 1, 0.01, 100);

new GLTFLoader().load('/game/assets/characters/hero/hero.glb', (gltf) => {
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
  scene.add(model);

  // Head-and-shoulders from the rig's own proportions, so a re-scaled export
  // still frames the face.
  const box = new THREE.Box3().setFromObject(model);
  const height = box.max.y - box.min.y;
  const centreX = (box.max.x + box.min.x) / 2;
  const centreZ = (box.max.z + box.min.z) / 2;
  const eyeLine = box.min.y + height * 0.87;
  const visible = height * 0.34;
  const distance = visible / (2 * Math.tan(THREE.MathUtils.degToRad(24) / 2));
  camera.position.set(centreX + height * 0.06, eyeLine - visible * 0.06, centreZ + distance);
  camera.lookAt(centreX, eyeLine - visible * 0.12, centreZ);
  camera.updateProjectionMatrix();

  renderer.render(scene, camera);
  window.__portrait = canvas.toDataURL('image/png');
}, undefined, (error) => {
  window.__portrait = 'ERROR ' + String(error && error.message ? error.message : error);
});
</script></body></html>`;

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/__portrait') {
    res.writeHead(200, { 'content-type': 'text/html' });
    res.end(HARNESS);
    return;
  }
  const file = path.join(ROOT, url);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    res.end('not found');
    return;
  }
  res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((resolve) => server.listen(PORT, '0.0.0.0', resolve));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
});

try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(String(error).split('\n')[0]));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text().slice(0, 200));
  });
  await page.setViewport({ width: SIZE, height: SIZE });
  await page.goto(`http://127.0.0.1:${PORT}/__portrait`, { waitUntil: 'domcontentloaded' });
  const data = await page.waitForFunction(() => window.__portrait, { timeout: 60000 }).then((handle) => handle.jsonValue());
  if (typeof data !== 'string' || !data.startsWith('data:image/png')) {
    throw new Error(`portrait render failed: ${data}`);
  }
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, Buffer.from(data.split(',')[1], 'base64'));
  console.log(`portrait ${path.relative(ROOT, OUT)}  ${SIZE}x${SIZE}${errors.length ? `  (${errors.length} console errors)` : ''}`);
} finally {
  await browser.close();
  server.close();
}
