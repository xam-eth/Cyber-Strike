# Game-dev skills we work from

These are the **Agent Skills** from
[`gamedev-skills/awesome-gamedev-agent-skills`](https://github.com/gamedev-skills/awesome-gamedev-agent-skills),
copied verbatim so a checkout is enough to work from them — no network, no CLI.

- **Source commit:** `184b72b` (2026-10-24), branch `main`.
- **Licence:** Apache-2.0, © 2026 Abhishek Barali and contributors. `LICENSE` and
  `NOTICE` are the originals.
- **Copied:** every discipline (`disciplines/`), the router (`router/`), the
  Godot UI engine skill (`godot-ui-control/`), and the authoring standard
  (`SKILL-FORMAT.md`). Nothing was edited; a change from upstream is a diff, not
  a fork.

## What we actually use, and where it changed this project

| Skill | The rule we hold ourselves to | Where it lives in this code |
| --- | --- | --- |
| `disciplines/game-ui-ux` | Layout is anchors + containers, never absolute pixels | `game/scripts/ui/ui_layout.gd`, every `UiLayout.place()` call |
| | One scaling strategy: `canvas_items` + `expand`, 1280x720 reference | `game/project.godot` → `[display]` |
| | Inset critical UI by the safe area the OS reports, not by a constant | `UiLayout.measure_safe_insets()` reads `DisplayServer.get_display_safe_area()` and `get_display_cutouts()`; `AegisTokens.SAFE_*` are floors, not the answer |
| | Screens are a **stack**, not flags | `front_end.gd` stages + `BackTarget`; `ui/hud/hud_overlay_stack.gd` for the in-game overlays |
| | A modal **traps** focus (`focus_behavior_recursive`, Godot 4.5+) | `hud_overlay_stack.gd::_trap()` |
| | Open a screen with something focused | `MenuStage.focus_primary()`, called by `FrontEnd._enter()` |
| | The HUD updates from signals, never by polling game state | `health_changed` / `weapon_changed` / `progress_changed` → `TouchControls` |
| | Touch targets ≥ ~9 mm; don't encode state in colour alone | `AegisTokens.MIN_TOUCH_PX` (56 px ≈ 9 mm), the ACCESS tab's colourblind toggle |
| `godot-ui-control` | Containers own child layout; theme on the root, overrides by exception | `AegisTheme` + the `Aegis*` widgets |
| `disciplines/performance-optimization` | Measure before changing anything | a frame-time capture in `qa-evidence/ui/round-12/` before any redraw tuning |

## What is *not* adopted

- The **genres** and other engines in the upstream catalogue: this project is
  Godot only and has no genre skill that fits a third-person arena shooter.
- The `godot-*` skills other than `godot-ui-control` are not vendored; add the
  one you need from the same commit rather than copying the whole tree.

## A note on the copy

`router/SKILL.md` links to engine and genre skills that are not in this
repository. It is kept for its routing rules (engine detection, "read the
chosen skill before acting"), not as a working link index.
