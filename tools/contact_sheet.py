#!/usr/bin/env python3
"""Tile one folder of frames into a single sheet, labelled.

    tools/contact_sheet.py exports/vision/vision/390x844 out.png 390x844

The point is a reviewer's first question — "is the thing on screen at all?" —
being answerable from one image instead of twelve. Frames are scaled to a
common height, laid out in a grid, and each is captioned with its stage name.
A frame that came out blank stays visibly blank: nothing here hides one.

Pillow only, no network, no engine.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

MAX_TILE_HEIGHT = 420
GUTTER = 12
CAPTION = 22
BACKGROUND = (8, 11, 16)
CAPTION_COLOR = (219, 231, 242)
LABEL_COLOR = (255, 176, 32)


def _font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        Path(__file__).resolve().parents[1] / "game/assets/ui/fonts/Rajdhani-Medium.ttf",
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ):
        if candidate.exists():
            try:
                return ImageFont.truetype(str(candidate), 16)
            except OSError:
                continue
    return ImageFont.load_default()


def build(folder: Path, destination: Path, viewport: str) -> int:
    frames = sorted(p for p in folder.glob("*.png") if not p.name.startswith("contact-"))
    if not frames:
        print(f"ERROR: no frames in {folder}", file=sys.stderr)
        return 1

    tiles = []
    for frame in frames:
        with Image.open(frame) as image:
            tile = image.convert("RGB")
        if tile.height > MAX_TILE_HEIGHT:
            width = round(tile.width * MAX_TILE_HEIGHT / tile.height)
            tile = tile.resize((width, MAX_TILE_HEIGHT), Image.LANCZOS)
        tiles.append((frame.stem, tile))

    columns = min(len(tiles), 4 if tiles[0][1].width > 600 else 6)
    rows = (len(tiles) + columns - 1) // columns
    cell_w = max(tile.width for _, tile in tiles)
    cell_h = max(tile.height for _, tile in tiles)
    canvas = Image.new(
        "RGB",
        (
            GUTTER + columns * (cell_w + GUTTER),
            GUTTER + rows * (cell_h + CAPTION + GUTTER),
        ),
        BACKGROUND,
    )
    draw = ImageDraw.Draw(canvas)
    font = _font()
    for index, (label, tile) in enumerate(tiles):
        column, row = index % columns, index // columns
        x = GUTTER + column * (cell_w + GUTTER)
        y = GUTTER + row * (cell_h + CAPTION + GUTTER)
        draw.text((x, y), label.upper(), fill=LABEL_COLOR, font=font)
        canvas.paste(tile, (x, y + CAPTION))

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination)
    print(f"{destination}  ({len(tiles)} frames, {viewport})")
    return 0


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    folder = Path(sys.argv[1] if Path(sys.argv[1]).is_absolute() else Path.cwd() / sys.argv[1])
    destination = Path(sys.argv[2])
    viewport = sys.argv[3] if len(sys.argv) > 3 else ""
    return build(folder, destination, viewport)


if __name__ == "__main__":
    raise SystemExit(main())
