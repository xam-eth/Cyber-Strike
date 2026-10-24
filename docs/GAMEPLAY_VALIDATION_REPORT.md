# Gameplay Validation Report

Date: 2026-10-24  
Branch: `arena/0b0dc2fd-cyber-strike`  
Base: `2bd09b05cd665aa5ac8d877461aa1208d2115aae`  
Code/CI checkpoint: `ad6a221dda7a426a409071258d432951b4ff061b`  
Godot CI: [run 40082660757](https://github.com/xam-eth/Cyber-Strike/actions/runs/40082660757)

## 1. Result summary

| Area | Result |
|---|---|
| Repository gameplay audit | **PASS** — source, scenes, resources, tests, and design docs inspected; absent systems identified |
| Local static checks | **PASS** — 81 GDScript files, tooling, architecture, doctor, and handover map |
| CI static checks | **PASS** |
| Godot engine suite on CI | **EXECUTED — 24 passed, 3 failed of 27; overall FAIL** |
| New gameplay vertical-slice test | **EXECUTED as part of that suite; individual outcome UNKNOWN** (see §4) |
| Base committed WebAssembly boot | **PASS** for the tested entry/viewport |
| Base browser Explore → Prepare → Defense | **PASS**, with two Runners and a real Pulse shot observed |
| CI Web export of code checkpoint | **EXPORT PASS; BROWSER FAIL** on the base world parse error |
| Android/device/performance | **NOT RUN** |
| Human hook/retention playtest | **NOT RUN** |

This is not a clean full-suite validation. The user explicitly chose to leave the World Development parse error untouched, so it remains an integration blocker.

## 2. Static checks actually executed

### 2.1 Initial environment/baseline

`./scripts/dev_check.sh` was first run before installing the optional local linter:

- Project doctor: **PASS**, 0 failures / 30 warnings.
- Tooling self-tests: **PASS**, 25 tests.
- Architecture boundaries: **PASS**.
- Smoke inventory: **PASS**, 26 tests at that point.
- gdtoolkit: **SKIP** (not installed).
- Godot: **SKIP** (not installed).
- Local export preset: **SKIP** (machine-local file absent).

The warnings are pre-existing node-path/input/signal/orphan-reference warnings. They are not treated as runtime proof.

### 2.2 Final local static state

After installing `gdtoolkit==4.5.0` into the git-ignored `.venv` and adding the content contract:

```text
gdparse:           PASS, 81 game GDScript files
gdlint:            PASS, 81 game GDScript files
gdformat --check:  PASS, 81 game GDScript files
project doctor:    PASS, 0 failures / 30 warnings
tooling unittest:  PASS, 25 tests
architecture:      PASS, no new layer/module violations
smoke inventory:   PASS, 27 tests discovered
handover map:      PASS
local preset:      SKIP (not required for source checks)
local Godot:       SKIP (binary unavailable)
```

Additional checks on the new external test:

- `gdlint tests/gameplay_vertical_slice_smoke.gd`: **PASS**.
- `gdformat --check tests/gameplay_vertical_slice_smoke.gd`: **PASS**.
- `git diff --check`: **PASS**.

### 2.3 CI static result

The `Static checks (gdtoolkit + project doctor)` job in run `40082660757` completed **SUCCESS** on `ad6a221`.

## 3. Runtime checks actually executed

### 3.1 Committed baseline WebAssembly boot — PASS

Command equivalent:

```bash
node tools/web_qa.mjs \
  --url http://127.0.0.1:8000 \
  --page / --viewport 390x844 --timeout 90 --json
```

Observed on the base committed payload:

- Godot `4.7.2.stable.official.ed1daf0bf` booted.
- WebGL 2 context alive; canvas was hittable and correctly sized.
- No script/parse errors, page errors, failed requests, or HTTP error responses in that boot.
- Fourteen procedural sounds synthesized.
- Result: **PASS** for boot only, not gameplay or performance.

### 3.2 Committed baseline encounter and shot — PASS within stated limits

Command equivalent:

```bash
node tools/web_qa.mjs \
  --url http://127.0.0.1:8000 \
  --page / --viewport 1280x720 \
  --encounter --encounter-timeout 240 --explore-wait 1000 \
  --play 20 --still --json
```

All 19 requested browser checks passed. Actual observations:

- Front-end journey reached the gameplay scene.
- Explore remained safe before explicit activation.
- `B` produced `Encounter: Preparing Defense (5 s)` and then `Encounter: Defense started`.
- Two Runner visual instances initialized for wave one.
- Actual canvas input produced a Pulse Rifle shot; the captured HUD changed from **24/24 to 23/24**.
- No Godot script errors were reported in that run.
- Browser run took about 244 seconds under headless software rendering.

**Not established by this check:** a hit, KO, wave clear, reward, upgrade, elite, stable frame rate, mobile-device behavior, or human enjoyment. The two captured play frames are not a combat-completion test.

### 3.3 Legacy direct-combat browser script — EXECUTED, invalid for current entry flow

`node tools/qa_combat_loop.mjs --url=http://127.0.0.1:8000/` was attempted. It timed out after 90 seconds waiting for `Encounter: Explore safe` because it does not traverse the current front-end journey. It produced no combat evidence.

This is recorded as a **QA harness mismatch**, not as evidence that combat failed and not counted as a pass. The supported `web_qa.mjs` journey was used for the observations above.

### 3.4 Godot 4.7.2 CI — EXECUTED, overall FAIL

Run `40082660757` executed the full suite on the exact pinned engine:

```text
Engine: 4.7.2.stable.official.ed1daf0bf
Import: ok
Result: 24 passed, 3 failed (of 27)
Static job: PASS
Engine job: FAIL
```

Visible CI annotations explicitly report these individual passes:

- `arc_weapon_smoke` — PASS;
- `arena_blockout_smoke` — **FAIL**;
- `audio_smoke` — PASS;
- `combat_feedback_smoke` — PASS;
- `data_source_smoke` — PASS;
- `effects_smoke` — PASS;
- `enemy_visual_smoke` — PASS;
- `exploration_flow_smoke` — PASS.

The aggregate establishes 24 passing tests, but the public annotation cap and unavailable log artifact do not expose the complete pass/fail list. No other individual result is inferred here.

The recurring engine error is:

```text
Parse Error: Cannot call non-static function "build_central_arena()"
on the class "NeonFrontierArena" directly. Make an instance instead.
at res://scripts/worlds/neon_frontier_world.gd:43
```

`arena.gd` also declares `add_arena_hazard_markings` and `add_arena_spawn_gates` as instance functions while the arena builder calls them unqualified. Every other zone builder inspected is declared `static`. The same code exists in base commit `2bd09b0`; this branch did not modify the world file.

### 3.5 CI Web export/browser — EXPORT PASS, browser FAIL

For the same code checkpoint:

- Web export completed.
- Static delivery returned HTTP 200 for HTML, JS, WASM, and PCK.
- A `web-preview` artifact was produced.
- Chromium checks failed on all four page/viewport combinations because the exported source reports the same `NeonFrontierArena` parse error.
- The payload/template commit step was skipped after the failed browser check. The local server therefore continues to serve the older committed payload, not a validated build of this branch.

## 4. Vertical-slice status

`tests/gameplay_vertical_slice_smoke.gd` was included in the 27-test CI invocation, so the suite attempted it. Its individual result is **UNKNOWN**, not PASS and not NOT RUN: the aggregate says three tests failed, but the accessible annotations/artifact do not identify all three names.

The test is designed to validate:

| Required representative path | Coverage in test | Claimed result |
|---|---|---|
| Existing hero | Real `Player` from `main.tscn`; Player physics held still for determinism | **UNKNOWN individual result** |
| Energy Rifle where applicable | Real default Pulse Rifle resource/controller/projectile; naming mapping remains open | **UNKNOWN individual result** |
| Existing enemy | One enemy spawned by WaveDirector through the Runner definition | **UNKNOWN individual result** |
| Combat interaction | Two real 18-damage Pulse projectiles; first must leave collider enabled, second must eliminate | **UNKNOWN individual result** |
| Wave/encounter transition | One-enemy wave clear, intermission, wave two | **UNKNOWN individual result** |
| Reward integrity | One KO/wave outcome despite repeated reward calls | **UNKNOWN individual result** |
| Upgrade/milestone interaction | Not applicable: feature absent | **NOT RUN — NOT IMPLEMENTED** |

Next safe validation step: after the World owner repairs the baseline parse error, rerun the suite and inspect `exports/test-logs/gameplay_vertical_slice_smoke.log`. If it fails independently, fix the gameplay/content issue before claiming the vertical slice.

## 5. Checks not run and why

| Check | Status / reason |
|---|---|
| Local Godot smoke run | **NOT RUN locally.** `scripts/install_godot.sh` could not follow the release redirect to `release-assets.githubusercontent.com`, which is outside the sandbox's allowed hosts. CI supplied the engine instead. |
| Individual vertical-slice log inspection | **NOT RUN.** Artifact/log download redirects are unavailable in this sandbox; only aggregate CI and capped annotations were accessible. |
| Android export and physical-device testing | **NOT RUN.** No Android SDK/device validation was performed; outside the approved content-only scope. |
| Real-GPU/mobile performance | **NOT RUN.** Headless SwiftShader timing is not representative. |
| Human audibility, visual comfort, touch ergonomics | **NOT RUN.** Browser synthesis and screenshots do not prove these. |
| Human hook engagement/retention test | **NOT RUN.** Requires approval and participants; no retention claim is made. |
| Long-run/post-cap endless balance | **NOT RUN.** Early browser contact and short headless tests cannot establish long-run stability/fun. |
| Elite milestone behavior | **NOT RUN — NOT IMPLEMENTED.** |
| One-of-three upgrade behavior | **NOT RUN — NOT IMPLEMENTED.** |
| Overcharge / Rapid Pulse / Chain Reactor | **NOT RUN — NOT IMPLEMENTED / NOT APPROVED in repository evidence.** |

Historical smoke results in older documents were not counted as verification of this branch.

## 6. Cross-domain integration handoff

### 6.1 World Development — required baseline repair

**Dependency:** current source cannot produce a clean full Godot suite or browser boot because the world composition root calls arena builders as static functions.

**Affected files:**

- `game/scripts/worlds/neon_frontier_world.gd` — existing caller; no change requested in this branch.
- `game/scripts/worlds/neon_frontier/zones/arena.gd` — World-owned repair target.

**Smallest compatible proposal:** declare these existing functions `static`, matching their call style and the other zone builders:

```text
build_central_arena(world)
add_arena_hazard_markings(world)
add_arena_spawn_gates(world)
```

No geometry, gameplay balance, world layout, or navigation change is proposed. The user selected **leave world untouched** on 2026-10-24, so this remains a request, not an applied fix.

**Validation after integration:** run all 27 smoke tests, inspect the vertical-slice log, export Web, and rerun browser boot on both pages/viewports. World-specific arena assertions must also pass.

### 6.2 Integration/Core + UI/UX — future milestone choice

The exact dependency, affected systems, smallest proposed transition, and tests are in `GAMEPLAY_CONTENT_CONTRACTS.md` §7–8 and `GAMEPLAY_LOOP_SPEC.md` §7. No shared signal or UI flow was changed unilaterally.

### 6.3 Design/production — unresolved decisions

- Confirm whether “Energy Rifle” means the existing Pulse Rifle.
- Approve milestone indexes and the actual first three upgrades before implementation.
- Choose post-cap escalation/elite policy through playtesting rather than raising every stat.
- Decide whether to approve locked-shot combat mastery as the single hook playtest hypothesis.

## 7. Files changed by this work

### Gameplay/content and tests

- `game/scripts/enemies/enemy_definition.gd` — new spawn/role data interface.
- `game/resources/enemies/runner.tres` — new Runner content definition.
- `game/resources/enemies/shooter.tres` — new Shooter content definition.
- `game/scripts/waves/wave_director.gd` — consumes configured definitions; existing wave signals preserved.
- `game/scenes/main.tscn` — supplies existing enemy definitions; no navigation change.
- `game/scripts/enemies/runner.gd` — collider disable moved to lethal branch only.
- `tests/gameplay_vertical_slice_smoke.gd` — new representative regression path.
- `tests/README.md`, `README.md` — current test count/invocation documentation.

### Architecture and required reports

- `docs/ARCHITECTURE.md` — regenerated module data and enemy-content guidance.
- `docs/GAMEPLAY_MECHANICS_AUDIT.md`
- `docs/GAMEPLAY_LOOP_SPEC.md`
- `docs/GAMEPLAY_CONTENT_CONTRACTS.md`
- `docs/HOOK_AND_RETENTION_SPEC.md`
- `docs/GAMEPLAY_VALIDATION_REPORT.md`

No world script, global save/persistence, main navigation, UI navigation, new currency, upgrade, elite, or hook system was changed.

## 8. Outstanding limitations and next safe step

1. **BLOCKER:** World parse error prevents a clean full-suite/new-Web validation.
2. **UNKNOWN:** individual result of the new vertical-slice test until logs are available or the suite is rerun cleanly.
3. **UNVERIFIED:** actual player experience, target-device input/performance, long-run balance, and retention.
4. **PROPOSALS ONLY:** milestone upgrades, elite milestones, post-cap scaling, and the primary hook.

The next safe step is the explicitly scoped World static-builder repair by its owner, followed by the same engine/browser gates. No additional gameplay system should be started to bypass that baseline failure.
