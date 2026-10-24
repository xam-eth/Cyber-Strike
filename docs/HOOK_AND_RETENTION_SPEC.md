# Hook and Retention Specification

Date: 2026-10-24  
Approval status: **RECOMMENDATION ONLY — NOT APPROVED AS THE LOCKED PRIMARY HOOK**  
Evidence status: mechanics can be tested; player engagement and retention have **not** been tested.

## 1. Constraint

The project needs one concrete reason to improve and try another run, not several new systems at once. This evaluation uses the existing game and does not claim that sci-fi presentation, additional models, reward spam, or a larger enemy roster constitutes a hook.

No persistent economy, monetization, account progression, enemy-power system, world-mystery system, or milestone upgrade system was added for this recommendation.

## 2. Recommended candidate: locked-shot combat mastery

### Working name

**Dodge the lock. Punish the recovery.**

The name is shorthand only. The proposed differentiator is the following repeatable combat behavior:

1. A Shooter obtains line of sight and begins a visible 0.7-second windup.
2. It locks the player's position at the start of that windup instead of tracking the player until impact.
3. The player reads the aim marker/core charge and moves away from the locked line or behind cover.
4. The shot resolves against the old point and misses; the player takes no damage.
5. The Shooter cannot immediately begin another attack because its 2.2-second attack interval began with the windup. This leaves roughly 1.5 seconds after a standard windup before the next possible attack, subject to range/line-of-sight conditions.
6. The player counterattacks during that recovery window. A Shooter has 30 HP; two 18-damage Pulse Rifle hits are sufficient in principle, and Pulse supports a 0.2-second cadence.
7. Runners continue applying close-range pressure, so the mastery decision is not merely waiting in safety: the player chooses when to dodge, which target to punish, and when to relocate.

This is a concrete input → enemy response → player outcome loop. It is not a proposal to add a new enemy, weapon, upgrade, or global combat manager.

### Why it fits the current project

Evidence in `game/scripts/enemies/shooter.gd`:

- `_begin_attack_windup()` stores `_locked_attack_point`, shows `AimMarker`, and starts `_attack_cooldown`.
- `_update_core_telegraph()` scales the chest core during charge.
- `_resolve_attack()` rays to the locked point, applies damage only if the target is hit and can take damage, and emits `attack_resolved(hit_target)`.
- `_physics_process()` gates another windup on attack cooldown, range, and line of sight.

Evidence in `tests/shooter_enemy_smoke.gd` already exercises:

- cover preventing an attack;
- a visible windup marker;
- moving during windup causing `attack_resolved(false)` and no health loss;
- a later stationary shot causing 8 damage;
- lateral cover search;
- exactly-once elimination.

The test proves mechanics when it passes; it does not prove human readability, enjoyment, or retention. See the validation report for the actual run result in this pass.

### Why it could motivate another run

The player can improve a legible skill rather than only accumulate larger numbers:

- recognize the windup earlier;
- dodge with less movement;
- use the recovery window more efficiently;
- prioritize a Shooter while Runners close distance;
- survive to a higher wave or improve best score with the same loadout.

That is a plausible mastery/replayability hypothesis, **not measured retention**. Another-run willingness must be observed in playtesting.

## 3. Complexity and dependency analysis

| Dimension | Assessment |
|---|---|
| Moment-to-moment effect | High relevance: movement, cover, aiming, timing, and target priority all participate in the same exchange. |
| New mechanics required for first playtest | None intended. Use the existing Shooter, Pulse Rifle, Player, and wave-two encounter. |
| Code complexity | Low for the initial test. Existing `attack_resolved`, damage, health, and elimination signals can support observation. |
| Content dependency | Existing Shooter visuals/marker/core and Pulse feedback. No new asset is required to test the hypothesis. |
| UI dependency | None for the first test. A recovery indicator or tutorial prompt should be added only if observation shows a specific readability failure. |
| Integration dependency | No shared contract change for the initial playtest. Persistent telemetry or a new combat event would require coordination. |
| Balance dependency | Standard 0.7 s windup, 2.2 s interval, 30 Shooter HP, and Pulse 18 damage/5 per second must be evaluated together on target devices. |
| Principal risk | Players may not notice the marker/core, may not understand the locked-point rule, or may find the punish window trivial once learned. Headless software-rendered WebGL cannot answer these questions. |

## 4. Alternatives considered

| Candidate | Fit with current evidence | Complexity/dependencies | Effect on combat and another run | Disposition |
|---|---|---|---|---|
| **Combat mastery: locked-shot dodge/punish** | Directly supported by Shooter windup, locked point, cover checks, cooldown, Pulse time-to-kill, and existing tests | Lowest; no new system for first test | Immediate movement/aim/timing decisions; improve survival and score through skill | **RECOMMENDED for approval/playtest** |
| Weapon identity evolves through a run | Aligns with the addendum's milestone-choice direction and existing data-driven weapons | Medium/high: milestone state, three approved upgrades, run modifiers, reset semantics, UI, effect feedback, compatibility rules | Could change build decisions during a run, but no such behavior exists now | **Promising later alternative; not approved or prototyped** |
| Acquire/adapt to enemy powers | Current EMP is player-owned; enemies have only melee and locked-shot basics | High: power definitions, acquisition rules, enemy ability interfaces, balance, UI, feedback | Could create novel interactions, but would introduce several new systems at once | **Reject for current slice** |
| Environmental/world mysteries | A connected world exists, but no mystery/interactable/discovery loop is established | High and cross-domain: world content, interaction contract, clues, UI, save semantics if persistent | Discovery could motivate exploration, but does not currently strengthen the Defense combat loop | **Defer; outside this gameplay slice** |
| Risk-versus-reward decisions | Finish Run already offers a cash-out path and BP is banked at Results | Medium: needs a meaningful voluntary risk decision, reward rules, balance, and clear UI; must not invent an economy | Could create tension, but reward multipliers or wagering would change the approved loop | **Defer; do not combine with the mastery hook** |

Choosing combat mastery does **not** lock out later weapon evolution. It prevents both from being presented as co-primary hooks or implemented simultaneously without evidence.

## 5. Approval and prototype boundary

### Current status

- Candidate recommendation: **locked-shot combat mastery**.
- Product approval: **PENDING / UNKNOWN**.
- Implementation as a new hook system: **NOT STARTED**; no new system is required for the initial test.
- Engagement validation: **NOT RUN**.
- Retention improvement claim: **NONE**.

Approval is requested only to designate this as the primary playtest hypothesis. It is not approval to add upgrade candidates, elites, currencies, or a meta-progression system.

### Prototype using existing content

Use the current game with no new mechanics:

- Hero: existing Exo Operative/player scene.
- Weapon: Pulse Rifle (pending the Energy Rifle naming decision).
- Enemy: existing Shooter, with Runners present for pressure in the real wave-two context.
- Interaction: read windup → dodge locked shot/cover → counterattack during cooldown.
- Run outcome: compare survival, damage taken, successful dodges, Shooter eliminations, wave reached, and the player's explanation of what happened.

A controlled fixture may shorten time-to-Shooter for observation, but conclusions about the real loop also require the actual wave-two encounter. A fixture must not be presented as proof of full-run balance.

## 6. Playtesting and validation criteria

### Mechanistic gates (automated)

These are necessary but insufficient:

1. Cover prevents Shooter damage.
2. Moving after the locked point is sampled produces a miss and no health loss.
3. Remaining stationary can produce an 8-damage hit.
4. The marker is visible during windup and hidden after resolution/cancellation.
5. Pulse can damage the same Shooter repeatedly while it remains alive.
6. No change to reward duplicate guards or wave progression occurs.

### Human comprehension gates

Before claiming the hook works, observe whether a new player can, without being told the implementation:

- identify that the Shooter is preparing an attack;
- explain that the attack locked an earlier position or can be avoided by movement/cover;
- deliberately dodge at least once, rather than accidentally avoiding damage;
- recognize and use the recovery window to counterattack;
- describe how a Runner changes the decision.

Do not set a success threshold after seeing the results. Product/QA should agree on the sample, device, and thresholds before the test. No sample or retention threshold is invented in this document.

### Another-run evidence

After a run, ask and observe:

- Can the player name one timing or targeting improvement they want to make?
- Do they choose to retry to execute that improvement?
- Does performance on the next run reflect the stated learning (fewer locked-shot hits, more deliberate counterattacks, or higher wave with equivalent conditions)?

Self-reported “fun” alone, a scripted retry, or a higher wallet balance is not evidence of mastery-driven retention. Analytics would require a separately approved measurement/privacy contract and are not added here.

## 7. Retention layers mapped to actual behavior

| Layer | Current executable support | Gap / honest interpretation |
|---|---|---|
| Moment-to-moment engagement | Movement, aiming, recoil/tracers/impacts, Runner pressure, Shooter windup/dodge, EMP timing | The locked-shot exchange is the smallest coherent mastery candidate. Human feel remains unverified. |
| Within-run progression | Wave count and Shooter composition increase; score/BP accumulate during a run | Growth caps at waves 6–7; no upgrade choices or evolving weapon behavior. |
| Between-run motivation | Results, best score, banked BP, Nova/Arc unlock goals, retry/redeploy | Existing goals can support another run, but no behavioral evidence shows they do. |
| Long-term collection/account progression | Local wallet, ownership, best score, completed-run count and selected loadout ids | Keep the existing small profile. No account system, premium economy, battle pass, or new save layer is justified. |

### Motivation categories

- **Mastery:** strongest current candidate through locked-shot avoidance and counterattack timing.
- **Progression:** persistent weapon unlocks exist; in-run upgrades do not.
- **Discovery:** encountering the Shooter at wave two and trying unlocked weapons offers limited content discovery; mysteries do not exist.
- **Identity:** Pulse precision, Nova splash, and Arc chain provide different weapon roles; a preferred-playstyle claim requires player evidence.
- **Ownership:** buying and equipping a weapon with earned BP is real; expanding collection for its own sake is not recommended.
- **Replayability:** score/survival improvement and weapon experimentation exist; the proposed hook targets skill-based replay rather than reward spam.

## 8. Next safe step

1. Obtain product approval to playtest locked-shot mastery as the single primary hook candidate.
2. Run the existing mechanistic checks and a human target-device test without adding new systems.
3. Record observed failures separately: telegraph readability, input latency, cooldown clarity, balance, or lack of motivation.
4. Make the smallest correction indicated by evidence.
5. Re-evaluate weapon evolution only after the milestone upgrade design is approved and its contracts are coordinated.

Until then, the hook remains a well-grounded recommendation, not a locked design decision or a validated retention result.
