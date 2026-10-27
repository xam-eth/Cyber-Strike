# Toolchain and Setup Runbook

Use this runbook to prepare a development machine. It describes setup, not the result of running setup in the current session. Executed verification belongs in [`../VALIDATION.md`](../VALIDATION.md).

## 1. Pinned baseline

| Component | Baseline | Notes |
|---|---|---|
| Engine | **Godot 4.7.2-stable Standard**, not .NET | `.godot-version` is the pin; editor and export templates must match |
| Language | GDScript | Static lint does not replace engine type resolution |
| Project | `game/project.godot` | Repository root is not the Godot `res://` root |
| Python | Python 3 | Static checks, asset/QA tools, and optional `gdtoolkit` environment |
| Node.js | Version required by `tools/package.json` / lockfile | Browser QA and asset tooling |
| Android | JDK + Android SDK/ADB compatible with the pinned Godot | Required only for Android export/device work |
| Authoring | Blender CLI for applicable source assets | Not required merely to open the existing project or Web payload |

Do not change the engine pin in the middle of a milestone without recording the reason and rerunning import, smoke, export, and payload checks.

## 2. Clone and repository hygiene

1. Work on the assigned branch and inspect `git status` before editing.
2. Do not commit machine-local SDK paths, signing material, credentials, `.godot/`, caches, or transient exports.
3. `game/export_presets.cfg` is intentionally local/git-ignored. Use the provided preset tools instead of sharing a machine-specific file.
4. Follow the repository's existing Git/LFS and generated-payload conventions. Do not put cache files into LFS or treat source assets as disposable cache.

## 3. Godot and export templates

```bash
./scripts/install_godot.sh --with-templates
godot --version
godot --headless --editor --path game --quit
```

The installer downloads the pinned Standard build, verifies its checksum, installs outside the repository, and can install matching templates. A machine without access to the release host must use CI or another prepared machine; do not claim an install/export succeeded when the download could not run.

Useful commands after installation:

```bash
./scripts/run_smoke_tests.sh
./scripts/run_smoke_tests.sh --list
./scripts/run_smoke_tests.sh wave_director_smoke
```

Tests live outside `game/` so they cannot be packed accidentally. Godot runs them by absolute script path while `res://` still resolves to `game/`; see [`../../tests/README.md`](../../tests/README.md).

## 4. Python static tooling

The core static scripts use Python's standard library. GDScript lint/format and Pillow-based visual image inspection use the pinned development requirements:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
./scripts/dev_check.sh
```

`.venv/` is local and ignored. If optional lint tools are unavailable, report the lint step as skipped rather than implying it passed. `gdparse` alone does not catch every duplicate local, undeclared identifier, or cross-file static-call error; headless Godot remains necessary.

Read-only toolchain preflight:

```bash
./scripts/check_toolchain.sh
```

This reports missing tools; it does not install them or alter project settings.

## 5. Node and browser QA tooling

```bash
npm ci --prefix tools
node tools/web_qa.mjs
node tools/web_loading_qa.mjs
```

Use the committed lockfile. Browser QA may download/provide a headless Chromium through the tool package. Software-rendered Chromium is useful for boot/input/frame evidence but is not representative of physical mobile GPU performance.

Read a tool's source for supported flags when necessary; some tools treat `--help` as a real QA invocation rather than a help command.

## 6. Android SDK and JDK

Install components required by the pinned Godot documentation. The helper can detect or install common command-line packages:

```bash
./scripts/setup_android_sdk.sh --guide
./scripts/setup_android_sdk.sh
./scripts/setup_android_sdk.sh --install-packages
./scripts/check_toolchain.sh
```

Set `ANDROID_SDK_ROOT`/`ANDROID_HOME`, `JAVA_HOME`, and `PATH` through machine-local environment configuration. Do not commit credentials, signing passwords, or shared logs containing them.

Create or validate a local debug preset:

```bash
python3 tools/android_preset.py scaffold \
  --package-id com.yourstudio.exocomplict \
  --arch arm64-v8a
python3 tools/android_preset.py check
```

Use a real application id, not `com.example.*`. Then follow [`ANDROID.md`](ANDROID.md) for export, installation, physical-device checks, and profiling.

Official starting points:

- [Godot downloads](https://godotengine.org/download/)
- [Godot Android export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Android Studio/SDK](https://developer.android.com/studio)

## 7. Blender and asset authoring

Use a stable Blender CLI when a subsystem requires editable DCC authoring:

```bash
blender --background --python path/to/authoring_script.py
```

Keep editable sources separate from runtime assets:

```text
source-assets/       editable source models, rigs, and authoring inputs
game/assets/         runtime assets imported by Godot
tools/               reproducible conversion/authoring/verification tools
```

For each asset, validate scale, orientation, origin, material, rig/animation where applicable, license/provenance, and actual Godot import. A GLB's existence is not evidence that its socket, collision, animation, or device cost is correct.

Subsystem pipelines own their detailed commands:

- Hero/rifle: [`HERO_RIG.md`](HERO_RIG.md)
- Mission worlds: [`../world/README.md`](../world/README.md)
- Audio: [`AUDIO.md`](AUDIO.md)
- Art rules: [`../ART_DIRECTION.md`](../ART_DIRECTION.md)

## 8. Web export templates and preview

The pinned Web templates are kept under `engine/web_templates/` according to the repository's export setup. Build through the provided pipeline rather than hand-editing generated files:

```bash
./scripts/export_web_preview.sh
python3 tools/serve_preview.py --port 800
```

The export applies the required loader-recovery patch and verifies the generated build. See [`WEB_PREVIEW.md`](WEB_PREVIEW.md) for the complete contract.

## 9. Monetization and external SDKs

No ad, IAP, billing, analytics, or account SDK is part of the active prototype. Do not install one merely because a retired concept mentioned it. Such an SDK requires separate product, privacy/policy, architecture, and validation approval.

## 10. Setup completion checklist

A machine is ready for a particular task only when its required tools work:

- [ ] Correct branch and clean/understood Git state.
- [ ] Pinned Godot imports the project when engine work is required.
- [ ] `./scripts/dev_check.sh` results are understood, including skips.
- [ ] Current smoke inventory runs when gameplay/runtime changes are made.
- [ ] Node browser tooling runs when shell/Web behavior changes.
- [ ] Android preset/export/device path runs when Android evidence is claimed.
- [ ] Asset authoring/import tools run for the specific asset pipeline being changed.
- [ ] No local secret, cache, or generated transient file is staged accidentally.
