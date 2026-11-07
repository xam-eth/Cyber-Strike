#!/usr/bin/env python3
"""Generate one PBR surface map set (albedo/normal/ORM PNGs) at full size.

Thin CLI wrapper around pbr_lib for tools/gltf/upgrade_closeup_textures.mjs,
which promotes selected close-up world maps to 1024 px. Mirrors exactly how
enrich_aetherfall.py builds its sets (same seeds, same save_set) so a promoted
map is the same procedural field the 512 px profile was downscaled from.

    python3 tools/blender/gen_surface_set.py <kind> <out_dir>

Prints the written PNG paths (slot order: albedo, normal, orm).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbr_lib  # noqa: E402


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: gen_surface_set.py <kind> <out_dir>", file=sys.stderr)
        return 2
    kind, out_dir = sys.argv[1], sys.argv[2]
    maps = pbr_lib.surface_set(kind)
    paths = pbr_lib.save_set(out_dir, "aetherfall_" + kind, maps)
    for slot in ("albedo", "normal", "orm"):
        if slot in paths:
            print(paths[slot])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
