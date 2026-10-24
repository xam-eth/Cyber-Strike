# QA evidence — mobile HUD (17 Oct 2026)

Frames from the **exported WebAssembly build** in headless Chromium, captured by
the browser QA gate. They document what a phone actually sees; the numbers behind
them are asserted in `tests/playability_hud_smoke.gd`.

## How these were produced

```bash
GODOT_BIN=/path/to/godot ./scripts/export_web_preview.sh --output /tmp/preview/web
cp index.html /tmp/preview/index.html
cd /tmp/preview && python3 -m http.server 8130 --bind 0.0.0.0

# layout frames (portrait phone + landscape phone)
node tools/web_qa.mjs --url http://127.0.0.1:8130 --page / \
  --viewport 390x844 --viewport 844x390 --out exports/web-qa/hud-mobile

# scripted play; presses M partway through to prove the mute wiring
node tools/web_qa.mjs --url http://127.0.0.1:8130 --page / --viewport 844x390 \
  --play 30 --play-shot-every 10 --json --out exports/web-qa/hud-mobile
```

## What each frame shows

| Frame | What it proves |
| --- | --- |
| `01-portrait-390x844.png` | A 390 px portrait phone: `VITALS 100/100`, `WAVE 01 ACTIVE 1/3`, `PAUSE`, `SOUND`, then one compact card under the bar with `ENEMIES 1 ACTIVE · 3 LEFT` and the run summary wrapped over two lines. Before this pass the same phone rendered the HUD at ~30% of its designed size because the layout was measured against the logical 1280-unit canvas instead of the window. |
| `02-landscape-844x390.png` | The same build at 844×390 keeps the three-column top bar (`VITALS`, `WAVE 01`, `RUN DATA`), so the wide layout is still the primary one. |
| `03-landscape-muted-19s.png` | After 19 s of scripted play (Runner **and** Shooter engaging, `VITALS 76/100`, weapon cycled to `ARC SHOOTER`) the SOUND button reads **MUTED** and is tinted red: the scripted `M` key press reached the game, changed the audio state and the label followed it. |

The matching console lines from that run:

```
Audio: 14 sounds synthesised in 542 ms
Audio: 14 sounds, 0 played, ready in 542 ms, muted=no
Audio: first voice played (wave_start) 1096 ms after synthesis
Audio: muted
```

The QA gate asserts on `Audio: muted` exactly — the boot line ends in
`muted=no`, so a loose match would pass without the key ever arriving.

## Honest limits

- Headless Chromium renders through **SwiftShader**, so frame rate here says
  nothing about a real phone.
- 390×844 is a viewport, not a device: no notch, no DPI scaling, no touch
  digitizer. The physical-size maths is asserted in the smoke test
  (`>= 11 physical px`), which is stronger than eyeballing a screenshot, but a
  real Android run is still the only proof for the device itself.
