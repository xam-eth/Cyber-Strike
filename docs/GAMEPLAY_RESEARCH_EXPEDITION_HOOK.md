# Gameplay Research — TECH HUNT Expedition Hook

- **Date:** 2026-10-26
- **Status:** **RESEARCHED PROPOSAL — PRODUCT APPROVAL AND HUMAN PLAYTEST STILL REQUIRED**
- **Scope:** Experience design and implementation boundaries only. No gameplay, economy, save, content, or mode implementation is included in this change.

Companion records: [GAMEPLAY_LOOP_SPEC.md](GAMEPLAY_LOOP_SPEC.md), [HOOK_AND_RETENTION_SPEC.md](HOOK_AND_RETENTION_SPEC.md), and [GAMEPLAY_CONTENT_CONTRACTS.md](GAMEPLAY_CONTENT_CONTRACTS.md). This document extends their direction; it does not mark their proposals as approved or implemented.

## 1. Executive recommendation

### Player promise

> **Choose a technology worth hunting, enter a guarded world, decide how much danger to accept, secure the blueprint permanently, then return with a new way to play.**

The content pillars—hero/weapon tiers, hero/weapon types, and world types—remain the **containers**. They are not the experience by themselves. The felt experience should be:

1. **I always know what I am trying to accomplish.**
2. **I make meaningful combat and route decisions while doing it.**
3. **What I earn changes what I can try next.**

### Working hook name: TECH HUNT

TECH HUNT is the macro hook. It should not erase the existing combat-mastery candidate. The three hook layers have different jobs:

| Timescale | Hook | Player thought |
|---|---|---|
| Seconds | **Dodge the lock. Punish the recovery.** Existing Shooter windup/locked-point/cooldown exchange | “I can read that attack and improve my timing.” |
| One expedition | **Find and secure guarded technology** | “I came here for that blueprint; the risk was worth it.” |
| Across expeditions | **Turn technology into new tactics and loadouts** | “What can this unlock let me do differently now?” |

Endless Survival remains the mastery/score-pressure path. It should be available as an explicit choice after the expedition objective, not become a mandatory grind or a separate disconnected justification for the game.

## 2. What external games and player discussions suggest

These are qualitative design signals, not statistically representative market research and not evidence that Cyber Strike retention will improve. Community posts are self-selected and often reflect a particular play style. The useful evidence is the repeated mechanism behind both praise and complaints.

| Reference | Useful pattern | Warning from players | Application here |
|---|---|---|---|
| **Hades** | Players describe permanent unlocks plus a meaningful hub as making failed attempts feel like progress rather than a wipe [2](https://www.reddit.com/r/pcgaming/comments/knjhtm/hades_is_the_bestreviewed_steam_game_of_2020/). | The same loop can still become repetitive when room order, encounters, and effective decisions stop changing [3](https://www.reddit.com/r/patientgamers/comments/1antgbz/hades_a_good_game_whose_repetitiveness_holds_it/). | Keep secured progress after death, but do not rely on persistence to rescue repetitive combat. Each expedition needs a goal and a tactical variable. |
| **Subnautica** | Blueprints and capability upgrades reinforce exploration: new equipment enables reaching places that previously felt out of reach [5](https://www.reddit.com/r/gamedesign/comments/8fc4a5/subnauticas_invisible_guiding_hand_game_design/). | Players also report directionless wandering, external-wiki dependence, backtracking, and inventory friction [1](https://www.reddit.com/r/patientgamers/comments/18u0m5w/subnautica_is_the_most_boring_game_ive_ever_played/). | Preserve discovery, but show a current task, a destination area, and escalating hints. Do not add survival-inventory chores to make exploration feel substantial. |
| **Deep Rock Galactic** | Players praise the combination of directed tasks, freedom, pressure, and pacing [31](https://www.reddit.com/r/DeepRockGalactic/comments/1de2ual/what_keeps_you_playing/). Secondary objectives create a legible time/danger-versus-payout decision [25](https://gameinformer.com/review/deep-rock-galactic/deep-rock-galactic-review-off-to-work-we-go). | Mission diversity and reward pacing can still be criticized as grindy [17](https://www.reddit.com/r/DeepRockGalactic/comments/brp0em/negative_opinions_for_deep_rock_galactic_really/). | One primary objective plus one optional guarded tech opportunity is enough for the first slice. Extraction should be a choice, not an extra chore after the fun ends. |
| **Risk of Rain 2** | Build synergies and alternate abilities can make familiar stages play differently [2](https://www.reddit.com/r/patientgamers/comments/17wiy1h/risk_of_rain_2_is_what_a_content_rich_game_should_be/). | Players also describe low-agency item intake, repetitive objectives, stat-stick upgrades, proc-chain homogeneity, and bullet-sponge outcomes [9](https://www.reddit.com/r/riskofrain/comments/1k68f53/am_i_missing_something_about_ror2_it_has_amazing_reviews_but_i_just_feels_boring/). | Prefer a few understandable, build-changing choices over a large pool of small percentages. Do not scale every axis at once. |
| **Marvel's Guardians of the Galaxy** | Additional abilities can make combat more expressive; players note that new powers can create strength without merely raising a level number [20](https://www.reddit.com/r/patientgamers/comments/15hmb3h/guardians_of_the_galaxy_2021_a_pretty_great_time/). | Repetitive encounters, cooldown dead time, and bullet-sponge enemies are recurring complaints [1](https://www.reddit.com/r/gaming/comments/tzwq1x/guardians_of_the_galaxy_combat_is_extremely_boring/). | Take the cinematic expedition fantasy, not a squad system or long health bars. The existing readable dodge/punish exchange must remain useful inside every mission. |
| **Vampire Survivors** | Constant short-term growth, evolutions, and build planning create a strong “one more run” pull for some players [4](https://www.reddit.com/r/VampireSurvivors/comments/1khkit6/what_makes_vampire_survivors_so_addictive_for_you/). | Once a build becomes self-sufficient, players report waiting for the run to end rather than making decisions [8](https://www.reddit.com/r/VampireSurvivors/comments/15qfa0t/the_replayability_falls_off_hard/). | Endless escalation must preserve decisions and threat readability. More particles, HP, and automatic damage are not a complete endgame. |
| **Returnal** | Its community documents permanent weapon traits, traversal capabilities, boss milestones, and item-pool unlocks alongside run-only resets [14](https://www.reddit.com/r/Returnal/comments/n529h1/list_of_permanent_progression_items_minor_spoilers/). | Long attempts and sparse meaningful milestones can make death feel like lost time [3](https://www.reddit.com/r/Returnal/comments/p66erk/a_critical_look_at_returnal_why_dying_sucks/). | Put a meaningful, secured milestone in a short first expedition. Do not require a boss clear before every small form of progress. |
| **Helldivers 2** | Carrying valuable samples to extraction creates real tension for some players [15](https://www.reddit.com/r/Helldivers/comments/1apfyxr/dropping_samples_on_death_and_losing_them_on_a/). | Others describe dropped/lost samples as frustration and backtracking rather than interesting risk [19](https://steamcommunity.com/app/553850/discussions/0/4302697675602204989/). | Do not drop unique tech on death. Secure it after the guardian interaction and save immediately; keep tension in the unfinished mission and the choice to continue. |

### Synthesis

The research does **not** support “more progression systems = more fun.” It supports a narrower chain:

```text
clear purpose
  → readable danger
  → player-owned decision
  → specific reward
  → immediately understandable new possibility
  → another attempt with a different plan
```

The main design risk is not a lack of content. It is building containers—tiers, chests, currencies, worlds, and menus—before the chain above is enjoyable with one mission and one reward.

## 3. The three experience promises

These complements, rather than replaces, the user's three content pillars.

### 3.1 Purpose without a wiki

Every expedition answers, before DEPLOY:

- **What is the main task?**
- **What technology or capability is the known target?**
- **What guards or hazard makes it difficult?**
- **What optional opportunity may be worth a detour?**

The player may explore freely, but should never need to guess whether the game has an objective.

### 3.2 Mastery and adaptation under pressure

The mission must repeatedly use the existing combat verbs:

```text
read threat → relocate/use cover → dodge locked attack
  → punish recovery → prioritize the next threat → adapt the loadout
```

A chest, objective, boss, or upgrade is valuable only if it changes or recontextualizes those decisions. Walking to a marker and holding interact is not a complete adventure loop.

### 3.3 Technology that creates new possibilities

Permanent rewards should primarily unlock **verbs, interactions, and build paths**:

- a different target-priority or positioning problem;
- a new way to handle groups, shields, or ranged pressure;
- a new route or interaction with a world rule;
- a new loadout combination worth testing.

Small stat improvements can support tiers, but they cannot be the main evidence that technology matters.

## 4. Refined loop — preserving the established direction

The approved chain remains:

**Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy**

Exploration and tech discovery live inside that chain; they do not require replacing it with a new session manager or adding a parallel game mode.

| Step | What the player does | What the player should feel | Required outcome |
|---|---|---|---|
| **Prepare** | Select a mission, hero, and weapon loadout; inspect the known tech target and threat | “I have a plan.” | One primary objective, one clear target reward, one optional opportunity |
| **Deploy** | Enter the selected world at a readable safe landing point | “I understand where I am and the first direction.” | Main task and destination area visible; no unsolicited wave |
| **Fight / Explore** | Follow landmarks, fight patrols, use cover, and choose the direct route or guarded detour | “I am driving the expedition, not only clearing a spawn queue.” | Movement and combat advance the mission; optional risk is legible |
| **Adapt** | Change target priority, weapon, EMP timing, route, or an approved run modifier | “My decisions affect this attempt.” | At least one meaningful response to the encounter, not automatic stat accumulation alone |
| **Survive** | Resolve the guardian encounter or withstand escalating pressure | “I earned the opening.” | Guardian has a readable rule and recovery/punish opportunity, not only more HP |
| **Reward / Secure** | Open the secured cache, synchronize the blueprint, complete the main objective | “This specific reward is now mine.” | Permanent save occurs immediately after the secure event; unique rewards cannot be farmed by dying |
| **Upgrade** | Extract to upgrade/equip, or review what was secured at Results | “I can see a new possibility.” | Clear before/after explanation and a suggested next use, without auto-equipping unexpectedly |
| **Redeploy** | Return with a new plan, or explicitly continue into Endless Survival before leaving | “I want to test this build or improve my mastery.” | The next attempt has a player-selected purpose, not only a larger wallet number |

### The decision after the main objective

```text
MAIN OBJECTIVE SECURED
        │
        ├─ EXTRACT / RESULTS
        │     → bank completion rewards
        │     → upgrade / equip
        │     → redeploy with a new plan
        │
        └─ CONTINUE TO ENDLESS SURVIVAL
              → keep the current expedition loadout/run adaptations
              → pursue score, mastery, and clearly bounded bonus rewards
              → already secured permanent tech remains safe
```

This creates a voluntary risk decision without deleting the reward that motivated the expedition.

## 5. First-session hook hypothesis

The following is a **playtest target, not a measured promise**. The first ten minutes should demonstrate the whole loop before content breadth is expanded.

| Target time | Beat | Proof intended |
|---|---|---|
| 0:00–1:00 | Choose a recovery mission with a named tech target and deploy | The player can state the goal before combat |
| 1:00–3:00 | Learn the landing landmark, fight a small patrol, see the guarded tech direction | The world is a place to traverse, not only an arena background |
| 3:00–5:00 | Choose the direct objective route or the guarded optional cache | The player makes an understandable risk decision |
| 5:00–7:00 | Defeat the guards using the existing dodge/punish and weapon roles, then secure the cache | The reward is earned through the core combat verb |
| 7:00–9:00 | Complete the main task, then choose extraction or Endless Survival | Short-session completion and long-session mastery are both valid |
| 9:00–10:00 | Review/equip the unlock and identify one reason to redeploy | Progression produces a plan, not only a collection entry |

If the first meaningful tech reward requires several long runs, the hook is delayed. If everything is handed out in the first minute, there is no hunt. Exact timing must be tuned through observation rather than treated as a quota.

## 6. Mission and exploration rules

### 6.1 Mission card contract

Before deployment, show only the information needed to form a plan:

```text
MISSION: RECOVER THE RELAY BLUEPRINT
Main: reach the relay site → disable its guard → secure the cache
Known reward: [specific blueprint / capability]
Threat: [dominant enemy behavior or world hazard]
Optional: [one additional cache / scan / rescue opportunity]
```

Do not show a large list of currencies, lore paragraphs, or hidden-rarity percentages. A known target is a stronger initial hook than an entirely random loot roll because the player can choose the mission intentionally.

### 6.2 Guidance that preserves discovery

Use escalating guidance rather than choosing between a permanent exact waypoint and no help:

1. **Area guidance:** the objective names a district/landmark and general direction.
2. **Local guidance:** entering the area reveals signal strength, sight-line landmarks, or the guardian arena.
3. **Stuck guidance:** after a measured lack of objective progress, offer an optional stronger hint.

The task tracker should retain one active primary task and at most one tracked optional task. Completed steps must remain visible long enough for the player to understand what changed.

### 6.3 Guarded cache contract

A tech cache has four readable states:

```text
UNDISCOVERED → GUARDED → READY TO SECURE → SECURED
```

- Guarded means its assigned encounter is still active; interaction cannot bypass the fight.
- Ready means the guard condition is complete and the player can perform the secure interaction.
- Secured is an idempotent event: the unique cache id and reward id are persisted immediately.
- A unique tech cache cannot be reopened for the same permanent reward.
- Death before Secured does not grant the blueprint; death after Secured cannot remove it.

The cache is the conclusion of an encounter, not a replacement for one.

### 6.4 Mission templates — later expansion, not first-slice breadth

| Template | Core task | Tactical variation |
|---|---|---|
| **Recovery** | Reach a cache, defeat its guard, secure technology | Route choice and optional detours |
| **Sabotage** | Disable a small set of linked nodes, then survive the response | Target order, positioning, and escalating pressure |
| **Hunt** | Track and defeat a named guardian/boss | Learning the boss rule and preparing a counter-loadout |

These are proposals only. World metadata such as `hunt` or `recovery` must not silently create Gameplay behavior; each template requires an explicit Gameplay/Core and World integration decision.

## 7. Progression architecture — keep the pillars, clarify their jobs

| Layer | Persistence | Player-facing job | Design constraint |
|---|---|---|---|
| **Blueprint / technology** | Permanent after Secured | Unlocks a weapon, gadget, module, interaction, or other capability | Prefer new decisions over rarity color and small percentages |
| **Hero / weapon tier** | Permanent | Provides bounded mastery goals and loadout specialization | Cap stat growth; avoid exponential power and mandatory grinding |
| **Hero / weapon type** | Permanent selection | Defines a play style and target/position preference | A type must change more than its model or damage number |
| **World type** | Permanent discovery/access | Changes mission ecology, landmark routing, guardian mix, and relevant technology | Not only a skybox/palette; one readable world rule is better than many hidden modifiers |
| **Run adaptation** | Current run only | Lets the player respond to the current encounter | Uses the proposed milestone contract; never mutates shared base weapon resources |
| **Mission item** | Mission-scoped unless explicitly a permanent unlock | Opens or completes a specific task | Separate from combat inventory capacity; no busywork stacking |

### Minimal resource policy for the first slice

**Do not add a new crafting currency yet.** Use:

- the existing **BP** path for approved purchase/upgrade costs;
- a **blueprint/unlock record** to establish eligibility;
- existing weapon/module ownership for the crafted result.

A blueprint is not another wallet. It answers “what can be built?” while BP answers “can the approved cost be paid?” A generic salvage currency should only be proposed if playtesting proves that BP + blueprint cannot produce clear decisions. Multiple ores, circuits, rarity dust, and fragment types would add UI and grind before proving fun.

### Current weapons already provide a useful proof set

- **Pulse Rifle:** direct, precise pressure.
- **Nova Launcher:** area denial and grouped-target positioning.
- **Arc Shooter:** chained-target prioritization and line-of-sight decisions.

The first tech-hunt slice can unlock or specialize these existing capabilities rather than requiring a fourth weapon. The repository default remains `pulse_rifle`; an “Energy Rifle” rename or id mapping is still a separate product decision. Overcharge, Rapid Pulse, and Chain Reactor remain candidates, not approvals from this document.

## 8. Field kit / “tas” without inventory chores

The bag should support combat preparation and discovery, not become a second inventory-management game.

### Recommended first field-kit shape

```text
Weapons: existing three-slot loadout
Active capability: existing EMP path
Tech modules: up to two proposed slots after the module contract exists
Mission pouch: objective items and secured blueprint records; no combat-slot pressure
```

No grid Tetris, hunger/thirst, item durability, or mandatory consumable stacking is recommended for this slice. Those systems would compete with the shooter/adventure hook and add UI, balancing, and save complexity before the mission loop is proven.

The bag screen should answer:

- What am I carrying into the next expedition?
- Which behavior does each equipped item change?
- What did I just secure?
- What new combination can I try?

## 9. Death and permanent-save contract

The user's permanent-progress direction can coexist with meaningful danger by separating **secured progress** from **the unfinished attempt**.

| Kept after death | Reset or left incomplete on death |
|---|---|
| Secured blueprints and technology | Current wave/encounter state |
| Unique secured-cache ids | Temporary run adaptations |
| Completed permanent mission milestones | Unfinished guardian/objective state |
| Owned weapons/modules and approved tiers | Current health, ammunition, position, and active run loadout state as defined by retry |
| World access/unlocks | Provisional run score state, subject to existing Results rules |
| Banked BP, best results, and other existing profile fields | Any reward whose secure condition was not completed |

### Save boundaries

1. `TECH_SECURED(unique_cache_id, reward_id)` — persist immediately and idempotently.
2. `MISSION_MILESTONE_SECURED(mission_id, milestone_id)` — persist only for explicitly permanent milestones.
3. `RUN_ENDED` — use the existing exactly-once run reward/banking path.
4. Death never drops a unique blueprint or requires a corpse run.
5. Full profile reset is a separate, explicit, confirmed destructive action; ordinary death/retry must never invoke it.

The death cost is therefore **time, an unfinished objective, and loss of the current run's temporary state**, not deletion of the technology the player already earned. This avoids both extremes: no stakes at all, and losing the reason for the expedition after a late mistake.

## 10. Guardian and boss principles

A guardian should be an **exam of the game's existing verbs**, not a health-bar gate.

### Example future Warden structure — proposal only

- **Read:** a clearly telegraphed locked-shot or area-denial attack establishes the same visual language as ordinary enemies.
- **Respond:** the player relocates, uses cover, and chooses when EMP or a weapon role is most useful.
- **Punish:** the guardian exposes a recovery/weak-point window instead of merely waiting for the next cooldown.
- **Escalate:** a later phase recombines the learned rule with limited Runner/Shooter pressure; it does not introduce several unrelated mechanics at once.
- **Secure:** defeating the guardian makes its cache ready, then the tech-secured save event occurs through the actual interaction.

The first tech-hunt slice does not need a new boss. Existing Runner/Shooter guards can validate the mission/cache/persistence chain before boss production is justified.

## 11. Endless Survival without bullet-sponge escalation

The current endless structure needs meaningful post-cap decisions, not only higher numbers. Use one approved escalation axis at a time and measure its effect.

Preferred escalation sources:

1. **Composition:** new angles and combinations of existing close-pressure and ranged-standoff roles.
2. **Encounter rules:** a readable guardian milestone or arena condition.
3. **Player build interactions:** situations where different weapon/module choices remain useful.
4. **Bounded numeric pressure:** only after the encounter remains readable and time-to-kill does not become the sole difficulty source.

Avoid simultaneously increasing health, damage, speed, count, and elite density. If the player has stopped making decisions and is only holding fire while a build resolves the screen, the survival loop has exhausted its hook.

## 12. Recommended vertical slice: TECH HUNT 0

### Include

- One existing world and hero.
- Existing Pulse/Nova/Arc behaviors and Runner/Shooter guards.
- One Recovery mission with one primary objective and one optional guarded cache.
- One specific blueprint/capability reward; no random rarity roll.
- Clear task/area guidance and guarded/ready/secured cache feedback.
- Immediate, idempotent permanent save on Secured.
- Death-before/death-after secure persistence checks.
- An explicit Extract versus Continue to Endless Survival decision.
- A Results/upgrade explanation that leads to a concrete redeploy reason.

### Explicitly exclude

- A new boss, hero, weapon family, or world.
- A new crafting currency or random loot rarity economy.
- Grid inventory, survival meters, durability, crafting trees, and consumable stacking.
- A new session/wave/save manager or a second persistent source of truth.
- Automatic conversion of forge metadata into mission behavior.
- Any claim of improved retention before human evidence exists.

### Acceptance hypotheses

1. A new player can explain the main objective and target reward before deployment.
2. The player encounters at least one understandable route/risk decision before the cache.
3. The guard cannot be bypassed by opening the cache early or dying into the reward.
4. Secured technology survives death, retry, and reload; an unsecured reward is not granted.
5. The player can state what was kept and what reset after death.
6. Extract and Endless are both explicit choices; neither starts accidentally.
7. The secured capability creates a visibly different option in the Armory/loadout and a reason to test it.
8. Existing wave/reward duplicate guards, safe deployment, and persistent profile behavior remain intact.

These are acceptance criteria to test, not current implementation claims.

## 13. Ownership and integration boundaries

| Domain | Required responsibility | Must not do |
|---|---|---|
| **Gameplay/Core** | Mission/session transitions, secure-event lifecycle, run reset boundary, persistent transaction coordination | Do not invent a parallel mission, wave, or profile manager |
| **Character & Content** | Weapon/gadget/module effects, enemy/guardian behavior, content feedback | Do not place permanent profile writes inside weapon/projectile effects |
| **World** | Mission landmarks, cache locations, guard arenas, world-rule configuration, route readability | Do not let decorative metadata silently become Gameplay modes |
| **UI/UX** | Mission card, tracker, cache state, field kit, secure/death/extract/Results feedback | Do not make UI the authority for reward or save state |
| **Integration/QA** | Cross-domain contracts, persistence and recovery tests, actual browser/device validation | Do not claim subjective fun, retention, touch quality, or device performance from static checks |

The existing `ProgressionService`, `RewardService`, `Main`, and `WaveDirector` responsibilities need a coordinated extension design before implementation. A separate autosave singleton or a UI-authored reward path would be an undocumented compatibility layer, not a safe shortcut.

## 14. Playtest and measurement plan

### Mechanistic evidence required first

- Secure is impossible while guards are active.
- Secure writes once; repeated interaction/reload does not duplicate the reward.
- Death before secure grants nothing; death after secure retains exactly the intended records.
- Retry clears run-only effects and cannot clear secured tech.
- Mission completion, extraction, and endless continuation cannot bank the same completion reward twice.
- Existing opening, selected-world DEPLOY, combat, and save behavior still pass their gates.

### Human evidence required for the hook

Without coaching, observe whether a player can:

- state the current mission and next useful action;
- notice the optional guarded opportunity and explain its risk/reward;
- deliberately dodge and punish a Shooter rather than only hold fire;
- explain what the secured technology changed;
- correctly predict what death will keep and reset;
- choose to redeploy with a stated tactical or discovery goal.

### Useful event candidates — not implemented analytics

```text
mission_selected
objective_progressed
optional_cache_seen
guardian_started / guardian_completed
tech_secured
death_before_secure / death_after_secure
extract_selected / endless_selected
upgrade_equipped
redeploy_selected
```

Event collection needs a separately approved measurement/privacy contract. Event counts alone do not establish fun; pair them with observation and player explanations.

### Stop and revise signals

- Players cannot find the objective without external help.
- Everyone ignores the optional cache, or everyone takes it without deliberation.
- Extract versus Endless is effectively automatic for all players because one option has no meaningful value.
- The unlock is received but never equipped or used.
- A new weapon changes only time-to-kill, not any player decision.
- Death is still described as “losing my progress.”
- Repeated runs differ only in spawn count or HP.

## 15. Product decisions requested

The recommended defaults are intentionally narrow:

1. **Hook:** approve TECH HUNT as the macro hypothesis while retaining locked-shot dodge/punish as the combat-mastery hypothesis.
2. **Persistence:** approve immediate permanent save for secured unique tech/milestones, with only unfinished run state and temporary adaptations resetting on death.
3. **First slice:** approve TECH HUNT 0—one Recovery mission, one guarded cache, one specific existing-capability unlock, and an explicit Extract/Endless choice—before funding bosses, more worlds, inventory complexity, or new currencies.

Until those decisions are approved and the shared contracts are coordinated, the design remains **PROPOSED**, not implemented. No retention improvement is claimed.
