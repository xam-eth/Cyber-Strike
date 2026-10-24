#!/usr/bin/env python3
"""Turn a burst of gameplay frames into an "animation motion map".

    python3 tools/avatar_motion_map.py exports/avatar-qa/avatar-1280x720-1.png \
        exports/avatar-qa/avatar-1280x720-2.png ... --out exports/avatar-qa/motion.png

Every pixel is scored by how much its luma moved across the burst. Static world
geometry scores ~0; anything that animated - the avatar breathing in its idle
clip, a walking figure, a HUD plate - lights up. It is the cheapest honest way
to answer "is the avatar actually drawn?" from a real WebGL frame: a screen
rectangle predicted from the camera transform can be checked against a
silhouette that only exists if the renderer drew something there.

The map is written as a greyscale PNG (brighter = more motion) and the numbers
that matter are printed: the bounding box of everything above the motion
threshold, and how many pixels cleared it.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - Pillow is a documented prerequisite
    print("ERROR: Pillow is not installed (pip install --break-system-packages Pillow)")
    raise SystemExit(2)


def luma(rgb: tuple[int, int, int]) -> float:
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames", nargs="+", type=Path, help="two or more frames of one camera")
    parser.add_argument("--out", type=Path, required=True, help="greyscale motion map PNG")
    parser.add_argument("--threshold", type=float, default=20.0, help="luma delta to count")
    args = parser.parse_args()

    if len(args.frames) < 2:
        print("ERROR: need at least two frames of the same camera.")
        return 2

    images = [Image.open(frame).convert("RGB") for frame in args.frames]
    size = images[0].size
    if any(image.size != size for image in images):
        print("ERROR: frames have different sizes; they are not one camera.")
        return 2

    pixels = [image.load() for image in images]
    width, height = size
    out = Image.new("L", size)
    out_pixels = out.load()

    min_x, min_y, max_x, max_y = width, height, -1, -1
    moved = 0
    peak = 0.0
    for y in range(height):
        for x in range(width):
            values = [luma(pixel[x, y]) for pixel in pixels]
            spread = max(values) - min(values)
            peak = max(peak, spread)
            out_pixels[x, y] = min(255, int(spread))
            if spread >= args.threshold:
                moved += 1
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)

    print(f"frames      : {len(args.frames)}  size={width}x{height}")
    print(f"peak spread : {peak:.1f} luma")
    print(f"moved pixels: {moved} ({moved / float(width * height) * 100.0:.2f}% at >= {args.threshold})")
    if moved:
        print(f"motion bbox : x {min_x}..{max_x} (w={max_x - min_x + 1}) "
              f"y {min_y}..{max_y} (h={max_y - min_y + 1})")
        print(f"             {((max_y - min_y + 1) / float(height) * 100.0):.1f}% of frame height")
    print(f"map written : {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
