/**
 * The operative on the hero stage is the rig itself, not a painting of one.
 *
 *   ui/hero_stage.js  ->  #hero-canvas  ->  game/assets/characters/hero/hero.glb
 *
 * Why the model is here and not only in the engine: the hero screen is the one
 * moment before a run where the player is looking at their own character, and it
 * used to show a generated illustration standing on a generated hangar. When the
 * player changed livery, the illustration did not change; when the rig was
 * re-exported, the illustration did not change; and the "info" tab described
 * clips the picture could not play. The room can stay a photograph -- a room
 * does not animate -- but the figure has to be the asset that goes into the
 * match, with its own skeleton, its own clips, its own materials.
 *
 * What that costs: three.js is vendored under ui/vendor/three (an import map in
 * index.html maps the bare "three" specifier), and the loader fetches the same
 * 3 MB hero.glb the engine later loads. The render target is small -- the stage
 * canvas is roughly 180 x 210 CSS pixels on a 844 x 390 phone -- and the model
 * is 36 k triangles, so this is cheaper than the painted plate behind it.
 *
 * The stage the figure stands on is geometry, not a photograph of one. A rig
 * that animates over a painted pad can only look pasted onto a backdrop: the
 * painted pad cannot take his weight, cannot take his shadow, and does not move
 * when the camera does. So the room stays a photograph (it is far away and does
 * not move) and the deck under his boots is a real cylinder with a lit rim,
 * drawn in the same scene, in the same perspective, with the contact shadow on
 * its own surface. Camera, deck and rig share one space -- the only way
 * "standing on a stage" is true instead of claimed.
 *
 * Lifecycle, because the engine needs the GPU back:
 *   play()   starts the frame loop (entering the hero screen)
 *   pause()  stops the loop but keeps the loaded scene (leaving and returning)
 *   pulse()  the celebration beat: the rig raises into `aim` and settles to idle
 *   dispose()frees the context before the engine boots, so Deploy is not
 *            competing with a WebGL context the lobby no longer needs
 */

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

/* The operative shown here is the tier the player picked: five GLBs, one per
   rank (game/assets/characters/human_hero_tiers/). The path arrives from the
   roster through `setLoadout()`; DEFAULT_MODEL is what the page shows before
   the roster answers, so the stage is never empty. */
const DEFAULT_MODEL = './game/assets/characters/human_hero_tiers/hero_human_tier_1.glb';
const MODEL = DEFAULT_MODEL;
const RIFLE = './game/assets/weapons/futuristic_rifle/rifle.glb';
const IDLE = 'idle';
const SALUTE = 'aim';
const CELEBRATION_CLIP = 'celebration';
/* Per-hero signature beat, authored in Blender
   (tools/blender/author_celebrations.py -> game/assets/characters/hero/
   celebrations/<hero>.glb). The stage does not ship one animation for
   everybody: a celebration is the hero's identity, so the file is looked up by
   the hero id on the selected card, and a hero without one falls back to the
   rig's own `aim` pose rather than borrowing someone else's move. */
const CELEBRATIONS = './game/assets/characters/hero/celebrations/manifest.json';

/* The socket numbers are the engine's, not guessed: game/assets/characters/hero/
   hero_rig.json is what CharacterVisual reads to hang the rifle off R_Hand
   (scale_model_units 0.4, carry_rotation_xyzw, offset). Using the same file for
   the lobby means the rifle in the hero's hands is the rifle in the match, held
   the same way -- and it is what makes the `aim` celebration read as a weapon
   coming up instead of a figure folding its arms. */
/* Defaults from hero_rig.json. `setLoadout()` replaces them with the selected
   tier's own sidecar (human_hero_tiers/*_rig.json), whose socket differs in the
   fourth decimal -- small, but it is the same numbers the engine uses. */
let SOCKET = {
  rotationXYZW: [0.727734, 0.229505, -0.429349, 0.483105],
  aimRotationXYZW: [0.17042, 0.090197, -0.620581, 0.760066],
  offset: [0, 0.018, 0],
  scale: 0.4,
};

/* The plate the canvas sits in. Named by id because the operative page's stage
   is one column of a grid, not a full-bleed hero band. */
const stage = document.getElementById('op-stage') || document.querySelector('.hero__stage');
const canvas = document.getElementById('hero-canvas');
const note = document.getElementById('hero-stage-note');

if (stage && canvas) {
  const reduceQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

  const reduced = () => {
    // The shell's own switch wins: a player who turned motion down in settings
    // means it, whatever the OS says.
    const flag = document.documentElement.dataset.motion;
    if (flag === 'reduced') return true;
    if (flag === 'full') return false;
    return reduceQuery.matches;
  };

  let renderer = null;
  let scene = null;
  let camera = null;
  let mixer = null;
  let actions = {};
  let current = null;
  let model = null;
  let ready = false;
  let running = false;
  let frame = 0;
  let disposed = false;
  let rifleAttached = false;
  let celebration = null;
  let heroId =
    document.querySelector('#hero-roster .card[aria-pressed="true"]')?.dataset.hero || 'sable';
  let tierNumber = 1;
  /* The model cache. Each tier GLB is ~4 MB and switching tiers re-loads one, so
     an already-seen tier is kept as a scene graph rather than fetched again: a
     player walking the ladder with the arrow keys would otherwise download the
     same five files repeatedly. */
  const modelCache = new Map();
  let loadToken = 0;
  /* Entrance state: the body's own travel, in the scene, so the figure moves
     rather than the frame it is drawn in. */
  const entrance = {
    mode: '',
    start: 0,
    duration: 0.78,
    from: { x: 0, y: 0 },
    restX: 0,
    restY: 0,
  };
  let rifleRef = null;
  let loadedUrl = '';
  let weaponUrl = RIFLE;
  let weaponId = 'pulse_rifle';
  let weaponTier = 1;
  let socketUrl = '';
  let socketNode = null;
  let handFound = false;
  let saluteTimer = 0;
  const clock = new THREE.Clock();

  function fail(reason) {
    // A silent empty stage is the worst outcome: say what happened, in the same
    // place the character would be.
    if (note) {
      note.hidden = false;
      note.textContent = `Render 3D gagal dimuat · ${reason}`;
    }
    console.warn('[hero_stage]', reason);
    window.dispatchEvent(new CustomEvent('aegis:hero-stage-error', { detail: reason }));
  }

  function size() {
    if (!renderer) return;
    const box = stage.getBoundingClientRect();
    const width = Math.max(1, Math.round(canvas.clientWidth || box.width));
    const height = Math.max(1, Math.round(canvas.clientHeight || box.height));
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(width, height, false);
    if (camera) camera.aspect = width / height;
    frame_();
  }

  function frame_() {
    if (camera) camera.updateProjectionMatrix();
  }

  /* Frame the rig by its own bounds, not by magic numbers: the camera is placed
     so the boots sit on the bottom edge of the canvas and the helmet lands at
     `FILL` of its height. Re-exporting the model at a different scale therefore
     re-frames itself. */
  const FILL = 0.93;
  const FOV = 27;
  /* Deck, in the rig's own units (hero.glb is 1.0 units tall and the engine
     scales it to 1.78 m, so one unit is a body here, not a metre). */
  const DECK_RADIUS = 0.62;
  const DECK_HEIGHT = 0.085;

  let bounds = new THREE.Box3();

  let ground = null;
  let deck = null;

  /* The deploy deck: a machined ring the operative stands on, built from three
     cylinders -- a recessed base, a plated top, a lit rim -- so the edge has real
     thickness and a real highlight. Its top face is the rig's ground plane;
     nothing about it is painted into the backdrop. */
  function buildDeck() {
    const group = new THREE.Group();
    const metal = (colour, rough, metalness) =>
      new THREE.MeshStandardMaterial({ color: colour, roughness: rough, metalness });

    const radius = DECK_RADIUS;
    const base = new THREE.Mesh(
      new THREE.CylinderGeometry(radius * 1.04, radius * 1.12, DECK_HEIGHT * 0.45, 64, 1),
      metal(0x2b3138, 0.72, 0.55),
    );
    base.position.y = -DECK_HEIGHT * 0.5 + DECK_HEIGHT * 0.225;
    group.add(base);

    const top = new THREE.Mesh(
      new THREE.CylinderGeometry(radius, radius, DECK_HEIGHT * 0.55, 64, 1),
      metal(0x4d5865, 0.42, 0.6),
    );
    top.position.y = DECK_HEIGHT * 0.5 - DECK_HEIGHT * 0.275;
    group.add(top);

    // Neutral white rim, sitting in a groove just inside the edge. Neutral
    // because the stage is shared by every hero.
    const rim = new THREE.Mesh(
      new THREE.TorusGeometry(radius * 0.92, DECK_HEIGHT * 0.055, 10, 96),
      new THREE.MeshStandardMaterial({
        color: 0xffffff,
        emissive: 0xdfe9f2,
        emissiveIntensity: 2.6,
        roughness: 0.35,
        metalness: 0,
      }),
    );
    rim.rotation.x = Math.PI / 2;
    rim.position.y = DECK_HEIGHT * 0.5 + DECK_HEIGHT * 0.05;
    group.add(rim);

    // The standing surface: a lighter inset plate, so the top face reads as a
    // floor with a lit border rather than as a hole in a hoop.
    const plate = new THREE.Mesh(
      new THREE.CylinderGeometry(radius * 0.88, radius * 0.88, DECK_HEIGHT * 0.06, 64, 1),
      metal(0x5a6672, 0.55, 0.5),
    );
    plate.position.y = DECK_HEIGHT * 0.5;
    group.add(plate);

    // A dimmer inner ring: two concentric lights read as a pad, one reads as a
    // hoop.
    const inner = new THREE.Mesh(
      new THREE.TorusGeometry(radius * 0.55, DECK_HEIGHT * 0.028, 8, 80),
      new THREE.MeshStandardMaterial({
        color: 0xcfdae4,
        emissive: 0x9fb2c2,
        emissiveIntensity: 1.1,
        roughness: 0.5,
        metalness: 0,
      }),
    );
    inner.rotation.x = Math.PI / 2;
    inner.position.y = DECK_HEIGHT * 0.5 + DECK_HEIGHT * 0.05;
    group.add(inner);

    return group;
  }

  /* A soft patch of shadow where the boots meet the deck, in the scene rather
     than in CSS: only the renderer knows where the boots actually landed, and a
     DOM ellipse behind a transparent canvas cannot follow a re-exported rig. */
  function grounding(box) {
    const size = Math.max(box.max.x - box.min.x, box.max.z - box.min.z);
    const surface = document.createElement('canvas');
    surface.width = 128;
    surface.height = 64;
    const ctx = surface.getContext('2d');
    const gradient = ctx.createRadialGradient(64, 32, 2, 64, 32, 62);
    gradient.addColorStop(0, 'rgba(0, 0, 0, 0.72)');
    gradient.addColorStop(0.55, 'rgba(0, 0, 0, 0.34)');
    gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 128, 64);
    const texture = new THREE.CanvasTexture(surface);
    texture.colorSpace = THREE.SRGBColorSpace;
    const plane = new THREE.Mesh(
      new THREE.PlaneGeometry(size * 1.55, size * 0.62),
      new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthWrite: false }),
    );
    plane.rotation.x = -Math.PI / 2;
    plane.renderOrder = 1;
    return plane;
  }

  function fit() {
    if (!model || !camera) return;
    // The rig stands ON the deck's top face, not at the origin: the difference
    // between a character on a stage and a character near one.
    model.position.y -= new THREE.Box3().setFromObject(model).min.y;
    model.position.y += DECK_HEIGHT * 0.5;
    model.updateMatrixWorld(true);
    bounds = new THREE.Box3().setFromObject(model);
    const height = bounds.max.y - bounds.min.y;
    const width = bounds.max.x - bounds.min.x;
    const depth = bounds.max.z - bounds.min.z;
    const centre = new THREE.Vector3(
      (bounds.max.x + bounds.min.x) / 2,
      0,
      (bounds.max.z + bounds.min.z) / 2,
    );

    const tan = Math.tan(THREE.MathUtils.degToRad(FOV) / 2);
    // Frame the operative and his deck as one object, with the deck proud of the
    // frame on both sides so it reads as something he is standing on.
    const visible = (height + DECK_HEIGHT) / FILL;
    // Fit height, then make sure the shoulders and the rifle still clear the
    // sides of a tall, narrow canvas.
    const byHeight = visible / (2 * tan);
    const byWidth =
      Math.max(width, DECK_RADIUS * 2.35) / (2 * tan * Math.max(0.2, camera.aspect));
    const distance = Math.max(byHeight, byWidth) * 1.02;

    // Look slightly down at the deck so its top face reads as an ellipse: a
    // dead-on camera turns any disc into a line, and the point of a real stage
    // is that the eye can see the surface the boots are on.
    const eye = bounds.min.y + visible * 0.5;
    camera.fov = FOV;
    camera.position.set(centre.x, eye + visible * 0.09, centre.z + distance);
    camera.lookAt(centre.x, eye - visible * 0.02, centre.z);
    camera.updateProjectionMatrix();

    // Keep the near/far planes proportional to the model rather than to metres:
    // a re-export in centimetres would otherwise be clipped or invisible.
    if (ground) {
      scene.remove(ground);
      ground.geometry.dispose();
      ground.material.map?.dispose();
      ground.material.dispose();
    }
    ground = grounding(bounds);
    ground.position.set(centre.x, bounds.min.y + 0.003, centre.z);
    scene.add(ground);

    camera.near = Math.max(0.01, distance - Math.max(height, depth) * 2);
    camera.far = distance + Math.max(height, depth) * 4;
    camera.updateProjectionMatrix();
    frame_();
  }

  function play(name, fade = 0.25) {
    const next = actions[name];
    if (!next || current === next) return;
    next.reset();
    next.enabled = true;
    next.setEffectiveTimeScale(1);
    next.setEffectiveWeight(1);
    next.play();
    if (current) current.crossFadeTo(next, fade, false);
    current = next;
  }

  /* The celebration is a one-shot: it plays through, holds, then hands back to
     idle. A clip that looped would turn a signature into an idle animation. */
  function playCelebration() {
    if (!celebration) return;
    for (const action of Object.values(actions)) {
      if (action !== celebration) action.fadeOut(0.2);
    }
    celebration.reset();
    celebration.fadeIn(0.18);
    celebration.play();
    current = celebration;
    const seconds = celebration.getClip().duration;
    window.clearTimeout(saluteTimer);
    saluteTimer = window.setTimeout(() => {
      celebration.fadeOut(0.3);
      current = null;
      play(IDLE, 0.3);
    }, Math.max(600, seconds * 1000 + 250));
  }

  function loadCelebration() {
    fetch(CELEBRATIONS, { cache: 'no-cache' })
      .then((response) => (response.ok ? response.json() : null))
      .then((manifest) => {
        const entry = manifest && manifest.heroes ? manifest.heroes[heroId] : null;
        if (!entry || !entry.file) return;
        new GLTFLoader().load(entry.file, (gltf) => {
          if (disposed || !mixer) return;
          const clip =
            gltf.animations.find((item) => item.name === CELEBRATION_CLIP) || gltf.animations[0];
          if (!clip) return;
          celebration = mixer.clipAction(clip);
          celebration.setLoop(THREE.LoopOnce, 1);
          celebration.clampWhenFinished = true;
        });
      })
      .catch(() => {
        // A missing manifest is not an error: it means no hero has a signature
        // beat authored yet, and the aim fallback is the designed answer.
      });
  }

  /* The body's own entrance, in the scene.
     'top'  -- an upgrade: the operative drops in from above the frame, which is
               where a rank is earned from;
     'right'-- a hero selection: the incoming operative slides in from the right,
               the direction the roster strip reads.
     The travel is in model units (the rig is 1.0 tall), so it re-scales with the
     model instead of depending on the canvas size. */
  function applyEntrance(restart) {
    if (!model) return;
    const mode = entrance.mode;
    if (!mode) return;
    if (reduced()) {
      entrance.mode = '';
      model.position.x = entrance.restX;
      model.position.y = entrance.restY;
      return;
    }
    // A beat that is already travelling is not restarted: the stage announces
    // itself more than once (mount, model ready, a second `setLoadout` from the
    // shell), and restarting from a mid-flight position would both cut the
    // animation short and leave the body standing off its mark.
    const elapsed = performance.now() / 1000 - entrance.start;
    if (entrance.mode === mode && elapsed < entrance.duration) return;
    // The mark is where `fit()` put the body, never where it happens to be:
    // the travel is always rest -> (rest + from) -> rest.
    entrance.start = performance.now() / 1000;
    entrance.baseX = entrance.restX;
    entrance.baseY = entrance.restY;
    const depth = bounds.max.y - bounds.min.y || 1;
    entrance.from =
      mode === 'top' ? { x: 0, y: depth * 0.62 } : { x: depth * 0.5, y: depth * 0.04 };
    if (restart) {
      model.position.x = entrance.baseX + entrance.from.x;
      model.position.y = entrance.baseY + entrance.from.y;
    }
  }

  function stepEntrance() {
    if (!entrance.mode || !model) return;
    const elapsed = performance.now() / 1000 - entrance.start;
    const t = Math.min(1, elapsed / entrance.duration);
    // easeOutCubic: fast arrival, long settle -- the "landing" reads as weight.
    const eased = 1 - Math.pow(1 - t, 3);
    model.position.x = entrance.baseX + entrance.from.x * (1 - eased);
    model.position.y = entrance.baseY + entrance.from.y * (1 - eased);
    if (t >= 1) {
      model.position.x = entrance.baseX;
      model.position.y = entrance.baseY;
      entrance.mode = '';
    }
  }

  function updateSocket(delta = 1, immediate = false) {
    if (!socketNode) return;
    socketNode.position.set(...SOCKET.offset);
    if (rifleRef) {
      rifleRef.visible = true;
      rifleRef.scale.setScalar(SOCKET.scale);
    }
    const aiming = current === actions[SALUTE];
    const rotation = aiming ? SOCKET.aimRotationXYZW : SOCKET.rotationXYZW;
    const target = new THREE.Quaternion(...rotation);
    const alpha = immediate ? 1 : 1 - Math.exp(-Math.max(0, delta) / 0.16);
    socketNode.quaternion.slerp(target, alpha);
  }

  function tick() {
    frame = requestAnimationFrame(tick);
    const delta = Math.min(clock.getDelta(), 0.05);
    if (mixer && !reduced()) mixer.update(delta);
    stepEntrance();
    updateSocket(delta);
    renderer.render(scene, camera);
  }

  function start() {
    if (!ready || running || disposed) return;
    if (!reduced()) {
      running = true;
      clock.getDelta();
      tick();
      return;
    }
    // Reduced motion: no loop, one honest frame of the rig in its idle pose.
    renderer.render(scene, camera);
  }

  function stop() {
    running = false;
    cancelAnimationFrame(frame);
    frame = 0;
  }

/* The rifle socket is per tier, and it is data, not a constant: the sidecar
   beside the model says where the hand is. A tier whose sidecar will not load
   keeps the previous socket rather than dropping the weapon. */
function loadSocket(url) {
  socketUrl = url;
  fetch(`./${url}`)
    .then((response) => (response.ok ? response.json() : null))
    .then((data) => {
      const spec = data && data.weapon_socket;
      if (!spec || socketUrl !== url) return;
      SOCKET = {
        rotationXYZW: spec.carry_rotation_xyzw || SOCKET.rotationXYZW,
        aimRotationXYZW: spec.aim_rotation_xyzw || SOCKET.aimRotationXYZW,
        offset: spec.offset || SOCKET.offset,
        scale: Number(spec.scale_model_units) || SOCKET.scale,
      };
      updateSocket(1, true);
    })
    .catch(() => {});
}

/* Loads one tier of one hero. Every call is token-guarded: walking the ladder
   quickly starts several loads, and the last request is the one that must win --
   otherwise the stage settles on whichever file happened to arrive last. */
function loadModel(url) {
  const token = ++loadToken;
  if (model) {
    scene.remove(model);
    model = null;
    mixer = null;
    actions = {};
    current = null;
    celebration = null;
    ready = false;
    canvas.dataset.state = 'loading';
  }
  if (rifleRef) {
    rifleRef = null;
    rifleAttached = false;
  }
    new GLTFLoader().load(
      url,
      (gltf) => {
        if (disposed || token !== loadToken) return;
        model = gltf.scene;
        model.traverse((node) => {
          if (node.isMesh) {
            node.frustumCulled = false; // skinned bounds lie; the stage is tiny
            node.castShadow = false;
            node.receiveShadow = false;
            for (const material of [].concat(node.material)) {
              if (!material) continue;
              material.envMapIntensity = 0.9;
              // The rig ships as a single scanned material; give it the little
              // bit of specular response that reads as armour under the beams.
              if (material.isMeshStandardMaterial) {
                material.roughness = Math.min(material.roughness ?? 0.7, 0.55);
                material.metalness = Math.max(material.metalness ?? 0.1, 0.35);
              }
            }
          }
        });
        scene.add(model);

        mixer = new THREE.AnimationMixer(model);
        actions = {};
        for (const clip of gltf.animations) {
          const action = mixer.clipAction(clip);
          action.setLoop(THREE.LoopRepeat, Infinity);
          actions[clip.name] = action;
        }
        if (!actions[IDLE]) {
          fail('hero.glb tidak memuat klip "idle"');
          return;
        }

        // Fit on the body before the rifle attaches: the weapon hangs past the
        // hip, and letting it into the bounding box would shrink the operative
        // to make room for a prop.
        size();
        fit();
        entrance.restX = model.position.x;
        entrance.restY = model.position.y;
        play(IDLE, 0);

        const hand = model.getObjectByName('R_Hand');
        handFound = Boolean(hand);
        if (hand) {
          new GLTFLoader().load(weaponUrl, (weaponGltf) => {
            if (disposed || token !== loadToken) return;
            const rifle = weaponGltf.scene;
            rifle.scale.setScalar(SOCKET.scale);
            rifle.traverse((node) => {
              if (node.isMesh) {
                node.frustumCulled = false;
                for (const material of [].concat(node.material)) {
                  if (material && material.isMeshStandardMaterial) {
                    material.envMapIntensity = 0.9;
                  }
                }
              }
            });
            const socket = new THREE.Group();
            socketNode = socket;
            socket.position.set(...SOCKET.offset);
            socket.quaternion.set(...SOCKET.rotationXYZW);
            // The equipped weapon is part of the operative, including during
            // the authored celebration. The socket follows R_Hand on every
            // frame; updateSocket chooses the sidecar's carry or aim rotation.
            rifle.visible = true;
            socket.add(rifle);
            hand.add(socket);
            rifleRef = rifle;
            rifleAttached = true;
          });
        } else {
          console.warn('[hero_stage] hero.glb has no R_Hand bone; the operative is unarmed');
        }

        if (deck == null) {
          deck = buildDeck();
          scene.add(deck);
        }

        ready = true;
        if (reduced()) mixer.update(0.001);
        applyEntrance(true);
        start();
        canvas.dataset.state = 'ready';
        if (!celebration) loadCelebration();
        window.dispatchEvent(new CustomEvent('aegis:hero-stage-ready'));
      },
      undefined,
      (error) => {
        if (token !== loadToken) return;
        fail(String(error && error.message ? error.message : error));
      },
    );
}

  function init() {
    renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.74;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.setClearAlpha(0);

    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(FOV, 1, 0.1, 100);

    // Neutral light, on purpose. The stage is shared by every hero, and the
    // hero art is locked: a cyan rim or an amber bounce would repaint whatever
    // the artist painted, and the next hero's palette would clash with a room
    // keyed to this one. So the room is gunmetal grey and the light is white --
    // a paper white key, a softer white fill from the other side, and a dim
    // neutral env for the metal to have something to reflect. Per-hero colour
    // belongs to the hero, not to the room.
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    scene.environmentIntensity = 0.5;
    pmrem.dispose();

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

    if (!loadedUrl) loadedUrl = MODEL;
    loadModel(loadedUrl);

    if (typeof ResizeObserver === 'function') {
      new ResizeObserver(() => size()).observe(stage);
    }
    window.addEventListener('resize', size);
  }

  const api = {
    play() {
      if (!renderer) init();
      start();
    },
    /* What the operative page asks for: one hero, one tier, one entrance. The
       roster decides the paths; the stage decides how a body arrives. */
    setLoadout({
      heroId: hero,
      tier,
      model: url,
      rig,
      weaponId: id,
      weaponTier: rank,
      weaponModel,
      entry,
    } = {}) {
      if (typeof hero === 'string' && hero) heroId = hero;
      if (Number.isFinite(tier)) tierNumber = tier;
      if (typeof id === 'string' && id) weaponId = id;
      if (Number.isFinite(rank)) weaponTier = Math.max(1, Math.floor(rank));
      entrance.mode = entry === 'top' ? 'top' : entry === 'right' ? 'right' : entrance.mode;
      if (typeof rig === 'string' && rig && rig !== socketUrl) loadSocket(rig);
      let reload = false;
      if (url && url !== loadedUrl) {
        loadedUrl = url;
        reload = true;
      }
      if (typeof weaponModel === 'string' && weaponModel && weaponModel !== weaponUrl) {
        weaponUrl = weaponModel;
        reload = true;
      }
      if (!renderer) {
        init();
        return;
      }
      if (reload) {
        loadModel(loadedUrl);
        return;
      }
      // Same assets, new beat: replay the entrance without another download.
      if (entry) applyEntrance(true);
      start();
    },
    pause: stop,
    pulse() {
      if (!ready || reduced()) return;
      window.clearTimeout(saluteTimer);
      if (rifleRef) rifleRef.visible = true;
      if (celebration) {
        playCelebration();
        return;
      }
      // A hero without an authored signature uses the rig's real aim clip and
      // the aim socket, then returns to carry without hiding the weapon.
      play(SALUTE, 0.18);
      saluteTimer = window.setTimeout(() => {
        play(IDLE, 0.35);
      }, 950);
    },
    /* QA only: freeze the celebration at a given second and draw one frame. The
       screenshot tools cannot time a 2.2 s clip from a headless browser -- each
       capture costs seconds on SwiftShader -- so review needs to ask for the
       pose it wants to see. */
    poseAt(seconds) {
      if (!ready || !celebration) return null;
      stop();
      for (const action of Object.values(actions)) action.stop();
      celebration.reset();
      celebration.play();
      celebration.paused = true;
      celebration.time = Math.max(0, Math.min(seconds, celebration.getClip().duration));
      current = celebration;
      mixer.update(0);
      updateSocket(1, true);
      renderer.render(scene, camera);
      return Number(celebration.time.toFixed(3));
    },
    resume() {
      if (celebration) {
        celebration.paused = false;
        play(IDLE, 0.2);
      }
      start();
    },
    dispose() {
      disposed = true;
      stop();
      window.clearTimeout(saluteTimer);
      if (renderer) {
        renderer.dispose();
        renderer.forceContextLoss?.();
      }
      mixer = null;
      ready = false;
      canvas.dataset.state = 'idle';
    },
    get ready() {
      return ready;
    },
    /* What the stage is actually holding, for the QA tools: a screenshot proves
       the pixels, this proves which asset made them. */
    describe() {
      if (!ready) return { ready: false };
      const box = new THREE.Box3().setFromObject(model);
      return {
        ready,
        model: MODEL,
        clips: Object.keys(actions),
        bone: handFound ? 'R_Hand' : null,
        tier: tierNumber,
        modelUrl: loadedUrl,
        /* The entrance, while it is in flight: the QA tools assert the body is
           actually moving, so a still frame cannot pass for motion. */
        entrance: {
          mode: entrance.mode,
          offset: model
            ? [
                Number((model.position.x - (entrance.baseX ?? 0)).toFixed(3)),
                Number((model.position.y - (entrance.baseY ?? 0)).toFixed(3)),
              ]
            : null,
        },
        celebration: celebration ? celebration.getClip().name : null,
        celebrationSeconds: celebration ? Number(celebration.getClip().duration.toFixed(2)) : null,
        heroId,
        weaponId,
        weaponTier,
        weaponModel: weaponUrl,
        rifle: rifleAttached,
        rifleVisible: Boolean(rifleRef?.visible),
        socketParent: socketNode?.parent?.name || null,
        socketPose: current === actions[SALUTE] ? 'aim' : 'carry',
        rifleWorld: rifleRef
          ? new THREE.Box3().setFromObject(rifleRef).getCenter(new THREE.Vector3()).toArray().map((n) => Number(n.toFixed(3)))
          : null,
        handWorld: handFound
          ? model.getObjectByName('R_Hand').getWorldPosition(new THREE.Vector3()).toArray().map((n) => Number(n.toFixed(3)))
          : null,
        rifleSize: rifleRef
          ? Object.fromEntries(
              ['x', 'y', 'z'].map((axis) => [
                axis,
                Number(new THREE.Box3().setFromObject(rifleRef).getSize(new THREE.Vector3())[axis].toFixed(3)),
              ]),
            )
          : null,
        bounds: {
          height: Number((box.max.y - box.min.y).toFixed(3)),
          width: Number((box.max.x - box.min.x).toFixed(3)),
        },
      };
    },
  };

  window.AegisHeroStage = api;
  window.dispatchEvent(new CustomEvent('aegis:hero-stage-mounted'));

  // The shell can boot a screen before this module evaluates (it is a module and
  // the shell is a classic deferred script, so the order is not fixed). If the
  // hero screen is already up, start now instead of waiting for a transition.
  const heroScreen = document.getElementById('screen-hero');
  if (heroScreen && heroScreen.dataset.active === 'true') api.play();
}
