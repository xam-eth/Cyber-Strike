# Front-end journey

status: implemented. `tests/front_end_journey_smoke.gd` walks the whole
journey and `tests/menu_layout_smoke.gd` measures every screen at four
viewport sizes; both are green. This file describes what is in the tree and what
each stage actually does; where a claim could not be verified it says so.

Before this work the game booted straight into `scenes/main.tscn`. The journey
below did not exist at any point — no boot screen, no loading screen, no
dashboard, no selection screens — so every stage here is new code rather than a
re-skin.

```
BOOT ──> LOADING ──> CINEMATIC ──> CHAPTER ──> DASHBOARD ──> HERO ──> WEAPON
                         │                         ▲
                         └── (skipped once seen) ───┘
                                                   │
                       GAMEPLAY <── PRELOAD <── WORLD <──┘
```

`scenes/ui/front_end.tscn` is the project's main scene and the only object that
knows the order. A stage finishes by emitting `completed(next_stage, payload)`;
`FrontEnd` decides whether that request is legal and instantiates the target.
Stages are created once and shown/hidden, never freed.

---

## BOOT — `stage_boot.gd`

| | |
| --- | --- |
| Real work | `ProgressionService.load_profile()`, `AegisPreferences.read()` |
| Progress shown | **indeterminate sweep** |
| Advances | automatically, after the work and a 1.2 s minimum hold |

Two `ConfigFile` reads report no fraction — `ConfigFile.load` either returns OK
or it does not — so the bar states no percentage. The 1.2 s hold is a brand
beat for the wordmark, not a loading claim, and the caption reads
`READING PROFILE` rather than implying a quantity.

## LOADING / PRELOAD — `stage_loading.gd`

| | |
| --- | --- |
| Real work | `ResourceLoader.load_threaded_request` over a queue of resource paths |
| Progress shown | **real percentage**, `(completed + current fraction) / total` |
| Advances | when the queue drains |

One implementation serves both stages; the payload decides. `LOADING` fetches
the nine front-end textures and goes to `CINEMATIC`. `PRELOAD` fetches
`res://scenes/main.tscn` and changes scene.

If the queue is empty the stage does not animate a number: it swaps the bar for
the sweep and the caption reads `PREPARING`. A resource that fails to load
raises `push_error` and is recorded, so the failure is visible in the log rather
than hidden behind a completed bar.

The robot walk cycle is `loading_robot.ogv` (512×512, four frames, 8 fps,
looping) — Asset C as a real video, encoded by `tools/art/build_ui_video.py`
from the same four generated frames, with the same union crop and scale as the
sprite sheet. The sheet (`loading_robot_sheet.png`, 2048×512, four 512 px cells)
is still shipped and is the fallback: a device that cannot decode Theora gets
the same animation by moving an `AtlasTexture` region instead. `reduce_motion`
holds the first frame of whichever one is in use.

## CINEMATIC — `stage_cinematic.gd`

| | |
| --- | --- |
| Real work | a scripted 9.6 s sequence over the loading key art |
| Progress shown | **real playback position** (elapsed / duration) |
| Advances | on completion or on SKIP |

This plays `cinematic_opening.ogv` (1280×720, 24 fps, 9.58 s) when the video
loads — Asset F, encoded by `tools/art/build_ui_video.py` — and falls back to
the same beat composed in-engine: a slow push-in on `loading_keyart.jpg` under
four captions, 4 × 2.4 s. The key art stays behind the video as its poster
frame, so a device that cannot decode Theora sees the composed opening rather
than a hole. Either way it is skippable from the first frame, and the progress
bar is driven by whichever clock is running (`stream_position`, or elapsed
time). The video carries no captions: the stage overlays them as UI text.

The captions state the premise the game implements and nothing else: a training
facility, the Neon Frontier, inbound waves, Battle Points. `GAME_CONCEPT.md` is
explicit that this game is not story-driven, so a lore-dump intro would be a
misrepresentation of the product.

Finishing **or skipping** marks `intro_seen` on the profile. Skipping has to
count as seeing it: being dropped straight into the dashboard *is* what the
skip button is offering.

## CHAPTER — `stage_chapter.gd`

A title card: `CHAPTER 01 / FIRST LIGHT`, the objective the run measures, and a
CONTINUE action. It also advances on any tap.

## DASHBOARD — `stage_dashboard.gd`

Every number is read from `ProgressionService`, the single owner of the
persistent profile:

* Battle Points
* Best score
* Runs completed
* The loadout the next launch will use

There is no profile level, no streak, no daily reward and no second currency.
The save file holds five things and the dashboard shows those five things; a
sixth row would be decoration disagreeing with gameplay.

| Button | Action |
| --- | --- |
| DEPLOY | starts HERO → WEAPON → WORLD → PRELOAD |
| ARMORY | `ArmoryUi`, the in-game shop widget, spending real BP for real unlocks |
| SETTINGS | `AegisSettingsMenu`, writing `user://aegis.cfg` |
| REPLAY INTRO | clears `intro_seen` so the cinematic can be seen again without wiping anything |

## HERO SELECTION — `stage_hero_select.gd`

**One operative exists.** The rig in `assets/characters/hero/` is the only
skinned hero in the project, so one card is selectable and two slots are
disabled and labelled `IN DEVELOPMENT`.

The card deliberately carries no numeric stats. There is no hero data model —
no per-hero health, speed or damage — so any number printed here would be
decoration. The portrait is concept art, not the playable model
(`docs/ART_DIRECTION.md` §4).

## WEAPON SELECTION — `stage_weapon_select.gd`

All three weapons are real: the stats are read off the `WeaponDefinition`
resource at runtime, so the screen cannot drift from the weapon the player
fires.

| | Damage | Rate | Mag | Reload | Range | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Pulse Rifle | 18 | 5.0/s | 24 | 1.35 s | 45 m | starter |
| Nova Launcher | 34 | 0.8/s | 6 | 2.2 s | 32 m | splash 24 / 4 m |
| Arc Shooter | 20 | 2.0/s | 12 | 1.7 s | 30 m | chain 2 |

Locked weapons are **disabled** and priced from `ProgressionService.COSTS`
(pulse 0, nova 120, arc 250). Unlocking happens in the Armory, which is the one
place that spends Battle Points, so there is exactly one purchase path.

## WORLD SELECTION — `stage_world_select.gd`

**One theatre exists**: `scenes/worlds/neon_frontier.tscn`, the arena the game
loads. Two slots are disabled placeholders. LAUNCH hands PRELOAD
`{"scene": "res://scenes/main.tscn", ...}` plus the chosen weapon and world.

## PRELOAD — `stage_preload.gd` (same script as LOADING)

Fetches `main.tscn` with real progress, then `change_scene_to_packed`. This is
the only stage allowed to change scene.

---

## Persistence

`user://progression.cfg`, section `profile`. New keys, all validated on read:

| Key | Meaning | Fallback if edited to garbage |
| --- | --- | --- |
| `intro_seen` | cinematic played (or skipped) | `false` |
| `selected_hero` | last chosen hero | `exo_operative` |
| `selected_weapon` | last chosen weapon | `pulse_rifle` |
| `selected_world` | last chosen world | `neon_frontier` |

Ids are checked against `HERO_IDS` / `WEAPON_IDS` / `WORLD_IDS`, which list
only content that exists. A hand-edited save cannot make the front end offer a
hero, weapon or world the game cannot load, and a selected weapon that is not
unlocked falls back to the starter.

`Main._apply_saved_weapon()` applies the saved weapon **once, on boot**. It is
deliberately not on `profile_changed`, so a mid-run swap in the armory is not
overwritten by the saved choice.

## Safe area

Menu screens call `MenuStage.apply_safe_margins()`, which uses
`UiLayout.measure_safe_insets()` — the same function the combat HUD uses. The
pure form was extracted from `resolve_safe_insets()` so the two cannot drift,
which is the failure BUG 2 was about. Back navigation is wired to `ui_cancel`
with a per-stage `BACK_TARGET`, plus an on-screen BACK button on each selection
screen for devices with no Escape key.

## Layout at phone sizes

The project stretches a 1280x720 canvas with `aspect=expand`, so on a 390x844
phone the canvas is 1280x2770 at 0.305 scale: a button authored as 60 canvas
units reaches the screen 18 px tall and a 24 px gap lands at 7. Authoring in
canvas units is why the first pass read as broken rather than small. Every menu
size is therefore written in **physical pixels** and converted once, through
`MenuStage.px()`.

| `MenuStage` helper | What it is for |
| --- | --- |
| `px()` / `touch_height()` / `gap()` | physical pixels → layout units |
| `physical_min_size()` / `physical_separation()` | author a size once, re-convert it on resize or rotation |
| `card_line()` | card text that wraps to the card instead of widening the screen it lives in |
| `enforce_font_floor()` | nothing renders below `AegisTokens.MIN_PHYSICAL_FONT_PX` |
| `is_landscape()` | wider than 1.2x taller |
| `_size_both()` / `_orient_nodes()` | a portrait size and a landscape size for one control |
| `_make_card_list()` / `_orient_card_list()` | a card column in portrait, a card row in landscape |
| `_make_selection_split()` / `_orient_selection()` | the landscape layout: text beside the list |

Orientation is handled on `resized`, so rotating a device re-lays out the screen
without rebuilding it:

* **DASHBOARD** stacks wordmark → stats → actions in portrait (DEPLOY last,
  bottom-anchored, closest to the thumb). In landscape it splits: stats left,
  actions right. The stack is ~500 px tall and a landscape phone is 390 px,
  which is what put DEPLOY at y=444, 114 px past the bottom edge.
* **HERO / WEAPON / WORLD** scroll one card per row in portrait. In landscape the
  heading, the summary and the footer move into a fixed-width info column and the
  card list becomes a row that scrolls sideways beside it: a stacked header
  leaves the list ~130 px of a 390 px screen, and a 216 px card in a 130 px
  window is unusable. Locked placeholder slots travel with the real cards and
  stay disabled.

Measured, in physical pixels, from the browser's own rect report
(`?qa_menu=1`, touch insets `SAFE=8,8,28`) and from `menu_layout_smoke.gd`:

| Screen | 390x844 | 844x390 |
| --- | --- | --- |
| DASHBOARD | `DEPLOY=36,732,320x60` | `DEPLOY=427,278,381x60` (was `36,444` — off screen) |
> Node names in this table were recorded before the HERO card was named from the
> hero id; the card is now `ExoOperativeCard`, and the rects are unchanged.

| HERO | `ExoOperativeCard=36,132,318x190`, `BACK=36,736,153x56` | `ExoOperativeCard=346,54,340x190`, `BACK=36,282,144x56` |
| WEAPON | `PulseRifleCard=36,115,316x216`, `CONTINUE=201,736,153x56` | `PulseRifleCard=346,54,340x216`, `CONTINUE=191,282,144x56` |
| WORLD | `NeonFrontierCard=36,115,318x168`, `LAUNCH=201,736,153x56` | `NeonFrontierCard=346,54,340x168`, `LAUNCH` bottom right |

Every action is 56–60 px tall, and in every measurement above the lowest pixel
of the last action is at least 24 px clear of the safe area.

## Verification

`tests/front_end_journey_smoke.gd` instantiates the real `front_end.tscn`
and walks the journey, asserting at each stop that the stage is the one the
journey asked for, that no enabled button is inert, that no control crosses the
reserved edge, that absent content is disabled, and that `intro_seen` round-trips
through a real `ConfigFile`.

`tests/video_asset_smoke.gd` loads both videos the way the stages do and
compares the size and length the engine reports against
`game/assets/ui/video_manifest.json`, then checks that CINEMATIC and LOADING
really did select the video over their composed fallbacks.

In a browser build the same thing is measured from outside the engine:
`?qa_stage=CINEMATIC&qa_menu=1` logs which path ran and the stream position
(`stream at 2.02 s of 9.58 s`), and three frames taken 2 s apart differ across
89.8 % of the screen — the decoded video, on screen and moving, not a poster.
The same `?qa_menu=1` report prints each `VideoStreamPlayer` rect, which is how
the two aspect defects were caught (a 16:9 opening at `0,0,390x844` and a square
robot at `36,590,318x160`); both are cover rects now. A loading stage can only
be photographed via `?qa_stage=LOADING|PRELOAD` because with no targets it leaves
on the next frame.

`tests/menu_layout_smoke.gd` mounts the same scene once and then rotates
the live viewport through 390x844, 844x390, 360x640 and 1280x720 (sixteen
stage/size combinations, twelve of them reached by rotation) and asserts, in
physical pixels, that nothing outside a scroll container is drawn outside the
viewport, that no button is under the 56 px touch floor, and that every card list
can be scrolled to the end with the cards moving with it. It prints the same rect
report as `?qa_menu=1`, so the headless numbers and the browser numbers can be
read against each other.

### The card row could not be dragged on a phone

Godot 4.7's `ScrollContainer` pans on `InputEventMouseButton` /
`InputEventMouseMotion`, or on screen events that `Input` has emulated into mouse
events (`core/input/input.cpp:908`, gated on `emulate_mouse_from_touch`). This
project sets `pointing/emulate_mouse_from_touch=false` deliberately, because the
combat HUD reads raw screen events — so on a real phone the row did not move at
all, and the third weapon card (canvas x 1050-1390 in an 809 px window) could not
be reached by touch. `MenuStage` now reads `InputEventScreenTouch` /
`InputEventScreenDrag` itself, with a 10 px deadzone, and hands the container the
same deltas; it claims the release and re-runs `refresh_profile()` so a drag that
starts on a card does not also select it. The handler begins with
`if Input.is_emulating_mouse_from_touch(): return`, so if that project setting is
ever turned back on, this code steps aside instead of scrolling at double speed.

Measured in a served browser build, 844x390, `tools/qa_touch_scroll.mjs
--serve web --viewport 844x390 --drag 240`: before the change 24 `ScreenDrag`
events arrived with `rel=(-36.92, 0.0)` and the row moved **0.0 px**; after it
moves **396.0 px** whether the drag starts on a card or on empty space, the wheel
still moves it, and a tap still reaches the engine (`card pressed pulse_rifle`).
`menu_layout_smoke.gd` now drives the same gesture headlessly — 7 cases, each
scrolling as far as its range allows — and it reports 0 px against the unfixed
build, so it fails for the right reason.

## The roster is one list

The HERO, WEAPON and WORLD screens, the dashboard's loadout line, the
cinematic's theatre caption and `ProgressionService` used to each keep their own
copy of the same names -- the world's name in four places, the hero's in three.
They now read `HeroDefinition`, `WeaponDefinition` and `WorldDefinition`, and
the progression service's id lists and defaults are read *out of* those
registries rather than typed again beside them. The screens are built by
iterating the registries, so a second hero or world is one `.tres` file, not a
hunt through five scripts.

What the suite can prove about that is narrower than it looks, and it is worth
saying so: "the card prints the definition's name" is nearly a tautology when
both sides read one file -- rename it and they agree again. The check that can
actually fail reads each screen's *source* and fails if it spells out a roster
name or an art path as a literal, which is the copy that drifts. Two controls
were run and reverted: a `const` naming "EXO OPERATIVE" added back to the HERO
stage fails it, and a world whose `world_scene` is not inside `main.tscn` fails
the launch check. `data_source_smoke.gd` carries all of it, 186 assertions.

No hero or world stat block was created along the way. There is no per-hero
health, speed or ability in this project and no per-world wave count in data, so
a number in the resource would be decoration -- readable by the player, used by
nothing.

Results are recorded in `docs/asset-inspections/` once the suite has been run.
