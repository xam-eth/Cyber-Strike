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
| `weapon_arc_shooter.png` | 1408×768 | 1546 kB |
| `weapon_nova_launcher.png` | 1200×896 | 1799 kB |
| `weapon_pulse_rifle.png` | 1200×896 | 1526 kB |
| `wordmark.png` | 1024×1024 | 508 kB |
| `world_neon_frontier.png` | 1584×672 | 2214 kB |

## The robot frames are gone

`robot_walk_01`-`04`, `robot_walk_alt1` and `robot_walk_alt2` were deleted with
the LOADING walk cycle on 2026-10-23 (docs/DECISIONS.md 3). The
robot was cut from the loading screen for competing with the product mark; the
sources went with it, because a build step that reads six inputs to produce no
output is a pipeline that lies about what it ships.

## Honest limits

* The images in this directory have been inspected visually as of 2026-10-23
  (the wordmark above all: it is the asset that shipped with its backdrop
  baked in for weeks). Statements elsewhere in the docs that describe art
  without a frame reference predate that pass and are measurements, not
  impressions.
* "It reads as ZYVRO Labs" is a human judgement. What the build can prove is
  that the pixels arrived, that their palette is what the manifest says, and
  that the key removed exactly the plate it measured.
