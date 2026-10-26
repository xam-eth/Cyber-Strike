# Round 11 — every in-game menu goes home

Frames from the committed WebAssembly build, not mock-ups and not composited.
The engine is `web/index.pck` as CI exported it for this branch, served from disk
and driven with real touch events in @sparticuz/chromium at both shipping
viewports. `tools/hud_evidence.mjs` is the harness.

| Frame | What it is |
| --- | --- |
| `844x390/01-explore-hud.png` | Explore with the four docks: status strip and system plate on the top edge, movement bracket bottom-left, action rail bottom-right, ammo column on the trailing edge |
| `844x390/02-pause-home.png` | Pause: RESUME, the run decision, then SETTINGS \| HOME |
| `844x390/03-settings-home.png` | Settings: RESET DEFAULTS \| HOME \| DONE |
| `844x390/04-armory-home.png` | Armory: three weapon photographs, RETURN TO FIELD \| HOME |
| `844x390/05-dashboard-from-pause.png` | What the HOME plate on pause actually does — the dashboard, after a real tap |
| `844x390/06-dashboard-from-armory.png` | Same, from the armory's HOME |
| `667x375/01-explore-hud.png` | The small phone. The armory entry is the WEAPON plate here (`weapon_acts_as_armory`), not a second button |
| `667x375/02-pause-home.png` | Pause on 375 px: three 52 px rows plus the header fit, nothing clipped |
| `667x375/03-armory-home.png` | Armory on 375 px: the art floor drops to 76 px so the footer stays on the glass |
| `667x375/04-dashboard-from-pause.png` | HOME from pause on the small phone |

## What the frames prove, and what they caught

Pressing HOME prints `FrontEnd: stage DASHBOARD` in the engine console and the
last frame of each route is that stage. Three defects were only visible once a
finger did the pressing, and all three are fixed in this round:

1. the new HOME plates were drawn, connected and **dead** — the touch HUD
   resolves a finger to a button and then walks a hand-written `activate()`
   chain, and they were not in it;
2. HOME returned to the front end, which read `?qa_stage=GAMEPLAY` first and
   handed the player straight back into the arena;
3. the armory panel grew taller than a 375 px phone and drew its footer half off
   the glass.

`tests/menu_home_smoke.gd` now presses one of those plates with a synthetic
touch rather than emitting `pressed`, so defect 1 cannot come back quietly.

Reasoning and sources: `docs/DECISIONS.md` 44.
