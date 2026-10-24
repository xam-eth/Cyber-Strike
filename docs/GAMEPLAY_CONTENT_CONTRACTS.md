# Gameplay Content Contracts

Date: 2026-10-24  
Purpose: record the real interfaces between content, combat execution, encounters, feedback, UI, and Integration/Core.

## 1. Contract status and ownership

- **CURRENT** means executable code uses the interface now.
- **INTERNAL REFACTOR** means implementation changed without changing the existing public signal/method behavior.
- **PROPOSED** means no implementation exists and integration approval is required.

| Boundary | Current owner(s) | Status |
|---|---|---|
| Weapon data → player weapon execution | Character & Content data; `WeaponController` system | **CURRENT** |
| Projectile/hitscan → combatant damage | Weapon content + combatant duck-typed methods/signals | **CURRENT, informal/shared** |
| Enemy content → WaveDirector spawn | Character & Content `EnemyDefinition`; wave system consumes it | **CURRENT after compatible internal refactor** |
| Wave events → reward/run state | WaveDirector + RewardService + Main | **CURRENT; unchanged** |
| Gameplay events → HUD feedback | Main signal composition + UI presentation | **CURRENT; unchanged** |
| Upgrade data → run-scoped combat effects | No owner/end-to-end path exists | **PROPOSED ONLY** |
| Elite definition → milestone spawn/feedback | No implementation exists | **PROPOSED ONLY** |

No existing shared signal was renamed or had its payload changed. No autoload, global damage manager, second wave manager, save service, or UI navigation flow was added.

## 2. Weapon content → combat execution — CURRENT

### 2.1 Definition

`game/scripts/weapons/weapon_definition.gd` (`class_name WeaponDefinition`) is the public content data interface. Current resources live in `game/resources/weapons/`.

| Field group | Fields | Consumer |
|---|---|---|
| Identity | `weapon_id`, `display_name`, `role_description` | Controller, front end, Armory, HUD |
| Execution scene | `projectile_scene` | `WeaponController.try_fire` |
| Cadence/ammo | `fire_rate`, `magazine_size`, `reload_seconds` | `WeaponController` only |
| Direct attack | `damage`, `projectile_speed`, `max_range`, `collision_mask` | Projectile's `launch` implementation |
| Area effect | `splash_damage`, `splash_radius` | Nova projectile |
| Chain effect | `chain_count`, `chain_radius`, `chain_damage_multiplier` | Arc projectile |

`is_valid_definition()` rejects incomplete or contradictory definitions. The registry (`DEFINITION_PATHS`, `DEFINITION_IDS`) is also read by content selection/progression code; player scene and cards are checked by `data_source_smoke.gd`.

### 2.2 Execution entry point

```gdscript
WeaponController.try_fire(
    shooter: CollisionObject3D,
    muzzle: Marker3D,
    aim_point: Vector3
) -> bool
```

A successful call:

1. validates current definition, cadence, reload state, ammo, shooter, muzzle, and muzzle-to-world cover;
2. instantiates the configured projectile scene;
3. requires a `Node3D` with `launch`;
4. calls the content contract below;
5. sets cooldown, consumes one round, handles auto-reload/ammo feedback, plays weapon audio, and emits `shot_fired`.

```gdscript
projectile.launch(
    start_position: Vector3,
    aim_point: Vector3,
    shooter: CollisionObject3D,
    definition: WeaponDefinition
) -> void
```

The definition supplies rules; the controller does not contain Pulse/Nova/Arc damage formulas. Conversely, projectiles do not own ammunition, weapon unlocks, or persistent profile state.

### 2.3 Current execution strategies

| Weapon | Id | Behavior |
|---|---|---|
| Pulse Rifle | `pulse_rifle` | Moving energy projectile; one direct damage application on first hit |
| Nova Launcher | `nova_launcher` | Moving explosive projectile; direct hit plus radius damage, deduplicated by target instance |
| Arc Shooter | `arc_shooter` | Immediate ray; chained nearby targets with per-chain falloff and line-of-sight checks |

The addendum's “Energy Rifle” has no separate id. Pulse Rifle was used for the vertical slice without asserting an approved rename.

### 2.4 Weapon events

| Signal | Owner | Payload/use |
|---|---|---|
| `weapon_changed(display_name)` | WeaponController; Player relays its own equivalent | HUD/armory/equip feedback |
| `shot_fired(weapon_id)` | WeaponController | Available to weapon-aware consumers |
| `shot_fired()` | PlayerController | Main shot count/shot feedback |
| `ammo_changed(remaining, capacity, reloading)` | WeaponController | HUD ammo and Player reload animation |

These are existing interfaces; no upgrade event was added to them.

## 3. Hit and damage contract — CURRENT, informal/shared

Combatants currently expose:

```gdscript
apply_damage(amount: float, source: Node = null) -> void
can_take_damage() -> bool                 # Player; used by enemy targeting
is_defeated() -> bool                     # enemies and player
```

Relevant signals:

```gdscript
damage_received(amount: float, current: float, maximum: float)
health_changed(current: float, maximum: float)
eliminated()                              # enemies
defeated()                                # Player
```

Rules established by current implementations:

- non-positive damage is ignored;
- health clamps to zero;
- post-defeat damage is ignored;
- Nova/Arc use per-attack instance-id sets to prevent duplicate damage;
- collision masks and source exclusions are strategy-specific;
- damage feedback is driven by actual `damage_received`, not by merely firing.

This is duck typing, not a typed shared `Damageable` class. Changing signatures, adding a damage packet, or centralizing health would affect multiple domains and requires Integration/Core coordination. This branch did not do so.

## 4. Enemy content → encounter spawning — CURRENT

### 4.1 Public EnemyDefinition

`game/scripts/enemies/enemy_definition.gd` now exposes:

| Field | Meaning |
|---|---|
| `enemy_id` | Stable content id used by encounter composition (`runner`, `shooter`) |
| `display_name` | Source for spawned node naming and readable content identity |
| `gameplay_role` | Stable role metadata (`close_pressure`, `ranged_standoff`) |
| `role_description` | Explanation of actual gameplay purpose |
| `enemy_scene` | PackedScene implementing the behavior |

`is_valid_definition()` requires complete identity/role metadata and an instantiable scene. `DEFINITION_IDS` and `load_all_definitions()` provide the default registry. The training drone is deliberately not encounter content.

Role metadata describes existing behavior; it does not magically add behavior and is not presented as an elite/variant system.

### 4.2 Composition root configuration

`game/scenes/main.tscn` supplies the two resources through:

```gdscript
WaveDirector.enemy_definitions: Array[EnemyDefinition]
```

If the array is empty, WaveDirector loads the default registry for isolated fixtures. Explicit scene references keep export dependency scanning visible. `WaveDirector._get_enemy_definition(enemy_id)` resolves content; `_attempt_spawn_enemy()` no longer preloads `runner.tscn` or `shooter.tscn` directly.

This is an **INTERNAL REFACTOR**: wave indexes, composition, spawn timing, signals, names (`Runner_Wave...` / `Shooter_Wave...`), and rewards are intended to remain unchanged.

### 4.3 Spawned-scene expectations

The current wave/reward/player integration expects more than `Node3D`:

| Expectation | Consumer | Current enforcement |
|---|---|---|
| `target_path` property | Runner/Shooter targeting | WaveDirector sets it |
| `eliminated` signal | WaveDirector accounting | Explicitly checked; missing signal blocks session |
| `apply_damage(amount, source)` | Weapons/EMP | Duck-typed at call sites |
| `is_defeated()` | Reward validation, aiming/EMP filters | Duck-typed |
| `damage_received` signal | Main hit feedback | Connected when present |
| `enemies` group | EMP and reward eligibility | Added by enemy `_ready` |
| `runner_enemies` / `shooter_enemies` groups | Reward selection and aiming | Added by enemy `_ready` |

Only the `eliminated` check is explicit in WaveDirector. The remaining expectations are current implicit shared contracts; a new enemy must satisfy them or integration must deliberately replace them. Adding a visual model alone is insufficient.

### 4.4 Behavior parameters

Runner/Shooter combat statistics remain exported on their behavior scripts and scenes. They were **not** copied into `EnemyDefinition` in this pass. A future stat/variant migration must include scene defaults and tests that override behavior values; otherwise two configuration sources can disagree.

## 5. Wave events → rewards and run outcomes — CURRENT, unchanged

| Signal | Producer | Current consumer(s) |
|---|---|---|
| `wave_started(wave_index, enemy_count)` | WaveDirector | Main: Defense phase, training-drone disable, RunStats start, HUD/audio |
| `enemy_spawned(enemy)` | WaveDirector | Main: connect damage feedback |
| `enemy_defeated(enemy)` | WaveDirector | RewardService: validate and award once |
| `wave_completed(wave_index)` | WaveDirector | Main HUD update + RewardService wave award |
| `progress_changed()` | WaveDirector | Main HUD update |
| `session_ended(wave_index, total_defeated)` | WaveDirector | Main: bank/Results/death reveal |
| `spawn_blocked(reason)` | WaveDirector | Main: safe Explore recovery |

`RewardService` emits `enemy_rewarded` and `wave_rewarded` only after updating RunStats and passing duplicate guards. Main uses those applied-reward events for player feedback, so a repeated event does not produce a second toast.

## 6. Gameplay feedback contract — CURRENT

| Event | Gameplay source | Player-facing response | Owner boundary |
|---|---|---|---|
| Shot accepted | Player `shot_fired` / WeaponController ammo event | Shot feedback, recoil/muzzle effect, ammo update | Content effect + Main + HUD |
| Valid target damaged | Enemy `damage_received` | Hit marker, hit-confirm sound, enemy hit flash | Enemy content + Main + HUD/Audio |
| Player damaged | Player `damage_received` | Health update and damage flash | Player system + Main + HUD |
| Shooter winds up | Shooter internal `_begin_attack_windup` | Aim marker at locked point and growing emissive core | Enemy content; no UI contract required |
| Enemy reward applied | RewardService `enemy_rewarded` | `TARGET DOWN · +N BP` | Progression + Main + HUD |
| Wave reward applied | RewardService `wave_rewarded` | Wave-clear message and intermission status | Progression + Main + HUD |
| Player defeated | Player `defeated` | Defeat audio, death reveal, then Results | Integration + content animation + UI |
| Run ended | Main/ProgressionService | Results score, BP banked, wallet/best score | Integration + UI |

There are no events for elite appearance, milestone choice, upgrade application, or upgrade-altered weapon feedback because those mechanics do not exist. Adding them as shared signals requires integration review.

## 7. Upgrade contract — PROPOSED ONLY

No `UpgradeDefinition`, modifier container, choice generator, or choice UI is present. The following is the minimum boundary to review, not an implemented API:

1. **Character & Content:** data describing stable id, player-readable name/description, supported effect, parameters, eligibility, and stacking limits.
2. **Integration/Core:** milestone scheduling and exactly-once choice lifecycle; run reset boundary. No new autoload is assumed.
3. **Combat system:** a run-scoped modifier/read path used by `WeaponController` and supported projectile effects. Shared `.tres` resources must remain immutable during a run.
4. **UI/UX:** presentation and input for exactly three eligible choices, plus applied-effect feedback. UI must not directly rewrite weapon/projectile internals.
5. **Character & Content feedback:** effect-specific audiovisual assets driven by a confirmed applied event, not by hovering a card.

Unresolved contract questions:

- designated milestone waves and ordering versus wave reward/intermission;
- the actual approved first three upgrades;
- stack/replacement/incompatibility rules;
- whether choices affect one weapon, the current weapon, or the loadout;
- duplicate generation rules when the pool is exhausted;
- pause/defeat/retry behavior;
- persistence prohibition for run-only effects.

Until these are resolved, mutating `WeaponDefinition` or adding an independent upgrade manager would be an unsafe workaround.

## 8. Integration requests and smallest compatible next steps

| Request | Why current interface is insufficient | Affected systems/files | Smallest compatible proposal | Required test |
|---|---|---|---|---|
| Confirm Energy Rifle ↔ Pulse Rifle naming | Addendum and executable ids differ | Design record, `pulse_rifle.tres`, selection UI; save ids only if explicitly approved | Record the mapping; prefer display-copy change over renaming the stable id | Data-source, save/load, equip, and firing tests |
| Define milestone choice lifecycle | WaveDirector only supports automatic intermission; Main has no choice state | `main.gd`, `wave_director.gd`, HUD, combat controller, new content definitions | Add one coordinated blocking choice path after existing wave reward; keep all existing signals compatible | Exactly-once choice, resume, defeat, retry, non-milestone regression |
| Define run-scoped weapon modifiers | Current resources are shared static base stats | `weapon_controller.gd`, relevant projectile strategies, Integration run state | Add an additive per-run modifier read/reset path; do not mutate base resources | Cadence/damage effect, reset, weapon swap, duplicate application |
| Choose post-cap escalation and elite policy | Count/composition stop growing; EnemyDefinition has no stat variant contract | WaveDirector, enemy behaviors/resources, feedback/UI | Select one approved scaling axis or one elite milestone at a time | Long-wave schedule, variant behavior, reward and readability |
| Playtest locked-shot mastery | Code has windup/cooldown but no engagement evidence | Shooter, Player, HUD only if observation shows a readability gap | First test existing `attack_resolved(hit_target)` and current visuals; avoid a new system | Human dodge/punish comprehension and another-run willingness |

These requests are coordination items, not silently approved shared-contract changes.
