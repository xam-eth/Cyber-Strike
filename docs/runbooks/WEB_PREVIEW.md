# WebAssembly Preview Runbook

Use the Web preview to review the real shell and Godot build without installing Android tooling. It is a development/review path, not evidence of Android rendering, touch comfort, or mobile performance.

Latest executed checkpoint and payload identity: [`../VALIDATION.md`](../VALIDATION.md). This runbook intentionally does not carry historical byte totals or pass counts.

## 1. Daily use

From the repository root:

```bash
python3 tools/serve_preview.py --port 800
```

Then open:

- `http://localhost:800/` — player shell and game;
- `http://localhost:800/web/` — raw Godot export page.

For another device on the same network, use the development machine's reachable address and bind the server appropriately. A remote browser must not be told to use its own localhost to reach the development service.

The committed `web/` directory contains the generated HTML/JS/WASM/PCK payload. Do not hand-edit generated output. CI/export tooling refreshes it when a full Web gate runs; a documentation-only `[skip ci]` change does not produce a new payload.

## 2. Player and loading flow

The root shell owns the player-facing journey:

```text
opening → HERO → theatre selection → DEPLOY → selected theatre gameplay
```

The root shell does not need to stop at the engine WORLD stage. The raw/native engine journey retains its own registry-driven stages.

### Initial opening contract

```text
opening:
  new Engine(config)
  → init(executable)
  → preloadFile(mainPack)

DEPLOY:
  engine.start({ args: ["--main-pack", mainPack] })
```

- `init()` initializes WASM; `preloadFile()` downloads the main PCK containing required world data/assets.
- Neither opening operation starts hidden gameplay.
- MASUK waits for the real preload promises.
- DEPLOY uses the same main pack and does not call a path that preloads the PCK again.
- Progress uses actual byte counts and exported file-size information, not a timer.
- Download/initialization failure exposes a readable retry surface and does not reveal a broken canvas.
- Direct selected-theatre retry/reload preserves the validated `qa_world` and weapon handoff.

This is a download/preinitialization contract. It does not claim every world GLB is instantiated or GPU-warmed during the HTML opening; the selected world is instantiated for gameplay.

## 3. Cache behavior

Use `tools/serve_preview.py`, not a server that forces `Cache-Control: no-store`, when testing warm development reloads. Do not substitute `python3 -m http.server` for update diagnosis: it does not provide the `/__build` identity endpoint or this server's strong-content-ETag policy, so it cannot establish that the browser and repository are testing the same payload.

- A cold opening downloads the full payload.
- An unchanged file uses a strong content ETag and can complete revalidation with **304 Not Modified** and no large response body.
- A changed file gets a new ETag and must be downloaded again. Because the game is one monolithic `index.pck`, changing any packed source/asset changes that HTTP object; unchanged assets inside it cannot be revalidated as separate browser-cache entries.
- DEPLOY should not request the main PCK a second time after a successful opening preload.
- DevTools **Disable cache**, a new/private profile, cleared storage, or a different origin intentionally changes the result.
- The server has no source watcher or automatic browser reload. After a source change, export a new Web payload and reload the page; `/__build` only identifies the served pack.

The exact transferred-byte evidence belongs to the checkpoint in `../VALIDATION.md`, not this reusable runbook.

### Offline Web versus `Scary-Night`

The reviewed `xam-eth/Scary-Night` runtime uses Three.js/Canvas plus `GLTFLoader`; its service worker caches same-origin static assets and uses network-first navigation for its PWA/TWA path. Cyber-Strike instead boots a Godot WASM engine and a large PCK through `Engine.init()`/`preloadFile()`. Copying that service worker would not prove an atomic or complete Godot offline boot.

This repository currently provides warm HTTP revalidation, **not** a fully offline PWA. A first Web visit must download the engine and game data; subsequent visits can avoid unchanged response bodies as described above. For play without a Web server or repeated data transfer after installation, use the self-contained Android APK in [`ANDROID.md`](ANDROID.md). Do not describe either path as zero-initial-download.

## 4. Build the payload yourself

Install the pinned Godot editor and matching Web templates, then run:

```bash
./scripts/install_godot.sh --with-templates
./scripts/export_web_preview.sh
python3 tools/check_payload.py web/index.pck
```

The export pipeline:

1. creates/validates the local Web preset without replacing unrelated local presets;
2. imports the project headlessly;
3. exports the Web build;
4. applies `tools/web_loader_patch.py` so WASM/module/filesystem initialization failures reject correctly;
5. verifies expected files, magic bytes, placeholders, and custom shell output.

Useful overrides are documented by the scripts, including `GODOT_BIN`, `WEB_EXPORT_PRESET`, debug output, and alternate output directories. Do not treat a completed file export as a browser pass.

## 5. Automated browser gates

Install the locked tooling once per environment:

```bash
npm ci --prefix tools
```

Core gates:

```bash
node tools/web_qa.mjs
node tools/web_qa.mjs --json
node tools/web_loading_qa.mjs --throughput-mbps 100 --json
```

`web_qa.mjs` serves/opens the real pages and checks engine boot, WebGL context, canvas, failed requests, and error surfaces. Its gameplay/journey options exercise actual input and selected-theatre paths. `web_loading_qa.mjs` checks initial opening, interrupted asset recovery, real byte progress, retry, and selected-gameplay return.

Additional play/tour options exist in `tools/web_qa.mjs`; read the current source for exact flags and required server setup. A harness that only waits for a Godot banner may not traverse opening → HERO → theatre → DEPLOY. Diagnose harness mismatches instead of mislabeling them as game failures or passes.

For visual candidates, `ui_shots.mjs` also waits for the shell dock's `ok` readiness state so deep-linked screens do not capture a random loading status. `web_qa.mjs --encounter-prep` requires unpaused safe Explore before B and fails rather than presenting paused output as Defense preparation. Repeat new captures before approving a baseline. For reference/current/diff comparison and explicit golden approval, use [`VISUAL_REVIEW.md`](VISUAL_REVIEW.md); never auto-approve a changed screenshot.

For gameplay changes, require evidence of the actual intended state:

- safe Explore before explicit Defense;
- selected-theatre handoff when changed;
- real hit/KO/reward/Results when claimed;
- real TECH HUNT secure/death/extract states once implemented.

A screenshot of a menu or an ammunition decrease alone does not prove a complete combat/mission loop.

## 6. What ships and which tool owns it

| Path/tool | Role |
|---|---|
| `index.html` + `ui/` | Painted player shell, opening, HERO, theatre/loadout selection, launch and error/retry |
| `web/` | Generated Godot HTML/JS/WASM/PCK payload |
| `game/web_shell/index.html` | Custom raw Godot HTML shell |
| `tools/web_preset.py` | Local Web preset creation/validation |
| `scripts/export_web_preview.sh` | Reproducible export and verification pipeline |
| `tools/web_loader_patch.py` | Required exporter-compatibility recovery patch |
| `tools/verify_web_build.py` | Static exported-file verification |
| `tools/check_payload.py` | Payload content/policy audit |
| `tools/web_qa.mjs` | Browser boot/journey/gameplay/frame gates |
| `tools/web_loading_qa.mjs` | Opening preload and interrupted-recovery gates |
| `tools/serve_preview.py` | Local static server with content-based revalidation |

## 7. Renderer and product layout

Web uses **Compatibility / WebGL 2** and the exported build is single-threaded. Android retains its own renderer configuration. Do not infer identical lighting, precision, threading, audio latency, or performance across those targets.

The current product layout is landscape-first/landscape-only for the tested shell and HUD. Portrait Web displays the rotation guidance rather than maintaining a second untested HUD arrangement. Current tested viewport details belong to the UI tests and validation checkpoint.

## 8. Controls

| Action | Keyboard/mouse | Touch |
|---|---|---|
| Move | WASD | Left-side joystick |
| Aim/look | Right-mouse drag | Right-side look drag |
| Fire | Left mouse | FIRE control |
| Change weapon / Armory | Existing weapon/Armory bindings (`E` / `U` where applicable) | Weapon/Armory controls |
| EMP | `F` | EMP control |
| Start Defense / Engage or Secure a nearby Recovery cache | `B` from the relevant field context | Context action on the HUD |
| Pause/resume | Escape | PAUSE / RESUME |
| Retry | `R` where applicable / Results action | Results retry action |
| Mute | `M` / sound control | Sound control |

After the primary Seed Vault Secure, the existing Results surface presents explicit **Extract** and **Continue to Endless** actions. Their gameplay acceptance criteria live in [`../GAMEPLAY_DESIGN.md`](../GAMEPLAY_DESIGN.md).

## 9. Audio handoff

- Browsers require a valid user gesture before audio starts.
- Opening, HERO/dashboard, DEPLOY, and gameplay share the Frontier Signal direction.
- DEPLOY retires the HTML music voice before Godot takes ownership; two background beds must not overlap.
- Mute preference is shared through the existing shell/engine adapter.
- Automated playback/state checks are not human listening or speaker-quality approval.

See [`AUDIO.md`](AUDIO.md).

## 10. Troubleshooting

| Symptom | Likely class | Action |
|---|---|---|
| Build unavailable | `web/` missing/incomplete | Restore the committed payload or run the export; do not create a fake ready state |
| Long opening with advancing bytes | Large cold payload / slow connection | Keep the tab active; use warm cache for unchanged development reloads |
| Readable connection error | Interrupted download/initialization | Use retry; record the failed asset, visible detail, Console and Network evidence |
| Loading without real progress | Incorrect exported file-size/path wiring or stalled delivery | Inspect current loader config and network completion; never replace it with a timer percentage |
| WASM/PCK 404 | Server started from the wrong directory or wrong executable path | Serve the repository root and preserve `./web/index` mapping |
| Full payload downloads every reload | `no-store`, disabled cache, new origin/profile, or changed bytes | Use the preview server and the same origin/profile; compare ETags and response bodies |
| Black canvas/WebGL error | Unsupported/blocked WebGL 2 | Check browser/GPU support; do not hide the error surface |
| Defense never reached in QA | Harness did not perform the real journey/action or software rendering is slow | Inspect stage/action logs and harness preconditions before changing gameplay |
| Browser works, Android unknown | Different renderer/platform/device | Run [`ANDROID.md`](ANDROID.md); do not infer device success |

## 11. Evidence limits

Web export, static delivery, headless Chromium, and screenshots do not establish:

- Android packaging or physical-device behavior;
- touch ergonomics or real-GPU mobile frame time;
- every network/proxy failure mode;
- final human visual/auditory acceptance;
- a complete human run, retention, or engagement improvement.

Record executed Web results in `../VALIDATION.md` and physical-device follow-up through [`ANDROID.md`](ANDROID.md).
