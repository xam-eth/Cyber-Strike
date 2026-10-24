# Gameplay Core Integration Baseline and Ownership Map

Date: 2026-10-24
Integration target: `arena/0b0dc2fd-cyber-strike`

## 1. Repository baseline

**VERIFIED** before integration:

- Repository: `/home/user/Cyber-Strike` (`xam-eth/Cyber-Strike`).
- Target branch: `arena/0b0dc2fd-cyber-strike`.
- Starting commit: `51f1dac382db4d60722dabee7826de14e53036bd`.
- Starting gameplay commit: `ad6a221dda7a426a409071258d432951b4ff061b`.
- Main/base commit: `2bd09b05cd665aa5ac8d877461aa1208d2115aae`.
- Working tree was clean before fetching and remained clean through the baseline audit.
- The clone began shallow. Full history was fetched before using merge-base or ancestry results; no local source branches were created or checked out.
- The pre-integration code CI (`40082660757`) had 24 passing and 3 failing smoke tests, with the old World static-call parse error. The new integration assignment authorizes reconciling that World implementation.

### Actual source branches

| Role | Actual branch | Tip inspected | Evidence and disposition |
|---|---|---|---|
| Gameplay Core | `arena/0b0dc2fd-cyber-strike` | `51f1dac382db4d60722dabee7826de14e53036bd` | Existing enemy definitions, Runner correction, vertical-slice test, gameplay contracts |
| World Design | `arena/e7fb25af-cyber-strike` | `71e40ba36028530ce72a43a398d8913ea2ebe1b2` | Real staged Frontier world, Vanguard Station, world selection, asset forge, world/UI/content dependencies |
| Character Content | `arena/9f883711-cyber-strike` | `9e0ddadcb73aec9bdc935bbc905ecdce23e33568` | Older direct tier-1 Tripo hero integration with idle/walk/run only |
| UI/UX Workflow | `arena/c08beb55-cyber-strike` | `f99fb06fbaa3943d83ccc63cd235df86cd69e19d` | Actual player shell, AEGIS/HUD/front-end work, landscape-only interaction, and UI tests; selected for reconciled merge |
| Former incorrect UI mapping — not a disposition | `arena/c8558858-cyber-strike` | `e5ba023c9a6e523b03fff2ca29889d0e76ec2d29` | Its `ExoconflictFlow` audit does not describe the actual UI source and was not used to accept or reject `c08beb55` |
| Tooling/already integrated | `arena/5257bce8-cyber-strike` | `224ec13eebf7d4f895b4c1ef231a66c9de1629d5` | Already an ancestor of Gameplay Core; no integration needed |

### Baseline implementation facts

- Startup was `res://scenes/ui/front_end.tscn`, not direct combat.
- `main.tscn` composed the hero, Neon Frontier, HUD, WaveDirector, rewards, and progression.
- Hero, weapon, world, and enemy definitions existed; file presence alone was not treated as runtime proof.
- The active hero was already a later optimized Tripo derivative with ten animation clips, not the older branch's three-clip direct integration.
- The active engine front end used authoritative content registries. The actual UI branch added a newer player shell and presentation workflow that had to be connected to—not replace—those contracts.
- Milestone upgrade selection/application and elites remained absent. They were not invented for integration completeness.

## 2. Dependency and ownership map

| Contract / shared file | Gameplay Core responsibility | Domain boundary and integration risk |
|---|---|---|
| `game/project.godot` | Engine/version, startup, input, autoload configuration | Shared infrastructure. Do not change engine/rendering to hide integration defects. |
| `front_end.tscn`, `FrontEnd`, `MenuStage` | Launch the real gameplay scene and report loading errors | UI owns navigation/presentation. Only one production flow may be authoritative. |
| `HeroDefinition`, `WeaponDefinition`, `WorldDefinition` | Stable ids and valid resource references | Character/World own content; UI reads definitions rather than maintaining another roster. |
| `ProgressionService` | Persist and validate selected ids, unlocks, wallet, and profile | Shared Core contract. Front-end and gameplay instances reconcile through the same profile path. |
| `main.tscn`, `main.gd` | Composition root, saved weapon application, run lifecycle, reward orchestration | Must preserve both world initialization order and explicit enemy definitions. |
| `WorldSelection` + world scene build gates | Ensure only the selected world builds | World owns layout/assets. Both registered world scenes are instanced; selection controls construction. |
| `CharacterVisual`, `player.tscn` | Connect the approved rig, weapon socket, muzzle, and combat animation state | Character owns model/rig/clips. Do not replace a ten-clip optimized hero with an older three-clip adapter. |
| `WeaponController`, projectile strategies | Fire, reload, swap, damage, and combat timing | Character owns weapon content/model; Core owns execution. Base resources are not run-upgrade state. |
| `EnemyDefinition`, `WaveDirector` | Resolve configured enemy ids/scenes and execute waves | No duplicate wave manager or per-scene preload table in the director. |
| `RunStats`, `RewardService`, `ProgressionService` | Provisional rewards, banking, retry/reset | UI must not fabricate score, BP, enemy deaths, or wave completion. |
| HUD and Results | Display authoritative state and send player intents | UI/UX owns layout; Core owns signal/data adapters and authoritative outcomes. |
| Export presets and payload checks | Keep tests and authoring-only inputs out of player builds | Shared integration tooling. Runtime staged assets must remain included. |

## 3. Source implementation assessment

### World Design — compatible and newer

**VERIFIED:** the source contained the real staged Frontier GLB, a second world (`vanguard_station`), registry/build-gate changes, world tests, asset provenance/forge tooling, and the static-call checker. Its code at `d8a6a38` had green Godot CI; tip `71e40ba` changed only an import report.

Integration was performed with a traceable merge. `main.tscn` required a semantic union, not a one-sided choice.

### Character Content — already superseded by a more complete implementation

**VERIFIED:** the old candidate and current hero share the Tripo source lineage documented by `HERO_RIG_PIPELINE.md` and the GLTF/Blender pipeline. The old candidate has 482,282 triangles and three clips; the integrated derivative has about 36k triangles and ten clips, including combat reactions and aim locomotion.

The old branch was not merged because doing so would downgrade the active hero and add an unused 24 MB source copy. Remaining provenance/mobile-budget work is tracked in issue #4; it is not evidence that the current hero is absent.

### UI/UX Workflow — actual source reconciled with the registry-driven engine journey

**VERIFIED:** the actual source is `arena/c08beb55-cyber-strike` / `f99fb06`, with 35 unique commits and 113 changed files from merge-base `3eb146e`. It supplies the HTML/CSS player shell, self-hosted fonts, AEGIS bezel and HUD/front-end changes, landscape-only layouts, and UI tests. The earlier `c8558858` / `ExoconflictFlow` mapping was incorrect and is not this branch's disposition.

The source shell sent DEPLOY directly to `qa_stage=GAMEPLAY`, bypassing the engine's HERO/WORLD selection. Integration retains the shell but hands off to `qa_stage=WORLD`, preserving both registered worlds, the saved-loadout journey, and `ProgressionService` without a second JavaScript roster. Landscape-only is retained as an explicit UI-domain decision documented in `docs/DECISIONS.md` §31; portrait/desktop arrangements and `HudPauseGesture` are intentionally removed with their obsolete test.

Source headless CI was 26/27: CANCEL DEFENSE did not complete and several tests logged out-of-tree `grab_focus()` errors. Those failures block a playability claim. The integration keeps Core lifecycle rules unchanged, guards deferred focus, and separates Retry → Pause → Cancel taps with actionable-panel assertions. Issue #8 and [`issues/UI_UX_WORKFLOW_INTEGRATION.md`](issues/UI_UX_WORKFLOW_INTEGRATION.md) carry the corrected remote/local scope; remote edit/closure of incorrectly mapped issue #5 was permission-denied.

## 4. Integration rules applied

1. Merge incrementally and preserve second-parent history where a compatible source exists.
2. Resolve shared files from actual consumers, not branch recency alone.
3. Preserve newer optimized/content-complete implementations over older direct adapters.
4. Do not import parallel managers or unused assets to simulate integration.
5. Keep domain-owned design defects in actionable issues.
6. Treat static, engine, browser, visual, and physical-device evidence separately.
7. Do not add upgrades, elites, new modes, economies, or hooks merely to satisfy a checklist.
