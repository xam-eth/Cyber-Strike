# BUG 2 — touch controls crowded the right and bottom edges

**Status: FIXED, and now measured in a real WebGL browser build** (not only in
the headless runner). Below: the root cause, the fix, the numbers, and what is
still untested.

---

## 1. Root cause

Two things stacked:

1. **Nothing in the HUD consulted the display safe area.** Every bottom-docked
   control was placed with `Control` anchors measured from the raw display
   rectangle. On a phone with gesture navigation the bottom ~28 px belongs to
   the system — the swipe zone eats the touch before the game ever sees it.
2. **The authored margins were themselves tiny.** FIRE started 8 px from the
   right edge and 14 px from the bottom on a short phone. Even on a display
   that reports no safe area, that is inside the thumb's natural overshoot.

There was no single wrong line; there was no safe-area code at all, and the
margins had been tuned against a desktop window.

## 2. Fix

| File | Change |
|---|---|
| `scripts/ui/aegis_tokens.gd` | `SAFE_BOTTOM_PX = 28`, `SAFE_SIDE_PX = 8`, `SAFE_INSET_NOISE_PX = 4` — the reserve the HUD must keep from the glass |
| `scripts/ui/hud_layout.gd` | `resolve_safe_insets()` merges `DisplayServer.get_display_safe_area()` with `get_display_cutouts()` (window px → layout units, sub-noise insets ignored) and floors each edge in touch mode. `_place_button()` / `_place_weapon_dock()` now measure from the usable edge, so the reserve applies to every docked control including the mirrored left-hand layout. Authored margins grew to match; the weapon and magazine stack vertically instead of side by side; the joystick pocket keeps its whole 72 px capture circle clear of FIRE. |
| `scripts/ui/widgets/hud_combat_feedback_ui.gd` | the status toast yields to real controls — under the magazine plate in compact Explore, and pulled left of EMP on landscape |
| `scripts/ui/touch_controls.gd`, `hud_encounter_ui.gd` | wire the reserve in and report it from the opt-in `?qa_touch` overlay |

The authored margins were **reduced** where the reserve now provides the same
clearance (the weapon dock's 12 px became 4 px + the 8 px reserve). The net
position on a display that reports nothing is unchanged; on one that reports a
notch or a gesture bar it gains real clearance. Nothing was moved arbitrarily.

## 3. Measured in the real browser build

`web/` could not be re-exported (`engine/web_templates/*.zip` are LFS
pointers), but `--export-pack` needs no template, so a `.pck` was built from
this branch and dropped next to the committed `index.wasm` / `index.js`:

```
python3 tools/web_preset.py ensure
godot --headless --path game --export-pack Web /tmp/webshot/index.pck
node tools/qa_avatar_shot.mjs --serve /tmp/webshot \
     --page "/index.html?qa_touch=1" --viewport 390x844
```

The `?qa_touch` overlay reports real `Control` rects in physical pixels:

### 390×844 — `SAFE=8,42,8,28`

| control | rect | bottom clearance | side clearance |
|---|---|---|---|
| FIRE | 162,574 202×202 | **68 px** | **26 px** (right) |
| ADS | 240,438 124×124 | 282 px | 26 px (right) |
| EMP | 240,302 124×124 | 418 px | 26 px (right) |
| JOY (movement pocket) | 14,666 144×144 | **34 px** | **14 px** (left) |

### 375×667 — `SAFE=8,42,8,28`

| control | rect | bottom clearance | side clearance |
|---|---|---|---|
| FIRE | 163,435 186×186 | **46 px** | **26 px** (right) |
| JOY | 9,495 144×144 | **28 px** | **9 px** (left) |

### 844×390 — `SAFE=8,42,8,28`

| control | rect | bottom clearance | side clearance |
|---|---|---|---|
| FIRE | 636,162 180×180 | **48 px** | **28 px** (right) |
| JOY | 64,234 128×128 | **28 px** | 64 px (left) |
| AMMO vs ARMORY | 384,228 112×54 / 350,106 186×56 | — | **66 px** vertical gap |
| AMMO vs EMP | 384,228 112×54 / 516,230 112×112 | — | **20 px** horizontal gap |

The reported top inset is 42 px here (a mobile browser chrome simulation the
headless runner never produces). Top-anchored controls — START, ARMORY, SWAP,
AMMO, PAUSE — sit exactly 30 px lower than in the headless runner for that
reason; bottom-docked controls match the headless measurements to the pixel.
That is the reserve behaving as designed, not a discrepancy.

Frames: [`touch-safe-margins-390x844-browser.png`](qa-frames/touch-safe-margins-390x844-browser.png) ·
[`375x667`](qa-frames/touch-safe-margins-375x667-browser.png) ·
[`844x390`](qa-frames/touch-safe-margins-844x390-browser.png)

## 4. Tests

* `tests/hud_safe_margin_smoke.gd` (new) — measures physical-pixel edge
  clearance and pairwise overlap on 390×844, 375×667, 844×390 and 667×375,
  including the status toast. **PASS on all four.** It failed with 5 real
  collisions before the fix (FIRE∩JOY twice, EMP∩AMMO, EMP∩ARMORY, START∩JOY).
* `tests/playability_hud_smoke.gd` — went from **5 failing assertions to 0**.
* `./scripts/run_smoke_tests.sh` — **21 passed, 0 failed**.

## 5. NOT TESTED

* **Android gesture navigation and real notch cutouts.** No device. The
  headless runner and this browser both report no bottom safe area, so only the
  28 px floor is exercised; a device reporting more must be checked there.
* **Thumb comfort on a physical phone** — reachability was preserved, not
  measured with a hand.
* The exported `.pck` was built by a `4.7.2.stable.custom_build` editor while
  `index.wasm` is `4.7.2.stable.official`. The payload boots and plays, but that
  is an observation on one build pair, not a supported combination.
