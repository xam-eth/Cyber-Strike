# Gameplay Design — STELLAR HORIZON

- **Document role:** canonical product/gameplay direction and gameplay-logic scope.
- **Direction status:** **TECH HUNT selected for prototyping on 2026-10-26.**
- **Implementation status:** the executable baseline remains safe Explore + explicit Defense + persistent BP weapon unlocks. TECH HUNT mission/cache behavior is **ABSENT** until implemented and verified.
- **Evidence status:** combat mechanics have automated coverage; human hook, engagement, retention, and physical-device experience remain **UNKNOWN**.

Read this document before changing gameplay or player-facing logic. Process and sequencing live in [`DEVELOPMENT.md`](DEVELOPMENT.md); module boundaries live in [`ARCHITECTURE.md`](ARCHITECTURE.md); executed evidence lives in [`VALIDATION.md`](VALIDATION.md).

## 1. Product promise

**Exocomplict: STELLAR HORIZON** is a mobile-first, single-player third-person sci-fi action/adventure-survival game.

> **Choose a technology worth hunting, enter a guarded world, decide how much danger to accept, secure the blueprint permanently, then return with a new way to play.**

The player should repeatedly think:

1. **I know what I am trying to accomplish.**
2. **My movement, targeting, timing, and route decisions matter.**
3. **What I earned changes what I can try next.**

The game is not built around long cinematic exposition, inventory administration, or an ever-larger list of currencies. Adventure presentation, including the Guardians of the Galaxy inspiration, supports the playable expedition; it does not justify a squad system or bullet-sponge combat.

### 1.1 Content pillars and their actual job

The user's three content pillars remain, but they are containers rather than the hook by themselves.

| Content pillar | Player-facing job | Design constraint |
|---|---|---|
| Hero/weapon upgrade tiers | Bounded long-term mastery and specialization goals | Do not make exponential stats the main source of progress |
| Hero/weapon types | Different positioning, targeting, timing, and loadout decisions | A type must be more than a model or damage-number swap |
| World types | Different mission ecology, routing, threats, and technology opportunities | A world is not only a palette/skybox; metadata alone is not gameplay |

The corresponding experience pillars are **purpose**, **mastery/adaptation**, and **technology that creates new possibilities**.

### 1.2 Current non-goals

Unless explicitly re-scoped, the active prototype excludes:

- multiplayer, open world, a long campaign, clans, and online leaderboards;
- complex crafting trees, hunger/thirst, durability, grid inventory, and consumable stacking chores;
- premium currency, IAP, rewarded ads, Battle Pass, loot boxes, and pay-only gameplay power;
- random rarity loot as the main reason to replay;
- new managers or abstraction layers added only to imitate another game's architecture.

## 2. Hook model

TECH HUNT is the macro hook. It works with, rather than replaces, the existing combat-mastery candidate.

| Timescale | Hook | Intended player thought | Status |
|---|---|---|---|
| Seconds | **Dodge the lock. Punish the recovery.** | “I can read that attack and improve my timing.” | Existing mechanics; human hook value **UNKNOWN** |
| One expedition | **Find and secure guarded technology** | “I came for that blueprint; the risk was worth it.” | **SELECTED for prototype; ABSENT in code** |
| Across expeditions | **Turn technology into new tactics and loadouts** | “What can this unlock let me do differently?” | Existing BP weapon unlocks are **PARTIAL** support; blueprint hunting is **ABSENT** |

Endless Survival is the mastery/score-pressure path. It is not replaced by TECH HUNT and must not become a disconnected second justification for the game.

### Why this is a loop rather than a feature list

```text
a visible target
  → a chosen expedition
  → readable danger and optional risk
  → a specific earned reward
  → an immediately understandable new possibility
  → another attempt with a different plan
```

More tiers, chests, worlds, or menus do not repair a break in this chain.

## 3. Active prototype: TECH HUNT 0

### 3.1 Include

- One existing world and one existing hero.
- Existing Pulse Rifle, Nova Launcher, and Arc Shooter behaviors.
- Existing Runner and Shooter combat roles as guards.
- One Recovery mission with one primary objective and one optional guarded cache.
- One specific blueprint/capability reward known before deployment; no random rarity roll.
- Clear task/area guidance and guarded/ready/secured cache feedback.
- Immediate, idempotent permanent save when technology is secured.
- Death-before/death-after secure persistence behavior.
- An explicit Extract versus Continue to Endless Survival decision after the main objective.
- Results/upgrade feedback that identifies a concrete reason to redeploy.

### 3.2 Exclude from this prototype

- A new boss, hero, weapon family, enemy family, or world.
- A new crafting currency, premium economy, or random loot rarity system.
- Grid inventory, survival meters, durability, crafting trees, or consumable stacking.
- A second session/wave/reward/save/mission manager.
- Automatic conversion of World metadata such as `recovery` or `hunt` into Gameplay behavior.
- One-of-three run upgrades, elite variants, and named candidates such as Overcharge/Rapid Pulse/Chain Reactor unless separately approved.
- Any retention or engagement claim before human playtesting.

### 3.3 Existing behavior to preserve during the transition

- Shell theatre selection and direct DEPLOY into that theatre.
- Safe initial gameplay entry: no unsolicited WaveDirector session at the landing point.
- Existing explicit Explore → Preparing → Defense path until its replacement/extension passes regression.
- Exactly-once enemy/wave rewards and Defense → Results banking.
- Persistent BP wallet, unlocks/equip, best results, and selected content ids.
- Retry resetting run state without clearing the persistent profile.
- All five currently registered theatre definitions and their existing selection behavior.

Do not remove the working Defense path merely to make the new mission look complete. Extend the existing composition root through a reviewed transition, then retire obsolete entry controls only as an explicit UI/Core decision.

## 4. Core loop

The established chain remains:

**Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy**

Exploration and discovery are activities inside this chain, not a new session manager.

| Step | Target player activity | Required gameplay result |
|---|---|---|
| **Prepare** | Select mission/theatre, hero, and weapon loadout; inspect target tech and threat | One main objective, one known target reward, at most one tracked optional opportunity |
| **Deploy** | Enter the selected theatre at a readable safe landing | Objective and first direction are clear; no automatic wave starts |
| **Fight / Explore** | Follow landmarks, fight guards, use cover, choose direct route or guarded detour | Movement/combat advances the mission; optional risk is understandable |
| **Adapt** | Change target priority, weapon, EMP timing, route, or an approved run modifier | At least one player-owned response to the encounter |
| **Survive** | Resolve the guardian encounter or withstand pressure | Readable recovery/punish opportunity; not merely a larger health bar |
| **Reward / Secure** | Complete the objective and secure its cache | Unique cache/reward ids persist immediately and exactly once |
| **Upgrade** | Extract to review/equip, or inspect the secured result | Clear before/after capability; no unexpected auto-equip |
| **Redeploy** | Return with a new plan, or explicitly continue into Endless before leaving | Another attempt has a tactical/discovery purpose |

### 4.1 Decision after the main objective

```text
MAIN OBJECTIVE SECURED
        │
        ├─ EXTRACT / RESULTS
        │     → apply completion banking exactly once
        │     → review / upgrade / equip
        │     → redeploy with a new plan
        │
        └─ CONTINUE TO ENDLESS SURVIVAL
              → preserve the current run context
              → pursue score, mastery, and bounded bonus rewards
              → already secured permanent tech remains safe
```

Extraction is a session transition, not a new persistent currency. Continuing must not duplicate mission rewards or silently restart the profile/run.

## 5. First-session hypothesis

The following is a playtest target, not a measured duration promise.

| Target time | Beat | Observation intended |
|---|---|---|
| 0:00–1:00 | Choose a Recovery mission with a named tech target and deploy | Player can state the goal before combat |
| 1:00–3:00 | Read the landing landmark, fight a small patrol/guard, see the tech direction | World is traversed with purpose |
| 3:00–5:00 | Choose the direct objective route or guarded optional cache | Player can explain the risk/reward choice |
| 5:00–7:00 | Defeat guards using existing weapon roles and dodge/punish, then secure the cache | Core combat earns the reward |
| 7:00–9:00 | Complete the main task; choose Extract or Endless | Short completion and extended mastery are both valid |
| 9:00–10:00 | Review/equip the unlock and identify a next-run plan | Progress creates a possibility, not only a collection entry |

Do not tune by forcing every player into these timestamps. First observe where purpose, readability, or reward comprehension fails.

## 6. Mission and exploration rules

### 6.1 Mission card

Before DEPLOY, the player needs only plan-forming information:

```text
MISSION: RECOVER THE RELAY BLUEPRINT
Main: reach the relay site → disable its guard → secure the cache
Known reward: [specific blueprint / capability]
Threat: [dominant enemy behavior or world hazard]
Optional: [one additional guarded cache / scan / rescue opportunity]
```

A known target supports intentional mission selection. Avoid lore dumps, long currency lists, and hidden-rarity percentages in this card.

### 6.2 Guidance without removing discovery

Use escalating guidance:

1. **Area:** objective names a district/landmark and general direction.
2. **Local:** entering the area reveals signal strength, sight-line landmarks, or guardian arena.
3. **Stuck:** after measured lack of objective progress, offer an optional stronger hint.

The tracker holds one primary task and at most one tracked optional task. Completed steps remain visible long enough for the player to understand the state change.

### 6.3 Guard activation and safe entry

- Landing does not auto-start a wave or spawn an unavoidable encounter on the player.
- A guard encounter starts through a clearly communicated entry/interaction condition, not an invisible surprise trigger.
- Existing World markers may supply locations, but Gameplay/Core owns activation and completion.
- Optional guards must be avoidable or clearly signposted before commitment; the player needs a meaningful choice.

### 6.4 Cache state contract

```text
UNDISCOVERED → GUARDED → READY TO SECURE → SECURED
```

| State | Rule |
|---|---|
| Undiscovered | No reward or completion has occurred |
| Guarded | Assigned encounter is active/incomplete; interaction cannot bypass it |
| Ready to secure | Guard condition is complete; the player can perform the secure interaction |
| Secured | Unique cache id and reward id are persisted immediately; repeated interaction is idempotent |

Death before Secured grants no blueprint. Death after Secured cannot remove it. A unique cache cannot be farmed by retrying or dying.

### 6.5 Later mission templates — not TECH HUNT 0 breadth

| Template | Core task | Tactical variation | Status |
|---|---|---|---|
| Recovery | Reach a cache, defeat its guard, secure technology | Route choice and optional detours | **SELECTED for first prototype** |
| Sabotage | Disable linked nodes, then survive the response | Target order and escalating pressure | **PROPOSED** |
| Hunt | Track and defeat a named guardian/boss | Learn a boss rule and prepare a counter-loadout | **PROPOSED** |

World metadata never implements these templates by itself.

## 7. Combat design

### 7.1 Existing weapon roles — IMPLEMENTED content baseline

| Weapon | Stable id | Gameplay role |
|---|---|---|
| Pulse Rifle | `pulse_rifle` | Direct, precise pressure |
| Nova Launcher | `nova_launcher` | Area denial and grouped-target positioning |
| Arc Shooter | `arc_shooter` | Chained-target prioritization with line-of-sight constraints |

TECH HUNT 0 should prove its loop with these capabilities before adding another weapon. “Energy Rifle” has no separate executable id; its mapping to Pulse Rifle remains an open naming decision, not permission to rename saves or create a fourth weapon.

### 7.2 Existing enemy roles — IMPLEMENTED content baseline

| Enemy | Role | Decision created |
|---|---|---|
| Runner | Close pressure | Forces relocation and target-priority decisions |
| Shooter | Ranged standoff with locked-point attack | Creates dodge/cover and recovery-punish timing |

The current Shooter uses a 0.7-second windup and 2.2-second attack interval. Its windup stores a locked attack point, exposes an aim marker/core charge, then resolves against that point. These are implementation facts, not proof that humans notice or enjoy the exchange.

### 7.3 Combat mastery hypothesis

```text
read windup → relocate/use cover → locked shot misses
  → punish recovery → choose the next threat under Runner pressure
```

The first playtest should use existing mechanics and feedback. Add a recovery indicator, tutorial prompt, new enemy, or new combat manager only if observation identifies a specific failure that existing presentation cannot solve.

### 7.4 Adaptation boundary

Current adaptation is positional aiming, cover/movement, target prioritization, weapon selection, and EMP timing. Persistent Armory unlocks are **not** in-run upgrade choices.

A future one-of-three milestone system remains **PROPOSED**. Before implementation it needs approved milestones, eligible definitions, stacking/incompatibility rules, pause/defeat behavior, exactly-once application, and run-reset semantics. Shared base weapon resources must remain immutable.

## 8. Progression and technology

| Layer | Persistence | Purpose | Constraint |
|---|---|---|---|
| Blueprint/technology | Permanent after Secured | Unlocks a weapon, gadget, module, interaction, or capability | Prefer new decisions over rarity and small percentages |
| Hero/weapon tier | Permanent | Bounded mastery and specialization | Cap stat growth; avoid mandatory grind |
| Hero/weapon type | Permanent selection | Defines a play style | Behavior must support the stated identity |
| World type/access | Permanent discovery/access where applicable | Changes ecology, routing, threats, and tech opportunities | No silent mode creation from metadata |
| Run adaptation | Current run only | Responds to the current encounter | Reset on retry/death; never mutate shared base definitions |
| Mission item | Mission-scoped unless explicitly permanent | Opens/completes a task | Separate from combat-slot capacity |

### 8.1 Minimal resource policy

Do not add a new crafting currency for TECH HUNT 0. Use:

- existing **BP** for approved purchase/upgrade costs;
- a **blueprint/unlock record** for eligibility;
- existing weapon/module ownership for the resulting capability.

A blueprint answers “what can be built?” BP answers “can the approved cost be paid?” Generic salvage, ores, circuits, fragments, and rarity dust are deferred unless playtesting demonstrates a real decision that BP + blueprint cannot provide.

### 8.2 Technology quality bar

A useful unlock does at least one of the following:

- creates a different target-priority or positioning problem;
- provides a new answer to groups, ranged pressure, shields, or another approved threat;
- opens a new route/interaction through an explicit World contract;
- enables a loadout combination worth testing.

A small damage increase may support a tier, but is not sufficient evidence that a technology hunt matters.

## 9. Field kit / “tas”

The field kit supports preparation and discovery rather than inventory administration.

```text
Weapons: existing three-slot loadout
Active capability: existing EMP path
Tech modules: up to two slots only after a module contract is approved
Mission pouch: objective items and secured blueprint records; no combat-slot pressure
```

For TECH HUNT 0, do not add module slots merely to fill the screen. The field-kit UI must answer:

- What am I taking into this expedition?
- Which behavior does each equipped item change?
- What did I just secure?
- What new combination can I try?

## 10. Death and permanent-save contract

Permanent progress and meaningful danger coexist by separating **secured progress** from **the unfinished attempt**.

| Kept after death | Reset or incomplete on death |
|---|---|
| Secured blueprints/technology | Current wave/encounter state |
| Unique secured-cache ids | Temporary run adaptations |
| Completed permanent mission milestones | Unfinished guardian/objective state |
| Owned weapons/modules and approved tiers | Current health, ammo, position, and transient encounter state |
| World access/unlocks | Provisional run state according to the existing Results/retry rules |
| Banked BP, best results, and existing profile fields | Any reward whose secure condition was not completed |

### 10.1 Transaction boundaries

1. `TECH_SECURED(unique_cache_id, reward_id)` — logical event name for the contract; persist immediately and idempotently through the existing profile path.
2. `MISSION_MILESTONE_SECURED(mission_id, milestone_id)` — persist only milestones explicitly classified as permanent.
3. `RUN_ENDED` — use the existing exactly-once run banking path.
4. Death never drops a unique blueprint and never requires a corpse run.
5. Full profile reset is a separate explicit confirmed destructive action; ordinary death/retry never invokes it.

These names describe required semantics, not permission to add a new event bus or autoload. Actual API naming belongs to the integration design.

The death cost is time, an unfinished objective, and temporary run state—not deletion of technology already earned.

## 11. Endless Survival

### 11.1 Current implementation — PARTIAL Endless

- Waves have no authored final index.
- Count and Shooter composition increase only to configured caps.
- A run ends through defeat or deliberate Finish Run.
- There is no implemented elite/boss/post-cap escalation system.

Structurally endless waves are not proof of durable escalating challenge or long-run stability.

### 11.2 Target integration

The TECH HUNT target path offers Endless after the main objective as an explicit choice. Existing Defense remains the regression baseline while this path is implemented through the current session/wave owners.

Escalation should use one approved axis at a time:

1. enemy composition and attack angles;
2. readable encounter/guardian rules;
3. situations where different weapon/module decisions remain useful;
4. bounded numeric pressure after readability and time-to-kill are measured.

Do not simultaneously increase health, damage, speed, count, and elite density. If the player only holds fire while an automatic build resolves the screen, the loop has exhausted its decisions.

## 12. Guardians and future bosses

A guardian is an exam of existing verbs, not a health-bar gate. A future encounter should:

- telegraph with the same readable language as ordinary enemies;
- require relocation, cover, target priority, or EMP timing;
- expose a recovery/weak-point punish window;
- escalate by recombining learned rules with limited pressure;
- make its cache Ready, after which the actual secure interaction persists the reward.

A new boss is **DEFERRED** until TECH HUNT 0 proves mission, cache, persistence, and redeploy with existing guards.

## 13. Gameplay logic and ownership contracts

### 13.1 Existing state owners — preserve

| Owner | Current responsibility |
|---|---|
| `Main` / `SessionMode { EXPLORE, PREPARING, DEFENSE, RESULTS }` | Session composition and transitions |
| `WaveDirector` / `WaveState { IDLE, SPAWNING, INTERMISSION, GAME_OVER, BLOCKED }` | Wave scheduling, spawning, completion, blocked recovery |
| `RunStats` | Active-run score/BP/time and run-active guard |
| `RewardService` | Validated exactly-once enemy/wave run rewards |
| `ProgressionService` | Persistent wallet, unlock/equip, best/profile fields, save/load |
| `WeaponController` | Fire validation, cadence, ammo/reload, switching, projectile launch |
| Weapon projectile strategies | Content-specific direct/splash/chain execution |
| HUD/menus | Presentation and user intent, not reward/save authority |

Pause is orthogonal to session state. Armory purchases use persistent previously banked BP; they are not milestone choices.

### 13.2 Weapon and damage contracts

Current public entry points include:

```gdscript
WeaponController.try_fire(shooter, muzzle, aim_point) -> bool
projectile.launch(start_position, aim_point, shooter, definition) -> void
combatant.apply_damage(amount, source) -> void
combatant.is_defeated() -> bool
```

Current damage behavior uses duck-typed methods/signals, per-attack duplicate guards where needed, and real `damage_received` feedback. Do not centralize damage into a global singleton merely for symmetry. Changing signatures or introducing a damage packet requires cross-domain coordination.

`WeaponDefinition` owns identity/cadence/ammo/direct/splash/chain data. Controllers own execution state; projectile content owns its strategy; neither may own persistent profile writes.

### 13.3 Enemy and wave contracts

`EnemyDefinition` provides stable enemy id, display identity, gameplay role, role description, and scene. Spawned enemies must satisfy the existing targeting, elimination, damage, group, and feedback expectations—not merely provide a model.

Existing wave signals (`wave_started`, `enemy_spawned`, `enemy_defeated`, `wave_completed`, `progress_changed`, `session_ended`, `spawn_blocked`) remain compatible unless an integration change explicitly reviews every consumer.

### 13.4 Domain ownership

| Domain | Owns | Must not do |
|---|---|---|
| **Gameplay/Core** | Combat orchestration, damage/health integration, weapon adapters, enemy combat state, waves, upgrades, rewards, mission/run lifecycle, persistent transaction coordination | Do not create parallel sources of truth or silently take over content/UI design |
| **Character & Content** | Hero/enemy/boss models, rigs, animations, weapon/module content and effects | Do not write permanent profile state from weapon/projectile effects |
| **World** | Environment identity, assets, layout, markers, cache/guardian locations, world configuration | Do not turn decorative metadata into Gameplay modes silently |
| **UI/UX** | Mission card, tracker, cache state, field kit, secure/death/extract/Results presentation and input | Do not make UI authoritative for rewards, saves, or encounter completion |
| **Integration/QA** | Cross-domain contracts, regression, persistence/recovery, browser/device evidence | Do not claim subjective or device outcomes from static checks |

### 13.5 Required implementation style

- Extend the existing composition root and services; no duplicate manager or undocumented compatibility layer.
- Keep stable content ids and preserve save compatibility.
- Make secure/reward transitions idempotent and explicit.
- Keep run modifiers separate from shared `.tres` base resources.
- Add tests at the real integration boundary, not only isolated helpers.
- Repair clear adapters/references; escalate defective domain design instead of replacing it silently.

## 14. Acceptance and playtest gates

### 14.1 Existing regression invariants

Any TECH HUNT implementation must preserve:

- safe entry without an unsolicited wave;
- explicit preparation before the existing Defense path while that path remains;
- valid enemy content composition and spawn recovery;
- damage only while a target is alive and able to receive it;
- one enemy reward and one wave-clear reward per applicable run;
- one session-end/banking transition;
- retry clearing run state without clearing persistent unlocks/wallet/best results;
- selected-theatre DEPLOY and existing shell/engine handoff;
- no new architecture violations.

### 14.2 TECH HUNT 0 functional acceptance

1. Before deployment, a new player can see the main objective, known target reward, threat, and optional opportunity.
2. The player encounters an understandable route/risk decision before the optional cache.
3. The cache cannot be secured while its guard condition is incomplete.
4. Secure writes once; repeated interaction/reload cannot duplicate the reward.
5. Death before secure grants nothing; death after secure retains exactly the intended records.
6. Retry clears run-only effects and cannot clear secured tech.
7. Results/death feedback explains what was kept and what reset.
8. Extract and Endless are explicit; neither starts accidentally or banks completion twice.
9. The secured capability creates a real loadout/armory option and a reason to test it.
10. Existing wave/reward duplicate guards, safe deployment, profile behavior, and theatre selection still pass.

These are criteria to implement and test, not current claims.

### 14.3 Human comprehension gates

Without coaching, observe whether a player can:

- state the current mission and next useful action;
- notice the optional guarded opportunity and explain its risk/reward;
- deliberately dodge and punish a Shooter rather than only hold fire;
- explain what the secured technology changed;
- predict correctly what death keeps and resets;
- choose to redeploy with a stated tactical or discovery goal.

Agree on participants, target devices, and thresholds before seeing results. Self-reported fun, a scripted retry, or a larger wallet alone is not mastery/retention evidence.

### 14.4 Stop-and-revise signals

- Players need external help to find the objective.
- Everyone ignores the optional cache, or takes it without deliberation.
- Extract versus Endless is automatic because one option has no perceived value.
- The unlock is received but never equipped or used.
- A new capability changes only time-to-kill, not any decision.
- Death is still described as “losing my progress.”
- Repeated runs differ only in enemy count or HP.

Analytics event names and collection are not implemented by this design. Any measurement system requires its own privacy and ownership approval.

## 15. Open decisions

| Decision | Current status | Required before |
|---|---|---|
| Exact world, mission id, cache location, and first blueprint reward for TECH HUNT 0 | **UNKNOWN** | Mission/content implementation |
| Energy Rifle ↔ `pulse_rifle` naming | **UNKNOWN** | Display-copy or save-id change; prefer no id rename |
| Permanent blueprint schema and migration inside `ProgressionService` | **PROPOSED** | Secure/save implementation |
| Guard activation and extraction UI details | **PROPOSED within TECH HUNT 0** | Shared UI/Core transition work |
| First run-upgrade milestones and actual three choices | **PROPOSED** | Any upgrade implementation |
| Elite/post-cap escalation axis | **PROPOSED** | Long-run Endless work |
| Boss/guardian production beyond existing guards | **DEFERRED** | After TECH HUNT 0 playtest |
| Playtest participants, devices, and numeric thresholds | **UNKNOWN** | Human validation |

## 16. Research basis

These are qualitative signals from self-selected player discussions/reviews, not representative market research or proof of Cyber Strike retention. They explain the design inference; they do not replace playtesting.

| Reference | Recurring useful signal | Warning applied to this design |
|---|---|---|
| Hades | Permanent unlocks can make failed attempts feel meaningful [2](https://www.reddit.com/r/pcgaming/comments/knjhtm/hades_is_the_bestreviewed_steam_game_of_2020/). | Persistence alone does not prevent repetitive rooms/combat [3](https://www.reddit.com/r/patientgamers/comments/1antgbz/hades_a_good_game_whose_repetitiveness_holds_it/). |
| Subnautica | Blueprints and capabilities can give exploration purpose [5](https://www.reddit.com/r/gamedesign/comments/8fc4a5/subnauticas_invisible_guiding_hand_game_design/). | Directionless wandering, wiki dependence, and inventory friction undermine that loop [1](https://www.reddit.com/r/patientgamers/comments/18u0m5w/subnautica_is_the_most_boring_game_ive_ever_played/). |
| Deep Rock Galactic | Directed tasks, freedom, pressure, and pacing can coexist [31](https://www.reddit.com/r/DeepRockGalactic/comments/1de2ual/what_keeps_you_playing/). | Mission variety/reward pacing can still feel grindy [17](https://www.reddit.com/r/DeepRockGalactic/comments/brp0em/negative_opinions_for_deep_rock_galactic_really/). |
| Risk of Rain 2 | Build synergies can change familiar encounters [2](https://www.reddit.com/r/patientgamers/comments/17wiy1h/risk_of_rain_2_is_what_a_content_rich_game_should_be/). | Stat-stick items, proc homogeneity, and sponge outcomes reduce agency [9](https://www.reddit.com/r/riskofrain/comments/1k68f53/am_i_missing_something_about_ror2_it_has_amazing_reviews_but_i_just_feels_boring/). |
| Guardians of the Galaxy | New abilities can refresh combat expression [20](https://www.reddit.com/r/patientgamers/comments/15hmb3h/guardians_of_the_galaxy_2021_a_pretty_great_time/). | Repeated attacks, cooldown dead time, and bullet sponges undermine presentation [1](https://www.reddit.com/r/gaming/comments/tzwq1x/guardians_of_the_galaxy_combat_is_extremely_boring/). |
| Vampire Survivors | Short-term growth and build planning can support “one more run” [4](https://www.reddit.com/r/VampireSurvivors/comments/1khkit6/what_makes_vampire_survivors_so_addictive_for_you/). | A self-sufficient build can turn late runs into waiting [8](https://www.reddit.com/r/VampireSurvivors/comments/15qfa0t/the_replayability_falls_off_hard/). |
| Returnal | Permanent capabilities/milestones can coexist with run resets [14](https://www.reddit.com/r/Returnal/comments/n529h1/list_of_permanent_progression_items_minor_spoilers/). | Long attempts and sparse milestones can make death feel wasted [3](https://www.reddit.com/r/Returnal/comments/p66erk/a_critical_look_at_returnal_why_dying_sucks/). |
| Helldivers 2 | Carrying value to extraction can create tension [15](https://www.reddit.com/r/Helldivers/comments/1apfyxr/dropping_samples_on_death_and_losing_them_on_a/). | Dropped rare resources can instead create frustration/backtracking [19](https://steamcommunity.com/app/553850/discussions/0/4302697675602204989/). |

The design inference is: preserve permanent secured tech and clear mission purpose; put tension in the unfinished expedition and voluntary continuation, not in deleting the unique reward after death.

## 17. Change record

- **2026-10-26:** TECH HUNT selected as the prototype direction; locked-shot dodge/punish retained as the combat-mastery hypothesis. TECH HUNT 0 scope, death/save semantics, Endless integration, ownership, and acceptance gates consolidated into this canonical document. No gameplay implementation or human-validation claim is attached to this documentation decision.
