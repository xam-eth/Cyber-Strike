# Validation Status

This document records the latest relevant evidence and its limits. It is not a design specification, a chronological collection of old reports, or proof that every current branch change has been validated.

For intended behavior, read [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md). For required gates, read [`DEVELOPMENT.md`](DEVELOPMENT.md).

## Active target decision and local Web incident — 2026-10-27

- **USER DECISION (APK paused):** native APK/device work is **PAUSED** for now. Active development and testing target is the **Website**. The earlier APK's native presentation gap and force-close after DEPLOY remain unresolved and deferred; they are not accepted, fixed, or final-device evidence.
- **VERIFIED (real insecure-context reproduction):** before the shell correction, Chromium at `http://169.254.0.21:8000` reproduced the user's exact `Dunia gagal dimuat` / `Cannot read properties of undefined (reading 'addModule')` DEPLOY failure; see `exports/incident/insecure-context-preflight/before-800x360.png`. The generated engine calls `AudioContext.audioWorklet.addModule(...)`, while the custom root shell previously started without the raw export's Secure Context preflight.
- **IMPLEMENTED (actionable browser preflight):** the root shell now checks Secure Context and AudioWorklet, then uses the exported engine's remaining single-threaded feature probe before fetching the exported config, WASM, or PCK. Opening and direct-DEPLOY failures retain localized HTTPS/localhost or current-browser guidance and a reload/retry surface; audio is not disabled to bypass the requirement.
- **VERIFIED (automated Chromium support and normal gameplay):** `node tools/web_support_qa.mjs --timeout 30 --json` passed **3/3** cases: real insecure HTTP opening, real insecure direct DEPLOY, and simulated missing AudioWorklet on secure localhost. Every case exposed the intended guidance with **0 Engine constructions and 0 config/WASM/PCK requests**; see `exports/web-qa/support-report.json`. A separate normal `web_qa.mjs` run against the final shell source passed all **16/16** checks at 800×360 with touch, including HERO, Frostline card selection, authoritative handoff, and actual `frostline_relay` gameplay in 36.81 seconds; see `exports/incident/secure-context-regression-final-report.json`. The served PCK remained **90,682,996 bytes**, SHA-256 `e670e689fa906bc2704c8b578ace1948f159a3ec2448a253db966af9d37fd2cd`.
- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 100 tooling tests, 19/19 canonical documents with 163 relative links, and 87 GDScripts parsed/linted/formatted. The machine-local export preset and Godot binary were skipped; this shell-only change has no new Godot engine-test claim.
- **UNKNOWN (user's local cause and closure):** the sandbox reproduction proves one way to produce the reported exception, not the user's exact URL/browser condition. The user has not yet supplied the current `/__build`, exact failing URL, or browser/version. An insecure LAN HTTP URL and a browser without AudioWorklet now take different guidance paths; a localhost URL on the server machine remains the immediate local corrective test. Local gameplay is not declared fixed until the user confirms DEPLOY on that setup.

## Current Phase 1 visual-review checkpoint — 2026-10-27

This checkpoint adds review tooling and hardens existing browser capture. It does not approve a golden, change gameplay, or replace the runtime CI evidence below.

- **IMPLEMENTED (comparison and approval):** `tools/visual_review.py` and `tools/visual_review.json` provide reference/current/diff reports, per-case channel and pixel-ratio tolerances, explicit `MATCH` / `REVIEW_REQUIRED` / `BASELINE_PENDING` / missing/error states, and named-case approval from the exact reviewed report with report-digest and current-image hash verification. Compare never updates references. The reusable procedure is [`runbooks/VISUAL_REVIEW.md`](runbooks/VISUAL_REVIEW.md).
- **VERIFIED (synthetic/local static):** all **10/10** comparator contract tests passed for real changes, tolerances, dimensions, corrupt current evidence, pending baselines, report/image tamper rejection, unsafe paths, and output overwrite protection. The full `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 100 tooling tests, 19/19 canonical documents, and 87 GDScripts parsed/linted/formatted. The local preset and Godot binary remained skipped; synthetic images do not prove game appearance.
- **VERIFIED (initial automated Web capture):** against payload commit `41ccd8e51d8ee8cfaaa191480ad991f796131a60` and PCK SHA-256 `bfd82c279b38fcf2f6c2a644527003815f36da1a409b876728437d683711c70d`, two shell runs produced **10/10 nonblank 844×390 frames with 0 failures**. Two gameplay runs both passed actual journey, unpaused safe Explore, visible B-triggered Defense preparation, and WorldTour checks; each tour produced **8/8 distinct frames**. These are Chromium/SwiftShader results, not Android evidence.
- **VERIFIED (CI):** [Godot CI 40511867894](https://github.com/xam-eth/Cyber-Strike/actions/runs/40511867894) succeeded on tooling commit `641b637535c5eef643313c746fb9d8a5ed921d53`: static checks, the headless Godot smoke job, Web export/payload audit, and the registered browser/recovery/theatre/audio jobs passed. Optional asset-authoring and Pages jobs were skipped. The run committed refreshed payload `014555d57abf363fc38945fc889e172268887742`; Android workflow `40511867994` was skipped and supplies no new APK/device evidence.
- **VERIFIED (refreshed Web payload):** the CI payload's PCK SHA-256 is `e670e689fa906bc2704c8b578ace1948f159a3ec2448a253db966af9d37fd2cd`. A fresh local capture produced **5/5 nonblank shell frames**, passed gameplay/Explore/Defense preparation, and produced **8/8 distinct WorldTour frames**. All eight current images stayed inside their case tolerances in the previous-payload/new-payload comparison; see `exports/visual-review/web-payload-014555d-review/payload-review.md`. This verifies the registered Web states only and is not human or Android approval.
- **VERIFIED (repeat-capture stability, limited scope):** the initial A/B comparison on payload `41ccd8e` reports `MATCH` within each proposed tolerance for all eight registered cases. Diff ratios range from `0` to `0.002166`; this is run-to-run stability in one environment, not a golden comparison or proof on another GPU. Evidence: `exports/visual-review/web-stability-20261027/stability.md` and `stability.json`.
- **FIXED (capture harness only):** repetition exposed two harness races: a late fallback Escape could pause newly reached gameplay, and a deep-linked shell screen could capture the dock before async readiness became `ok`. `web_qa.mjs` now rechecks arrival before fallbacks and refuses Defense input from paused/unsafe Explore; `ui_shots.mjs` waits for readiness. The failed paused run was rejected as a candidate, and the final A/B runs above passed after the fix. No gameplay/runtime source changed.
- **BASELINE_PENDING (human review):** `exports/visual-review/web-candidates-final/index.html` was refreshed from payload `014555d`, contains eight unapproved candidates, and its JSON report records **8 × BASELINE_PENDING**. No golden or approval ledger has been created. A human must inspect the exact report and explicitly name each accepted case; the agent's image inspection is not approval.
- **UNKNOWN (remaining coverage):** TECH HUNT Secure/Extract/Results, high-load/damage/reward states, motion-sequence approval, and device variants remain incomplete. No physical Android capture, native visual/animation approval, touch/FPS/thermal/lifecycle/save/soak result, or Android baseline exists.

## Phase 0 development-loop tooling checkpoint — 2026-10-27

This is a source/tooling-only checkpoint. It does not replace the runtime payload identities or CI evidence below.

- **IMPLEMENTED (native visual tooling):** `scripts/android_visual.sh shot` captures a validated native PNG; `record` adds timed MP4 and before/after PNGs. Both write `run.json` and `report.md` with device/package/display/source context and artifact hashes. Reports keep human visual review **PENDING** and performance evidence **NO**. The tool does not build/install, clear data, or pretend that checkout identity proves the installed build.
- **IMPLEMENTED (workflow guidance):** [`runbooks/ANDROID.md`](runbooks/ANDROID.md) now distinguishes Godot One-click Deploy/Remote Debug/Small Deploy/scene-script synchronization, native visual capture, and the existing offline USB/profiling path. Visual recording and FPS capture are explicitly separate runs. Remote editor synchronization has not been executed in this environment.
- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 3 skipped steps**: 90 tooling tests, 18/18 canonical documents with 148 relative links, an 87-script static-call scan, architecture/module-map checks, and a 35-test smoke inventory. The skips were gdtoolkit, the machine-local export preset, and the Godot binary; no GDScript parse/lint or engine pass is claimed from this run.
- **VERIFIED (fake ADB/static fixtures):** the 90-test total includes eight visual-capture contracts for valid PNG/video artifact layout, pending-review metadata, unauthorized/ambiguous device handling, corrupt PNG rejection, recording failure, evidence overwrite protection, and Android's 180-second recording limit. Synthetic PNG/MP4/ADB results prove tooling control flow only.
- **VERIFIED (preview guidance/static HTTP):** user-facing export/CI instructions now use `tools/serve_preview.py`; cache-contract tests still cover strong ETags, 304, changed-content invalidation, and keep-alive behavior. The runbook explicitly states that changed monolithic PCK bytes download again and that no automatic source watcher/browser reload exists. No new real-browser warm-cache measurement was performed.
- **UNKNOWN (physical device and human review):** no Android Remote Debug session, native screenshot/video, installation, visual/animation approval, touch result, FPS, thermal, save, lifecycle, or soak result has been obtained. No gameplay/runtime source or committed Web/Android payload changed for this tooling checkpoint.

## Current Android profiling and packaging checkpoint — 2026-10-27

| Item | Checkpoint |
|---|---|
| Source validated by Godot/Web and Android CI | `d2eb9f70fa5b66be9c6107cda74577fa3e186556` |
| Godot/Web CI | [40488126429](https://github.com/xam-eth/Cyber-Strike/actions/runs/40488126429) — **SUCCESS** |
| Android debug APK CI | [40488126366](https://github.com/xam-eth/Cyber-Strike/actions/runs/40488126366) — **SUCCESS** |
| Committed Web payload after that gate | `41ccd8e51d8ee8cfaaa191480ad991f796131a60` |
| Documentation update | Separate source-only change; it adds no new runtime claim |

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 87 GDScript files parsed/linted/formatted, 81 tooling tests, 18/18 canonical documents, architecture boundaries, generated module map, and a 35-test inventory. The local Godot binary and machine-local export preset remained skipped.
- **VERIFIED (CI engine/browser):** Godot 4.7.2 passed **35/35 smoke tests**, including profiler window/lifecycle coverage and the existing Recovery/Defense regressions. Web export, 965-file payload audit, static delivery, and the registered browser/loading/theatre/audio gates passed in the same Godot CI run. The resulting `web/index.pck` is 90,682,980 bytes with SHA-256 `bfd82c279b38fcf2f6c2a644527003815f36da1a409b876728437d683711c70d`.
- **VERIFIED (CI Android packaging):** JDK/SDK setup, generated preset, required ETC2/ASTC import, **35/35 smoke tests**, arm64 debug APK export, Godot 4.7 sparse-bundle directory/asset-size audit, forbidden-content audit, and profiler-presence check passed. Artifact `android-debug-apk` was uploaded to the Android run. This proves packaging, not installation or device runtime.
- **IMPLEMENTED (device harness):** `scripts/android_usb.sh --profile-seconds N` records raw logcat, five-second FPS/frame-time windows with gameplay context, APK/device metadata, gfxinfo, memory, thermal, and battery evidence, then generates Markdown/CSV/JSON reports. The parser preserves window percentiles and reports weighted FPS/worst-window values rather than inventing an exact whole-run percentile.
- **UNKNOWN (physical device):** no USB installation, actual Android FPS/frame-time measurement, touch ergonomics, native-resolution behavior, thermal/throttling, battery, audiovisual quality, save preservation, or soak result has been obtained. Debug/profile output is diagnostic and is not final uninstrumented-release certification.

Earlier failed Android setup attempts (runner packages, a floating-point test fixture, missing ETC2/ASTC, and the old monolithic-PCK audit assumption) are superseded by the final successful runs above; they are not current product failures.

## 1. TECH HUNT 0 full product baseline

| Item | Checkpoint |
|---|---|
| Source validated by full CI | `b3c907e4fe5ef09db7482ecd45506259e6a4a687` |
| Full CI run | [40472922173](https://github.com/xam-eth/Cyber-Strike/actions/runs/40472922173) — **SUCCESS** |
| Committed Web payload after that gate | `adcf89e580c53d09a43a64a07438e7538b517cec` |
| Evidence date | 2026-10-27 |
| Documentation consolidation | Separate source-only change; it does not revalidate gameplay or create a new runtime checkpoint |

### TECH HUNT 0 source gate — 2026-10-27

For the Verdant Recovery implementation and its integration repairs:

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 86 GDScript files parsed/linted/formatted, 64 tooling tests, 18/18 canonical documents, 142 relative links, 86-script static-call scan, architecture boundaries, generated module map, and a 34-test inventory including `recovery_smoke.gd`.
- **VERIFIED (CI engine):** Godot `4.7.2.stable.official.ed1daf0bf` imported the project and passed **34/34 smoke tests** in [40472922173](https://github.com/xam-eth/Cyber-Strike/actions/runs/40472922173). The strict runner now fails on engine script errors even if Godot exits 0; its annotations contain no script-error failure. Recovery coverage includes real guard elimination, blocked/duplicate Secure, death/retry/reload, Endless coexistence, Extract, and exactly-once banking.
- **VERIFIED (CI deployment/traversal):** the repaired fixture completed all four authored deployment walks. Verdant settled at its authored spawn and reached `z=28.09344` with `on_floor=true`; this is automated collision/traversal evidence, not a human mission playthrough.
- **VERIFIED (CI export/browser):** Web export, 963-file PCK audit, all five Worlds plus dynamic Character/Recovery visuals, static delivery, four root/direct Chromium boots, opening/interrupted-download recovery, Vanguard selection, and Titans selection/audio steps passed in the same run.
- **VERIFIED (local static):** English and Indonesian catalogs each contain 246 keys with aligned placeholders; the cache GLB hash and provenance are recorded beside the asset.
- **SKIPPED locally:** machine-local export preset and Godot binary/runtime. CI supplies the engine/browser evidence above; it is not Android, physical-device, subjective visual/audio, human-comprehension, or retention evidence.

### Documentation consolidation gate — 2026-10-26

For the canonical-documentation/tooling consolidation itself:

- **VERIFIED (local static):** `tools/check_docs.py` accepts all 17 canonical Markdown files and their relative links, with root-guide and single module-map marker rules enforced.
- **VERIFIED (local static):** `./scripts/dev_check.sh` reports **0 failed steps**, including 56 tooling tests, static project doctor, 76-script static-call scan, architecture boundaries, generated module map, and the 28-test inventory.
- **SKIPPED locally:** gdtoolkit, machine-local export preset, and Godot binary/runtime. No new Godot, browser, Android, human, or device result is claimed for this consolidation.

### Content-module import integration — 2026-10-26

For the dynamic World/Character visual-load and package-intake change:

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 77 GDScript files parsed/linted/formatted, 64 tooling tests, 18/18 canonical documents, 141 relative links, 77-script static-call scan, architecture boundaries, package validation, generated module map, and 29-test inventory.
- **VERIFIED (local static):** importer tests cover self-contained GLTF dependencies, script/cache rejection, traversal/symlinks, deterministic bundle hashes, failed-stage preservation of active content, and committed-package checks.
- **VERIFIED (CI engine):** Godot `4.7.2.stable.official.ed1daf0bf` imported the project and passed **29/29 smoke tests**, including `module_isolation_smoke` and the existing domain regressions. The preceding `2683d60` run failed only because its new enemy fixture used `VisualRoot` instead of `Visuals`; `957858c` corrected that fixture and was fully rerun.
- **VERIFIED (CI export/browser):** Web export, 793-file PCK audit, all five World assets plus dynamic hero/held-weapon/enemy visuals, static delivery, Chromium smoke, opening/interrupted-download recovery, Vanguard shell selection, and Titans selection/audio steps passed in [40339588322](https://github.com/xam-eth/Cyber-Strike/actions/runs/40339588322).
- **SKIPPED locally:** machine-local export preset and Godot binary/runtime. CI supplies the engine/browser evidence above; it is not a local Godot run and not Android, physical-device, subjective visual/audio, or retention evidence.

Older failed/partial gameplay, integration, loading, and World reports describe their own historical commits. They must not be used to override the full checkpoint above or to describe a later branch without a new run.

## 2. Automated evidence at that checkpoint

| Gate | Result | Evidence level and boundary |
|---|---|---|
| Static source/tooling | **VERIFIED PASS in CI** | Static only; not runtime or human experience |
| Godot import + smoke suite | **VERIFIED 34/34 PASS in CI** | Headless Godot 4.7.2; includes Recovery and real World/Character/UI fixtures; strict script-error gate; not rendered/device proof |
| Web export and payload audit | **VERIFIED PASS in CI** | Export/content checks; not Android packaging |
| Root/raw browser boot | **VERIFIED PASS in CI** | Automated Chromium/WebGL at configured viewports |
| Initial opening preload and interrupted recovery | **VERIFIED PASS in CI** | Tested Web paths/network controls; not every proxy/network condition |
| Theatre selection/DEPLOY | **VERIFIED for automated Vanguard and Titans selection/build paths in this CI run** | Browser gestures and runtime logs; Frostline/Verdant/Emberfall were not given a new interactive pass in this run |
| Rebuilt-world traversal | **VERIFIED: four authored deployment walks passed in this CI run** | Verdant reached `z=28.09344`, `on_floor=true`; automated route/collision evidence, not human navigation or mission completion |
| Frostline tour | **HISTORICAL: 8/8 distinct captured frames** | Earlier automated captures; not a new visual capture or final aesthetic acceptance for this change |
| Shell/gameplay audio gates | **VERIFIED for automated signal/state checks** | Does not establish human audibility or speaker/headphone quality |

### Published payload identity

| Asset | Bytes | SHA-256 |
|---|---:|---|
| `web/index.pck` | 90,676,528 | `b5c88eaa7450d45497c625190864d20c2244c79900506d09757d7b7662c21c71` |
| `web/index.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |

These hashes identify the payload commit above. Recompute them after any later export rather than carrying the numbers forward.

### Earlier cache/delivery evidence

These warm-cache measurements belong to the earlier `15e594f` payload and were not re-measured for `afc7b8f`. The current run independently passed its opening single-download and interrupted-recovery gates.

- Cold requests returned full successful responses.
- Warm unchanged WASM/PCK requests returned **304 with zero response body** using strong content ETags.
- The real Chromium warm-reload harness transferred **220 + 220 bytes** for those revalidations rather than downloading the full assets again.
- This supports the unchanged-asset Web caching contract for the tested server/browser path. It is not a universal CDN/proxy guarantee.

## 3. Gameplay evidence interpretation

The current checkpoint verifies the implemented Verdant Seed Vault Recovery contract at the automated Godot integration boundary: real Main/Profile/Wave/HUD objects cover blocked Secure, guard elimination, permanent Arc blueprint eligibility, optional cache BP, death/retry/reload, Endless coexistence, Extract, and exactly-once banking. Existing safe Explore, Defense, theatre deployments, and the Web shell also passed their registered regressions.

This does **not** mean every presentation or human outcome is proven:

- the browser gates prove boot, preload/recovery, selection, and safe gameplay, but are not a complete interactive Recovery secure/extract playthrough;
- cache-model appearance, interaction readability, combat feel, and audiovisual quality still need rendered human review;
- human understanding of the mission and optional risk remains **UNKNOWN**;
- human mastery/enjoyment of locked-shot dodge/punish remains **UNKNOWN**;
- long-run Endless decision quality and post-cap balance remain **UNKNOWN**;
- retention or engagement improvement remains **UNKNOWN**.

A selected design, a resource file, a UI card, a headless transaction, or a passing static check must not be reported as completion of those human or device outcomes.

## 4. Explicitly unverified at the full checkpoint

- Android APK/runtime on a physical device.
- Physical touch ergonomics and device-specific input behavior.
- Representative mobile frame time, thermals, memory, and battery behavior.
- Final visual, animation, and auditory acceptance by a human on target hardware.
- Every real-world network/proxy/interruption condition.
- Full human Endless Survival playthrough and long-term stability.
- Player retention, engagement improvement, or market-level appeal.

Use [`runbooks/ANDROID.md`](runbooks/ANDROID.md), [`runbooks/WEB_PREVIEW.md`](runbooks/WEB_PREVIEW.md), and the human gates in `GAMEPLAY_DESIGN.md` for the appropriate follow-up.

## 5. Recording new evidence

Replace or extend the current checkpoint only with executed results. Do not stack contradictory addenda.

Record:

```text
Date and exact source/payload commit:
Task/scope:
Environment (static / Godot / Chromium / interactive / physical device):
Commands or CI run:
Pass/fail/skip counts and named failures:
Artifacts or reports:
What the result proves:
What remains unverified:
```

Rules:

- A skipped check is **SKIPPED**, not passed.
- A harness error is not automatically a product failure; diagnose and label it.
- An aggregate suite result does not identify an individual test unless the log does.
- Browser software rendering is not physical-device performance evidence.
- A screenshot needs the correct stage/gameplay state and must not be blank or unrelated.
- Payload sizes/hashes, test counts, and world counts are checkpoint data, not timeless constants.
- Human playtest observations include setup and sample; do not generalize them to retention without suitable evidence.
