# Menu layout at phone sizes — landscape overflow, and text that widened the screen

**Status: FIXED and measured** in a real WebGL browser build at 390×844 and
844×390, and by a new headless test at four viewport sizes. Below: the three
defects the measurements found, the fix, the numbers before and after, and what
is still NOT TESTED.

Everything here comes from numbers the engine reports, not from looking at a
picture: `?qa_menu=1` prints each visible control's rect in physical pixels
(`Menu QA: STAGE=… | CANVAS=… PHYSICAL=… STRETCH=… | SAFE=… | label=x,y,w×h`),
and `tests/menu_layout_smoke.gd` prints the same report inside a
`SubViewport` of a known size.

---

## 1. What was wrong

Three measured defects, all found on a 390×844 frame, plus one on 844×390.

**a. Text stretched the screen, not the other way round.** A `Label` with
autowrap sizes itself to its text and a container grows to fit its children, so
the card row forced its own labels wider than the display:

| Screen | Measured | Why |
| --- | --- | --- |
| HERO 390×844 | every label on the screen **753 px** wide | an `HBox` of three 240 px cards needs 752 px, so the container grew to 752 and every label filled it — on a 390 px display |
| WEAPON 390×844 | card 318×132, but its text ran to y≈587, ~100 px **past the bottom of its own card** | the card's minimum height was smaller than the text it holds |
| WORLD 390×844 | the 240 px plate left the text column **64 px**, so the blurb wrapped to 64×284 | same mechanism, sideways |

**b. Landscape overflowed the screen.** At 844×390 the canvas is 1558×720 at
0.542 stretch and the dashboard column is ~504 px tall:

```
Menu QA: STAGE=DASHBOARD | CANVAS=1558x720 PHYSICAL=844x390 STRETCH=0.542
  | SAFE=8,8,28 | … REPLAY INTRO=36,376,772x56 | DEPLOY=36,444,772x60
```

DEPLOY started 54 px *below* the bottom of a 390 px screen. Bottom-anchoring
cannot fix a column taller than the viewport it lives in.

WEAPON at 844×390 had the same shape: cards from y=118 to y=514 while the footer
sat at y=282 — the list window was ~130 px tall for cards that need 132+, so a
card could never be seen whole.

---

## 2. Fix

| File | Change |
| --- | --- |
| `scripts/ui/menus/menu_stage.gd` | `card_line()` — card text with `AUTOWRAP_WORD_SMART`, `SIZE_EXPAND_FILL` and a zero minimum width, so a container can shrink the text instead of the text stretching the container. `is_landscape()`, `_size_both()` / `_orient_nodes()` (a portrait size and a landscape size per control), `_make_card_list()` / `_orient_card_list()` (card column ↔ card row), `_make_selection_split()` / `_orient_selection()` (landscape: text beside the list). |
| `scripts/ui/menus/stage_dashboard.gd` | portrait stacks wordmark → stats → actions with DEPLOY last and bottom-anchored; **landscape splits** into a stats column and an actions column (`_apply_orientation()`), and the wordmark shrinks to 220×56. |
| `scripts/ui/menus/stage_hero_select.gd` | one card per row in a `VBox` (was three 240 px cards in an `HBox`); locked slots travel to the landscape row with the real card; portrait 130×170 → 100×100 in landscape. |
| `scripts/ui/menus/stage_weapon_select.gd` | card 132 → 216 px so its four text lines fit inside it; plate 150 → 110 px wide; weapon cards become a 340 px sideways row in landscape. |
| `scripts/ui/menus/stage_world_select.gd` | plate 240 → 120 px wide, so the blurb column is 184 px instead of 64 px; blurb goes through `card_line()`. |
| `tests/menu_layout_smoke.gd` (new) | mounts the real `front_end.tscn` in `SubViewport`s of 390×844, 844×390, 360×640 and 1280×720 and asserts, in physical pixels, that nothing outside a scroll container is drawn outside the viewport and no button is under the 56 px touch floor. |

Layout is re-applied on `resized`, so a rotation re-lays out the screen instead
of rebuilding it: every portrait/landscape pair is built once and the blocks are
moved between containers.

---

## 3. Measured after the fix

### Real WebGL build, 390×844 — `SAFE=8,8,28`, `STRETCH=0.305`

| Screen | Key rects | Clearance |
| --- | --- | --- |
| DASHBOARD | `ARMORY=36,596,154x56` `SETTINGS=202,596,154x56` `REPLAY INTRO=36,664,320x56` `DEPLOY=36,732,320x60` | DEPLOY bottom 792, **52 px** clear of 844 |
> Node names in this table were recorded before the HERO card was named from the
> hero id; the card is now `ExoOperativeCard`, and the rects are unchanged.

| HERO | `ExoOperativeCard=36,132,318x190`, labels 174 px wide (was 753), `BACK=36,736,153x56` `CONTINUE=201,736,153x56` | buttons bottom 792, 52 px clear |
| WEAPON | `PulseRifleCard=36,115,316x216` with all four lines ending inside the card (was 132, text 100 px past it), `BACK=36,736,153x56` `CONTINUE=201,736,153x56` | 52 px clear |
| WORLD | `NeonFrontierCard=36,115,318x168`, blurb `184x83` (was `64x284`), `BACK=36,736,153x56` `LAUNCH=201,736,153x56` | 52 px clear |

### Real WebGL build, 844×390 — `SAFE=8,8,28`, `STRETCH=0.542`

| Screen | Key rects | Clearance |
| --- | --- | --- |
| DASHBOARD | `PROFILE=36,120,381x16` (stats left) · `ARMORY=427,141,185x56` `SETTINGS=623,141,185x56` `REPLAY INTRO=427,210,381x56` `DEPLOY=427,278,381x60` | DEPLOY bottom 338, **52 px** clear of 390 (was y=444, off screen) |
| HERO | info column 300 px: `SELECT OPERATIVE=36,54,300x20`, `BACK=36,282,144x56` `CONTINUE=191,282,144x56` · cards `ExoOperativeCard=346,54,340x190`, `LockedHeroCard0=698,54,200x190`, `LockedHeroCard1=910,54,200x190` | 52 px clear |
| WEAPON | `BACK=36,282,144x56` `CONTINUE=191,282,144x56` · cards `340x216` at x=346 / 698 / 1050, scrolling sideways | 52 px clear |
| WORLD | `BACK=36,282,144x56` `LAUNCH=191,282,144x56` · `NeonFrontierCard=346,54,340x168`, locked `170x168` | 52 px clear |

### Headless probe (`menu_layout_smoke.gd`) — 33 assertions, all pass

The front end is **mounted once** at 390×844 and then the same live viewport is
**rotated** to 844×390, 360×640 and 1280×720, so 12 of the 16 stage/size
combinations go through a real `resized` on an open screen rather than a fresh
build. Every action is 56–60 px tall and nothing is drawn outside the viewport at
any of the four sizes. Smallest phone measured (360×640):
`DEPLOY=28,556,320x60` (bottom 616 of 640). Desktop 1280×720 takes the landscape
arrangement too: `DEPLOY=649,636,603x60` (bottom 696 of 720).

Each card list is also driven to the end of its range and the cards are checked
to have moved with it:

| Screen / size | scroll range | first card moves |
| --- | --- | --- |
| WEAPON 390×844 | 0 → 96 px down | x stays, y 125 → 29 |
| HERO 844×390 | 0 → 294 px sideways | x 346 → 52 |
| WEAPON 844×390 | 0 → 574 px sideways | x 346 → −228 |
| WORLD 844×390 | 0 → 234 px sideways | x 346 → 112 |
| HERO 360×640 | 0 → 32 px down | y 144 → 112 |
| WEAPON 360×640 | 0 → 300 px down | y 125 → −175 |
| WEAPON 1280×720 | 0 → 138 px sideways | x 346 → 208 |

---

## 4. Still NOT TESTED

| Gap | Why |
| --- | --- |
| A thumb drag on the landscape card row | **Engine-level blocker.** Godot gates touch panning on the platform: `scene/gui/scroll_container.cpp:237` returns early unless `DisplayServer::is_touchscreen_available()`, and the headless dummy display server never reports one. A synthetic `InputEventScreenDrag` moved the scroll by 0 px however it was sent — while a synthetic *click* pushed the same way does fire a Button's `pressed`, so input reaches the controls and it is specifically the touch-pan gate that is closed. The row's scroll range and the fact that scrolling moves the cards are measured (§3); that a finger produces the gesture is not. |
| Real device safe areas | No Android device and no emulator (no JDK, no Android SDK). Insets come from `UiLayout.measure_safe_insets()`, whose synthetic model reports 8/8/28 in touch mode; a real notch or gesture bar may report more. |
| A physical rotation | The probe resizes the live viewport, which is what a rotation does to the layout; it does not exercise the platform's `DisplayServer` orientation signal, the OS re-layout or a real sensor. |
| Touch scroll *momentum / deacceleration* | The same gate, plus it needs a device to observe. |
| 120 Hz / very tall (21:9) displays | Not measured. |
