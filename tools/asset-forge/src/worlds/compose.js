/**
 * compose.js — turn a world's data into a scene.
 *
 * Each world module (`frostline.js`, `verdant.js`, `emberfall.js`, `titans.js`) is *data*:
 * a theme, a layout, a terrain configuration and a landmark list. This file is
 * the one builder they all share, so the mission worlds cannot drift apart in
 * behaviour — only in art direction and in what is placed.
 *
 * It creates no geometry. Every mesh comes from `realModels.js`, which loads a
 * licensed GLB and tags it `userData.realSource`; the capture gate fails the run
 * if a single mesh lacks that tag.
 *
 *   const world = await composeWorld(FROSTLINE);
 *   const mixer = new THREE.AnimationMixer(world.root);
 *   world.clips.forEach((c) => mixer.clipAction(c).play());
 */
import * as THREE from 'three';
import { makePart, setWorldGrade } from './realModels.js';
import { buildRole } from './assemblyReal.js';
import { buildTerrainLayer, seeded } from './terrainKit.js';

/** Worlds share one scatter rule: deterministic tilt and scale from position. */
async function scatterProps(world, specs, districtName) {
  const root = new THREE.Group();
  root.name = 'Scatter';
  const clips = [];
  const counts = {};
  const sources = [];

  for (const [roleId, entries] of Object.entries(world.scatter ?? {})) {
    const spec = specs[roleId];
    if (!spec) throw new Error(`${world.id}: scatter role "${roleId}" has no spec`);
    for (const [i, entry] of entries.entries()) {
      const [x, z, scale = 1, yaw = 0] = entry;
      const jitter = seeded(i, 13);
      const built = await buildRole(spec, {
        name: `${spec.title.replace(/\s+/g, '')}_${String(i).padStart(2, '0')}`,
        pos: [x, 0, z],
        yaw: yaw + jitter * 90,
        scale: [scale, scale * (0.85 + jitter * 0.4), scale],
        district: districtName,
      });
      root.add(built.root);
      clips.push(...built.clips);
      sources.push(...built.sources);
      counts[roleId] = (counts[roleId] ?? 0) + 1;
    }
  }
  return { root, clips, counts, sources };
}

/**
 * @param {object} world  a world module's default export
 * @param {object} specs  the role library (`ROLES`)
 */
export async function composeWorld(world, specs) {
  setWorldGrade({ kit: world.theme.kit, nature: world.theme.nature, ground: world.theme.ground });

  const root = new THREE.Group();
  root.name = world.name;
  const sources = [];
  const clips = [];

  const terrain = await buildTerrainLayer(
    { width: world.width, depth: world.depth, centreZ: world.centreZ },
    world.terrain,
  );
  root.add(terrain.root);
  sources.push(...terrain.sources);

  /* --------------------------------------------------------- placed roles -- */
  const districts = new Map();
  const counts = {};
  const districtGroup = (name) => {
    if (!districts.has(name)) {
      const group = new THREE.Group();
      group.name = `District_${name}`;
      districts.set(name, group);
      root.add(group);
    }
    return districts.get(name);
  };

  for (const placement of world.layout) {
    const spec = specs[placement.role];
    if (!spec) throw new Error(`${world.id}: placement "${placement.name}" uses unknown role "${placement.role}"`);
    const built = await buildRole(spec, {
      name: placement.name,
      pos: placement.pos,
      yaw: placement.yaw ?? 0,
      scale: placement.scale ?? 1,
      district: placement.district,
    });
    districtGroup(placement.district).add(built.root);
    clips.push(...built.clips);
    sources.push(...built.sources);
    counts[placement.role] = (counts[placement.role] ?? 0) + 1;
  }

  /* ------------------------------------------------------------ landmarks -- */
  const landmarkGroup = districtGroup('landmark');
  for (const landmark of world.landmarks ?? []) {
    const part = await makePart({
      model: landmark.model,
      height: landmark.height,
      width: landmark.width,
      scale: landmark.scale,
      stretch: landmark.stretch,
      pos: landmark.pos,
      yaw: landmark.yaw ?? 0,
      name: `Landmark_${landmark.id}`,
    });
    landmarkGroup.add(part.group);
    sources.push(part.source);
  }

  /* -------------------------------------------------------------- scatter -- */
  const scattered = await scatterProps(world, specs, world.scatterDistrict ?? 'wilds');
  root.add(scattered.root);
  clips.push(...scattered.clips);
  sources.push(...scattered.sources);
  for (const [id, n] of Object.entries(scattered.counts)) counts[id] = (counts[id] ?? 0) + n;

  /* --------------------------------------------------------------- spawns -- */
  const spawns = new THREE.Group();
  spawns.name = 'PlayerSpawns';
  for (const spawn of world.spawns) {
    const marker = new THREE.Object3D();
    marker.name = spawn.name;
    marker.position.set(...spawn.pos);
    spawns.add(marker);
  }
  root.add(spawns);

  /* ---------------------------------------------------------------- stats -- */
  const files = new Set();
  let triangles = 0;
  root.traverse((node) => {
    if (!node.isMesh) return;
    if (node.userData.realSource) files.add(node.userData.realSource);
    const geometry = node.geometry;
    const index = geometry?.getIndex();
    const position = geometry?.getAttribute('position');
    triangles += index ? index.count / 3 : (position ? position.count / 3 : 0);
  });

  const placed = world.layout.length;
  const stats = {
    instances: placed + Object.values(scattered.counts).reduce((a, b) => a + b, 0),
    counts,
    districts: [...districts.keys()],
    triangles: Math.round(triangles),
    clips: clips.length,
    roles: new Set(world.layout.map((p) => p.role)).size,
    realFiles: files.size,
    realFileList: [...files].sort(),
    landmarks: (world.landmarks ?? []).length,
  };

  const meta = {
    id: world.id,
    name: world.name,
    mission: world.mission,
    tagline: world.tagline,
    category: 'world',
    width: world.width,
    depth: world.depth,
    centreZ: world.centreZ,
    spawns: world.spawns.map((s) => s.name),
    theme: {
      id: world.theme.id,
      label: world.theme.label,
      mood: world.theme.mood,
      accent: world.theme.accent,
      hazard: world.theme.hazard,
      sky: world.theme.sky,
      fog: world.theme.fog,
    },
    assetPolicy: 'every mesh is a real licensed GLB from game/assets/world/real',
  };

  root.userData.forge = { id: meta.id, stats, meta };
  return { root, clips, stats, meta, theme: world.theme };
}

/* -------------------------------------------------------------- atmosphere -- */

/** Sky dome for a theme — cinematic v2: glowStrength + horizon haze + sun disc + subtle stars.
 * No texture, one draw. The haze band is now theme-driven (0.32–0.42) so each
 * world has its own horizon breathing. */
export function themeSky(theme) {
  const geometry = new THREE.SphereGeometry(620, 32, 16);
  const glowStrength = theme.sky.glowStrength ?? 0.18;
  const horizonHaze = theme.sky.horizonHaze ?? 0.32;
  const sunWarmth = theme.sky.sunWarmth ?? 0.0;
  // sun dir from key light (first directional) so sky sun and key light agree
  const keyPos = theme.lights?.[0]?.pos ?? [-60, 60, -60];
  const sunDir = new THREE.Vector3(...keyPos).normalize();
  const material = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    uniforms: {
      top: { value: new THREE.Color(theme.sky.top) },
      mid: { value: new THREE.Color(theme.sky.mid) },
      bottom: { value: new THREE.Color(theme.sky.bottom) },
      glow: { value: new THREE.Color(theme.sky.glow) },
      glowStrength: { value: glowStrength },
      horizonHaze: { value: horizonHaze },
      sunDir: { value: sunDir },
      sunWarmth: { value: sunWarmth },
    },
    vertexShader: 'varying vec3 vPos; varying vec3 vWorldDir; void main(){ vPos = position; vWorldDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `
      uniform vec3 top; uniform vec3 mid; uniform vec3 bottom; uniform vec3 glow;
      uniform float glowStrength; uniform float horizonHaze; uniform vec3 sunDir; uniform float sunWarmth;
      varying vec3 vPos; varying vec3 vWorldDir;
      // cheap star noise — only for frostline (cold longing), hidden by haze otherwise
      float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      void main(){
        float h = normalize(vPos).y;
        vec3 c = mix(bottom, mid, smoothstep(-0.14, 0.28, h));
        c = mix(c, top, smoothstep(0.20, 0.96, h));
        // cinematic glow band — narrow at horizon, theme-driven strength
        float band = exp(-pow((h - 0.015) * 10.0, 2.0));
        c += glow * band * glowStrength;
        // horizon scattering — bottom color bleeds up with height, like aerial perspective
        float haze = pow(1.0 - clamp((h + 0.12) / 0.42, 0.0, 1.0), 2.8);
        c = mix(c, bottom, haze * horizonHaze);
        // sun disc + warm halo — anamorphic subtle, not a cartoon sun
        float sunDot = max(dot(vWorldDir, sunDir), 0.0);
        float sunDisc = pow(sunDot, 720.0) * 1.6;
        float halo = pow(sunDot, 18.0) * 0.22 * (0.2 + sunWarmth);
        vec3 sunCol = mix(vec3(1.0, 0.92, 0.78), glow, sunWarmth * 0.55);
        c += sunCol * (sunDisc + halo);
        // subtle star field — visible only high up (h>0.45) and where glow low
        if (h > 0.45) {
          vec2 uv = vWorldDir.xz * 3.2 + vWorldDir.y * 0.6;
          float n = hash(floor(uv * 64.0));
          float star = step(0.996, n) * pow(hash(uv), 1.2) * (1.0 - band * 2.0);
          c += vec3(0.9, 0.95, 1.0) * star * 0.55 * smoothstep(0.45, 0.75, h);
        }
        // film vignette — darken edges slightly, more cinematic on lens
        float vign = length(vWorldDir.xz) * 0.14;
        c *= (1.0 - vign * 0.35);
        gl_FragColor = vec4(c, 1.0);
      }`,
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.name = 'SkyDome';
  return mesh;
}

/** Height fog volume — pools at ground like real height fog, not uniform FogExp2.
 * A translucent box with exponential height falloff; scene fog still provides
 * distance haze, this adds the *vertical* storytelling (ground mist in Verdant,
 * ash storm in Emberfall, ice breath in Frostline). Added to scene, not root,
 * so the real-asset gate never sees it. */
export function heightFogVolume(theme) {
  const fog = theme.fog;
  if (!fog || !fog.height) return null;
  const w = 760, d = 760, h = fog.height;
  const geometry = new THREE.BoxGeometry(w, h, d);
  const hazeCol = new THREE.Color(fog.hazeColor ?? fog.color);
  const baseCol = new THREE.Color(fog.color);
  const material = new THREE.ShaderMaterial({
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.NormalBlending,
    side: THREE.DoubleSide,
    uniforms: {
      hazeColor: { value: hazeCol },
      baseColor: { value: baseCol },
      height: { value: h },
      falloff: { value: fog.heightFalloff ?? 0.12 },
      density: { value: fog.density },
      hazeStrength: { value: fog.hazeStrength ?? 0.12 },
    },
    vertexShader: 'varying vec3 vLocal; varying vec3 vWorld; void main(){ vLocal = position; vec4 wpos = modelMatrix * vec4(position,1.0); vWorld = wpos.xyz; gl_Position = projectionMatrix * viewMatrix * wpos; }',
    fragmentShader: `
      uniform vec3 hazeColor; uniform vec3 baseColor; uniform float height; uniform float falloff; uniform float density; uniform float hazeStrength;
      varying vec3 vLocal; varying vec3 vWorld;
      void main(){
        float yLocal = vLocal.y + height * 0.5; // 0 at bottom, height at top
        float hNorm = clamp(yLocal / height, 0.0, 1.0);
        float hFog = exp(-falloff * yLocal) * (1.0 - hNorm * 0.55);
        float dist = length(vWorld.xz) / 380.0;
        float edge = 1.0 - smoothstep(0.58, 1.12, dist);
        // v2.1 attenuated: 210→85, 0.52→0.28 — ground mist is a breath, not a wall
        float alpha = hFog * density * 85.0 * edge * (0.42 + hazeStrength);
        alpha = clamp(alpha, 0.0, 0.28);
        vec3 c = mix(hazeColor, baseColor, hNorm * 0.42);
        float streak = sin(vWorld.x * 0.041 + vWorld.z * 0.038) * 0.045 + 0.955;
        c *= streak;
        gl_FragColor = vec4(c, alpha);
      }`,
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.name = 'HeightFog';
  mesh.position.y = h * 0.5 + 0.6; // sits on ground 0.6m up so it catches ground plane
  mesh.renderOrder = 1;
  return mesh;
}

/**
 * Four lights and a hemisphere, tuned per theme. Light is not an asset: it is
 * how the scanned surfaces are read, so it lives with the world's art direction.
 */
export function themeLighting(scene, theme) {
  const lights = [];
  theme.lights.forEach((spec, i) => {
    const light = new THREE.DirectionalLight(new THREE.Color(spec.color), spec.intensity);
    light.position.set(...spec.pos);
    light.name = spec.name;
    if (i === 0) {
      light.castShadow = true;
      light.shadow.mapSize.set(2048, 2048);
      light.shadow.camera.near = 10;
      light.shadow.camera.far = 420;
      light.shadow.camera.left = -160;
      light.shadow.camera.right = 160;
      light.shadow.camera.top = 160;
      light.shadow.camera.bottom = -160;
      light.shadow.bias = -0.0008;
    }
    scene.add(light);
    lights.push(light);
  });

  const hemi = new THREE.HemisphereLight(
    new THREE.Color(theme.hemi.sky),
    new THREE.Color(theme.hemi.ground),
    theme.hemi.intensity,
  );
  hemi.name = 'SkyBounce';
  scene.add(hemi);
  lights.push(hemi);

  scene.fog = new THREE.FogExp2(new THREE.Color(theme.fog.color), theme.fog.density);
  scene.background = new THREE.Color(theme.sky.mid);

  return { lights, key: lights[0], hemi };
}
