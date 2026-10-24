# Gameplay Mechanics Audit

> Historical pre-integration audit. For the later World/Character/UI reconciliation and current evidence, read [`INTEGRATION_BASELINE.md`](INTEGRATION_BASELINE.md) and the integration validation report. Statements here about one world or an unverified vertical slice describe checkpoint `ad6a221`, not the final integrated branch.

Date: 2026-10-24  
Branch: `arena/0b0dc2fd-cyber-strike`  
Code checkpoint audited: `ad6a221` (base: `2bd09b0`)  
Scope: Character & Content gameplay mechanics, the existing run loop, and their integration boundaries.

## 1. Method and evidence labels

The audit inspected executable GDScript, `.tscn` scenes, `.tres` resources, input actions, tests, and design documents. Repository-wide searches were also made for `elite`, `upgrade`, `milestone`, `Overcharge`, `Rapid Pulse`, `Chain Reactor`, `Energy Rifle`, and `Endless Survival`. Documentation alone was not treated as implementation evidence.

- **VERIFIED** — observed by a check actually executed during this pass, or verified absent by a complete source/resource search. The validation report identifies the evidence and its limits.
- **LIKELY** — a concrete executable path exists, but the claimed behavior has not been observed in every relevant runtime condition.
- **ASSUMPTION** — an interpretation or design inference, not a fact established by the project.
- **UNKNOWN** — the repository cannot answer the question, or a human/product decision is still required.

A script's existence is not a runtime pass. See [GAMEPLAY_VALIDATION_REPORT.md](GAMEPLAY_VALIDATION_REPORT.md) for exact results.

## 2. Executive finding

The project has a playable **single-player wave-survival prototype**, not a completed implementation of every part of the addendum. The existing hero, Pulse/Nova/Arc weapons, Runner/Shooter behaviors, bounded spawning, damage, rewards, Results, retry, and persistent BP weapon unlocks are real code paths. Safe Explore, explicit preparation, Defense, two wave-one Runners, and a real Pulse shot reducing ammunition were also observed in the committed WebAssembly build.

The following are **absent**, not merely unpolished:

- one-of-three milestone upgrade choices;
- upgrade definitions, eligibility, stacking, application, and run-scoped modifier storage;
- elite variants and elite milestone scheduling;
- a boss behavior implementation;
- endless difficulty growth beyond the existing count/composition caps;
- an approved primary hook or human retention evidence.

The current implementation does **not** establish that `Overcharge`, `Rapid Pulse`, or `Chain Reactor` is approved. Those names do not occur in the repository. No upgrade was implemented in this pass.

### Naming decision still open

**UNKNOWN:** the addendum calls the MVP weapon “Energy Rifle”; the executable default is `pulse_rifle`, displayed as **Pulse Rifle**, whose resource describes “fast, accurate energy bolts.” It is therefore the closest existing candidate for the vertical slice, but the repository does not explicitly declare that the two names are equivalent. This pass uses Pulse Rifle without renaming it or creating a fourth weapon. Integration/design must confirm the mapping.

## 3. System-by-system audit

“Owner” below means the current code owner, not permission for this branch to take over another domain.

| System | Status | Implementation and current owner | Dependencies and verified behavior | Missing, duplicated responsibility, or integration risk |
|---|---|---|---|---|
| Player combat controls | **LIKELY** | `player/player_controller.gd`; touch intent from `ui/hud/touch_controls.gd`; input actions in `project.godot` | Desktop fire/ADS, weapon slots/cycling, reload, EMP; HUD signals connect in `main.gd`. | Pointer-over-UI and touch soft-lock are platform-sensitive; real Android behavior remains **UNKNOWN**. |
| Movement and aiming | **LIKELY** | `PlayerController._update_movement`, `_get_aim_point`; `camera/camera_rig.gd` | Camera-relative WASD/joystick, sprint, jump, camera-center ray, touch look/soft lock. | No nav-aware player aim; soft lock deliberately rejects occluded targets. Feel and readability require human testing. |
| Weapon firing | **VERIFIED (limited browser path)** | `weapons/weapon_controller.gd::try_fire`; `WeaponDefinition` resources | A real browser input changed Pulse ammunition 24 → 23. Controller validates cadence, reload, ammo, muzzle cover, and `launch()`. | Full hit/KO path requires the engine vertical-slice result; browser ammunition evidence alone does not prove damage. |
| Fire rate, cooldown, reload, ammunition | **LIKELY** | `WeaponController` per-slot `_cooldowns`, `_magazines`, `_reload_remaining` | Pulse 5/s, 24 rounds, 1.35 s reload; Nova and Arc have their own resources. Auto-reload at zero; manual `G`; unlimited reserve by design comment. | No reserve ammunition or reload-cancel contract. Runtime upgrade modifiers do not exist. |
| Projectile and hitscan execution | **LIKELY** | `pulse_projectile.gd`, `nova_projectile.gd`, `arc_projectile.gd` | Pulse/Nova use swept per-frame ray queries; Arc resolves a hitscan ray then chained targets. | Projectile strategies each resolve their own damage. This is content-specific execution, not a reason to add a duplicate global damage manager. |
| Hit detection and damage resolution | **LIKELY** | Projectile queries plus duck-typed `apply_damage(amount, source)` on combatants | Pulse direct damage; Nova direct + splash deduplicated by instance id; Arc chain deduplicated and line-of-sight checked. | No shared typed damage packet, critical hits, armor, teams, knockback, or damage numbers. EMP and Nova splash do not perform the Arc chain's cover check. |
| Runner non-lethal hit integrity | **LIKELY; fixed pending engine result** | `enemies/runner.gd::apply_damage` | **Source-verified defect:** the base placed collider disable statements in the non-lethal `else`. They now execute only on death. `gameplay_vertical_slice_smoke.gd` covers two real Pulse hits. | Before the fix, one 18-damage Pulse hit could make the 36-HP Runner unreachable by the follow-up projectile. Do not claim the fix runtime-verified until the test passes. |
| Player health, damage, death | **LIKELY** | `PlayerController.apply_damage`, `defeated`; `main.gd::_on_player_defeated` | Health clamps at zero, touch input is cleared, death presentation starts, WaveDirector ends. | No mid-run respawn. Death reveal depends on rendered frames as well as time; device presentation remains **UNKNOWN**. |
| Enemy health and elimination | **LIKELY** | Runner/Shooter/TrainingDrone each own health and emit `damage_received`, `health_changed`, `eliminated` | Damage clamps to remaining health and ignores repeat damage after defeat. | Health logic is intentionally small but repeated across three scripts. Extracting a global health manager is not justified; a future local component needs a separate proven benefit. |
| Retry and reset | **LIKELY** | `main.gd::_reset_session`, `_return_to_explore`; `PlayerController.reset_player` | Clears wave enemies, resets health/ammo/skill/run stats/reward guards, restores safe training drone and camera. | Persistent wallet/unlocks intentionally survive. Reset is run recovery, not a second global player-lifecycle system. |
| Runner behavior | **LIKELY** | `enemies/runner.gd`; scene `scenes/enemies/runner.tscn` | Implicit pursue/melee/downed behavior; 36 HP, speed 3.8, 8 damage per 1.25 s, melee range 1.5. Role is now `close_pressure` metadata. | No NavigationAgent/pathfinding, attack windup, or explicit FSM. Straight-line pursuit can be blocked by world geometry. |
| Shooter behavior | **LIKELY** | `enemies/shooter.gd`; scene `scenes/enemies/shooter.tscn` | Standoff/retreat, cover-side search, 0.7 s locked-point windup, hitscan resolution, 2.2 s attack interval. Role is now `ranged_standoff` metadata. | No explicit recovery-state UI or NavigationAgent. The cooldown creates a punish window, but its quality as a hook is **UNKNOWN** until playtesting. |
| Training target | **LIKELY** | `enemies/training_drone.gd` | Safe Explore target with health and timed respawn; removed from the `enemies` group and collision during Defense. | Not a wave enemy, not a third combat role, and not evidence of enemy respawn during a run. |
| Enemy spawn requests | **VERIFIED (wave-one browser path)** | `waves/wave_director.gd`; content registry added at `enemies/enemy_definition.gd` and `resources/enemies/*.tres` | Two wave-one Runners appeared in the browser. WaveDirector now resolves content ids through configured `EnemyDefinition` resources instead of preloading concrete scenes. | Existing spawn signals and composition schedule remain coupled to the two ids. Adding a third role still requires an approved composition rule, not merely a model/resource. |
| Spawn validity and active cap | **LIKELY** | `WaveDirector` marker choice, shape clearance, distance, bounds, camera preference | Active cap 3, minimum distance 7.5, retry limits; world supplies markers/collision. | Repeated failure enters `BLOCKED`; Main returns to Explore. Marker layout vs. moving player/camera needs continued runtime coverage. |
| Wave progression | **LIKELY** | One `WaveDirector`; `WaveState {IDLE, SPAWNING, INTERMISSION, GAME_OVER, BLOCKED}` | Wave completion requires all scheduled enemies defeated; 3 s default intermission; next wave starts without a final wave. | This supports an endless session structurally, but does not by itself prove endless escalating challenge or long-run stability. |
| Difficulty escalation | **LIKELY; partial** | Count = `2 + (wave - 1)`, cap 8; Shooters from wave 2, +1 every two waves, cap 3 | Composition changes while count and Shooter count grow. | Count caps at wave 7 and Shooter count at wave 6; no health/damage/speed/elite scaling. Later waves repeat the same bounded composition. This is **not full endless escalation**. |
| Elite milestones | **VERIFIED ABSENT** | No elite resource, behavior, variant flag, signal, or schedule | Concept documentation mentions Elite as post-MVP. | No elite was invented. Milestone cadence, gameplay change, silhouette/VFX, reward, and UI contract are **UNKNOWN**. |
| Reward calculation/distribution | **LIKELY** | `progression/reward_service.gd`, `run_stats.gd`; Main wires events | Runner and Shooter: 100 score + 10 run BP; wave clear: +100 run BP. Per-enemy instance and per-wave dictionaries guard duplicates. | No distinct milestone reward. Reward values are exported on the service, not on enemy definitions; moving them requires an ownership decision. |
| Run completion and banking | **LIKELY** | `main.gd::_on_wave_session_ended`; `progression_service.gd::bank_run` | Voluntary Finish Run and Defense defeat bank provisional run BP once, then show Results (after defeat reveal). | Cross-run save/profile remains Integration/Core-owned. No new economy or persistence was added. |
| Upgrade selection/application | **VERIFIED ABSENT** | No upgrade script/resource, choice signal, choice UI, eligibility, stack rule, or modifier container | Persistent weapon purchase/equip exists, but it is not an in-run one-of-three upgrade. | Exact milestones, three approved options, stacking/incompatibility, pause behavior, and reset semantics are **UNKNOWN**. |
| Persistent progression | **LIKELY** | `ProgressionService` (`user://progression.cfg`), Armory UI | BP wallet, best score, completed runs, Pulse/Nova/Arc ownership and selection, hero/world selection ids. Only Pulse starts unlocked. | This supersedes older docs claiming persistence is absent. Save corruption/platform behavior and real-device persistence remain **UNKNOWN**. |
| Combat feedback | **VERIFIED (HUD/ammo only); rest LIKELY** | `hud_combat_feedback_ui.gd`, `hud_encounter_ui.gd`, Main signal wiring, content VFX/audio | Browser showed health, wave state, active enemies, Pulse label and ammo. Code also has hit marker, damage flash, reward toast, impact VFX, muzzle flash, and synthesized audio. | No elite/upgrade feedback because those mechanics are absent. Subjective audibility, visual clarity, and mobile comfort are not established by headless tests. |
| Existing events/state owners | **LIKELY** | Main `SessionMode`; WaveDirector `WaveState`; Player/Weapon/Enemy/Reward/Progression signals | Main is composition/integration root; UI receives intents and displays outcomes. | Any milestone-choice state or new shared signal is an integration change, not a content-only decision. |

## 4. Existing contracts and duplicated responsibilities

### Healthy separation to preserve

- `WeaponDefinition` describes cadence, damage, range, projectile scene, splash, and chain parameters; `WeaponController` owns fire validation, per-slot timing, ammunition, switching, and projectile launch.
- Each projectile strategy owns its content-specific hit execution. Combatants expose `apply_damage`; there is no global damage singleton.
- `WaveDirector` is the only wave manager. `RunStats`, `RewardService`, and `ProgressionService` have distinct run/persistent responsibilities.
- `Main` owns session composition and transitions. HUD code presents state and emits user intent.
- Enemy definitions now describe spawn identity and role; enemy scenes still implement behavior.

### Duplication or concentration that remains

1. **Small health/damage implementations are repeated** in Player, Runner, Shooter, and TrainingDrone. They are not duplicate global managers. Do not extract a framework solely to remove a few similar lines.
2. **Enemy stats remain on behavior exports**, not in `EnemyDefinition`. This is intentional for this pass: copying them into resources without migrating all scene/test overrides would create two sources of truth.
3. **Reward values remain on `RewardService`**, while role metadata lives on `EnemyDefinition`. Moving rewards into content metadata requires integration approval because reward distribution is a system concern.
4. **Main remains the integration hub** for session, HUD, rewards, banking, and pause. A milestone upgrade state would increase that responsibility and therefore requires coordination.
5. **Runner/Shooter logic is implicit state**, not a formal FSM. A new FSM is not required for the current two roles.

## 5. Design baseline versus executable baseline

| Topic | Established direction | Actual finding |
|---|---|---|
| Mode | Endless Survival | **Partial:** waves have no authored final index, but scaling caps and run ending on defeat/voluntary finish. |
| Core loop | Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy | **Partial:** preparation, deployment, combat, survival, reward, persistent weapon unlock/equip, and retry exist; milestone Adapt/Upgrade choice does not. |
| MVP weapon | Energy Rifle | **UNKNOWN mapping:** Pulse Rifle is the default energy-bolt implementation; no `energy_rifle` id exists. Nova and Arc also exist and were not removed. |
| Milestone choice | One of three upgrades | **Absent:** no definitions, choices, or application path. |
| Candidate upgrades | Overcharge, Rapid Pulse, Chain Reactor | **Documented only in the new addendum:** no repository implementation or prior approval evidence. |
| Elite milestones | Meaningful challenge changes | **Absent:** concept-only Elite references explicitly follow Runner/Shooter MVP work. |
| Enemy roster | Purpose beyond models | **Verified source roles:** Runner close pressure; Shooter ranged standoff/locked-shot avoidance. No new enemy added. |
| Persistent economy | Do not invent one | Existing BP wallet/unlocks/save audited and left unchanged. No currency, monetization, or save architecture added. |

`PROJECT_DECISIONS.md` and some older design records are stale relative to code: the current WaveDirector default starts at **two** enemies, not three, and persistent BP/unlock/save now exists. This audit uses executable source as the current truth and does not rewrite those historical documents silently.

## 6. Integration risks and open decisions

1. **Energy Rifle naming:** confirm whether Pulse Rifle is the intended implementation before changing ids, UI copy, or save compatibility.
2. **Escalation after caps:** choose one approved scaling axis and playtest it; do not simultaneously raise health, damage, speed, count, and elite density.
3. **Milestone contract:** designate waves, blocking/non-blocking behavior, reward ordering, exactly-once semantics, and what happens on defeat/retry before adding a state.
4. **Upgrade content:** approve the actual three choices and their gameplay effects. Do not treat all candidate names as implementation approval.
5. **Modifier ownership:** shared weapon `.tres` resources must not be mutated globally for a run upgrade. Integration must approve a run-scoped modifier interface and reset boundary.
6. **UI integration:** one-of-three presentation and input belong to UI/UX; gameplay must supply readable definitions and an outcome event rather than building a parallel navigation flow.
7. **Elite feedback:** silhouette/VFX alone is insufficient; elite behavior, scheduling, reward, and HUD announcement need separate acceptance criteria.
8. **Runtime navigation:** current direct movement can stall around cover. Measure real encounters before adding pathfinding or more roles.
9. **Enemy elimination presentation:** WaveDirector queues wave enemies for deletion on `eliminated`; long death animations would require a lifecycle contract change. This pass did not alter it.
10. **Hook approval:** the recommendation in `HOOK_AND_RETENTION_SPEC.md` is provisional and has no human retention evidence.

## 7. Audit disposition

Implemented in this pass:

- enemy spawn/role content definitions and a configured WaveDirector consumption path;
- the Runner non-lethal collider correction;
- a representative Pulse Rifle → Runner → KO/wave reward → next-wave regression test.

Deliberately left as proposals or open decisions:

- milestone upgrades and all named upgrade candidates;
- elite variants and post-cap scaling;
- new enemy types, weapons, persistent systems, and global managers;
- the primary hook and any retention claim.
