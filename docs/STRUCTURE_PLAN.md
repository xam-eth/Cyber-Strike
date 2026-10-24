# Structure plan — production layout and the order it gets built

Companion to `docs/AUDIT_2026-10-21.md`. That document measures what exists;
this one proposes where it goes and in what order, with the gate that proves
each step.

---

## 1. What the research says, and what it does not

Sources are listed at the bottom. The parts that apply here:

- **Organise by feature, not by type.** Godot's own documentation recommends
  keeping assets close to the scenes that use them; Godot's maintainer (reduz)
  is blunt about it: *"large projects work best with data locality"* — one
  character's scene, script, meshes, textures and shaders belong in one folder,
  not spread across five. The same rule is the strongest consensus in Unreal
  project- organisation guides: type-based trees feel tidy at 50 assets and
  collapse at 5,000 because nobody can tell which texture belongs to what.
  This project has 368 files under `game/`, 8 domains and 26k lines of script —
  past the point where type-based grouping earns its keep.
- **Layers, with one-way dependencies.** GDQuest's write-up of how AAA teams
  structure Godot projects describes four folders whose *dependency direction
  is the point*: libraries → systems → content, with UI reading from systems
  and **never writing to them**. The payoff is not tidiness; it is that you can
  swap content without touching systems.
- **Boundaries that are only folders are not boundaries.** This is the one
  lesson that comes from outside game dev (Angular/Nx, NestJS): *"boundaries
  are purely folder-based with no real enforcement — easy to create unwanted
  dependencies between features."* Every source above that ships a modular
  layout ships a checker with it. So does this plan: `tools/check_architecture.py`
  fails the build when a module reaches into another module's internals.
- **Naming (Godot docs):** `snake_case` for files and folders, `PascalCase` for
  node names and `class_name`, third-party code in `addons/`. Case matters:
  the exported PCK filesystem is case-sensitive even though Windows is not.

What the research does **not** say: that any of this should be done in one
sweep. The consistent advice is the opposite — move to feature folders when
the project outgrows type folders, and keep the tree shallow.

---

## 2. The rules

Four layers. A file may import **downwards only**.

| Layer | Folder | May import | May never import |
| --- | --- | --- | --- |
| 0 — core | `core/` | engine, other `core/` | anything game-specific |
| 1 — systems | `systems/` | `core/` | `content/`, `ui/` |
| 2 — content | `content/<module>/` | `systems/`, `core/`, **`ui/design/`** | another module's internals, `ui/hud`, `ui/menus` |
| 3 — ui | `ui/` | `systems/` (read-only), `core/`, `ui/design` | — and nothing may import `ui/` from layers 0–2 |

Two extra rules, because they are where this project actually hurts:

- **A module exposes its `data/` folder and nothing else.** `content/weapon/data/weapon_definition.gd`
  is public; `content/weapon/runtime/*` is not. Cross-module talk goes through
  `data/` or through `systems/`.
- **UI reads, it does not drive.** Today `ui/touch_controls.gd` has a fan-out
  of 23 and reaches into gameplay. The split in phase 1 exists to make the HUD
  a *view* of state that `systems/` owns.

Naming: every file in a module is prefixed with the module name (`hero_`,
`weapon_`, `enemy_`, `world_`) so one search string finds a whole set; every
module has the same internal shape (`data/`, `runtime/`, `view/`) so a new
owner knows where to look in a module they have never opened.

---

## 3. Target tree

Files that already exist are marked *(now)*. Nothing moves in phase 0.

```
game/
  project.godot
  addons/                          # third-party only (Godot convention)
  core/
    audio/                         # audio_director (autoload), procedural_sfx, sfx   (now)
    input/                         # action -> intent mapping
    save/                          # ConfigFile profile IO
    scene/                         # scene transition + threaded load helper
  systems/
    combat/                        # damage resolution, projectiles, splash, chain
    movement/                      # player_controller, camera_rig                     (now)
    waves/                         # wave_director                                     (now)
    progression/                   # progression_service, reward_service, run_stats    (now)
  content/
    hero/
      data/hero_definition.gd + resources/heroes/*.tres                                (now)
      rig/character_visual.gd, hero.glb, animations/                                   (now)
      runtime/                     # per-hero behaviour (empty: there is no hero model yet)
    weapon/
      data/weapon_definition.gd + resources/weapons/*.tres                             (now)
      runtime/weapon_controller.gd, projectiles/                                       (now)
      effects/impact_burst, nova_shockwave, pulse_afterglow  (moved out of effects/ 2026-10-21)
      view/                        # muzzle flash, weapon model hookups
    enemy/
      data/enemy_definition.gd     # NEW: today shooter.gd/runner.gd hardcode their stats
      behaviours/shooter.gd, runner.gd                                                 (now)
      view/enemy_visual.gd                                                             (now)
    world/
      data/world_definition.gd + resources/worlds/*.tres                               (now)
      neon_frontier/world, geometry, components/                                       (now, to be split)
      kit/scifi_kit_library.gd                                                         (now)
    skill/                         # NEW shell + README: no skill system exists yet
  ui/
    design/aegis_tokens, aegis_theme, aegis_panel, aegis_button, ...                   (now)
    hud/layout, renderer, styles, widgets, editor                                      (now, to be split)
    menus/front_end.gd + stage_*.gd (one file per page)                                (now)
    settings/aegis_settings_menu, aegis_preferences                                    (now)
  scenes/                          # composition roots: main, player, arena, menus     (now)
  tests/                           # stays put; excluded from export (see gate G4)     (now)
```

Note the one deliberate exception to "move the `.tres` into the module":
`game/resources/` keeps working as a path because `data_source_smoke.gd` binds
it, and moving it is a mechanical, test-covered step in phase 3 — not a
day-one risk.

---

## 4. The two build paths

The rule the owner asked for — **web first, then device** — is a gate, not a
preference:

1. **WebAssembly preview** (`scripts/export_web_preview.sh` → `web/`).
   Answers: does it build, does it boot, does the module run without errors.
   CI already exports it, serves it and boots it in real Chromium.
2. **Android APK** (`scripts/setup_android_sdk.sh` → `scripts/export_android_debug.sh`
   → `exports/*.apk`). Answers: does it look right and hold frame rate on real
   hardware. The local scripts exist and are well specified (JDK 17, SDK 36,
   arm64-v8a only, no Gradle build); **CI has no Android job at all** (audit §9).

Phase 0 adds the missing job as its own workflow so a broken APK path cannot
block the web pipeline, and wires the same payload check into both.

---

## 5. Phases and gates

Every phase ends in a commit. A phase is done when all gates pass.

| Gate | Proves |
| --- | --- |
| G1 `gdlint game/` | style/parse clean |
| G2 `scripts/run_smoke_tests.sh` | 26/26 — no behavioural regression |
| G3 `tools/check_architecture.py` | no layer/module violations (vs the phase's baseline) |
| G4 `tools/check_payload.py <pck>` | no `res://tests`, no `res://scripts/qa` in the shipped payload |
| G5 web export + Chromium boot | the preview path still runs |
| G6 APK export | the device path builds (CI; needs SDK + templates) |

**Phase 0 — hygiene and enforcement, no code moves.**
Docs (audit + this plan) · architecture checker, enforced (baseline
emptied 2026-10-21, so any new violation fails dev_check and CI) · payload checker · export filters so tests and QA
stop shipping · Android CI workflow · 42 MB of root `.glb` into `source-assets/`
· root Markdown consolidated under `docs/` with an `ARCHITECTURE.md` entry
point. Gates: G1, G2, G4, G5.

**Phase 1 — break up the HUD.** *Partly done, 2026-10-21 (commits `8294bd4`,
`f092fd3`, `92312a2`, `cf9a86c`).*

Done: `scripts/ui/` split into `hud/`, `menus/`, `settings/` and shared
(`ui_layout.gd`, `widgets/`); `touch_controls.gd` 1,600 → 1,391 lines in four
slices — the touch dispatcher (`hud/hud_touch_input.gd`, 211 lines), the run
read model (`hud/hud_state.gd`), the modal panel behaviour (`hud/hud_menu_ui.gd`,
which now builds *and* drives the help, pause, results and settings cards), and
the F10 QA rig taken out of `scenes/main.tscn`.

Not done yet: `set_paused()`, the one slice left that reaches everything at
once — scrim, help, desktop hint, fire and skill buttons, HUD editor — and the
1,391 lines still on the facade. Gates: G1, G2, G3, G4, G5.

**Phase 2 — the world module.** *Done, 2026-10-21 (commits `16963bc`,
`0717456`, `4a829c3`, `4d7637c`).*

`neon_frontier_world.gd` 1,571 -> 404 lines. What is left in it is the
composition root: terrain, world bounds, lighting, spawn beacons and the shape
helpers. Everything else has a file:

| File | What | Lines |
| --- | --- | --- |
| `neon_frontier/material_kit.gd` | How a surface behaves (was two drifting copies) | 41 |
| `neon_frontier/geometry.gd` | The eight shapes every component is built from | 221 |
| `neon_frontier/scenes.gd` | The component scenes and world dimensions the zones share | 22 |
| `neon_frontier/components/props.gd` | Crystals, flora, rock, spawn gates, cover | 300 |
| `neon_frontier/zones/arena.gd` | Central arena, hazard markings, spawn gates | 255 |
| `neon_frontier/zones/routes.gd` | The routes between districts | 177 |
| `neon_frontier/zones/settlement.gd` | Outpost, extraction zone | 226 |
| `neon_frontier/zones/perimeter.gd` | Boss platform, defense perimeter | 288 |
| `neon_frontier/zones/wilds.gd` | Destroyed sector, alien landscape | 259 |

Still one file, and the next thing to split if it grows: `neon_frontier_asset.gd`
(1,355 lines), the component dispatcher, which has nine components left in it.

**Phase 3 — content modules.**
`hero/`, `weapon/`, `enemy/`, `skill/`, `effects/` folders with the shared
`data|runtime|view` shape; `.tres` files move next to their definitions; the
module-boundary checker switches from report mode to **enforcing**. Enemy stats
move out of `shooter.gd`/`runner.gd` into `enemy_definition.gd` (data-driven,
so a second enemy is a file, not a fork). Gates: G1–G5.

**Phase 4 — systems layer.**
Extract combat resolution and movement out of `player_controller.gd` and the
weapon runtime into `systems/combat` and `systems/movement`, so content
depends on systems and not the reverse. Gates: G1–G5, G6.

**Phase 5 — handover pack.** *Partly done, 2026-10-21 (commit `f10c211`).*

`docs/ARCHITECTURE.md` now exists and is live: it answers where everything
lives, what a file may import, and where a change goes. The module map inside
it is generated by `tools/module_map.py` from the same classification as the
boundary checker, and `dev_check.sh` fails when the two disagree — so the
document cannot drift the way a hand-written one does. The README points to it
first.

Not done yet: `CONTRIBUTING.md`, a per-module `README.md` for every module
(only `scripts/worlds/neon_frontier/` has one so far, and it is the template
the others should copy), and the owner onboarding checklist. Gate: a new reader
can find any subsystem from the README alone.

---

## 6. What is deliberately *not* planned

- **No rewrite.** Every phase moves or splits code; nothing is rewritten from
  scratch. Rewrites are how a 20 %-complete project loses the 20 % that worked.
- **No history rewrite** to strip the 169 MB of committed payloads. Stop
  committing new ones; the past is cheap to leave alone.
- **No new gameplay systems** during the cleanup. `skill/` is created as an
  empty, documented shell — inventing a skill system to fill a folder would be
  the exact fake-data failure this project has avoided so far.
- **No "delete the 48 unreferenced files" task.** They total 0.05 MB. They get
  removed in passing, not as a milestone.

---

## 7. Sources

- Godot manual, *Project organization* — snake_case files, PascalCase nodes,
  `addons/` for third-party, keep assets near their scenes.
- `github.com/abmarnie/godot-architecture-organization-advice` — scene-based
  folders, search-based navigation, shared vs. exclusive resources.
- GDQuest, *Modular Game Architecture: How AAA veterans structure Godot
  projects* — addons / systems / UI / content, one-way dependencies, UI reads
  and never writes.
- `r/godot`, reduz — *"large projects work best with data locality."*
- Unreal project- organisation guides (Diversion, Sarah Hyperdense) — feature
  folders over type folders; Game Feature Plugins enforce the boundary because
  the build system refuses an undeclared dependency.
- Angular/Nx and NestJS architecture write-ups — folder-only boundaries are not
  enforced boundaries; ship a checker with the layout.
