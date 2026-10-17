# QA evidence — enemy models and audio (17 Oct 2026)

Frames captured from the **exported WebAssembly build** in headless Chromium, by
the scripted play pass of the browser QA gate. They are committed because
`exports/` is git-ignored and the only other copy lives in a CI artifact.

## How these were produced

```bash
# 1. export the current sources to a build outside the repository
GODOT_BIN=/path/to/godot ./scripts/export_web_preview.sh --output /tmp/preview/web
cp index.html /tmp/preview/index.html

# 2. serve it (any free port; 800 is blocked in some sandboxes)
cd /tmp/preview && python3 -m http.server 8130 --bind 0.0.0.0

# 3. boot check + play pass: click (the gesture audio needs), walk, turn,
#    switch weapon, shoot, and film
node tools/web_qa.mjs --url http://127.0.0.1:8130 --page / \
  --viewport 1280x720 --play 80 --play-shot-every 25 \
  --out exports/web-qa/enemy-audio
```

Result: `1/1 page/viewport combination(s) booted`, all 11 checks passed.

## What each frame shows

| Frame | What it proves |
| --- | --- |
| `01-boot-1280x720.png` | The exported build boots straight into wave 1 (`WAVE 01 ACTIVE 3/3`, `ENEMIES 3 ACTIVE · 3 LEFT`) with the HUD, AIM/EMP/FIRE buttons and pause chip laid out. |
| `02-play-38s-runner-melee.png` | After ~38 s of scripted play a Kenney Runner is in melee range of the player and has already dealt damage: `VITALS 84 / 100`, `Time 00:04`. Weapon reads `ARC SHOOTER`, so the scripted `E` presses reached the game. |
| `03-play-73s-runner-melee.png` | The same engagement later: `VITALS 60 / 100` (runner attacks keep landing, 8 damage each), weapon cycled on to `PULSE RIFLE`, `Target 30 / 54`. |

Audio is not something a screenshot can show. The gate asserts on the engine's
console instead:

```
Audio: 14 sounds synthesised in 289 ms
Audio: 14 sounds, 0 played, ready in 289 ms, muted=no
Audio: first voice played (wave_start) 611 ms after synthesis
```

The last line only appears when a sound really reaches the audio pipeline, and it
requires the click that the play pass performs — browsers keep audio suspended
until a user gesture.

## Honest limits

- Headless Chromium here renders through **SwiftShader** (no GPU), so the game
  ran at a few frames per second: game time advanced ~6 s across 73 s of wall
  clock. Frame rate from this run is meaningless; the loop budget is not.
- One screenshot costs 15–30 s in that software renderer, which is why frames
  are 25–35 s apart rather than a dense series.
- No human has listened to these sounds on a real device; the log proves the code
  path, not the listening experience.
