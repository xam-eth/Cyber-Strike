# KayKit Space Base Bits — selected world assets

- Upstream pack: https://github.com/KayKit-Game-Assets/KayKit-Space-Base-Bits-1.0
- License: CC0 (Creative Commons Zero); the original `LICENSE.txt` is included beside these files. The license states that optional credit to Kay Lousberg is appreciated but not required.
- Source snapshot: `https://github.com/KayKit-Game-Assets/KayKit-Space-Base-Bits-1.0` at commit
  **`6dfbcac9927d06283752c4defd4882cfe0d29666`** (2026-10-17). Files were copied byte-for-byte
  from `addons/kaykit_space_base_bits/Assets/gltf/`; the md5 of `cargo_A_stacked.gltf`,
  `cargo_A_stacked.bin` and `spacebits_texture.png` match that commit.
- Upstream `3DScifiStarterKitFree.zip` (259 MB, Git LFS) was **not** committed: the LFS object
  could not be downloaded in this environment, and the 57 unpacked GLTFs above are the same
  pack in the form Godot imports. Only the 7 models the earlier pass used were in the tree
  before; the other 50 were added from the pinned upstream commit.

Included GLTF models and companion BIN files (57 models, all of `Assets/gltf/`):

`basemodule_A`–`E`, `basemodule_garage`, `cargo_A/B`, `cargo_A/B_packed`,
`cargo_A/B_stacked`, `cargodepot_A/B/C`, `containers_A`–`D`, `drill_structure`,
`lander_A/B`, `lander_base`, `landingpad_large/small`, `lights`, `rock_A/B`,
`rocks_A/B`, `roofmodule_base`, `roofmodule_cargo_A/B/C`,
`roofmodule_solarpanels`, `solarpanel`, `spacetruck`, `spacetruck_large`,
`spacetruck_trailer`, `structure_low/tall`, `terrain_low`, `terrain_low_curved`,
`terrain_mining`, `terrain_slope`, `terrain_slope_inner_corner`,
`terrain_slope_outer_corner`, `terrain_tall`, `terrain_tall_curved`,
`tunnel_diagonal_long_A/B`, `tunnel_diagonal_short_A/B`, `tunnel_straight_A/B`,
`windturbine_low/tall`.

`gltf/spacebits_texture.png` is the shared texture atlas referenced by the GLTF files. The assets are loaded as 3D geometry by `game/scripts/worlds/gltf_asset_library.gd` and placed in the modular world; none is flattened into a background image or billboard.
