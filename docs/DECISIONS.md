# Decisions

The rules this project has paid for, and the reasoning that keeps them. One
file, because the alternative — nine dated audit and verification reports, four
of which contradicted each other by the end — is how a rule gets re-litigated
six months later by someone reading a stale one.

Everything here was measured against a real build (a headless Godot run, a
captured frame, or a reference lobby at a stated resolution). Anything that was
only an opinion is not here.

## 1. Architecture

1. **`FrontEnd` is the only place that knows the journey.** Stages ask for the
   next one by name; `FrontEnd` decides whether that is legal. Journey:
   `BOOT → LOADING → CHAPTER → DASHBOARD → HERO → WORLD → PRELOAD → gameplay`.
2. **There is no WEAPON stage.** It was three weapon chips around a 3D rifle:
   a section of a loadout, not a page. The rail lives on `HERO`, next to the
   operative who carries it.
3. **Data comes from the registries.** `HeroDefinition`, `WeaponDefinition` and
   `WorldDefinition` own names, prices, models and stats. A screen that prints a
   literal where a definition exists is a screen that will lie the first time
   the definition is tuned — `tests/data_source_smoke.gd` walks the rendered
   text and compares it with the resource.
4. **Content the project does not ship is disabled, not faked.** Placeholder
   slots say `IN DEVELOPMENT`, are never selectable, and never hand an id to a
   loader.
5. **A stage owns its layout and nothing else.** Saved state belongs to
   `ProgressionService`; a stage reads it on entry and on `profile_changed`.

## 2. Layout rules, in physical pixels

6. **`Control.PRESET_BOTTOM_WIDE` pins the control's *top* to the bottom edge.**
   A dock authored with it drew entirely off-screen. Place a box with
   `BoxContainer.ALIGNMENT_END` inside a full-rect host instead.
7. **A container inside a plain `Control` keeps whatever rect it was last
   given.** Manual placement re-read a stale minimum even with a deferred
   re-run; container hosts the engine lays out itself are the reliable fix.
8. **A `Label`'s minimum width is its text width unless it wraps.** One such
   label stretches its whole row and pushes every sibling past the viewport —
   the 360 px top bar measured 706 px wide because of it.
9. **An ellipsised `AUTOWRAP_WORD_SMART` label collapses to its longest word**
   when the row is tight: a wallet chip drew as an empty 40 px box. Keep figures
   on one unwrapped line and put the width in `physical_min_size`.
10. **`SIZE_SHRINK_CENTER` on a panel inside a `VBox` collapses it to a sliver.**
    Use `SIZE_EXPAND_FILL`.
11. **Everything is authored in physical pixels** (`MenuStage.px()`,
    `physical_min_size()`, `physical_separation()`) and re-authored on resize,
    because the canvas is letterboxed and a phone is not a small desktop.
12. **Portrait is a first-class layout, not a squeezed landscape.** Both are
    built, both are photographed, both are asserted.
13. **`clip_text` is what takes a label out of its minimum width.** Wrapping
    only changes the height a label reserves; an ellipsised one-line caption
    still reports its full text width as its minimum unless `clip_text` is set,
    and one such caption made a 360 px page 340 px wide. A Button is worse: its
    minimum width is its own `text`, which is how two 170 px tabs became a 348 px
    row on a 320 px boundary.
14. **`HBoxContainer` and `VBoxContainer` are two classes, not one with a
    `vertical` flag.** Assigning `vertical` silently does nothing; the engine
    then lays out the row in the other direction, and the failure reads as a
    layout bug rather than a typo. Reparent into the right container instead.
15. **`gdparse` does not catch duplicate locals, undeclared identifiers or a
    field typed as the wrong container.** All three reached CI while
    `dev_check.sh` was green, because those are type-resolution errors and
    `gdparse` only parses. Trust the headless run for anything a type checker
    would catch.
16. **A Button does not scale its icon texture.** `icon_max_width` and
    `expand_icon` change nothing for these SVG assets; a TextureRect sized in
    physical pixels is the reliable way to draw a glyph at a given size — and a
    full-rect child of a Button draws *over* its text.
17. **The boot overlay is not a screen.** A wordmark, a progress bar and a
    sentence about the engine are a developer's view of a download. The overlay
    in the web shell is a dark frame that fades when the engine is ready, and
    the landing page at the repository root is a dark frame with one hairline
    and no words at all. Not one engine string is legible at launch — "half
    removed" looks worse than not started.

    That includes the browser's own chrome: the export shell's `<title>` is
    exactly `$GODOT_PROJECT_NAME`, and its bar carries no "Web Preview" and no
    "Single-thread WebGL 2 build" chip. `project_doctor` asserts both by value,
    because a title is the one string the browser paints before any of our
    pixels exist.
18. **The primary action is the bottom row** — nearest the thumb — which is the
    order Apex's READY bar and Free Fire's start tile use. Tabs sit above it.

## 3. Art and type

19. **Chakra Petch for display, Rajdhani for the interface.** Both are squared,
    condensed, and built for uppercase rows; mixing a geometric face with a
    humanist one is what made the old menus read as a form.
20. **Minimum 16 physical pixels for supporting text, 64 for a touch target.**
    Measured against CoD Mobile (body 22 px at 1568×882), Apex (26 px), Free
    Fire (tabs 15 px, START ≈ 13 % of screen height).
21. **Never pure black or pure white**; the palette lives in `AegisTokens` and
    nothing hard-codes a colour.
22. **The character is the subject — on OPERATIVE.** The showcase page gives the
    operative the centre and a band that is a share of the screen (a phone
    24–42 %, a desktop ~42 %), not the space the cards left over. HOME shows no
    model at all (rule 29).

## 4. QA

23. **Every visual claim is a captured frame.** `tools/qa_flow_shots.mjs` walks
    the real stages from the committed payload and writes image statistics per
    frame, so a blank capture is visible instead of being a file that exists.
24. **A screenshot without the stage log is not a screenshot of that stage.**
    The tool refuses to file one that way.
25. **The smoke suite runs at four sizes** — 1280×720, 390×844, 360×640,
    844×390 — and asserts that every control is inside the viewport, that copy
    stays inside its own card, and that the journey's order holds.
26. **Renaming a field the tests read by name fails as a *layout* failure.**
    Grep `tests/` for `get("_…")` before renaming anything on a stage.
27. **`data_source_smoke.gd` scans screen *sources* for registry strings**, so a
    registry name inside a comment fails the build.
28. **There is no studio ident.** `branding_studio_present.mp4`,
    `studio_ident.ogv`, `stage_studio_ident.gd`, `tools/art/build_ui_video.py`,
    `video_manifest.json` and `tests/video_asset_smoke.gd` were deleted on
    2026-10-24: the owner's verdict on the delivered clip was that it looked
    bad, which reverses the earlier "the ident film opens the app". A launch now
    opens on BOOT. No stand-in film was authored in its place, and no
    placeholder card pretends to be the mark.
29. **HOME is a board, OPERATIVE is a showcase.** Two lobby pages that present
    the same 3D operative in the same composition are one page printed twice;
    the duplication is the defect, not the styling. HOME is a numbered manifest
    (01 operative, 02 theatre, 03 arsenal) with a record ribbon and the actions
    in the thumb arc; the 3D model lives on OPERATIVE only.
30. **The load screen is a poster.** The reference is *Doomsday: Last Survivors'
    opening: key art edge to edge, a heavy gradient to black across the lower
    half, a large wordmark in that band, one small credit line and one hairline.
    Measured off the captured frames, the mark spans ~60 % of the width and its
    cap-height centre sits ~88 % down. A flat void plate with the mark centred
    is BOOT's composition, and two stages that look alike are one stage printed
    twice. Cover, never contain, on the art: a letterbox puts black bars over
    the only thing the screen exists to show. Reference frames:
    `interfaceingame.com`-class captures of *Doomsday: Last Survivors*
    (filehorse.com screenshot 03 and the appgrowing.net opening capture,
    reviewed 2026-10-24).
