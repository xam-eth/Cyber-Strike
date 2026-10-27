# Exocomplict — STELLAR HORIZON

A mobile-first, single-player third-person sci-fi action/adventure-survival prototype built with Godot 4.7.2 and GDScript.

The executable baseline includes safe Explore, explicit Defense, Verdant Seed Vault Recovery with Extract/Continue to Endless, Pulse/Nova/Arc weapons, Runner/Shooter enemies, persistent BP and blueprint unlocks, five registered theatre definitions, and a painted shell with direct selected-theatre DEPLOY. **TECH HUNT 0** is the active prototype path; executed evidence and its limits are recorded in `docs/VALIDATION.md`.

## Start here

| Need | Read |
|---|---|
| Documentation map and conflict rules | [`docs/README.md`](docs/README.md) |
| **Game direction, gameplay logic, active scope** | [`docs/GAMEPLAY_DESIGN.md`](docs/GAMEPLAY_DESIGN.md) |
| Development workflow, ownership, roadmap, quality gates | [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) |
| Code/module boundaries | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Latest executed evidence and limitations | [`docs/VALIDATION.md`](docs/VALIDATION.md) |
| Persistent instructions for coding agents | [`AGENTS.md`](AGENTS.md) |

Old concept, audit, roadmap, integration, and validation reports have been retired from the active tree. Their useful current rules are consolidated above; earlier versions remain in Git history.

## Run the Godot project

Install the pinned engine and matching export templates using [`docs/runbooks/TOOLCHAIN.md`](docs/runbooks/TOOLCHAIN.md), then open `game/project.godot` or use the CLI:

```bash
./scripts/install_godot.sh --with-templates
godot --headless --editor --path game --quit
godot --path game
```

Gameplay starts safely. The existing Defense path begins only through its explicit action and preparation countdown. Keyboard/touch controls and platform limits are documented in the Web/Android runbooks.

## Browser preview

The committed Web payload can be served without installing Godot:

```bash
python3 tools/serve_preview.py --port 800
```

Open the landing page at `http://localhost:800/` on the same development machine. The opening preloads the WASM + main PCK before MASUK; DEPLOY reuses that pack for the selected theatre. A warm unchanged preview revalidates content instead of intentionally downloading every asset again.

Full export, QA, cache, recovery, and troubleshooting instructions: [`docs/runbooks/WEB_PREVIEW.md`](docs/runbooks/WEB_PREVIEW.md). The Web path requires an initial WASM/PCK download; it is not a zero-download or fully offline PWA.

## Android development and offline USB

With Godot/JDK/SDK configured, build, install, and relaunch the self-contained APK over USB:

```bash
./scripts/android_usb.sh
```

For an unchanged existing APK, `./scripts/android_usb.sh --skip-build` skips the export. The helper uses `adb install -r`, preserves profile data when package/signatures match, and never requires the Web server on the phone.

For rapid development, use the Godot Remote Debug/Small Deploy workflow in the Android runbook. Native visual evidence can be captured from the installed app without reinstalling:

```bash
./scripts/android_visual.sh shot --label hud-after
./scripts/android_visual.sh record --seconds 30 --label reload-animation
```

Visual captures remain human-review evidence and must be separate from performance runs. For a timed physical-device capture, run `./scripts/android_usb.sh --serial SERIAL_HP --profile-seconds 120`. It writes raw logcat, five-second FPS/frame-time windows, memory/thermal/gfxinfo snapshots, and a Markdown/CSV/JSON report under `artifacts/android/`; these are real measurements only when run with an actual phone. See [`docs/runbooks/ANDROID.md`](docs/runbooks/ANDROID.md) for the device matrix, release/profile distinction, and full protocol.

## Checks

```bash
./scripts/dev_check.sh
./scripts/run_smoke_tests.sh
python3 tools/check_payload.py web/index.pck
```

Browser and device checks are separate gates:

```bash
npm ci --prefix tools
node tools/web_qa.mjs
node tools/web_loading_qa.mjs
```

See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) before interpreting results. Static/headless/browser success does not prove physical Android behavior, touch comfort, representative mobile performance, human enjoyment, or retention.

## Repository map

```text
game/             Godot project: scripts, scenes, resources, runtime assets
tests/            Headless Godot smoke/regression tests
ui/               Painted Web shell, selection, loadout, art and audio
web/              Committed WebAssembly export and loader
engine/           Pinned Web export templates
scripts/          Setup, validation, test and export entry points
tools/            Asset, QA, payload, preview and architecture tooling
source-assets/    Authoring sources outside the runtime pack
qa-evidence/      Deliberately tracked QA evidence, not design authority
docs/             Canonical design, development, domain docs and runbooks
```

## Subsystem runbooks

- [Toolchain setup](docs/runbooks/TOOLCHAIN.md)
- [Web preview and recovery](docs/runbooks/WEB_PREVIEW.md)
- [Android build/device/profiling](docs/runbooks/ANDROID.md)
- [Frontier Signal audio](docs/runbooks/AUDIO.md)
- [Hero/rifle rig pipeline](docs/runbooks/HERO_RIG.md)
- [World asset build and design index](docs/world/README.md)
