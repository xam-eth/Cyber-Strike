# `game/assets/ui/generated/` — generator output (sources, not shipping assets)

These are the **raw** outputs of the image-generation tool used in this
session. Nothing here is loaded by the game. The shipping textures are produced
from these by `tools/art/build_ui_art.py` and written one directory up, to
`game/assets/ui/`.

They are committed on purpose: they are the provenance for the shipping art, and
without them the build is not reproducible — `build_ui_art.py` refuses to
invent a file it cannot find, so deleting them breaks the pipeline rather than
silently changing the art.

## Provenance

* **Tool:** the workspace image-generation tool (`generate_image`), which writes
  a PNG directly to the path it is given. Not a command-line utility, not
  something invoked from `build_ui_art.py`.
* **Prompt text:** session-local and **not persisted here**. Only the resulting
  pixels were written to disk, so the prompts cannot be reproduced from this
  repository. Any claim about what a prompt said would be invention.
* **What *is* reproducible:** every transformation after generation. The build
  is deterministic — same 14 inputs produce byte-identical outputs — and every
  crop, resize and palette number is re-derivable by running it.

## Inventory

Real on-disk sizes as measured. These are **not** the sizes the game uses; see
`docs/ART_DIRECTION.md` §6 for the shipping set.

| File | Resolution | Size |
| --- | --- | --- |
| `dashboard_bg.png` | 1376×768 | 2165 kB |
| `hero_portrait.png` | 896×1200 | 2559 kB |
| `loading_keyart_16x9.png` | 2048×1152 | 3805 kB |
| `robot_walk_01.png` | 1408×768 | 977 kB |
| `robot_walk_02.png` | 1408×768 | 1021 kB |
| `robot_walk_03.png` | 1408×768 | 1004 kB |
| `robot_walk_04.png` | 1408×768 | 999 kB |
| `robot_walk_alt1.png` | 1408×768 | 901 kB |
| `robot_walk_alt2.png` | 1408×768 | 976 kB |
| `weapon_arc_shooter.png` | 1408×768 | 1546 kB |
| `weapon_nova_launcher.png` | 1200×896 | 1799 kB |
| `weapon_pulse_rifle.png` | 1200×896 | 1526 kB |
| `wordmark.png` | 1024×1024 | 508 kB |
| `world_neon_frontier.png` | 1584×672 | 2214 kB |

## Which frames are used

`robot_walk_01..04` are the four walk frames that ship in
`loading_robot_sheet.png`. `robot_walk_alt1` and `robot_walk_alt2` are
alternate poses generated alongside them; they are kept for continuity at 8 fps
and were not selected. The build reads all six because the **union** crop that
keeps the robot from jittering is computed across every frame available.

## Honest limits

* No one in this session has *looked* at these images — there is no image
  display available. Every statement about them in the docs comes from measured
  pixel statistics (palette histograms, content bounding boxes, inter-frame
  motion).
* "The robot walks" is not something this repository can prove. What it can
  prove is that four frames exist, differ from one another inside a shared
  subject region, and are on-palette. Whether the loop reads as a walk is a
  human judgement that has not been made yet.
