# Project Overdrive — NEON FRONTIER World Prototype

**Project Overdrive** is a mobile-first, single-player third-person sci-fi action shooter prototype. **NEON FRONTIER** is its connected 3D world—not a static concept image. The current blockout uses reusable Godot components and some licensed KayKit GLTF props; provenance is in [`game/assets/world/kaykit_space_base_bits/`](game/assets/world/kaykit_space_base_bits/) and [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md). Ten real Kenney Space Kit GLBs are in the repository; the player avatar and all three enemy types now render fitted models from that kit instead of placeholder capsules.

## Start here

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — **read this first if you are new to the code**: where every subsystem lives, what a file may import, where a change of yours goes, and what has to pass before a merge. The module map in it is generated from the tree, so it cannot go stale.
- [`game/scenes/worlds/neon_frontier.tscn`](game/scenes/worlds/neon_frontier.tscn) — complete playable frontier environment.
- [`game/scenes/worlds/components/`](game/scenes/worlds/components/) — reusable 3D components for the reactor, outpost, laboratory, depot, extraction plant, gates, defenses, wrecks, rocks, crystals, and alien flora.
- [`game/assets/world/kenney_space_kit/ASSET_PROVENANCE.md`](game/assets/world/kenney_space_kit/ASSET_PROVENANCE.md) — downloaded Kenney GLB candidates, CC0/source provenance, hashes, and rig inspection; not yet instantiated by gameplay scenes.
- [`WORLD_BLOCKOUT.md`](WORLD_BLOCKOUT.md) — world zones, route layout, modular asset inventory, and implementation notes.
- [`DEVELOPMENT_ROADMAP.md`](DEVELOPMENT_ROADMAP.md) — project phases, scope gates, risks, and next steps.
- [`ANDROID_BASELINE.md`](ANDROID_BASELINE.md) — gate-E runbook: JDK/SDK setup, local Android preset, APK build, device test and profiling checklist.
- [`WEB_PREVIEW.md`](WEB_PREVIEW.md) — no-install WebAssembly preview: `python -m http.server 800 --bind 0.0.0.0` from the repository root, controls, limits, troubleshooting.
- [`GAP_ANALYSIS.md`](GAP_ANALYSIS.md) — verified-vs-claimed status, per-system gaps, prioritized backlog, and how to run the new tooling.
- [`PROJECT_DECISIONS.md`](PROJECT_DECISIONS.md) — provisional gameplay and technical decisions.
- [`GAME_CONCEPT.md`](GAME_CONCEPT.md) — source game and technical design concept.
- [`HERO_RIG_PIPELINE.md`](HERO_RIG_PIPELINE.md) — how the rigged hero and rifle were reduced, how the aim/fire clips are baked, and what is still unverified.
- [`WORLD_KIT_BUILD.md`](WORLD_KIT_BUILD.md) — how the level is assembled from the KayKit Space Base Bits pack, and how to review it in-game.
- [`GAME_OVERVIEW.md`](GAME_OVERVIEW.md) — gameplay/visual overview.
- [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md) — Godot/Android/Blender setup and asset workflow.

## Playable 3D world

The Godot project is in [`game/`](game/). Its world spans a connected frontier landscape with a central circular/hexagonal combat arena, a suspended cyan/emerald reactor, a military command center, research lab, equipment depot, generator bank, vehicle landing pad, perimeter gates and defenses, a destroyed sector, alien cliffs, crystal clusters, luminous vegetation, and a dedicated boss platform and docking gate. Broad ground-level routes connect the districts; modular cover and defense structures leave combat lanes readable. Reusable component scenes create distinct 3D meshes, PBR-style materials, colored emissive parts, and gameplay-relevant collision. A selective KayKit Space Base Bits subset is instantiated as real 3D GLTF models for the depot, cargo stacks, service truck, extraction drill, landing-pad surface, and four boundary rocks; the CC0 license travels with the assets. Most of the surrounding world remains editable procedural blockout geometry, not a single image or final authored art.

The player now boots into **safe Explore**: no Wave Director starts until the player deliberately selects **START DEFENSE** (or presses `B`), after a visible preparation countdown. Defense runs the capped Runner/Shooter waves; Results offers both **RETRY DEFENSE** and **EXPLORE**. The contextual HUD keeps an objective and clear actions in Explore, introduces wave/ammo/health during Defense, and moves detailed Score/BP/KOs/time to results/pause. Keyboard and touch support movement, aim, fire, weapon cycling, EMP, pause, retry, and return to Explore. `tests/exploration_flow_smoke.gd` checks the mode changes headlessly; visual readability still requires actual WASM/device review.

**Previously verified (headless, before the current GLTF/skill integration):** an earlier checkout passed nine world/combat/playability smoke tests, including the original touch/HUD checks and central-to-boss/landing-pad traversal. **Current worktree (checked 18 Oct 2026):** static GDScript parse, `gdlint`, and `gdformat --check` pass for all 63 GDScript files (gdtoolkit 4.5.0 via `./scripts/dev_check.sh`), and the static project doctor reports 0 failures (13 non-blocking warnings) across scene references, node paths, script-to-node types, input actions, signals, groups, weapon contracts, glTF integrity, and documentation drift. The **thirteen smoke tests on commit `125b2ee`** (world/arena/traversal, weapons, combat feedback, waves, rewards, shooter AI, HUD/touch, enemy visuals, audio, combat effects, and the rigged hero) passed headlessly on real Godot 4.7.2-stable in CI. All fifteen smoke tests, including settings and the HUD editor, passed on commit `4fcbf5f` in CI. The same workflow runs static checks and exports a WebAssembly preview; visual browser QA still must be done separately. That verifies gameplay logic only — the checks cannot see rendering, frame time, or device input. Browser gameplay was additionally checked by hand through the WebAssembly preview: `qa-evidence/enemies-and-audio/` holds frames from ~40 s and ~73 s of scripted play (runner reached melee range, dealt damage, HUD updated) plus the audio log lines, and `qa-evidence/hud-mobile/` holds the portrait/landscape layouts and the mute assertion. That run is a headless Chromium with **software rendering**, so its frame rate is not representative of a real GPU browser. **Not verified:** Android touch behaviour on a real device, mobile performance, Android export, and whether a human actually hears the audio on that device.

**Actor presentation:** the player is the uploaded rigged hero (`game/assets/characters/hero/hero.glb`) holding the uploaded rifle (`game/assets/weapons/futuristic_rifle/rifle.glb`). A `BoneAttachment3D` on `R_Hand` and measured `MuzzlePoint` align shots with the barrel; five clips exist, but moving aim, reload, hit/death, Blender inspection, and weapon identity still need production review ([`HERO_RIG_PIPELINE.md`](HERO_RIG_PIPELINE.md)). The world now instantiates the user-uploaded FBX SciFi kit converted to GLB for its central bay, district landmarks, landing deck and perimeter; KayKit runtime scripts/assets have been removed. Procedural foundations and details remain, and **this is not a claim of final FBX-only art** ([`docs/REBASE_VISUAL_GAMEPLAY_2026-10-18.md`](docs/REBASE_VISUAL_GAMEPLAY_2026-10-18.md)). Enemies remain Kenney kit GLBs. Audio is synthesised at runtime, not final authored sound ([`AUDIO_SYSTEM.md`](AUDIO_SYSTEM.md)). Android device QA, polish and visual acceptance are still open.

Open `game/project.godot` in Godot 4.7.2 and run the main scene to explore the world. Install the pinned engine build and run everything without a GUI:

```bash
# 1. Static checks that need no engine (syntax, lint, format, references, contracts)
./scripts/dev_check.sh

# 2. Install the pinned Godot 4.7.2 editor (+ export templates) outside the repo
./scripts/install_godot.sh --with-templates

# 3. Import the project and run all seventeen smoke tests with per-test logs
./scripts/run_smoke_tests.sh
./scripts/run_smoke_tests.sh --list                 # available tests
./scripts/run_smoke_tests.sh wave_director_smoke    # a single test
```

`scripts/run_smoke_tests.sh` performs the headless Editor import and then every smoke test with `--headless --path game --script res://tests/<name>`, writing logs to the git-ignored `exports/test-logs/`. The seventeen tests are `exploration_flow_smoke.gd`, `pause_gesture_smoke.gd`, `neon_frontier_world_smoke.gd`, `arena_blockout_smoke.gd`, `hud_editor_smoke.gd`, `weapon_system_smoke.gd`, `arc_weapon_smoke.gd`, `combat_feedback_smoke.gd`, `wave_director_smoke.gd`, `reward_loop_smoke.gd`, `shooter_enemy_smoke.gd`, `playability_hud_smoke.gd`, `ui_settings_smoke.gd`, `enemy_visual_smoke.gd`, `audio_smoke.gd`, `effects_smoke.gd`, and `hero_rig_smoke.gd`. The equivalent manual commands are:

```bash
godot --headless --editor --path game --quit
godot --headless --path game --script res://tests/neon_frontier_world_smoke.gd
godot --headless --path game --script res://tests/weapon_system_smoke.gd
```

`.github/workflows/godot-ci.yml` runs the static job plus a headless Godot job (install → import → all smoke tests → uploaded logs) on every pull request.

PC controls: WASD to move, right mouse drag to aim, left mouse or FIRE to shoot, `E` to cycle weapons, EMP to pulse, `B` to request Defense from Explore, Escape to pause, and `R` to retry a run. Mobile: joystick, look drag, FIRE, weapon, EMP, PAUSE, a labeled START DEFENSE button, and Results buttons for RETRY DEFENSE or EXPLORE. **No wave automatically starts when the game opens.**

## No-install browser preview (WebAssembly)

The fastest way to review UI/UX and gameplay without installing Godot, the Android SDK, or JDK is the exported
web build. Serve the repository root and open the landing page:

```bash
python -m http.server 800 --bind 0.0.0.0
# http://localhost:800/        landing page with status + embedded game
# http://localhost:800/web/    raw Godot build
```

The Godot payload lives in `web/` and **is committed** (≈39 MB, refreshed by the `web-preview` CI job), so a plain
`git pull` is enough to play. The ~10 MB `web-preview` artifact from Actions is still there as a fallback, GitHub Pages
(*Settings → Pages → Source: GitHub Actions*) removes the download entirely, and a local export needs only the web
export templates that are already in the repository (`engine/web_templates/`):

```bash
./scripts/install_godot.sh --with-templates
./scripts/export_web_preview.sh      # preset + import + export + build verification
```

A headless browser check for both entry pages is one command (`npm ci --prefix tools && node tools/web_qa.mjs`); CI runs
the same gate, and it is what proves the engine actually boots instead of only serving bytes. Add `--tour` and the
same run presses F10 in the engine, walks the eight review vantages and saves one screenshot per district — that is how
`qa-evidence/world-kit/` was captured, from the shipped `web/` payload rather than from a separate scene.

The web export is single-threaded (`variant/thread_support=false`) so it runs on a plain static server without
COOP/COEP headers, and it uses a custom shell at `game/web_shell/index.html`. The web platform always uses the
Compatibility (WebGL 2) renderer, while Android keeps the `mobile` renderer — see [`WEB_PREVIEW.md`](WEB_PREVIEW.md)
for the differences that must not be mistaken for Android behaviour.

## Android import/export workflow

The project structure is prepared for Android packaging: runtime KayKit GLTFs are explicitly preloaded as imported `PackedScene` resources so Godot can trace their BIN/texture dependencies. A local Godot Android export preset is still required. Create it in the Editor (`Project > Export > Add... > Android`), set the team's package ID and debug options, and configure matching SDK/JDK/export templates. `game/export_presets.cfg` is intentionally git-ignored because it may contain machine-local paths and signing settings; `tools/android_preset.py` creates, patches, and validates it from the command line.

The local toolchain and preset can be prepared without the Editor GUI:

```bash
./scripts/install_godot.sh --with-templates     # pinned editor + export templates
./scripts/setup_android_sdk.sh --guide           # JDK/SDK instructions per OS
./scripts/setup_android_sdk.sh --install-packages
python3 tools/android_preset.py scaffold --package-id com.yourstudio.projectoverdrive
python3 tools/android_preset.py check
```

Then run:

```bash
./scripts/check_toolchain.sh
./scripts/export_android_debug.sh
```

`ANDROID_BASELINE.md` covers the device installation commands, the manual touch/pause/retry checklist, the profiling procedure, and the gate-E acceptance criteria.

The export script imports in headless Editor mode, runs all `tests/*_smoke.gd` scripts, exports `exports/project-overdrive-debug.apk`, and checks the APK archive when `unzip` is installed. Override the preset/output with `ANDROID_EXPORT_PRESET` and `ANDROID_APK_PATH`; set `GODOT_BIN` if the executable is not named `godot` or `godot4`. It does not install SDK packages, create release signing keys, or deploy to a device. **This workflow is prepared, not executed here:** Godot, JDK, Android SDK/ADB and Gradle are unavailable in the current environment, so no APK or Android runtime result is claimed. Use [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md) for setup details.

## Toolchain check

Run this read-only preflight after installing local tools:

```bash
./scripts/check_toolchain.sh
```

It reports missing tools but does not install software or modify project settings. Optional static lint: create `.venv`, install `requirements-dev.txt`, then run `./scripts/lint_gdscript.sh`. Headless Editor import, Android export, interactive touch validation, and physical-device testing remain required; no GUI is needed for the CLI workflow.
