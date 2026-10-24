# Cross-Domain Integration Validation Report

Date: 2026-10-24
Target branch: `arena/0b0dc2fd-cyber-strike`
Baseline and ownership: [`INTEGRATION_BASELINE.md`](INTEGRATION_BASELINE.md)

## 1. Final status

# INTEGRATED WITH OPEN ISSUES

**VERIFIED:** the real World Design implementation is merged, the newer optimized Character implementation remains active, and the **actual** UI/UX Workflow branch is now merged and connected to the same registry/progression/gameplay contracts. The integrated source passes 28/28 Godot tests, static checks, Web export, four Chromium boot checks, and a strict WORLD → Vanguard selection gate. The regenerated payload also passes local Vanguard, Neon encounter/input/audio, HUD pause/settings, shell-frame, and payload-content checks.

This is not a claim of final visual acceptance, a complete human run, Android export, physical touch behavior, mobile performance, or retention improvement. Issues #4, #6, #7, and #8 remain open. Remote issue #5 is based on an incorrect UI source mapping and could not be edited or closed with the integration token; issue #8 and the tracked local correction supersede it.

## 2. Source dispositions and traceable checkpoints

| Role / checkpoint | Exact branch / commit | Disposition and evidence |
|---|---|---|
| Gameplay Core baseline | `arena/0b0dc2fd-cyber-strike` / `51f1dac382db4d60722dabee7826de14e53036bd` | Baseline audit; gameplay implementation at `ad6a221dda7a426a409071258d432951b4ff061b` |
| World Design source | `arena/e7fb25af-cyber-strike` / `71e40ba36028530ce72a43a398d8913ea2ebe1b2` | **Merged** as second parent of `b24c90916483ea60eb844651ae5ca1507dde2392` |
| Character Content candidate | `arena/9f883711-cyber-strike` / `9e0ddadcb73aec9bdc935bbc905ecdce23e33568` | **Not merged:** older three-clip, 482,282-triangle candidate would downgrade the active optimized ten-clip, 36,151-triangle hero |
| Actual UI/UX Workflow source | `arena/c08beb55-cyber-strike` / `f99fb06fbaa3943d83ccc63cd235df86cd69e19d` | **Merged** as second parent of `2243a5f888d379fc5a6457bd5984529b2dc26e3e`; first parent `c104a32d2428480598ec92ffe6f9e7e136c30a01` |
| Incorrect former UI mapping | `arena/c8558858-cyber-strike` / `e5ba023c9a6e523b03fff2ca29889d0e76ec2d29` | Its `ExoconflictFlow` findings are not a disposition of the actual UI branch and were not used to reject it |
| World selection/export reconciliation | `c2e9996babb100c6f02e82bb2a4bd233b8572d50` | Saved-world assertion, authoring-input exclusion, payload regression checks |
| Pre-UI validated source/payload | `ec8e624dd756fb3a3a6f50a8bfbdd65aff54388b` / `c26d4e508dd55266ad9fec8d0e5707e494312e2a` | Historical 29-test and browser evidence only; not evidence for the actual UI merge |
| Browser JSON repair | `66ad67940893128bc2658c00e7fd6ebc18f3c5cf` | Journey progress moved to stderr in `--json` mode after local reproduction |
| Measured WORLD selector repair | `9e82c0b0d655ddee44cedc682b6742cb9bfcaab0` | Final validated source; CI run `40099367032` **SUCCESS** |
| Final generated payload | `cec0fddf95ebb47cc4218a8b67a6e62eb2cb88b1` | Generated from `9e82c0b`; 95,586,752-byte PCK; payload audit passed |

The World and actual UI integrations use real merge commits. No source branch was deleted, no history was rewritten or force-pushed, nothing was merged to `main`, and no uncommitted work was discarded. Safety stash `bedfbdd8a2e315c0b10efd071fee47cce5bca9c5` remains retained.

## 3. Conflicts and semantic reconciliation

### World merge

- `game/scenes/main.tscn`: preserved World selection, both world scenes, early `ProgressionService`, HUD/gameplay composition, **and** Core's explicit Runner/Shooter `EnemyDefinition` resources. This was a shared-composition conflict, not a one-sided file choice.
- `docs/ARCHITECTURE.md`: retained the World architecture and Core contract/test guidance; regenerated the marked module map.
- The old non-static World build-call defect was repaired by the World implementation rather than repeating the old manual three-`static` edit.

### Actual UI merge

The merge of `f99fb06` produced exactly four textual/binary conflicts:

- `README.md`: retained the integrated World/Character/test inventory and the actual UI shell workflow; updated the suite to 28 tests.
- `docs/ARCHITECTURE.md`: retained compatible guidance from both sides and regenerated the module map after semantic reconciliation.
- `web/index.html`: retained the then-current integrated config only until CI could regenerate it. The final config now names the 95,586,752-byte PCK.
- `web/index.pck`: retained the newer pre-merge integrated binary only as a conflict-resolution placeholder. It was **not** used as evidence for the UI merge; CI replaced it with `cec0fdd`.

Textual auto-merges were also inspected and reconciled:

- **Shared shell contract:** source `ui/shell.js` sent DEPLOY to `qa_stage=GAMEPLAY`, bypassing HERO/WORLD. The integrated adapter sends it to `qa_stage=WORLD`, preserving both registered worlds, loadout selection, and `ProgressionService`. No JavaScript content registry was added.
- **UI-domain layout decision:** landscape-only is intentional and documented in `docs/DECISIONS.md` §31. Portrait/desktop HUD arrangements, `HudPauseGesture`, and its obsolete test were removed with that behavior; the resulting suite has 28 tests. This was not silently “repaired” by restoring a second layout.
- **Front-end focus:** deferred primary-button focus now checks that the Control is valid, visible, and inside the tree; entering a stage focuses its primary action through the same guard.
- **Pause/retry/cancel:** the source's 26/27 CANCEL DEFENSE failure was not treated as proof of a Core lifecycle defect. The smoke journey now lets results teardown and pause layout settle between separate Retry → Pause → Cancel taps and asserts an actionable pause panel before cancellation. Damage, waves, rewards, and run-lifecycle rules were not changed for this UI failure.
- **Browser regression 1:** journey logging contaminated `--json` stdout. `66ad679` moved progress to stderr; the corrected report was parsed successfully locally.
- **Browser regression 2:** CI `40098902155` reached WORLD and gameplay but failed the Vanguard build assertion. Fixed fractional coordinates were replaced by the engine's `qa_menu` Control rectangles. QA now requires `FrontEnd: world selected vanguard_station` before clicking the measured LAUNCH rect, then requires the real `VanguardStation:` build log.
- `front_end.gd`, `stage_world_select.gd`, HUD/input/layout modules, tests, and `tools/web_qa.mjs` were checked for removed desktop/portrait references; none remain.

## 4. Integrated, already present, and blocked work

### World Design — INTEGRATED

**VERIFIED:** the staged Neon Frontier GLB, Vanguard Station, world registry/build gates, selection-aware startup, authored world motion, world tests, asset provenance/forge tooling, and static-call checking are connected. Non-runtime `game/assets/world/real/` authoring inputs remain in source but are excluded from player exports; required staged runtime assets remain included.

### Character Content — NEWER IMPLEMENTATION ALREADY PRESENT

**VERIFIED:** active `hero.glb` has ten clips (`aim`, `aim_run`, `aim_walk`, `death`, `fire`, `hit`, `idle`, `reload`, `run`, `walk`), 36,151 triangles, and `fallback=no` in browser logs. The older candidate has idle/walk/run only and 482,282 triangles. Merging it would remove combat animation behavior and add an unused high-budget source copy, so it was not merged.

Character rights/provenance and representative mobile-budget evidence remain open in issue #4. The corrected ready-to-submit scope is tracked at [`issues/CHARACTER_CONTENT_INTEGRATION.md`](issues/CHARACTER_CONTENT_INTEGRATION.md).

### UI/UX Workflow — INTEGRATED WITH VISUAL/DEVICE FOLLOW-UP

**VERIFIED:** the actual `c08beb55` shell, local fonts, AEGIS presentation, landscape front end/HUD, and UI tests are integrated. The root shell hands off to the engine WORLD stage, and the same authoritative definitions and `ProgressionService` drive selection and gameplay.

**Open:** human visual approval and physical-device behavior are not established. Captured frames support layout/interaction diagnostics, including readable pause/settings panels, but also justify UI review of the pause hint's arrow glyph and small-bottom-action spacing. Those observations are not relabelled as a gameplay blocker or as final art acceptance. Corrected scope and next actions are in issue #8 / [`issues/UI_UX_WORKFLOW_INTEGRATION.md`](issues/UI_UX_WORKFLOW_INTEGRATION.md).

### Gameplay Core — PRESERVED AND ADAPTED

- Explicit enemy definitions, combat orchestration, damage/health, waves, rewards, run lifecycle, and upgrade/progression contracts remain under Core.
- Saved Arc Shooter + Vanguard selection still reaches `main.tscn`; `front_end_journey_smoke.gd` covers the saved-loadout contract.
- Export authoring-input exclusion and `tools/check_payload.py` prevent the 55 MB source authoring library from entering the player PCK without deleting source assets.
- No duplicate wave manager, parallel gameplay state machine, second selection roster, new economy, elite system, or unapproved upgrade hook was introduced.

## 5. Evidence by verification level

### Static evidence — VERIFIED

Final CI run: [40099367032](https://github.com/xam-eth/Cyber-Strike/actions/runs/40099367032), source `9e82c0b0d655ddee44cedc682b6742cb9bfcaab0`.

- Static development job: **PASS** — GDScript parse/lint/format, project doctor, tooling, static calls, layer boundaries, smoke inventory, and handover map.
- Local available static gate: **PASS** — 75 GDScript files and 36 tooling tests; local Godot and local export-preset steps were explicitly skipped.
- `node --check ui/shell.js` and `node --check tools/web_qa.mjs`: **PASS**.

Static success was not treated as playability evidence.

### Headless engine evidence — VERIFIED

- Engine: `4.7.2.stable.official.ed1daf0bf`.
- Final CI engine job `120888148266`: **28 passed, 0 failed (of 28, import ok)**.
- The suite includes front-end journey, menu layout, showcase, data source, landscape HUD/touch, CANCEL DEFENSE, both worlds, hero/showcase, combat, rewards, progression, and the gameplay vertical slice.
- The same 28/28 result was observed on merge commit `2243a5f` before the two browser-harness repairs; those repairs did not alter combat rules.
- Local engine: **NOT RUN** — no local Godot installation. Engine evidence above is CI evidence.

### Web export, delivery, and CI browser evidence — VERIFIED

Final CI Web job `120888148274`: **PASS**.

- Web export and static delivery passed; html/js/wasm/pck returned HTTP 200.
- Chromium boot checks passed `/` and `/web/index.html` at **844×390** and **667×375**.
- `Browser world-selection contract` passed: engine WORLD stage, measured Vanguard pin selection, real gameplay entry, and Vanguard build assertion.
- Payload commit/push completed and produced `cec0fddf95ebb47cc4218a8b67a6e62eb2cb88b1`.
- Final `web/index.pck`: **95,586,752 bytes**, **873 packed files**; local `tools/check_payload.py` **PASS**, with no authoring-source `assets/world/real/` entries.
- GitHub Pages deployment remained skipped by its existing branch condition. This is committed static payload publication, not a Pages-deployment claim.

Earlier UI merge runs `40098741822` and `40098902155` were not counted as final passes. The first had a locally reproduced JSON-report defect; the second specifically failed `front-end selection built Vanguard Station gameplay`. Neither published a payload. Their repairs are recorded above and the replacement run is the successful gate.

### Interactive browser evidence on final payload `cec0fdd` — VERIFIED FOR THE REQUESTED CHECKS

Reports and frames are under ignored `exports/integration-audit/`; they are not presented as committed visual sign-off artifacts.

| Evidence path | Result and limits |
|---|---|
| `ui-final-vanguard/report.json` | **PASS** — `FrontEnd: world selected vanguard_station`; `VanguardStation: 421 kit modules, 17 omnis, 4 rooms`; safe Explore reached. No full run claimed |
| `ui-final-neon/report.json` | **PASS for requested checks** — Explore → Preparing Defense (5 s) → Defense started; scripted firing, first weapon voice, mute and unmute all observed. Frames show health 100 → 92 and ammo 24 → 22. No KO, reward, Results, or complete-run claim |
| `ui-final-hud/report.json` | **PASS** — paused → settings opened → settings closed → resumed; Controls/HUD/Access tabs and Access-bottom scrolling captured |
| `ui-final-shell/manifest.json` | **PASS, 6/6 frames** — opening/hub/settings at 844×390 and 667×375; no blank frame, DOM overflow, or console error |

Selected WORLD, Neon Defense/play, pause, shell, and Access frames were inspected as visual diagnostics. They establish nonblank rendered UI and the specific visible changes above, not human visual acceptance, GPU performance, or physical touch behavior. The Neon close-structure framing remains covered by issue #7.

Earlier deep browser evidence from payload `26debc5` remains historical and was not reused as proof for this UI merge. A full eight-vantage tour was not rerun on `cec0fdd`.

## 6. Open issues and concrete next actions

| Issue | Owner | Current status | Next action and required validation |
|---|---|---|---|
| [#4 Character integration follow-up](https://github.com/xam-eth/Cyber-Strike/issues/4) | Character Content | Optimized hero is integrated; source/derived rights and representative mobile budgets are unverified. Remote correction was permission-denied, so the remote body remains broader than the tracked correction. | Apply `docs/issues/CHARACTER_CONTENT_INTEGRATION.md`; document usage/redistribution terms and profile intended mobile hardware. Preserve ten clips, attachment/muzzle contracts, and all hero/showcase/gameplay tests |
| [#5 Incorrect UI source mapping](https://github.com/xam-eth/Cyber-Strike/issues/5) | UI/UX + maintainer | Remote issue remains open but audits the wrong branch. Edit and close were both denied by GitHub permissions. **Superseded by #8**, not a valid reason to reject the actual UI implementation | Maintainer: close or re-scope #5 manually to point to #8 and `docs/issues/UI_UX_WORKFLOW_INTEGRATION.md`; do not reuse its `ExoconflictFlow` disposition |
| [#6 Canonical product spelling](https://github.com/xam-eth/Cyber-Strike/issues/6) | UI/UX + project owner | Imported `Exocomplict` conflicts with the assignment spelling; Core cannot choose the product identity unilaterally | Confirm one canonical spelling, then coordinate window/Web/Android/docs changes and rerun metadata/static/browser checks |
| [#7 Neon spawn/camera framing](https://github.com/xam-eth/Cyber-Strike/issues/7) | World Design + Gameplay Core | Final Neon frames still show a close structure dominating the initial/combat view; traversal evidence does not prove a hard movement blocker | Inspect world-owned spawn landmarks and Core camera/prop collision together. Validate first frames and traversal in both worlds at 844×390 and 667×375; do not claim a movement blocker without reproduction |
| [#8 Actual UI integration and review](https://github.com/xam-eth/Cyber-Strike/issues/8) | UI/UX Workflow | Technical selection/engine/browser gates pass. Human visual and physical-device acceptance remain open; pause glyph/small-action spacing deserve targeted review. GitHub denied the validation comment, so the tracked local issue document carries the update | Review `SETTINGS → CONTROLS` glyph rendering and bottom Access action spacing in the captured frames; correct confirmed font/layout defects at both landscape sizes. Then run shell shots, HUD smoke, pause/settings browser QA, and physical touch review before visual/device sign-off |

## 7. Explicitly unverified or unchanged

- **UNKNOWN:** a complete human Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy playthrough. Automated tests cover the existing pieces; the browser passes do not complete a full run.
- **UNKNOWN:** Android APK/AAB export, physical Android/touch behavior, thermal/frame-time/memory performance, human heard audio, and retention impact.
- **UNKNOWN:** final visual quality, animation/effects approval, every settings gesture, and every device orientation during live combat.
- **VERIFIED absent, not an integration regression:** milestone upgrade selection/application and elites were absent from the approved baseline and were not invented.
- **Unchanged:** repository default remains `pulse_rifle`. “Energy Rifle” mapping and Overcharge/Rapid Pulse/Chain Reactor remain unapproved candidates.
- **Not claimed:** KO/reward/Results from the final Neon browser pass, full combat/redeem/redeploy browser completion, or physical-device performance.

## 8. Handoff

The branch now contains one connected game rather than parallel unused World, Character, and UI modules. Continue from the open issues above without replacing the optimized hero, bypassing WORLD selection, restoring undocumented parallel layouts, or treating CI as device/visual acceptance. The validated integration runtime source was `9e82c0b`; its generated payload was `cec0fdd`. The current Web follow-up below preserves those integrations and supersedes only the current preview source/payload checkpoint.

## 9. Current Web loading follow-up

**Status remains INTEGRATED WITH OPEN ISSUES.** The player-reported stuck DEPLOY/loading handoff was investigated separately; no World, Character, combat, reward, or progression rules were changed.

- Source repair: `eac21bfce04d230a3ecc3c44d9b3b6b24af03e5d` (`Repair web loading progress and recovery`).
- Current generated payload: `b055f0dca4f35fcc0d67a7f4485ff8494c36548e`; PCK **95,586,768 bytes**, **873 files**, payload audit **PASS**.
- CI [40103458382](https://github.com/xam-eth/Cyber-Strike/actions/runs/40103458382): **SUCCESS** — static checks, 28/28 import-OK Godot tests, export/delivery, four browser boots, interrupted WASM/PCK recovery, and WORLD → Vanguard.
- **VERIFIED defects:** rewritten `./web/index` asset paths lacked matching `fileSizes` keys, producing real byte callbacks with `total=0`; Godot `doInit()` also accepted but did not use `reject` for three initialization stages.
- **VERIFIED recovery:** final-payload local gates report `135101522 / 135101522`, monotonic 0→100 progress, and retry into WORLD for both interrupted WASM and PCK. Truncated-body diagnostics also produced an actionable error and successful retry rather than an endless overlay.
- Exact diagnosis, commands, evidence boundaries, and player troubleshooting: [`WEB_LOADING_RECOVERY.md`](WEB_LOADING_RECOVERY.md).

The precise external browser/proxy cause of the user's original BrokenPipe remains **UNKNOWN**. Android, physical-device performance/touch, complete human gameplay, and final visual acceptance remain unverified; the loading repair does not close those issues.
