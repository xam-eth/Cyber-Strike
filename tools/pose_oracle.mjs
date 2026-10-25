#!/usr/bin/env node
/**
 * tools/pose_oracle.mjs -- pose hero.glb in a browser and look at it.
 *
 *   node tools/pose_oracle.mjs '{"flare": {"R_Upperarm": ["Z", -118], "L_Upperarm": ["Z", 118]}}'
 *
 * Writes /tmp/pose-<variant>.png per variant.
 *
 * Why: a celebration is authored in Blender (tools/blender/author_celebrations.py),
 * and Blender is a slow loop for questions like "does +Z on this bone raise the
 * arm or twist it?". Every such question is a single screenshot here -- same
 * GLB, same skeleton, same world-axis vocabulary as the authoring script, no CI
 * round trip. The numbers that survive this oracle are the numbers written into
 * the Blender timeline.
 *
 * A variant is { bone: [worldAxis, degrees] }, world axes X (the character's
 * left), Y (up) and Z (the way the character faces). Only the bones named are
 * touched, and every variant starts from the rig's own idle pose.
 */

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const root = process.cwd();
const types = { '.js': 'text/javascript', '.glb': 'model/gltf-binary', '.png': 'image/png' };
const HARNESS = `<!doctype html><html><head><meta charset="utf-8">
<script type="importmap">{"imports":{"three":"/ui/vendor/three/three.module.min.js","three/addons/":"/ui/vendor/three/addons/"}}</script>
</head><body style="margin:0;background:#0b0f13">
<canvas id="c" width="420" height="560"></canvas>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setSize(420, 560, false);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.9;
const scene = new THREE.Scene();
scene.background = new THREE.Color('#0b0f13');
scene.add(new THREE.HemisphereLight(0xdfe6ee, 0x121417, 0.9));
const key = new THREE.DirectionalLight(0xffffff, 2.0); key.position.set(2.2, 3.4, 3.2); scene.add(key);
const camera = new THREE.PerspectiveCamera(26, 420/560, 0.01, 100);
new GLTFLoader().load('/game/assets/characters/hero/hero.glb', (gltf) => {
  const model = gltf.scene;
  scene.add(model);
  const mixer = new THREE.AnimationMixer(model);
  const idle = gltf.animations.find(a => a.name === 'idle');
  if (idle) { mixer.clipAction(idle).play(); mixer.update(0.2); }
  const rest = new Map();
  model.traverse((n) => { if (n.isBone) rest.set(n, { q: n.quaternion.clone(), p: n.position.clone() }); });
  window.__apply = (spec) => {
    for (const [bone, value] of rest) { bone.quaternion.copy(value.q); bone.position.copy(value.p); }
    if (idle) { mixer.setTime(0.2); }
    model.updateMatrixWorld(true);
    for (const [name, [axis, deg]] of Object.entries(spec)) {
      const bone = model.getObjectByName(name);
      if (!bone) continue;
      // "lX/lY/lZ" rotate about the bone's own axis, exactly the way a Blender
      // pose bone does; "X/Y/Z" rotate about a world axis, which is what the
      // authoring timeline means when it says "abduct".
      let local;
      if (axis.startsWith('l')) {
        local = new THREE.Vector3(...(axis === 'lX' ? [1,0,0] : axis === 'lY' ? [0,1,0] : [0,0,1]));
      } else {
        const qw = bone.getWorldQuaternion(new THREE.Quaternion()).invert();
        const world = new THREE.Vector3(...(axis === 'X' ? [1,0,0] : axis === 'Y' ? [0,1,0] : [0,0,1]));
        local = world.clone().applyQuaternion(qw).normalize();
      }
      bone.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(local, deg * Math.PI / 180));
      bone.updateMatrixWorld(true);
    }
    const box = new THREE.Box3().setFromObject(model);
    const h = box.max.y - box.min.y;
    const d = h / (2 * Math.tan(THREE.MathUtils.degToRad(26) / 2)) * 1.06;
    camera.position.set((box.max.x + box.min.x)/2, box.min.y + h/2, (box.max.z + box.min.z)/2 + d);
    camera.lookAt((box.max.x + box.min.x)/2, box.min.y + h/2, (box.max.z + box.min.z)/2);
    camera.updateProjectionMatrix();
    renderer.render(scene, camera);
    return { height: Number(h.toFixed(3)) };
  };
  window.__ready = true;
}).catch(e => { window.__err = String(e); });
</script></body></html>`;

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/__pose') { res.writeHead(200, { 'content-type': 'text/html' }); res.end(HARNESS); return; }
  const file = path.join(root, url);
  if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(8143, '0.0.0.0', r));

const browser = await puppeteer.launch({ executablePath: await chromium.executablePath(), args: [...chromium.args, '--no-sandbox', '--enable-unsafe-swiftshader'], headless: true });
const page = await browser.newPage();
await page.setViewport({ width: 420, height: 560, deviceScaleFactor: 2 });
await page.goto('http://127.0.0.1:8143/__pose', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.__ready || window.__err, { timeout: 60000 });
const variants = JSON.parse(process.argv[2]);
for (const [name, spec] of Object.entries(variants)) {
  const info = await page.evaluate((s) => window.__apply(s), spec);
  await new Promise((r) => setTimeout(r, 250));
  await page.screenshot({ path: `/tmp/pose-${name}.png` });
  console.log(name, JSON.stringify(info));
}
await browser.close();
server.close();
