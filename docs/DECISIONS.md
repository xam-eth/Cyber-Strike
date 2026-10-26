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
31. **Landscape touch is the only layout that ships.** A portrait arrangement and
    a desktop arrangement were maintained beside the phone-on-its-side one, and
    each was a second thing to measure: the HUD carried `desktop()`,
    `touch_portrait()` and `touch_landscape()`; the menus carried a card column
    and a card row; the pause gesture existed only to give the portrait seam a
    back button. Only the landscape composition was ever QA'd with real pixels,
    so the other two drifted and the drift was the defect. Everything that is
    not landscape has been deleted — `ui_layout.landscape()` is the one layout,
    `touch_controls.gd` has no desktop widgets, `menu_stage.gd` keeps the
    landscape composition at every window size, and a portrait window is answered
    by the web shell's rotation notice. The two QA viewports are 844x390 and
    667x375.
32. **The shell owns the loadout, and it hands it over in the URL.** The player
    shell (`ui/`) is where a run is chosen, so it is where the operative and the
    weapon are chosen too; there was no way to pick either before Deploy. The
    shell cannot call into `ProgressionService` — the engine has not started —
    so Deploy writes `?weapon=<id>` into the URL and
    `ProgressionService._apply_web_loadout()` reads it after the saved profile
    and before anything is emitted. That reader is not a second save file: an
    unknown id falls back to the default and a still-locked weapon is refused,
    exactly like `select_weapon()`, so a hand-edited URL cannot field a weapon
    the player has not bought. BP is still spent in the arena, never in the
    shell, which is why the rack lists a priced weapon with its price and does
    not let you take it.
33. **Every screen stands on a painted plate** (2026-10-25). The shell used to be
    panels on a dark gradient with a grid drawn on it, and the owner's verdict
    was that it read as an app rather than a game. Each screen now cross-fades to
    its own painted plate — key art for the opening, a command-deck viewport for
    HOME, the mech service bay for OPERATIVE and TAMPILAN, the battlefield for the
    hand-off — graded to near-black only at the edges the controls sit on. The
    plates are the product's art direction in `ui/art/` (with web-sized JPEG
    derivatives in `ui/art/web/`); the shell frames them, it is never the subject.
34. **The opening is a poster with its title at the top — this reverses rule 30's
    composition for the shell.** Rule 30 was measured off *Doomsday: Last
    Survivors*, whose mark sits low; the owner's direction is the other way
    round ("art photo + wordmark + a fairly large tagline, centred at the top"),
    which is the Call of Duty Mobile / PUBG Mobile arrangement. So the shell's
    opening (screen 01 of the player journey) is key art edge to edge, the
    EXOCOMFLICT lockup centred at the top on its own machined banner, the tagline
    `TAK ADA GARIS DI BELAKANGMU` in display caps under it at ~5.4 % of screen
    height, and one rail at the bottom reporting the three real readiness checks
    as a percentage. Nothing else is on the screen: the previous version printed
    a three-row checklist with tick marks, which is a diagnostic panel and made
    the first frame of the game look like a status page. Rule 30 still governs
    the engine's own LOADING stage, which the shell never shows (Deploy hands
    over into gameplay).
35. **The theatre is a carousel of painted cards.** Two museum-style cards with
    the world's own painted art, a third slot drawn as an unbuilt slot, each with
    its own silhouette cut from the one 45 degree family (the frontier drops its
    trailing foot, the station shears its leading corner, the empty slot is
    notched on both diagonals). The card art is painted, never a gameplay
    capture: a first-person frame with the rig in it is not a picture of a place.
    All three fit the frame at 844×390 and 667×375, so the selection moves and
    the row never scrolls — a sideways scroller on a phone held sideways fights
    the thumb. The engine's WORLD stage and DASHBOARD read
    `WorldDefinition.plate_path`, which now points at the same painted cards.
36. **The dock carries glyphs, and the exported shell carries nothing.** The top
    strip printed a sector string, the measured viewport and the pointer type on
    every screen; the owner's reading was that it made the design worse, and it
    is a diagnostic strip rather than part of the game. It is now the wordmark
    plate, an engine-state glyph and two controls (fullscreen, settings). In the
    exported web shell the browser bar (a `UI` toggle, a product chip,
    Fullscreen / Hide UI, and a controls legend) was removed outright: it sat on
    top of the engine's own HUD in every gameplay frame and was the first thing
    the eye found.
37. **The combat HUD has its own stencil set.** Fire, aim, weapon, EMP and swap
    are authored as flat silhouettes on one chamfer grid
    (`game/assets/ui/icons/hud/`) and are drawn through `AegisTheme.hud_icon()`,
    which falls back to the Phosphor menu glyph if a stencil is missing. The
    system glyphs in the top rail (sound, pause, retry) stay in the menu family:
    they are read at 20 px while the run is paused, and the pause button's icon
    is a contract `tests/playability_hud_smoke.gd` already holds. The
    touch tiles gained a machined inner bevel, two rivets and a hazard band along
    the leading cut, so a tile on the touch layer and a button in the shell are
    the same manufactured object. A borrowed icon family drawn at 120 px is what
    read as "generic standard" in the owner's review.

38. **The journey is opening -> hero -> map -> deploy** (2026-10-25, owner). The
    order was wrong: pressing Masuk after the load screen landed on the theatre
    map, asking where the player was going before telling them who they were
    going as. Screen 02 of the lobby is now HERO, and the map moved to 03. The
    reference is the character page of a modern mobile shooter -- CoD Mobile's
    Operator page and Free Fire's Character page -- reduced to what this game can
    honestly fill: the hero at the largest scale on screen on his own lit stage,
    a roster of face cards under the name, one horizontal rail of tabs, and a
    single lit action. Each tab answers one question and states only what exists:
      * INFO     -- the rig, the three showcase clips, the numbers from
                    `HeroDefinition`;
      * UPGRADE  -- the kit ladder (the three weapon tiers and their BP prices).
                    There is no per-hero stat block to level, because
                    `hero_definition.gd` has none on purpose; the button is
                    therefore stated and disabled, with the reason under it;
      * SKIN     -- the one livery the rig actually renders, plus two slots
                    labelled "belum dibuat" rather than sold;
      * SENJATA  -- the rack, which is the only choice on this page that changes
                    the run, and it still travels to the arena in the URL.
    The old OPERATIF page was folded into it: two lobby pages showing the same
    character in two compositions was the duplication, not the styling. The kit
    strip at the bottom of the identity column ("livery / senjata / teater") is
    what the player is about to take into the world, read in one glance.
39. **The hero page celebrates once.** Entering it fires a one-shot beat -- a
    white flash, a spotlight cone, an expanding deck ring, eighteen sparks and a
    name banner -- because the moment a player first sees their operative is the
    one moment in a lobby that is supposed to feel like an event. It re-fires
    when the hero card is pressed again (a confirmation with no response reads as
    a missed input), and "kurangi gerak" turns every part of it off, banner
    included. Sparks are generated in `ui/shell.js` rather than typed into the
    markup: angle, distance, colour and duration vary per spark, and fifteen
    hand-authored custom properties is a transcription, not a design.

40. **The hero stage is a photograph of a room and a live render of the rig.**
    The character on the hero screen comes from
    `game/assets/characters/hero/hero.glb`, rendered in the page, not from a
    painted figure. It used to be a generated illustration standing on a
    generated hangar; the art direction was approved, but as an *answer* it was
    wrong on every axis a lobby is asked about: it did not change when the
    livery changed, it did not change when the rig was re-exported, and the INFO
    tab listed clips (`idle`, `aim`, `fire`) the picture could not play. Worse,
    it showed a different character than the one in the match.

    What ships now:

      * `ui/art/web/hero-stage.jpg` -- the bay with **nobody in it**. A room does
        not animate and does not change when the player does, so it stays a
        photograph: the empty deploy pad, two beams, crates, haze. This is
        finished background, not a placeholder.
      * `.stage__view` -- a WebGL canvas over that pad, driven by
        `ui/hero_stage.js`, which loads `hero.glb` and frames it by the model's
        own bounding box (boots on the bottom edge, helmet at 93 % of the
        height), so a re-scaled export re-frames itself.
      * the `aim` clip and the game's own rifle: `hero_rig.json`'s socket
        (carry rotation, offset, `scale_model_units` 0.4) hangs
        `weapons/futuristic_rifle/rifle.glb` off `R_Hand`, which means the
        celebration is the real weapon coming up, not a CSS zoom over a still.
      * the roster card's face is `ui/art/web/hero-portrait.png`, baked from the
        same GLB by `tools/hero_portrait.mjs` with the stage's light rig. The
        card and the stage cannot disagree about who the player is looking at.

    The stage owns the GPU only while it is on screen: `play()` on entry,
    `pause()` on exit, `dispose()` before the engine boots, because Deploy does
    not need two live WebGL contexts on a phone. If the rig cannot be reached the
    canvas stays empty and the reason is printed on the pad; a silently blank
    stage is the one outcome that is not allowed.

41. **three.js is vendored into the shell, pinned, with an import map.**
    `ui/vendor/three/` holds `three.module.min.js`, `GLTFLoader`,
    `BufferGeometryUtils` and `RoomEnvironment` -- 820 KB raw, and an import map
    in `index.html` is the whole configuration. Vendored rather than fetched
    from a CDN for three reasons: the lobby has to work offline; a CDN is a
    third party that can change under a shipped build; and the pinned copy in
    the repo is the version the engine's own GLB is tested against. The render
    target is roughly 180 x 210 CSS pixels on an 844 x 390 phone and the rig is
    36 k triangles, so this is cheaper than the JPEG behind it.

42. **The stage is neutral and shared; the celebration is the hero's own.** Two
    corrections, both from the same principle: the hero art is locked, so
    everything around it adapts to the hero, never the reverse.
    * The first plate was lit cyan and amber -- the AEGIS palette baked into the
      room. That paints the character (a cool rim is a colour grade on locked
      art) and it cannot host a second hero with a different palette. The plate
      is now gunmetal and white light only, desaturated, mid-key, with a neutral
      white pad ring; the stage's three lights are white as well, and the
      celebration burst and sparks are white. Per-hero colour belongs to the
      hero. The push-in that seats the pad under the boots is baked into the JPEG
      (`tools/web_art.mjs --crop`) rather than applied as a CSS scale, because a
      transformed plate is an oversized box to the layout QA and the honest fix
      is the composition.
    * Each hero gets its **own** celebration clip, authored in Blender by
      `tools/blender/author_celebrations.py` and exported as an animation-only
      GLB under `game/assets/characters/hero/celebrations/<hero>.glb`, with
      `manifest.json` naming the file per hero. `hero.glb` is never rewritten by
      that script -- the mesh, the materials and the shipped clips stay
      byte-identical -- and the CI job that runs it refuses to publish if
      `hero.glb` changed. A hero without an authored celebration falls back to
      the rig's own `aim` pose; borrowing another hero's move is not an option.
      The authoring pass is opt-in on CI (`[celebration]` in the commit message)
      because Blender is not installed in every environment; the script is
      plain `blender --background --python`, which is how `author_hero.py`
      already works.
      Timelines are written in **bone-local axes** -- the same numbers a Blender
      pose rotation uses -- and every one of them is verified first against
      `tools/pose_oracle.mjs`, which poses `hero.glb` in the pinned Chromium with
      the same axis vocabulary and writes a PNG per variant. That tool replaced
      a CI round trip per sign, and it also told the truth about this rig: the
      forearm channels twist instead of bending, so the celebration has to be
      carried by the shoulders and the spine. Two earlier attempts at a
      two-arm overhead flare (world-axis, then negated world-axis) both folded
      the arms across the chest in the bake; the guard beat that shipped is the
      pose the rig can actually hold. A rig that cannot straighten an arm cannot
      salute, and pretending otherwise is how a "celebration" ends up looking
      like a shrug.

43. **The HUD is framed by four docks, and the stage the hero stands on is
    geometry.** Three corrections, one review.
    * Every HUD element used to float: a vitals card here, a wave card under it,
      a sound and a pause plate detached in the middle of the top edge, then six
      action tiles loose in the bottom-right, next to a bare thumb stick. A screen
      of widgets sprinkled over a game is what an app looks like. `hud_dock.gd`
      frames them: a status strip along the top edge (vitals, wave, system), an
      action rail around the fire/aim/skill/swap tiles, a movement bracket in the
      bottom-left corner, and a weapon column on the trailing edge (ammo + swap).
      The docks are *drawn*, not containers: each plate is the union of its live
      widgets' rects, so the HUD editor's saved offsets and the platform safe
      insets move the frame with the widgets, and nothing joins the hit-test
      path. One vocabulary across all four: cut corner, hairline, one lit edge,
      corner ticks -- the same machined set as the touch tiles.
    * The armory is a modal of **cards with the weapon's own art**, not three text
      rows. A row that says "ARC · CHAIN" asks the player to imagine a gun; the
      card shows the gun, its role in one line, its numbers read from the weapon
      definition (damage / rate / magazine) and one action. The action *words*
      stay the interface's own (EQUIPPED / EQUIP / UNLOCK n BP) -- a redesign of
      the surface is not a licence to rename what a button does.
    * The hero's stage: the plate had a deploy pad **painted into it**, so the
      operative stood on a picture of a platform -- no weight, no shadow, no
      shared perspective, and the pad could not move while the rig did. The room
      is now a photograph of an empty hangar floor with no pad in it, and the
      deck is real geometry in `ui/hero_stage.js`: recessed base, plated top, lit
      rim, inner ring, all in the same scene and camera as the rig. The rig is
      seated on the deck's top face, the contact shadow is drawn on that surface,
      and the camera tilts just enough to show the deck as an ellipse. Stage, rig
      and light now share a space, which is the only version of "standing on a
      stage" that is not a caption.

44. **Home is one button, one meaning, and it exists in every in-game menu.**
    Four menus could hold the player — pause, results, armory, settings — and
    between them they offered resume, restart, retry, return to explore, close
    and done. None of them offered the way back to the dashboard, so the only
    exit from a run was the browser. Now all four carry **HOME**, they raise one
    signal (`TouchControls.home_requested`), and one object decides where home
    is: `DashboardReturn`. Embedded in the player shell it hands the document
    back to `window.AegisShell.home()`, which reloads into `?ui=hub` with the
    hand-off parameters dropped; running on its own it changes to
    `front_end.tscn` with `FrontEnd.resume_stage = DASHBOARD`, so the return does
    not replay BOOT → LOADING → CHAPTER on the way. The button unpauses the tree
    and releases the cursor before either route, because the pause card is what
    holds `get_tree().paused`.

    The pause card also had to change shape to hold a fourth action. Three
    stacked 52 px plates plus its header overflowed a 375 px-tall phone; RESUME
    now spans the card and RESTART / SETTINGS / HOME share one row at the same
    52 px height. Rank is read from size — the primary action is the wide one —
    not from a position that a short screen can crop. `tests/menu_home_smoke.gd`
    presses all four and asserts the signal, and that `resume_stage` lands on
    DASHBOARD and is spent.

### What the reference research says

The round-11 brief asked for real references rather than taste, so these are the
rules the HUD and the menus are held to, with their sources:

| Rule | Number | Source |
| --- | --- | --- |
| Minimum touch target | 44 pt iOS / 48 dp Android, 8 pt between actions | game-ace, *Mobile game design* |
| Primary actions sit in the lower thumb arc | bottom corners, not the top edge | game-ace; Unity anchor notes (top-left status, top-right pause, bottom-right confirm) |
| Physical edges are not a layout guide | pad by the platform insets, never by 0 | game-ace; polypane, *safe-area-inset* |
| Action safe / title safe | actions within 95 % of the edges, information within 90 % | gameuxmasterguide, *Layout of the HUD* |
| Nine-part grid | status top-left, pause top-right, actions bottom-right, alert centre | gameuxmasterguide; *How the HUD works in Black Ops 7* |
| HUD never bleeds to the glass | Borderlands 3 keeps every element inside the safe zone | medium, *Art Direction for AAA UI* |
| Pause menu: one prominent resume, then the exits | resume first and biggest; exits explicit, not nested | wayline, *20 reasons your pause menu is sabotaging your game*; UQ 2026 studio notes |
| The exit is named after the place it goes | "Return to Main Menu" / "Exit to Title"; "Exit" alone is ambiguous | gamedev.stackexchange 20492 |
| Menus are a stack, not a mode switch | a pause/settings/armory overlay returns to what was underneath | r/gamedev *menu stack* thread |

What that changed in the HUD: `AegisTokens.MIN_TOUCH_PX` is 64 and
`TOUCH_GAP_PX` is 14 (both above the 44/8 floor); the four docks are the grid —
status strip and system plate on the top edge, movement bracket bottom-left,
action rail bottom-right, ammo column on the trailing edge; the modal cards are
inset from the glass by the same safe reserves the thumb controls use; and the
shell already pads its chrome with `env(safe-area-inset-*)`. What it changed in
the menus: HOME is the last item in every list, always with the same word, and
settings is an overlay that returns to the card it was opened from.

45. **Overlays are a stack, and a finger calls the button's own handler.** Two
    lessons from `docs/skills/disciplines/game-ui-ux` (vendored; see that folder's
    README for provenance), both paid for with a bug.
    * **The stack.** Pause, results, settings, the armory and the HUD editor were
      five booleans plus an ESC ladder in `_input`. `HudOverlayStack` replaces
      them: it owns the order, so ESC closes exactly the top layer and the run
      resumes only when nothing is left; it owns the **focus trap**
      (`focus_behavior_recursive` / `mouse_behavior_recursive`, Godot 4.5+), so a
      gamepad cannot walk into the buttons behind a modal; and it remembers the
      control that opened the layer so closing it hands focus back instead of
      leaving the player with none. Each overlay's own close path still runs —
      the stack removes a layer, it does not reimplement what closing means.
    * **The dispatcher.** `HudTouchInput.activate()` was a hand-written if/elif
      naming every button in the HUD. A synthetic touch never reaches Godot's
      Button GUI, so `pressed` only fires if that function emits it — and the
      round-11 HOME plates were drawn, connected, and dead because the ladder did
      not name them. It now emits `pressed` and lets each button's own
      connection decide, with a `push_error` for a plate that has no handler at
      all. FIRE and AIM keep their hold behaviour; nothing in the ladder was
      load-bearing except the remembering.
    * **The `grab_focus` error** seen in every capture was the other end of the
      same problem: `make_button()` deferred a focus grab at *construction* time,
      and every stage is constructed up front, so a launch that skipped the front
      end (a deep link into the world) flushed those callbacks after the scene had
      been replaced — `Condition "!is_inside_tree()" is true. at: grab_focus`.
      Focus is now taken by `MenuStage.focus_primary()`, called by `FrontEnd`
      after the stage is shown, which is also what the skill asks for ("always
      focus something on open").
