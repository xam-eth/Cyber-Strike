# Cross-Domain Integration Validation Report

Date: 2026-10-24
Target branch: `arena/0b0dc2fd-cyber-strike`
Baseline and ownership: [`INTEGRATION_BASELINE.md`](INTEGRATION_BASELINE.md)

## 1. Final status

# INTEGRATED WITH OPEN ISSUES

The actual World implementation is merged; the newer optimized Character implementation and registry-driven UI already present in Gameplay Core are preserved and connected to it. Both registered worlds reach real gameplay, the saved-loadout contract is covered, the Godot suite passes, the Web payload publishes, and browser encounter/tour checks run against the exported game.

This is **not** a claim of final visual acceptance, full human gameplay completion, Android export, physical touch-device behavior, mobile performance, or retention improvement. Issues #4–#7 remain open as described below. The older Character/UI side branches were deliberately not merged over newer implementations; that is a source disposition, not a missing runtime module.

## 2. Traceable integration checkpoints

| Checkpoint | Commit | Result |
|---|---|---|
| Pre-integration Gameplay Core | `51f1dac382db4d60722dabee7826de14e53036bd` | Baseline audit and ownership map |
| World merge | `b24c90916483ea60eb844651ae5ca1507dde2392` | Merge parents `51f1dac` and `71e40ba3`; preserved both sides' compatible work |
| Selection/export reconciliation | `c2e9996` | Saved-world assertion, authoring-input exclusion, payload regression checks |
| Published payload used for deep browser QA | `26debc5` | Generated Web PCK/html from `c2e9996`; 95,602,192-byte PCK |
| Final validated handoff source | `ec8e624dd756fb3a3a6f50a8bfbdd65aff54388b` | Documentation, QA harness, and comment reconciliation; final CI `40088522484` passed |
| Final published payload | `c26d4e508dd55266ad9fec8d0e5707e494312e2a` | Generated from `ec8e624`; 95,602,304-byte PCK; payload audit passed |

The World merge used a real merge commit. No source branch was deleted, no history was rewritten or force-pushed, no uncommitted work was discarded, and nothing was merged to `main`.

### Merge conflicts and resolutions

- `game/scenes/main.tscn`: kept World selection, both world scenes, early ProgressionService, HUD/gameplay composition, **and** Gameplay Core's explicit Runner/Shooter `EnemyDefinition` resources. Resolved as a shared-composition conflict.
- `docs/ARCHITECTURE.md`: retained World's architecture/module inventory and restored Gameplay Core contract/test/EnemyDefinition guidance. Regenerated the marked module map and verified it with `tools/module_map.py --check`.
- Agent-only `.claude` metadata from the source tree was not retained as a product runtime input.
- Character and UI source branches were not merged after implementation comparison showed that they would downgrade or parallelize newer active systems.

## 3. Integrated, already present, and blocked work

### World Design — integrated

**VERIFIED:** `arena/e7fb25af-cyber-strike` / `71e40ba36028530ce72a43a398d8913ea2ebe1b2` is the second parent of `b24c909`.

Integrated behavior includes the staged real Neon Frontier GLB, Vanguard Station, world registry/build gates, selection-aware startup, authored world motion, world tests, asset-forge provenance/tooling, and static-call checking. The old non-static World build-call defect is gone; the merged suite passes.

Non-runtime `game/assets/world/real/` authoring inputs remain in source for reproducibility but are excluded from player exports. The required staged runtime asset `game/assets/forge/world/world.glb` remains included.

### Character Content — newer implementation already present; old branch superseded

**VERIFIED:** active `hero.glb` is the optimized derivative documented by `HERO_RIG_PIPELINE.md`: ten clips (`aim`, `aim_run`, `aim_walk`, `death`, `fire`, `hit`, `idle`, `reload`, `run`, `walk`) and about 36k triangles. Browser logs confirm ten clips and `fallback=no`.

The Character candidate `arena/9f883711-cyber-strike` / `9e0ddadc` has only idle/walk/run and about 482k triangles. Merging its direct adapter/source copy would replace a more complete optimized hero with an older integration. It was not merged. Character rights/provenance and representative mobile-budget evidence remain open in issue #4; the ready-to-submit correction is tracked at [`issues/CHARACTER_CONTENT_INTEGRATION.md`](issues/CHARACTER_CONTENT_INTEGRATION.md).

### UI/UX Workflow — current newer front end retained; parallel prototype blocked

**VERIFIED:** the integrated game still starts through `front_end.tscn` and the registry-driven stage flow. The same `ProgressionService` supplies hero/weapon/world selection to gameplay. Browser QA walks the actual screens rather than booting `main.tscn` directly.

The UI candidate `arena/c8558858-cyber-strike` / `e5ba023c` adds an uninstantiated `ExoconflictFlow`, independent selections/content ids, a hardcoded `nexus01`, and no production `selection_complete` listener. Its branch CI was red and its source has an additional `character_visual.gd` indentation defect. It was not merged over the newer UI. Issue #5 owns the domain reconciliation decision.

### Gameplay Core repairs and reconciliation

- Explicit enemy definitions remain connected to `WaveDirector`; no duplicate wave manager was introduced.
- Saved Arc Shooter + Vanguard Station selection is applied through the real front end into `main.tscn`; the test asserts both the saved weapon and selected world build gate.
- Export authoring-input exclusion reduced the PCK without removing runtime world assets.
- `tools/check_payload.py` now hard-fails if `assets/world/real/` enters an exported pack.
- Browser QA now enters gameplay **before** encounter input/screenshots, requires gameplay before scripted play, and has a `--select-vanguard` path whose pass condition is the real `VanguardStation:` runtime log.

## 4. Automated and runtime evidence

### Static and Godot CI

Final CI run: [40088522484](https://github.com/xam-eth/Cyber-Strike/actions/runs/40088522484) at source commit `ec8e624dd756fb3a3a6f50a8bfbdd65aff54388b`. The same gate also passed as run `40086792388` at `c2e9996`.

| Check | Evidence |
|---|---|
| Static development checks | **PASS** — GDScript parse/lint/format, project doctor, tooling, static calls, boundaries, inventory, handover map |
| Tooling self-tests | **PASS** — 36 tests, including Web preset exclusion regression |
| Godot engine | `4.7.2.stable.official.ed1daf0bf` |
| Import + smoke suite | **29 passed, 0 failed (of 29, import ok)** |
| Gameplay vertical slice | Included in the passing suite: real spawned Runner, two projectile hits, KO/wave rewards, intermission to wave two |
| Saved-loadout reconciliation | Edited `front_end_journey_smoke.gd` was included in the passing 29-test commit |
| Local engine | **NOT RUN** — no local Godot installation; the real engine evidence above is CI, not an assumed local result |

Local `./scripts/dev_check.sh` also passed all available steps for 75 GDScript files and 36 tooling tests; local Godot/preset steps were explicitly skipped.

### Web export and publication

Final CI Web job `120856253130` passed export, static delivery, artifact upload, Chromium QA, and payload commit/push.

- Previous merged PCK: **150,015,960 bytes**; payload publication failed after generation.
- First repaired PCK (`26debc5`): **95,602,192 bytes**; payload publication **passed**.
- Final PCK (`c26d4e5`): **95,602,304 bytes**; final payload publication **passed**.
- Static delivery returned HTTP 200 for html/js/wasm/pck.
- CI Chromium boots passed `/` and `/web/index.html` at **1280×720** and **390×844**.
- Local `tools/check_payload.py web/index.pck`: **PASS**, 873 packed files; no authoring-source `assets/world/real/` payload entries.
- The 55 MB source authoring library was not deleted; only its export inclusion changed.

GitHub Pages deployment was skipped by its existing branch condition. This is **committed static payload publication**, not a claim of a Pages deployment.

### Deep browser QA against committed payload `26debc5`

All commands used the actual exported game in headless Chromium/WebGL, not a scene mock. Reports and frames are under ignored `exports/integration-audit/`. These deep interaction passes predate final payload `c26d4e5`; the intervening source changes are documentation, external QA tooling, and one GDScript comment. Final CI rerun passed all 29 engine tests, export, and four browser boots, but the deeper encounter/tour scripts were not rerun on `c26d4e5`.

| Pass | Result and limits |
|---|---|
| `browser-vanguard-3/report.json` | **PASS** — real theatre selection visibly changed to Vanguard Station; runtime logged `VanguardStation: 421 kit modules, 17 omnis, 4 rooms`; Explore → Preparing → Defense completed; no script/page/request errors |
| `browser-neon-combat/report.json` | **PASS for requested checks** — default front-end journey, safe Explore, preparation, Defense, scripted input, audio pipeline, weapon voice, and mute control. Frames show health changing 100 → 92 and ammo 24 → 23. No KO/reward/full Results claim |
| `browser-neon-tour/report.json` | **PASS** — real gameplay reached, review camera engaged/released, eight of eight tour frames distinct. Spot-checked frames show actual staged world geometry across multiple districts |

Two earlier Vanguard harness attempts correctly failed their selected-world assertion and built Neon instead; they were not counted as passes. The final canvas-selector run passed only after the selected screen and runtime build both showed Vanguard.

The browser used software rendering. These results establish real exported behavior and provide visual diagnostic frames, not GPU performance, final art approval, or physical touch evidence.

## 5. Open issues and concrete next actions

| Issue | Owner | Why it remains open | Next action and validation |
|---|---|---|---|
| [#4 Character integration follow-up](https://github.com/xam-eth/Cyber-Strike/issues/4) | Character Content | Source/derived-asset rights and representative mobile budgets are not fully evidenced. GitHub denied both correction edit and comment, so the remote issue still has its original broader body. | Character owner: apply the tracked correction in `docs/issues/CHARACTER_CONTENT_INTEGRATION.md`, attach provenance/license evidence, and profile representative devices. Do not replace the optimized ten-clip hero with the old candidate. |
| [#5 UI/UX parallel front-end reconciliation](https://github.com/xam-eth/Cyber-Strike/issues/5) | UI/UX Workflow | The source branch's EXOCONFLICT flow is disconnected, duplicates selection state, and had parse/CI failures. | UI owner: choose which approved presentation/navigation work belongs in the registry-driven `FrontEnd`; remove/retire the parallel flow or connect it through the authoritative contracts. Validate startup, saved selections, parse, CI, and browser navigation. |
| [#6 Canonical product spelling](https://github.com/xam-eth/Cyber-Strike/issues/6) | UI/UX + project owner | Imported `Exocomplict` conflicts with assignment `EXOCOMFLICT`; package identity cannot be renamed unilaterally by Core. | Confirm one canonical spelling, then coordinate window/Web/Android/docs changes and rerun metadata/static/browser checks. |
| [#7 Neon spawn/camera framing](https://github.com/xam-eth/Cyber-Strike/issues/7) | World Design + Gameplay Core | Real browser frames at `(0,0,8)` are dominated by a close structure; traversal passes, so this is not labelled a hard movement blocker. | Inspect world-owned spawn landmarks and Core camera/prop collision together. Add a selected-world-aware spawn contract if needed; validate desktop/portrait first frames and both world/traversal suites. |

### Additional unverified or deliberately unchanged behavior

- **UNKNOWN:** physical Android/touch-device behavior, Android APK/AAB export, device thermal/frame-time performance, human heard audio, and full human visual acceptance.
- **UNKNOWN:** complete human Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy playthrough. Automated tests cover existing combat/reward/progression pieces; browser QA does not complete a full run.
- **VERIFIED absent, not an integration regression:** milestone upgrade selection/application and elites were absent from the approved baseline and were not invented.
- **Unchanged:** repository default remains `pulse_rifle`. “Energy Rifle” mapping and Overcharge/Rapid Pulse/Chain Reactor remain unapproved design candidates.
- **Not claimed:** retention improvement, final effects/animation quality, every menu/settings gesture, or every device orientation during live combat.

## 6. Handoff

The integrated branch is suitable for continued domain review and further validation with the open issues above. It is not a release-quality/device-acceptance sign-off. Preserve the traceable merge/source dispositions, keep runtime staged assets while excluding authoring-only inputs, and require the corresponding runtime/visual/device evidence before upgrading this status.
