# Front-end Journey

This document describes the current shell/engine navigation and presentation contracts. It does not own mission, reward, or progression rules; those live in [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md). Executed results belong in [`VALIDATION.md`](VALIDATION.md).

## 1. Two entry paths, one content registry

### Player Web shell

```text
OPENING → HERO → THEATRE → LAUNCH / DEPLOY → selected theatre gameplay
                   └──────── settings / utility controls ────────┘
```

The root shell (`index.html` + `ui/`) selects the operative/loadout and theatre, preloads required runtime data during opening, and hands DEPLOY directly to the selected gameplay theatre. It does not need to stop at the engine WORLD stage.

### Raw/native engine journey

```text
BOOT → LOADING → CHAPTER → DASHBOARD → HERO → WORLD → PRELOAD → gameplay
```

`CHAPTER` can be skipped after its persisted intro flag is seen. `FrontEnd` remains the only engine object that knows this journey order. Stages request a transition; `FrontEnd` validates and performs it.

There is no STUDIO stage or separate WEAPON stage. The loadout belongs with the operative on HERO, not in a redundant standalone page.

## 2. OPENING — painted poster plus real preload

The opening is key art, wordmark/tagline, and real readiness—not an engine diagnostic page.

The Web opening performs:

```text
Engine.init(executable) + Engine.preloadFile(mainPack)
```

before enabling MASUK. Neither call starts gameplay behind the opening. Progress comes from actual aggregate WASM/PCK bytes and exported file sizes.

DEPLOY later calls `Engine.start()` with the same main-pack argument. It must not trigger a second PCK preload. Failure keeps the canvas hidden and exposes an actionable retry path. Full loading/recovery details and commands are in [`runbooks/WEB_PREVIEW.md`](runbooks/WEB_PREVIEW.md).

## 3. HERO — operative and loadout

HERO is the operative showcase, not a duplicate HOME dashboard.

- Present only heroes, weapons, skins, tiers, and actions that actually exist or are explicitly disabled as unavailable.
- Read names, descriptions, prices, models, and selection ids from the relevant definitions/registries rather than duplicating literals.
- The live Web hero stage uses the shipped hero GLB and equipped weapon/socket data where available; a painted portrait cannot substitute for verifying the actual rig.
- Hero selection, hero-tier progress, equipped weapon, and weapon-tier progress are separate regions. The weapon rack previews only the shared three-weapon registry, reports owned/locked state, and leaves purchases/upgrades to Armory.
- Celebration, entrance, and settled idle keep the equipped rifle visible on the authored `R_Hand` attachment; the sidecar carry/aim socket pose is blended rather than replaced by an unrelated prop.
- The stage owns its GPU resources only while visible and releases/pauses them before gameplay needs the engine context.
- Reduced-motion preferences apply to celebration and nonessential motion.
- A locked or unknown weapon id handed through a URL must not bypass ownership validation.

No per-hero stat upgrade should be displayed unless a real hero-stat contract exists. Weapon-tier and TECH HUNT blueprint UI must reflect authoritative Gameplay/Core/profile state, not invent progression in JavaScript.

## 4. THEATRE — registry-backed selection

The shell and engine read the same `WorldDefinition` registry and valid world ids. The current registry contains five theatre definitions; content availability and presentation still come from the definitions rather than a hard-coded card assumption.

The selected theatre leaves the shell as `qa_world`; the selected weapon leaves as `weapon`. The engine adapters validate both. Unknown ids fall back through the existing profile/registry rules rather than reaching a loader.

World card art is presentation, not proof that the world loaded. A successful selection check requires the authoritative handoff and actual selected-world gameplay/build evidence.

## 5. DEPLOY / LAUNCH — handoff, not a second loader

DEPLOY:

1. resolves the validated shell selection;
2. retires shell-only music/GPU resources through the existing adapters;
3. starts Godot with the already preloaded main pack and selection arguments;
4. enters the selected theatre's safe gameplay path;
5. preserves selection on supported retry/reload recovery.

The root shell must not create a second World manager, save file, weapon ownership service, or gameplay scene. Engine `FrontEnd`, `ProgressionService`, and `Main` retain their existing roles.

## 6. Engine stage responsibilities

| Stage | Current responsibility |
|---|---|
| `BOOT` | Read profile/preferences; indeterminate work indication, not fabricated percentages |
| `LOADING` | Threaded resource queue with real progress for the front end |
| `CHAPTER` | Intro/objective card and persisted seen flag |
| `DASHBOARD` | Deployment board and current profile/loadout summary |
| `HERO` | Operative selection and weapon rail |
| `WORLD` | Registry-backed engine theatre selection |
| `PRELOAD` | Load the gameplay scene with real resource progress |
| `Main` gameplay | Own session/combat composition after the handoff |

Only the designated gameplay transition changes the engine's main scene. Menu stages do not write combat, reward, or run state directly.

## 7. Persistence touchpoints

`ProgressionService` owns `user://progression.cfg`; UI reads and requests changes through its public behavior.

Current selection/profile concerns include:

- intro seen state;
- selected hero, weapon, and world ids;
- BP wallet, weapon ownership/equip, persistent per-weapon tiers, best results, and run counts;
- legacy/missing tier fallback to 1 and validated fallback for unknown or locked selections;
- future TECH HUNT secured blueprint/cache/milestone records through the same reviewed profile path.

A shell selection is not a second persistent profile. URL parameters are a handoff validated after the saved profile is read, not a mechanism to unlock content.

The future secure/death semantics are defined in `GAMEPLAY_DESIGN.md`; UI must display the result but never decide it independently.

## 8. Presentation and layout rules

- The current shipping composition is **landscape-only** for the shell and combat HUD. Portrait Web receives rotation guidance rather than an unmaintained alternate HUD.
- Menu/HUD sizing uses physical pixels and the current layout helpers; a phone is not treated as a scaled desktop.
- Safe-area measurement is shared through the existing UI layout utilities.
- The tested shell viewports are 844×390 and 667×375; current results still require executed checks.
- Painted plates and the 45-degree shape vocabulary belong to the current art direction. See [`ART_DIRECTION.md`](ART_DIRECTION.md) and measured reversals in [`DECISIONS.md`](DECISIONS.md).
- Chakra Petch is the display face and Rajdhani the interface face; use shared tokens rather than hard-coded alternatives.
- Primary actions remain readable and reachable without covering gameplay.

Do not reintroduce retired portrait/desktop arrangements or diagnostic chrome merely because an old UI specification contained them.

## 9. TECH HUNT UI insertion boundary

TECH HUNT 0 will need mission-card, tracker, cache-state, secure/death, and Extract/Endless presentation. These are UI views of Gameplay/Core state:

```text
authoritative mission/cache state
  → UI presentation and input intent
  → Gameplay/Core validates transition
  → confirmed state/save result
  → UI feedback
```

UI must not:

- mark a cache secured because a button was pressed;
- grant a blueprint or completion reward;
- decide which permanent records survive death;
- start Endless without the explicit approved transition;
- create a parallel navigation/session state machine.

Mission content shown before DEPLOY must identify the main objective, known reward, threat, and optional opportunity required by the gameplay design.

## 10. Verification

Relevant automated coverage includes:

- `tests/front_end_journey_smoke.gd` for engine journey order;
- `tests/menu_layout_smoke.gd` and related UI tests for current landscape layouts;
- data-source tests for registry-backed text/content;
- `tools/ui_shots.mjs` / `tools/ui_flow_shots.mjs` for real shell frames where applicable;
- `tools/operative_evidence.mjs` for EN/ID resting, entrance, settled-tier, rack, overflow, and equipped-rifle evidence;
- `tests/ads_input_smoke.gd` and `tests/weapon_tier_smoke.gd` for real engine input/profile/controller boundaries;
- `tools/web_qa.mjs` for browser boot, journey, selected-theatre, and gameplay handoff;
- `tools/web_loading_qa.mjs` for initial preload and interrupted recovery.

A captured frame needs the correct stage and nonblank content. Automated browser evidence does not establish physical touch comfort, Android behavior, final visual acceptance, or human comprehension of a mission.

When navigation, selection, persistence, or handoff changes, update this document and record the executed checkpoint in `VALIDATION.md` in the same development change.
