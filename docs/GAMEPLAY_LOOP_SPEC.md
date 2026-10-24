# Gameplay Loop Specification

Date: 2026-10-24  
Status: implemented-loop record plus explicitly separated proposals  
Authoritative implementation: `game/scripts/main.gd`, `game/scripts/waves/wave_director.gd`, and the services identified below.

## 1. Established direction

The design baseline is **Endless Survival** with this intended loop:

**Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy**

This document does not replace that direction. It records which links currently exist and prevents the persistent Armory unlock flow from being mislabeled as the absent in-run upgrade-choice flow.

## 2. Current loop mapping

| Loop step | Current executable behavior | Status |
|---|---|---|
| Prepare | Front end selects available hero/world/weapon ids; gameplay starts in safe Explore. Armory can unlock/equip weapons with previously banked BP. Only one hero and one world have playable definitions. | **LIKELY; front-end journey observed, alternate content unverified** |
| Deploy | START DEFENSE or `B` changes Explore → Preparing; a visible five-second default countdown elapses before WaveDirector starts. | **VERIFIED in baseline browser** |
| Fight | Move, aim, fire, reload, swap unlocked weapons, and use EMP against Runner/Shooter waves. | **LIKELY; Pulse ammunition change browser-verified** |
| Adapt | Current adaptation is positional aiming, cover/movement, target prioritization, weapon selection, and EMP timing. There is no milestone modifier choice. | **CURRENT BEHAVIOR; MILESTONE CHOICE ABSENT** |
| Survive | Waves continue after intermission until defeat or voluntary Finish Run. Count/composition grow only to their caps. | **LIKELY; PARTIAL ENDLESS** |
| Reward | Enemy defeats and wave completions add provisional score/BP immediately; eligible run BP banks at Results. | **LIKELY; vertical-slice result pending** |
| Upgrade | Persistent BP can buy/equip Nova or Arc through the Armory. No one-of-three milestone upgrade exists. | **PERSISTENT PATH LIKELY; IN-RUN UPGRADE VERIFIED ABSENT** |
| Redeploy | Results supports retry Defense or return to Explore; retry resets run state while preserving persistent profile. | **LIKELY** |

There is no authored victory/final-wave state. A Defense run ends through player defeat or the pause menu's deliberate Finish Run path. Spawn failure is a recovery path to Explore, not a victory.

## 3. Current state ownership

### 3.1 Session state — Integration/Core owner

`main.gd` owns:

```text
SessionMode { EXPLORE, PREPARING, DEFENSE, RESULTS }
```

`Main` also composes Player, WaveDirector, RunStats, RewardService, ProgressionService, TrainingDrone, and HUD. This branch did not add another session manager.

### 3.2 Wave state — wave system owner

`wave_director.gd` owns:

```text
WaveState { IDLE, SPAWNING, INTERMISSION, GAME_OVER, BLOCKED }
```

`SPAWNING` means the wave is active, including after all scheduled enemies have spawned but while some remain alive. It does not mean a spawn must occur every frame.

### 3.3 Run-stat state — run progression owner

`RunStats.is_run_active` starts on the first `wave_started` and stops at Results. The guard in `start_run()` prevents later waves from resetting score or time. Survival time therefore includes wave intermissions, but excludes preparation and Results.

## 4. Current code transitions, triggers, inputs, and outputs

| From | Trigger/guard | To | Outputs and side effects | Owner/dependencies |
|---|---|---|---|---|
| Front end | Launch selected content | `EXPLORE` | Main instantiates playable scene, applies saved unlocked weapon, no automatic wave | Front end/UI + Main + ProgressionService |
| `EXPLORE` | START DEFENSE / `B`; not defeated, paused, or already in a run | `PREPARING` | Preparation countdown and HUD phase; training target remains safe until wave start | Main + HUD |
| `PREPARING` | Countdown reaches zero | `DEFENSE` | `wave_director.start_session()` | Main → WaveDirector |
| `IDLE` | Valid player, enemy container, spawn root, and clearance shape | `SPAWNING`, wave 1 | `wave_started(1, count)`; current default count is 2 | WaveDirector + Main scene |
| First `wave_started` | Run not already active | `DEFENSE` remains | Training drone disabled; run clock starts; wave-start audio/HUD | Main + RunStats + HUD/Audio |
| `SPAWNING` | Timer permits, active count below cap, valid marker found | `SPAWNING` remains | EnemyDefinition resolves scene; `enemy_spawned`; damage feedback connected | WaveDirector + Character & Content + Main |
| `SPAWNING` | Scheduled count defeated | `INTERMISSION` | `wave_completed`; duplicate-guarded +100 run BP; reward toast; countdown | WaveDirector + RewardService + HUD |
| `INTERMISSION` | Timer reaches zero and player is alive | `SPAWNING`, next wave | Count/composition recalculated; no stat reset | WaveDirector |
| `DEFENSE` | Pause → FINISH RUN | `GAME_OVER`, then `RESULTS` | Active enemies cleared; run clock stops; run BP banks once; Results | Main + WaveDirector + ProgressionService + UI |
| `DEFENSE` | Player health reaches zero | `GAME_OVER`, then delayed `RESULTS` | Input stopped, enemies cleared, BP banks, defeat reveal renders before Results | Player + Main + WaveDirector + UI |
| Any active wave state | No valid spawn after configured retries | `BLOCKED`, then `EXPLORE` | Warning, active run recovered safely; no automatic retry | WaveDirector + Main |
| `RESULTS` after Defense | RETRY DEFENSE | `EXPLORE` reset, then `PREPARING` | Enemies/run stats/reward guards/health/ammo/skill reset; persistent profile retained | Main + UI |
| `RESULTS` | EXPLORE | `EXPLORE` | Same run cleanup without automatic redeployment | Main + UI |
| `RESULTS` after an Explore defeat | RETRY EXPLORE | `EXPLORE` | Recovery does not start an unsolicited Defense | Main + UI |

### Pause and Armory are orthogonal to SessionMode

Pause uses `SceneTree.paused`; it is not a fifth session state. Opening the Armory pauses gameplay and shows a UI panel. Buying/equipping there uses persistent, previously banked BP. It is not a milestone reward or a run-scoped upgrade.

## 5. Combat-to-outcome path

The representative path covered by `tests/gameplay_vertical_slice_smoke.gd` is:

```text
configured PulseRifle WeaponDefinition
  → Player's WeaponController.try_fire
  → PulseProjectile.launch
  → swept collision query
  → Runner.apply_damage(18, player)
  → damage_received / health_changed
  → second valid shot after cadence
  → Runner.apply_damage(18, player)
  → eliminated (once)
  → WaveDirector enemy_defeated + wave_completed
  → RewardService / RunStats (100 score, 10 KO BP, 100 clear BP)
  → INTERMISSION
  → wave 2
```

The test uses the real Main scene, hero, Pulse resource/projectile, a wave-spawned Runner, and real physics queries. After spawn, it places the Runner in a deterministic clear lane so the test measures combat rather than random aim. It also repeats reward calls to verify duplicate guards. It does not claim human aiming quality or test an upgrade, because no upgrade exists.

## 6. Reward and failure invariants

### Current invariants

1. An active, non-defeated enemy awards nothing.
2. A given enemy instance can award only once per run.
3. A given wave index can award completion BP only once per run.
4. RunStats rejects stat changes while the run is inactive.
5. WaveDirector emits `session_ended` once; repeated `end_session()` after `GAME_OVER` returns early.
6. Main banks only when leaving actual Defense, not on an Explore-only defeat.
7. Retry clears run-only stats and reward guards but not wallet/best score/unlocks.
8. There is no separate “claim” button: banking is automatic on the Defense → Results transition.

### Current feedback outcomes

- Hit: target `damage_received` → hit marker and hit-confirm audio.
- Player damage: Player `damage_received` → HUD damage flash and health update.
- Enemy KO: `enemy_rewarded` → `TARGET DOWN · +N BP` toast/log.
- Wave clear: `wave_rewarded` → `WAVE NN CLEAR · +N BP` toast and intermission status.
- Run end: Results shows wave, eliminations, score, time, run BP banked, wallet, and best score.

## 7. Proposed milestone/upgrade insertion — NOT IMPLEMENTED

The established one-of-three choice requires an integration decision before it can become a real transition. The smallest compatible logical insertion is:

```text
wave_completed
  → existing wave reward applied exactly once
  → if the completed wave is an approved milestone:
       pause wave advancement and present exactly three eligible choices
       → accept one choice exactly once
       → apply its run-scoped effect through the approved combat interface
       → confirm the applied effect to the player
       → begin the normal intermission/next-wave path
     else:
       begin the normal intermission/next-wave path
```

This is a **proposal**, not a new `SessionMode` or `WaveState` implemented in this branch.

Required inputs before implementation:

- approved milestone wave indexes;
- exactly which three upgrade definitions are eligible for the first slice;
- stacking, replacement, and incompatibility rules;
- whether combat simulation pauses and how touch input is isolated;
- timeout/default behavior, if any (no auto-choice is assumed);
- run reset/retry semantics and persistence boundary;
- ownership of choice state and shared signals.

Required outputs:

- one applied run-scoped modifier, never a mutation shared across all users of a weapon Resource;
- readable choice and applied-effect feedback;
- exactly one continuation after selection;
- no duplicate wave reward, upgrade application, or resume transition.

Validation criteria for a future implementation:

1. Non-milestone waves behave exactly as they do now.
2. A milestone presents three distinct eligible options, never more than one application per milestone.
3. Repeated input cannot apply two options or resume twice.
4. Weapon cadence/damage/effect changes use the existing execution path and are measurable in combat.
5. Retry/redeploy clears every run-scoped modifier and does not write the persistent profile.
6. Defeat while the choice is open cannot soft-lock Results or grant an extra reward.
7. Keyboard, touch, pause, and UI focus are tested on the actual target layouts.

## 8. Current validation criteria

The existing loop is acceptable for this prototype only to the extent that checks demonstrate:

- no enemies before explicit deployment;
- preparation precedes Defense;
- wave composition and caps remain stable after the EnemyDefinition refactor;
- a Pulse shot can hit twice without the target becoming prematurely non-collidable;
- KO and wave rewards occur once;
- intermission advances;
- defeat/Finish Run reaches Results and retry restores a clean run;
- no script errors or new architecture violations occur.

Actual executed results and unverified items are recorded in [GAMEPLAY_VALIDATION_REPORT.md](GAMEPLAY_VALIDATION_REPORT.md), not inferred from these criteria.
