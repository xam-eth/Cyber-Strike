# EXOCOMFLICT: Stellar Horizon — mobile UI/UX delivery report

**Date** 2026-10-20 · **Branch** `arena/e8e7ed65-cyber-strike` · **Base** `224ec13`
**Engine** Godot 4.7.2.stable (pinned, `.godot-version`) · **Suite** 24/24 tests pass

Every number below was measured. Nothing is inferred from an inspector, from a
scene that loaded, or from a green test suite. Where a thing could not be
measured it is marked **NOT TESTED** or **BLOCKED**, never PASS.

| Status | Means |
| --- | --- |
| **PASS** | measured, and the measurement is in this report or in a doc it links to |
| **FAIL** | measured, and the measurement is wrong |
| **NOT TESTED** | not measured — no device, no encoder, no way to drive the input |
| **BLOCKED** | cannot be measured or built in this environment at all |

---

## 1. Audit — what the project actually contained

66 files added, 11 modified against `224ec13`. The audit came first: nothing was
redesigned until BUG 1 and BUG 2 were understood (Gate 0), and no system was
rewritten without a technical reason.

| Area | As found | Now |
| --- | --- | --- |
| Entry point | `project.godot` ran `scenes/main.tscn` — straight into gameplay, no front end at all | a 10-stage front-end journey is the main scene; gameplay is reached through it |
| Combat HUD | exists: `hud_encounter_ui.gd`, `touch_controls.gd`, `hud_layout.gd`, `aegis_tokens.gd`, `hud_combat_feedback_ui.gd` | kept. Retuned in physical pixels; safe-area reserve added; no rewrite |
| Safe area | **no code consulted it anywhere** | `UiLayout.measure_safe_insets()` is one function used by the HUD *and* the menus |
| Progression | `progression_service.gd` existed (BP, best score, runs, weapon unlocks) | kept and extended with `intro_seen` + the last loadout; still the only owner of the profile |
| Avatar / weapon | `character_visual.gd`, `weapon_controller.gd`, a 79-bone rig | kept. One real defect fixed in the outline pass (§2) |
| Art | no pipeline; `assets/ui/` held no shipping key art | `tools/art/build_ui_art.py` + nine shipping textures (5.3 MB) |
| Tests | 19 smoke tests | 24 — five new: `front_end_journey_smoke`, `hero_visibility_smoke`, `hud_safe_margin_smoke`, `menu_layout_smoke`, `ui_art_smoke` |
| Audio | `procedural_sfx.gd`, 14 synthesised sounds | unchanged |

---

## 2. BUG 1 — "hero not rendered in gameplay while the weapon is visible"

**Verdict: NOT REPRODUCED on the current build.** Full evidence:
[`docs/asset-inspections/HERO_VISIBILITY_QA_2026-10-20.md`](asset-inspections/HERO_VISIBILITY_QA_2026-10-20.md).

This is deliberately not written as "fixed": nothing in the path that draws the
hero was broken, so nothing there was changed. The gate that used to block the
claim — the headless runner has no rasteriser — was opened by driving the
committed `web/` payload in a pinned headless Chromium and scoring motion across
frames.

### What was checked (all measured, `hero_visibility_smoke.gd`, 54 assertions, PASS)

| Check | Result |
| --- | --- |
| model instance in the tree, all ancestors visible | `CharacterModel` under `ModelPivot / VisualRoot / Player / Main` |
| layers vs camera cull mask | layer 1 AND 1048575 ≠ 0 |
| skeleton + skinning | 79 bones, `skin=true`, bones move while a clip plays |
| **posed** silhouette (Σ wᵢ · pose · inverse(rest) · v over 23 310 vertices) | **1.79 m tall, 0.66 m wide**, feet on the floor, determinant +5.64 |
| near plane / frustum / occlusion | nearest corner 6.60 m vs 0.08 m near; in frustum; raycast clear |
| on screen at 5 aspects | inside the frame, **21 % of screen height** at 1280×720, 390×844, 375×667, 844×390, 667×375 |
| surface winding vs normals | 0 % disagreeing (calibrated against a `BoxMesh`) |
| material | opaque, alpha 1.00, albedo `hero_HERO_3d_model_basecolor.jpg` loaded |
| weapon relationship | socket 88 mm from `R_Hand`, muzzle 0.42 m ahead of the grip, both in frustum |
| placeholder | capsule exists and is **hidden** |
| states | re-measured in idle / ADS / hip fire / reload / defeated: 1.79 m every time |

The naive silhouette sum (dropping the inverse rest transform) reports a 2.6 m
hero from a 1.78 m model — recorded so nobody measures it that way again.

### The one real defect found on the way — and fixed

| | |
| --- | --- |
| **Root cause** | `ModelFitter.apply_overlay_material()` was called with `VisualRoot` as its root. `VisualRoot` already contains `WeaponSocket/MuzzleFlash/*`, so the near-black grow outline that gives the avatar a readable silhouette was also applied to five additive VFX meshes. An opaque `CULL_FRONT` shell around a muzzle flash paints a dark blob over the shot. |
| **File** | `game/scripts/player/character_visual.gd` |
| **Fix** | outline the fitted model and the fallback capsule only; the weapon model is spawned afterwards and never carried the outline |
| **Re-measured** | hero mesh keeps the outline; the five flash meshes report `overlay=null` |

Scale was not changed, the model was not swapped and no new character was
created before the cause was established, per the brief.

### Known measurement discrepancy (not a defect)

The §2 hand projection (34 % of frame height, one `?qa_camera` sample) and the
runtime measurement (21 %, same at all five aspects) are two camera states, and
both are now on record: the headless camera sits **6.59 m** from the player at
**73°** FOV, the sampled browser camera **4.77 m** at **66°**. A 1.79 m hero fills
18 % of the frame in the first and 29 % in the second (the measured 21 % / 34 %
are higher because an axis-aligned box projects taller than its own height when
the camera looks down at it); 21 % × 1.385 × 1.14 ≈ 33 %, which is where the 34 %
came from. Both sit inside the test's readable band (10 %–85 %) and neither
changes the verdict.

---

## 3. BUG 2 — touch controls crowded the right and bottom edges

**Status: FIXED, measured in a real WebGL browser build.** Full evidence:
[`docs/asset-inspections/TOUCH_SAFE_MARGIN_QA_2026-10-20.md`](asset-inspections/TOUCH_SAFE_MARGIN_QA_2026-10-20.md).

### Root cause

Two things stacked, and there was no single wrong line:

1. **Nothing consulted the display safe area.** Every bottom-docked control was
   anchored to the raw display rectangle. On a phone with gesture navigation the
   bottom ~28 px belongs to the system, which eats the touch before the game sees
   it.
2. **The authored margins were themselves tiny** — FIRE started 8 px from the
   right and 14 px from the bottom on a short phone, inside the thumb's natural
   overshoot even with no safe area reported.

### Fix and files

| File | Change |
| --- | --- |
| `scripts/ui/aegis_tokens.gd` | `SAFE_BOTTOM_PX = 28`, `SAFE_SIDE_PX = 8`, `SAFE_INSET_NOISE_PX = 4` |
| `scripts/ui/hud_layout.gd` | `resolve_safe_insets()` merges `get_display_safe_area()` with `get_display_cutouts()`, ignores sub-noise insets, floors each edge in touch mode; `_place_button()` / `_place_weapon_dock()` measure from the usable edge; weapon + magazine stack vertically; the joystick pocket keeps its whole 72 px capture circle clear of FIRE |
| `scripts/ui/widgets/hud_combat_feedback_ui.gd` | the status toast yields to real controls |
| `scripts/ui/touch_controls.gd`, `hud_encounter_ui.gd` | wire the reserve in, report it from `?qa_touch` |

Authored margins were **reduced** where the reserve now supplies the same
clearance (the weapon dock's 12 px became 4 px + the 8 px reserve), so the net
position on a display that reports nothing is unchanged.

### Measured — `?qa_touch=1`, 390×844, `SAFE=8,42,8,28`

| control | rect | bottom clearance | side clearance |
| --- | --- | --- | --- |
| FIRE | 162,574 202×202 | **68 px** | 26 px (right) |
| ADS | 240,438 124×124 | 282 px | 26 px (right) |
| EMP | 240,302 124×124 | 418 px | 26 px (right) |
| JOY | 14,666 144×144 | **34 px** | 14 px (left) |

Also measured at 375×667 and 844×390 (`hud_safe_margin_smoke.gd`, 246 assertions,
PASS). Every button stays 56 px or larger and remains in the thumb arc; nothing
was moved arbitrarily.

### Follow-on: the menus had the same class of bug

The same audit pass found the front-end screens overflowing on a phone. Fixed and
measured in [`docs/asset-inspections/MENU_LAYOUT_QA_2026-10-20.md`](asset-inspections/MENU_LAYOUT_QA_2026-10-20.md):

| Defect | Before | After |
| --- | --- | --- |
| HERO 390×844: three 240 px cards in a row grew the container to 752 px | every label on the screen **753 px** wide | labels 174 px, one card per row |
| WEAPON 390×844: card 132 px tall, four text lines | text ended ~100 px **past its own card** | card 216 px, all lines inside |
| WORLD 390×844: 240 px plate | blurb column **64 px**, wrapping to 64×284 | blurb 184×83 |
| DASHBOARD 844×390: a ~500 px column on a 390 px screen | `DEPLOY=36,444,772x60` — **54 px below the bottom** | `DEPLOY=427,278,381x60`, 52 px clear |

`menu_layout_smoke.gd` (new) mounts the real `front_end.tscn` in `SubViewport`s of
390×844, 844×390, 360×640 and 1280×720 — 16 stage/size combinations, all PASS.

Verified against the **shipped** artifact, not only a scratch export: the
committed `web/index.pck` (refreshed by CI after the layout commit) reports
`DEPLOY=427,278,381x60` at 844×390 — the same numbers as the scratch build, so
the payload in the tree carries the fix.

---

## 4. The journey — BOOT → … → GAMEPLAY

```
BOOT ──> LOADING ──> CINEMATIC ──> CHAPTER ──> DASHBOARD ──> HERO ──> WEAPON
                         │                         ▲
                         └── (skipped once seen) ───┘
                                                   │
                       GAMEPLAY <── PRELOAD <── WORLD <──┘
```

`scenes/ui/front_end.tscn` is the project's main scene and the only object that
knows the order; a stage asks for the next one and `FrontEnd` decides whether
that is legal. `front_end_journey_smoke.gd` (85 assertions, PASS) walks the whole
path on the real scene, including:

* `intro_seen` round-trips through a real `ConfigFile`, so the cinematic plays
  once and REPLAY INTRO is the only way to see it again without wiping a profile;
* every enabled button does something — no enabled button is inert;
* absent content is disabled (2 hero slots, 2 world slots, 2 locked weapons);
* the loadout the front end saves **reaches gameplay**: the test saves
  `arc_shooter`, boots `main.tscn`, and asserts
  `Player.weapon_controller.get_current_definition().weapon_id == "arc_shooter"`.

### No fake data — the rules the code enforces

| Rule | How it is enforced |
| --- | --- |
| No invented stats | weapon numbers are read off the `WeaponDefinition` resource at runtime; the hero card carries **no** stats because there is no hero data model |
| No fake heroes / weapons / worlds | slots are `LOCKED` / `IN DEVELOPMENT` and `disabled`; ids are validated against `HERO_IDS` / `WEAPON_IDS` / `WORLD_IDS` |
| No fake loading | BOOT shows an **indeterminate sweep** because two `ConfigFile` reads report no fraction; LOADING and PRELOAD show a real percentage because `ResourceLoader` reports one |
| One source of truth | `ProgressionService` owns BP, best score, runs, unlocks and the loadout; the dashboard shows exactly those five things |
| No mock-up passed as implementation | every measurement in this report comes from the shipped scenes, not from a mock |

---

## 5. Asset inventory

Nine shipping textures produced by `tools/art/build_ui_art.py` from generator
output in `game/assets/ui/generated/`. Resolution and format are what the engine
reports at runtime (`ui_art_smoke.gd`, 48 assertions, PASS), not what a tool
claimed. **Tool:** images generated with the session's image generator, then
processed (content-box crop, union crop across animation frames, resize,
spritesheet, palette audit) by `tools/art/build_ui_art.py` using Pillow.

| Key | File | Res | Format | Off-palette | Integration |
| --- | --- | --- | --- | --- | --- |
| Asset B — wordmark | `game/assets/ui/logo_wordmark.png` | 1024×256 | PNG | 1.2 % | BOOT, CINEMATIC, CHAPTER, DASHBOARD |
| Asset A — loading key art | `game/assets/ui/loading_keyart.jpg` | 1920×1080 | JPEG q90 | 0.0 % | LOADING, PRELOAD, CINEMATIC |
| Asset D — dashboard art | `game/assets/ui/dashboard_bg.jpg` | 1920×1080 | JPEG q90 | 0.2 % | DASHBOARD, HERO, WEAPON |
| Asset E — hero portrait | `game/assets/ui/portrait_hero.png` | 768×1024 | PNG | 0.2 % | HERO card |
| World plate | `game/assets/ui/world_neon_frontier.jpg` | 1600×900 | JPEG q90 | 0.0 % | CHAPTER, WORLD card |
| Asset E — weapon plate | `game/assets/ui/weapon_pulse_rifle.png` | 768×512 | PNG | 0.0 % | WEAPON card |
| Asset E — weapon plate | `game/assets/ui/weapon_nova_launcher.png` | 768×512 | PNG | 1.3 % | WEAPON card |
| Asset E — weapon plate | `game/assets/ui/weapon_arc_shooter.png` | 768×512 | PNG | 0.1 % | WEAPON card |
| Asset C — loading robot (fallback) | `game/assets/ui/loading_robot_sheet.png` | 2048×512 | PNG (4×512 px cells, 8 fps) | 0.0 % | LOADING, PRELOAD: used when the video is missing or `reduce_motion` is on |
| **Asset C — loading robot video** | `game/assets/ui/loading_robot.ogv` | 512×512, 8 fps, 4 frames, 0.50 s, 63 KB | OGV / Theora + silent Vorbis | frames audited before encoding | LOADING, PRELOAD — primary |
| **Asset F — cinematic opening video** | `game/assets/ui/cinematic_opening.ogv` | 1280×720, 24 fps, 230 frames, 9.58 s, 1.57 MB | OGV / Theora + silent Vorbis | frames audited before encoding | CINEMATIC — primary |

Total **6.8 MB** on disk (5.2 MB of textures + 1.7 MB of video). Every texture is loaded through
`MenuStage.try_texture()`, which returns `null` for a missing file, so a lost
plate is a visual regression rather than a boot failure. Palette audit: 9/9
within palette; the audit is HSV-only and says nothing about composition or
quality, and nobody has *looked* at these images — there is no image display in
this environment.

### How the video blocker was cleared

§8 item 5 recorded "no encoder exists in this environment". That changed: the
static ffmpeg 7.0.2 binary shipped inside the `imageio_ffmpeg` wheel on PyPI
(`imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2`, built with
`--enable-libtheora --enable-libvorbis`) is an encoder that can actually be
fetched here, and `modules/theora/` is present in the Godot 4.7.2 source. Both
videos are therefore real files on disk, decoded by the engine, and measured:

* **Asset C** is the sheet's own four frames at their own cadence (8 fps,
  0.5 s, looping), so the video and the sprite-sheet fallback are the same
  animation and the fallback is not a downgrade.
* **Asset F** is a 9.58 s push-in on the key art. It carries **no** baked-in
  text: all four captions stay UI text, so they remain translatable, legible at
  any size and skippable.
* Both stages keep their non-video path. A device that cannot decode Theora, or
  a player with `reduce_motion` on, gets the sprite sheet / the composed
  push-in — degradation, never a blank screen.

Nothing in this report claims a video plays until a measurement says so; see
§7 for the in-engine and in-browser rows.

### Three video defects the browser check caught

All three were invisible to the test suite and to the inspector; each was found
by a number from a real browser build.

| # | Defect | How it was caught | Fix |
| --- | --- | --- | --- |
| 1 | The intro ended on its first frame: `_total` was taken from `VideoStreamPlayer.stream_length`, which reads **0.00** until the decoder opens the file, so `clampf(_elapsed / maxf(_total, 0.001))` saturated immediately | browser log printed `playing the encoded opening (0.00 s)` and the stage jumped to CHAPTER within the 6 s settle | `stage_cinematic.gd`: start from the authored 4 × 2.4 s and adopt the measured length in `_process` once it reports > 0.1 s |
| 2 | The opening was smeared to the screen's aspect: `_layout_video()` sized the player from `VideoStream.get_size()`, which **does not exist** in this build (`has_method("get_size")` is false on `VideoStreamTheora`) — the call threw, the player kept the full stage rect, and `expand` stretched 16:9 into 390×844 | QA rect report printed `OpeningVideo=0,0,390x844` | `stage_cinematic.gd`: layout from the decoded `get_video_texture()` size with an authored 16:9 default, retried until the first frame arrives. Now `-555,0,1500x844` at 390×844 and `0,-42,844x475` at 844×390 |
| 3 | The loading robot was twice as wide as tall: the square 512×512 loop filled a 318×160 column rect while the sprite-sheet fallback drew it 160×160 | QA rect report printed `RobotVideo=36,590,318x160` | `stage_loading.gd`: `size_flags_horizontal = SIZE_SHRINK_CENTER`, so the player keeps its 160×160 minimum. Now `115,590,160x160` |

Two QA hooks had to be added to get those numbers: `report_menu_rects()` now
includes `VideoStreamPlayer` (previously Buttons, Labels and ProgressBars only),
and `?qa_stage=LOADING|PRELOAD` now deep-links with the same target list the
real journey passes — with an empty payload a loading stage leaves on the next
frame and cannot be photographed at all.

---

## 6. UI/UX changes

| Screen / system | Change |
| --- | --- |
| Combat HUD | sizes in physical pixels; safe-area reserve; weapon + magazine stacked; toast yields to controls; mirrored left-hand layout honours the reserve |
| BOOT | indeterminate bar; reads the real profile and preferences |
| LOADING / PRELOAD | real percentage from `ResourceLoader`; the robot **video** loops (0.5 s), sprite sheet if it is missing or `reduce_motion` is on |
| CINEMATIC | the **opening video** (9.58 s) with the composed push-in as fallback; four captions as UI text, skippable from frame 1, plays once |
| CHAPTER | title card, advances on tap |
| DASHBOARD | five real numbers, four working actions, bottom-anchored DEPLOY, two-column in landscape |
| HERO | one selectable card + two disabled slots, no invented stats, portrait labelled as concept art |
| WEAPON | real stats off the resource, locked weapons priced and disabled, unlocking only in the Armory |
| WORLD | one real theatre, two disabled slots |
| Settings | `AegisSettingsMenu`, writes `user://aegis.cfg` |
| Typography | every font rendered at ≥ `MIN_PHYSICAL_FONT_PX` on the real screen |
| Palette | `docs/ART_DIRECTION.md`; 9/9 textures on palette |

---

## 7. QA table

`GODOT_BIN=/usr/local/bin/godot SKIP_VERSION_CHECK=1 ./scripts/run_smoke_tests.sh --no-import`
→ **26 passed, 0 failed** (`exports/test-logs/summary.txt`).

| Test | Assertions | Status | What it proves |
| --- | --- | --- | --- |
| `front_end_journey_smoke` | 85 | **PASS** | the whole journey, incl. the saved weapon reaching gameplay |
| `hero_visibility_smoke` | 54 | **PASS** | BUG 1: the hero is skinned, in frustum, unoccluded, on screen |
| `hud_safe_margin_smoke` | 246 | **PASS** | BUG 2: every docked control clears the reserved edge at 3 viewports |
| `menu_layout_smoke` | 47 | **PASS** | nothing outside the viewport, no button under 56 px, every card list scrolls to the end and moves its cards, and a synthetic thumb drag scrolls every list as far as its range allows (7 stage/size cases) — at 4 sizes, 12 of the 16 combinations reached by rotating a live screen |
| `data_source_smoke` | 186 | **PASS** | one source of truth: the weapon card, the player scene's controller and the `.tres` files agree; the hero and world registries, `ProgressionService`, the HERO/WORLD cards, the dashboard and the cinematic caption are all the same list; the world a card advertises is inside the scene LAUNCH loads; and no screen spells out a roster name of its own |
| `ui_art_smoke` | 48 | **PASS** | all nine textures load in-engine at the documented size |
| `video_asset_smoke` | 17 | **PASS** | both OGVs decode in-engine: measured sizes 512×512 / 1280×720, lengths 0.50 s / 9.58 s matching the manifest, playback advances, both stages bind the file, a missing file loads as `null` instead of crashing |
| `hero_rig_smoke`, `weapon_system_smoke`, `arc_weapon_smoke`, `wave_director_smoke`, `shooter_enemy_smoke`, `runner_standoff_smoke`, `enemy_visual_smoke`, `effects_smoke`, `combat_feedback_smoke`, `exploration_flow_smoke`, `progression_smoke`, `reward_loop_smoke`, `playability_hud_smoke`, `pause_gesture_smoke`, `hud_editor_smoke`, `ui_settings_smoke`, `neon_frontier_world_smoke`, `arena_blockout_smoke`, `audio_smoke` | (single summary line each) | **PASS** | no regression from this session's work |

Browser measurements (headless Chromium + SwiftShader WebGL 2, via
`tools/qa_avatar_shot.mjs`) back BUG 1, BUG 2 and the menu layout numbers
above, and carry the video evidence:

| Browser check (390×844 unless noted) | Result | Status |
| --- | --- | --- |
| CINEMATIC: which path ran | log `MenuCinematic: playing the encoded opening`, no error, no stall warning | **PASS** |
| CINEMATIC: does it advance | log `MenuCinematic: stream at 2.02 s of 9.58 s` | **PASS** |
| CINEMATIC: is it on screen | 3 frames 2 s apart → 89.8 % of pixels change, motion bbox = whole 390×844 frame | **PASS** |
| CINEMATIC: is it distorted | `OpeningVideo=-555,0,1500x844` at 390×844 and `0,-42,844x475` at 844×390 — cover rects at the video's own 16:9, centred and clipped | **PASS** |
| LOADING: which path ran | log `MenuLoading: playing the encoded walk cycle` on the real boot flow | **PASS** |
| LOADING: is it laid out | `RobotVideo=115,590,160x160` — square, centred, on screen | **PASS** |
| LOADING: does the loop animate between two captured frames | the stage is on screen ~0.3–0.6 s and its fade-in dominates those frames; the loop's own frame-to-frame change could not be isolated | **NOT TESTED** |
| The committed `web/` payload, served as-is | `--serve web`: the opening plays (`stream at 2.01 s of 9.58 s`) with `OpeningVideo=-555,0,1500x844` | **PASS** |
| Shell `fileSizes` match the files on disk | `python3 tools/verify_web_build.py web` | **PASS** — and it now *fails* on a stale or missing `fileSizes` map (both cases tested by breaking the file on purpose). Without the map the loader's percentage is computed from a size that is not there, which is the fake-progress rule, in the loader |
| A touch drag on the card row, in the served `web/` payload | `node tools/qa_touch_scroll.mjs --serve web --viewport 844x390 --drag 240` → from a card `618 -> 378 px` (**396.0 px**), from empty space **396.0 px**, wheel still moves, a tap still reaches the engine (`card pressed pulse_rifle`) | **PASS** |

---

## 8. One source of truth for hero, weapon and world data

The brief asked for one place where hero, weapon, world, resource and
progression data lives. Auditing it turned up three separate copies of the same
facts, in three different shapes:

| Fact | Where it lived | What that allowed |
| --- | --- | --- |
| Weapon numbers | `stage_weapon_select.gd` (printed on the card) and `player.tscn`'s `weapon_definitions` (what actually fires) | a card quoting 18 damage for a gun that fires 20 |
| Hero name | the HERO card, `stage_dashboard.gd`'s loadout line, and `ProgressionService.HERO_IDS` | a rename that catches two of the three |
| World name | the WORLD card, the dashboard, the cinematic's theatre caption, and `ProgressionService.WORLD_IDS` | the same, in four places |

Weapons were already fixed this session (`WeaponDefinition` is now read by both
sides). Heroes and worlds had no resource at all: the names were string literals
and the ids were a hand-typed array.

**What changed.**

- `game/scripts/progression/hero_definition.gd` and `world_definition.gd` — new
  `HeroDefinition` / `WorldDefinition` resources with the same registry shape as
  `WeaponDefinition` (`DEFINITION_PATHS`, `DEFINITION_IDS`, `load_definition()`,
  `load_all_definitions()`), plus `.tres` files under `game/resources/heroes/`
  and `game/resources/worlds/`.
- `ProgressionService.HERO_IDS` / `WORLD_IDS` / `WEAPON_IDS` and the three
  `DEFAULT_*` ids are now *read from* those registries instead of being typed
  again. Adding a hero is one `.tres`; every screen and the save system pick it
  up, and a save naming an id that was deleted falls back to the registry's
  default instead of to nothing.
- The HERO and WORLD cards are built by iterating the registries, so the name,
  blurb, status line, portrait and plate come from the resource. The locked
  placeholder slots number themselves from the roster size (`SLOT 02`,
  `THEATRE 02` today).
- `stage_dashboard.gd`'s `_hero_name()` / `_world_name()` no longer contain an
  `if id == DEFAULT: return "EXO OPERATIVE"` branch; they read the definition,
  exactly as `_weapon_name()` already did.
- The cinematic's theatre caption is built at runtime from `WorldDefinition`.
- `WorldDefinition.world_scene` declares which arena the card is selling, and
  LAUNCH's payload names `FrontEnd.GAMEPLAY_SCENE` rather than a third copy of
  `res://scenes/main.tscn`.

**What is deliberately *not* in them.** No per-hero health, speed or ability
block and no per-world wave count or difficulty: neither has a model in this
project, and a number a player can read that nothing in the game uses is exactly
the decorative stat the brief rules out. The hero's portrait and the world's
plate are paths to real files, and `is_valid_definition()` refuses a definition
whose art does not exist on disk.

**How drift is caught.** "The card prints the definition's name" is close to a
tautology when both sides read the same file, so the suite checks the thing that
can actually fail: `data_source_smoke.gd` reads each screen's *source* and fails
if it spells out any roster name or art path as a literal. Two negative
controls, run and then reverted: putting `const CONTROL_LITERAL :=
"EXO OPERATIVE"` back into the HERO stage fails it ("'Exo Operative' is not
spelled out in the screen"), and pointing a world's `world_scene` at a scene
`main.tscn` does not contain fails the launch check. The suite went from 142 to
186 assertions; the web payload was re-exported and the HERO, WORLD and
DASHBOARD screens were re-measured in a browser build
(`ExoOperativeCard`, `EXO OPERATIVE`, `NeonFrontierCard`, `NEON FRONTIER`,
`STATUS  OPEN`, `THEATRE 02`).

---

## 9. Remaining issues

| # | Issue | Status |
| --- | --- | --- |
| 1 | **Android / any real GPU.** No device, no JDK, no Android SDK, and the sandbox has no GL/EGL/Vulkan library. Every render claim goes through SwiftShader in headless Chromium. | **NOT TESTED** |
| 2 | **A full `web/` re-export could not be run here.** `engine/web_templates/*.zip` are 133-byte LFS pointers, so the export template cannot be unpacked; `--export-pack` needs no template and was used instead. CI *does* refresh `web/index.pck` on push, and the refreshed payload was measured this session (§3) — but the refresh is CI's output, not a local export. | **PASS** (payload measured) / **NOT TESTED** (local re-export) |
| 3 | **A physical rotation.** The probe resizes a live viewport — which is what a rotation does to the layout — and 12 of 16 stage/size combinations are measured that way. Not exercised: the platform orientation signal, the OS re-layout, a real sensor. | **PASS** (layout) / **NOT TESTED** (device) |
| 4 | **Touch-drag scrolling of the card row — a real defect, found and fixed.** Godot 4.7's `ScrollContainer` pans on `InputEventMouseButton`/`InputEventMouseMotion` only, or on screen events *that `Input` has emulated into mouse events* (`core/input/input.cpp:908`), and this project sets `pointing/emulate_mouse_from_touch=false` on purpose so the combat HUD can read raw screen events. On a phone that left the row undraggable and the third weapon card (canvas x 1050–1390 in an 809 px window) unreachable. `MenuStage` now handles `InputEventScreenTouch`/`ScreenDrag` itself (10 px deadzone, guarded by `Input.is_emulating_mouse_from_touch()` so it self-disables if that setting is ever turned back on), claims the release, and re-runs `refresh_profile()` so a drag never also selects the card it began on. Measured before → after in a real browser at 844×390: **0.0 px → 396.0 px** from a card and from empty space, wheel and tap unaffected. | closed |
| 5 | **Assets C and F as video.** Was **BLOCKED** (no encoder); the ffmpeg binary inside the `imageio_ffmpeg` wheel on PyPI cleared it. Both videos are decoded in-engine and played in a browser build this session. Residual: the loading loop's own frame-to-frame motion is not isolated (§7), and no human has watched either video — the audit is numeric. | **PASS** (decode + playback) / **NOT TESTED** (frame isolation, human review) |
| 6 | **Real device safe areas.** Insets come from `UiLayout`'s synthetic model (8/8/28 in touch mode); a real notch or gesture bar may report more. | **NOT TESTED** |
| 7 | **Frame rate, shader compilation on real drivers, thermals.** | **NOT TESTED** |
| 8 | The 34 % vs 21 % hero-height figure — **reconciled**: two camera states (6.59 m / 73° headless vs 4.77 m / 66° in the browser sample), both inside the readable band. Recorded in the BUG 1 doc. | closed |
| 9 | **The shot tool waited on the wrong line.** `tools/qa_avatar_shot.mjs` blocked up to 240 s for `Encounter:`, a gameplay-only banner, so every *menu* screenshot was taken ~4 minutes after boot — long after the state it was meant to capture (caught when three cinematic frames came back byte-identical). It now waits for any engine banner, and the run dropped from ~245 s to ~15 s. Any menu screenshot taken before this fix should be re-taken. | closed |
| 10 | `ObjectDB` / `CanvasItem` RID leak warnings at exit in the menu tests (18 RIDs, 36 instances) — reported by Godot after `quit`, stages are freed by the harness. Not investigated. | open, cosmetic |
| 11 | **Headless touch-drag testing was written off as impossible** ("a synthetic drag moves 0 px"). It is not: the 0 px was the defect itself. `push_input` + synthetic `InputEventScreenDrag` works headlessly once the game handles the events. Two traps for anyone touching `_input` in a stage: an overriding `_input` silently disables the base class's (a stage's QA counter switched the fix off until `super._input(event)` was added), and `ScrollBar.value` can only reach `max_value - page`, so a drag that lands on the end of a short list looks like a failure unless the assertion is written against `max_value - page`. | closed |
