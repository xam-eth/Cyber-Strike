# Validation Status

This document records the latest relevant evidence and its limits. It is not a design specification, a chronological collection of old reports, or proof that every current branch change has been validated.

For intended behavior, read [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md). For required gates, read [`DEVELOPMENT.md`](DEVELOPMENT.md).

## 1. Latest recorded full product checkpoint

| Item | Checkpoint |
|---|---|
| Source validated by full CI | `957858cc11e19c1daccfb221e5f14872f2a93a79` |
| Full CI run | [40339588322](https://github.com/xam-eth/Cyber-Strike/actions/runs/40339588322) — **SUCCESS** |
| Committed Web payload after that gate | `afc7b8fd53621a180373cfc793942d3cad32b544` |
| Evidence date | 2026-10-26 |
| Documentation consolidation | Separate source-only change; it does not revalidate gameplay or create a new runtime checkpoint |

### TECH HUNT 0 source gate — 2026-10-27

For the Verdant Recovery implementation and its integration repairs:

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 86 GDScript files parsed/linted/formatted, 64 tooling tests, 18/18 canonical documents, 142 relative links, 86-script static-call scan, architecture boundaries, generated module map, and a 34-test inventory including `recovery_smoke.gd`.
- **VERIFIED (local static):** English and Indonesian catalogs each contain 246 keys with aligned placeholders; the cache GLB hash and provenance are recorded beside the asset.
- **DIAGNOSED (previous CI, not a current pass):** [40464131772](https://github.com/xam-eth/Cyber-Strike/actions/runs/40464131772) for `f812196` passed 32/33 headless tests before one test-side type-inference parse failure; its opening-loading QA also waited for the pre-localization label `Masuk` instead of the enabled localized ENTER/MASUK action. Those two harness/source issues are repaired in this change, but require a fresh CI run.
- **PENDING:** Godot import and execution of all 34 tests, Web export/payload audit, and Chromium opening/recovery/player-path checks for this Recovery source. Local engine and export preset remain unavailable; no runtime pass is inferred from static analysis.

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
| Godot import + smoke suite | **VERIFIED 29/29 PASS in CI** | Headless Godot 4.7.2; includes real World/Character/UI isolation fixtures; not rendered/device proof |
| Web export and payload audit | **VERIFIED PASS in CI** | Export/content checks; not Android packaging |
| Root/raw browser boot | **VERIFIED PASS in CI** | Automated Chromium/WebGL at configured viewports |
| Initial opening preload and interrupted recovery | **VERIFIED PASS in CI** | Tested Web paths/network controls; not every proxy/network condition |
| Theatre selection/DEPLOY | **VERIFIED for automated Vanguard and Titans selection/build paths in this CI run** | Browser gestures and runtime logs; Frostline/Verdant/Emberfall were not given a new interactive pass in this run |
| Rebuilt-world traversal | **HISTORICAL: four rebuilt worlds passed earlier automated checks** | MainNorth reached `z=25.30062`, `on_floor=true`; not rerun as a separate traversal gate for `957858c` |
| Frostline tour | **HISTORICAL: 8/8 distinct captured frames** | Earlier automated captures; not a new visual capture or final aesthetic acceptance for this change |
| Shell/gameplay audio gates | **VERIFIED for automated signal/state checks** | Does not establish human audibility or speaker/headphone quality |

### Published payload identity

| Asset | Bytes | SHA-256 |
|---|---:|---|
| `web/index.pck` | 54,018,072 | `35654f00bb47968dc6db3610546d6665376f37413afd53c62372d54730e0cfd3` |
| `web/index.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |

These hashes identify the payload commit above. Recompute them after any later export rather than carrying the numbers forward.

### Earlier cache/delivery evidence

These warm-cache measurements belong to the earlier `15e594f` payload and were not re-measured for `afc7b8f`. The current run independently passed its opening single-download and interrupted-recovery gates.

- Cold requests returned full successful responses.
- Warm unchanged WASM/PCK requests returned **304 with zero response body** using strong content ETags.
- The real Chromium warm-reload harness transferred **220 + 220 bytes** for those revalidations rather than downloading the full assets again.
- This supports the unchanged-asset Web caching contract for the tested server/browser path. It is not a universal CDN/proxy guarantee.

## 3. Gameplay evidence interpretation

The old full checkpoint supports the pre-Recovery combat/session/world baseline only. The current source now implements Verdant Seed Vault Recovery, its optional crashed-lab cache, persistent Arc blueprint eligibility, and Extract/Continue; the registered Recovery smoke drives real Main/Profile/Wave/HUD objects through blocked Secure, real guard elimination, death/retry/reload, Endless coexistence, Extract, and exactly-once banking.

Until the fresh engine/browser run is recorded, the following are **IMPLEMENTED IN SOURCE BUT RUNTIME-UNVERIFIED for this change**:

- mission card/tracker → guarded cache → Secure → permanent blueprint → redeploy;
- death-before/death-after Secure and immediate profile persistence;
- Extract versus Continue to Endless, optional-cache completion during waves, and run cleanup/banking;
- the actual rendered cache model, interaction readability, and browser player path.

The following remain **UNKNOWN** regardless of that automated run:

- human understanding of the mission and optional risk;
- human mastery/enjoyment of locked-shot dodge/punish;
- long-run Endless decision quality and post-cap balance;
- retention or engagement improvement.

A selected design, a resource file, a UI card, or a passing static check must not be reported as completion of those human or device outcomes.

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
