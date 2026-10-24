#!/usr/bin/env python3
"""Report whether a screenshot contains an image, not just bytes.

The project has been burned twice by passes that counted files instead of
looking at them: eight byte-identical "world tour" frames, and a tour that
photographed a live game while claiming to show a review camera
(docs/DECISIONS.md §12.3, docs/DECISIONS.md §3). A PNG
that exists proves nothing; these numbers decide whether it is a render.

Usage:
    image_stats.py FRAME.png [FRAME.png ...]        # human-readable table
    image_stats.py --json FRAME.png [...]           # JSON array
    image_stats.py --check FRAME.png                # exit 1 if the frame is blank

What is reported per file:

    mean / stddev   luminance over the whole frame. A black or single-colour
                    frame has stddev ~0; a rendered 3D scene at 1280x720 sits
                    near 35-60.
    distinct        distinct colours after a box filter down to 80x45. A
                    gradient-free frame (one fill colour) reports 1-3.
    lit             share of pixels brighter than 8/255. A frame that is 95 %
                    black plus a HUD is not a game frame.
    black           share of pixels darker than 4/255.
    clip            share of pixels at 254/255 or above, i.e. how much of the
                    image is blown out. Useful after a glow/tonemap change.

Thresholds in `--check` are deliberately loose: they separate "rendered" from
"blank", not "good" from "bad". Judging composition needs eyes on the frame;
this only refuses the obviously empty one.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment problem, not logic
    Image = None

THUMB = (80, 45)


def _pixels(image):
    """Pillow 13 deprecates getdata(); 12 does not have the replacement yet."""
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def stats_for(path: Path) -> dict:
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        width, height = rgb.size
        pixels = _pixels(rgb)

    total = max(1, len(pixels))
    luma = [0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in pixels]
    mean = sum(luma) / total
    variance = sum((value - mean) ** 2 for value in luma) / total

    with Image.open(path) as image:
        thumb = image.convert("RGB").resize(THUMB, Image.BOX)
        distinct = len(set(_pixels(thumb)))

    return {
        "file": str(path),
        "size": [width, height],
        "mean": round(mean, 1),
        "stddev": round(variance**0.5, 1),
        "distinct": distinct,
        "lit": round(sum(1 for value in luma if value > 8) / total, 3),
        "black": round(sum(1 for value in luma if value < 4) / total, 3),
        "clip": round(sum(1 for value in luma if value >= 254) / total, 4),
    }


def is_blank(row: dict) -> bool:
    """True when the frame carries no picture. Deliberately loose."""
    return row["stddev"] < 6.0 or row["distinct"] < 8 or row["lit"] < 0.05


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Decide whether frames are renders.")
    parser.add_argument("frames", nargs="+", help="PNG files to measure")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 when any frame is blank (stddev/distinct/lit thresholds)",
    )
    args = parser.parse_args(argv)

    if Image is None:
        print(
            "ERROR: Pillow is required for image inspection "
            "(python3 -m venv .venv && .venv/bin/pip install pillow)",
            file=sys.stderr,
        )
        return 2

    rows = []
    missing = 0
    for name in args.frames:
        path = Path(name)
        if not path.is_file():
            print(f"ERROR: not a file: {path}", file=sys.stderr)
            missing += 1
            continue
        row = stats_for(path)
        row["blank"] = is_blank(row)
        rows.append(row)

    if args.json:
        print(json.dumps(rows, indent=2))
        return 1 if missing or (args.check and any(row["blank"] for row in rows)) else 0

    header = f"{'frame':<46} {'size':>10} {'mean':>6} {'sd':>6} {'cols':>5} {'lit':>5} {'clip':>6}  verdict"
    print(header)
    print("-" * len(header))
    for row in rows:
        size = f"{row['size'][0]}x{row['size'][1]}"
        verdict = "BLANK" if row["blank"] else "render"
        print(
            f"{Path(row['file']).name[:46]:<46} {size:>10} {row['mean']:>6} "
            f"{row['stddev']:>6} {row['distinct']:>5} {row['lit']:>5} "
            f"{row['clip']:>6}  {verdict}"
        )

    blank = [row["file"] for row in rows if row["blank"]]
    if blank:
        print(f"\n{len(blank)} blank frame(s): {', '.join(Path(p).name for p in blank)}")
    return 1 if missing or (args.check and blank) else 0


if __name__ == "__main__":
    sys.exit(main())
