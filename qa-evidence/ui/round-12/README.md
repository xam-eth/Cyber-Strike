# Round 12 — the HUD's overlays are a stack, and the frame is unchanged

Frames from the committed WebAssembly build (`web/index.pck` as CI exported it
for this branch), served from disk and driven with real touch + real Escape in
@sparticuz/chromium at 844×390. `tools/hud_evidence.mjs` is the harness
(`TAPS="447,65:02-pause;343,280:03-settings;key:Escape:04-pause-again;…"`).

| Frame | What it is |
| --- | --- |
| `01-pause-home.png` | Pause with the layered card: RESUME, the run decision, SETTINGS \| HOME |
| `02-settings-stacked.png` | Settings **on top of** pause, not instead of it |
| `03-esc-closed-one-layer.png` | One Escape later: settings gone, pause still up |
| `04-dashboard-after-home.png` | One tap later: HOME lands on the dashboard |

The engine console for that session, in order:

```text
HUD: paused
HUD: settings opened
HUD: settings closed
FrontEnd: stage DASHBOARD
```

## What changed, and what it is evidence of

- **Overlay stack** (`game/scripts/ui/hud/hud_overlay_stack.gd`): one owner for
  the order, the focus trap and where focus returns. The frames above are the
  stack being used, not the stack existing — `03` is the proof that Escape
  closes exactly one layer.
- **Touch dispatcher**: `HudTouchInput.activate()` no longer holds a list of
  button names; it emits each button's own `pressed`. The pause and settings
  frames here were produced by real taps on plates that used to be dead.
- **`grab_focus` error is gone.** Round-11 captures each printed
  `ERROR: Condition "!is_inside_tree()" is true. at: grab_focus`. This session,
  which walks the same route (deep link into the world, then the menus), prints
  no such line.
- **Redraw**: the HUD no longer rebuilds its docks behind a paused tree. The
  paused frame is byte-for-byte the same HUD as before the change, which is the
  point — nothing visible moved.

## Performance claim, stated honestly

`tools/hud_evidence.mjs perf` reports ~1 fps in this sandbox because the canvas
is drawn by SwiftShader (software GL) and `requestAnimationFrame` is starved. That
number says nothing about a phone GPU, so it is **not** offered as evidence of a
frame-time win; the redraw change is justified by the logic (a paused tree cannot
change what the HUD draws), and a real measurement needs a device or a GPU runner.

Reasoning and sources: `docs/DECISIONS.md` 44 (HOME, AAA references) and 45
(overlay stack, dispatcher, focus). Vendored skills: `docs/skills/README.md`.
