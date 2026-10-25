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

const MODEL = './game/assets/characters/hero/hero.glb';
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
const SOCKET = {
  rotationXYZW: [0.727734, 0.229505, -0.429349, 0.483105],
  offset: [0, 0.018, 0],
  scale: 0.4,
};

const stage = document.querySelector('.hero__stage');
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
  const heroId =
    document.querySelector('#hero-roster .hcard[data-active="true"]')?.dataset.hero || 'exo_operative';
  let rifleRef = null;
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

  let bounds = new THREE.Box3();

  let ground = null;

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
    const visible = height / FILL;
    // Fit height, then make sure the shoulders and the rifle still clear the
    // sides of a tall, narrow canvas.
    const byHeight = visible / (2 * tan);
    const byWidth = width / (2 * tan * Math.max(0.2, camera.aspect));
    const distance = Math.max(byHeight, byWidth) * 1.02;

    camera.fov = FOV;
    camera.position.set(centre.x, bounds.min.y + visible / 2, centre.z + distance);
    camera.lookAt(centre.x, bounds.min.y + visible / 2, centre.z);
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

  function tick() {
    frame = requestAnimationFrame(tick);
    const delta = Math.min(clock.getDelta(), 0.05);
    if (mixer && !reduced()) mixer.update(delta);
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

    new GLTFLoader().load(
      MODEL,
      (gltf) => {
        if (disposed) return;
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
        play(IDLE, 0);

        const hand = model.getObjectByName('R_Hand');
        handFound = Boolean(hand);
        if (hand) {
          new GLTFLoader().load(RIFLE, (weaponGltf) => {
            if (disposed) return;
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
            socket.position.set(...SOCKET.offset);
            socket.quaternion.set(...SOCKET.rotationXYZW);
            // Held down the leg at ease the rifle reads as a brace strapped to
            // the thigh, so the lobby keeps it in hand but out of sight and
            // brings it up with the `aim` beat: the celebration is the weapon
            // coming up, drawn by the rig's own clip and the game's own socket.
            rifle.visible = false;
            socket.add(rifle);
            hand.add(socket);
            rifleRef = rifle;
            rifleAttached = true;
          });
        } else {
          console.warn('[hero_stage] hero.glb has no R_Hand bone; the operative is unarmed');
        }

        ready = true;
        if (reduced()) mixer.update(0.001);
        start();
        canvas.dataset.state = 'ready';
        loadCelebration();
        window.dispatchEvent(new CustomEvent('aegis:hero-stage-ready'));
      },
      undefined,
      (error) => fail(String(error && error.message ? error.message : error)),
    );

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
    pause: stop,
    pulse() {
      if (!ready || reduced()) return;
      window.clearTimeout(saluteTimer);
      // The hero's own move, not a weapon drill: the rifle stays holstered out
      // of sight unless the rig has no authored celebration to play.
      if (rifleRef) rifleRef.visible = false;
      if (celebration) {
        playCelebration();
        return;
      }
      // No authored celebration for this hero yet: the rig's aim pose is the
      // honest stand-in, and it is the only beat hero.glb can actually play.
      if (rifleRef) rifleRef.visible = true;
      play(SALUTE, 0.18);
      saluteTimer = window.setTimeout(() => {
        play(IDLE, 0.35);
        if (rifleRef) {
          window.setTimeout(() => {
            if (rifleRef) rifleRef.visible = false;
          }, 380);
        }
      }, 950);
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
        celebration: celebration ? celebration.getClip().name : null,
        celebrationSeconds: celebration ? Number(celebration.getClip().duration.toFixed(2)) : null,
        heroId,
        rifle: rifleAttached,
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
