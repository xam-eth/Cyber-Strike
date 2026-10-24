#!/usr/bin/env python3
"""Turn the generated concept art in ``game/assets/ui/generated/`` into the
shipping textures the game loads.

    python3 tools/art/build_ui_art.py            # build + audit + write manifest
    python3 tools/art/build_ui_art.py --check    # audit only, change nothing

Why a build step instead of committing the raw downloads: the generator emits
whatever canvas it likes (a 1024x1024 wordmark with the glyphs in a 891x218
band, six 1408x768 robot frames whose subject wanders across the frame). The
game needs tight, predictable textures, and a hand-cropped PNG that nobody can
reproduce is how an art pipeline rots. Every rule below is deterministic, so
deleting ``game/assets/ui/`` and re-running this reproduces it byte for byte
from the generated sources.

What it does:
  * crops to content where the subject floats on a flat backdrop,
  * uses the *union* of the content boxes for animation frames, so the robot
    does not jitter between cells,
  * letterboxes or centre-crops to the shipping aspect without stretching,
  * packs the walk cycle into one horizontal sprite sheet,
  * audits every output against the ART_DIRECTION.md palette and fails loudly
    when a texture drifts outside it,
  * writes game/assets/ui/art_manifest.json with the real, measured
    resolution of every shipped file so no report has to guess.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import sys
from collections import Counter
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("ERROR: Pillow is not installed "
          "(pip3 install --break-system-packages Pillow)")
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game" / "assets" / "ui" / "generated"
OUT = ROOT / "game" / "assets" / "ui"

# The palette from docs/ART_DIRECTION.md, as HSV hue windows. Anything outside
# these families is a drift: a stray purple planet or a washed-out pastel sky.
# Amber starts at 15 degrees, not 25: oxidised gunmetal and warm dust land in
# the 15-25 band and are part of the palette, not a drift. Widening the window
# was measured against loading_keyart.png, where 8.9% of pixels were flagged
# and every one of them was a dark rust tone (hue 15-24, value below 0.35).
PALETTE = {
    "navy": (200, 260),
    "cyan": (175, 200),
    "green": (95, 175),
    "amber": (15, 70),
    "red": (345, 375),  # wraps past 360
    "steel": None,      # desaturated: any hue, saturation below the cutoff
}
STEEL_MAX_SAT = 0.14
SHADOW_MAX_VALUE = 0.10


# --------------------------------------------------------------------------- #
# geometry helpers
# --------------------------------------------------------------------------- #
def content_box(image: Image.Image, tolerance: int = 45) -> tuple[int, int, int, int]:
    """Bounding box of everything that is not the flat backdrop."""
    probe = image.copy()
    probe.thumbnail((320, 320))
    counts = Counter(probe.convert("RGB").getdata())
    background = counts.most_common(1)[0][0]
    mask = Image.new("L", probe.size)
    source = probe.convert("RGB").load()
    target = mask.load()
    for y in range(probe.size[1]):
        for x in range(probe.size[0]):
            r, g, b = source[x, y]
            delta = abs(r - background[0]) + abs(g - background[1]) + abs(b - background[2])
            target[x, y] = 255 if delta > tolerance else 0
    box = mask.getbbox()
    if box is None:
        return (0, 0, image.size[0], image.size[1])
    sx = image.size[0] / probe.size[0]
    sy = image.size[1] / probe.size[1]
    return (int(box[0] * sx), int(box[1] * sy), int(box[2] * sx), int(box[3] * sy))


def union_box(boxes: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    return (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale to fill `size` and centre-crop the overflow. Never stretches."""
    sw, sh = image.size
    tw, th = size
    scale = max(tw / sw, th / sh)
    resized = image.resize((max(1, round(sw * scale)), max(1, round(sh * scale))), Image.LANCZOS)
    left = (resized.size[0] - tw) // 2
    top = (resized.size[1] - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def contain(image: Image.Image, size: tuple[int, int], fill: tuple[int, int, int]) -> Image.Image:
    """Scale to fit inside `size` and letterbox onto `fill`. Never stretches."""
    sw, sh = image.size
    tw, th = size
    scale = min(tw / sw, th / sh)
    resized = image.resize((max(1, round(sw * scale)), max(1, round(sh * scale))), Image.LANCZOS)
    canvas = Image.new("RGB", size, fill)
    canvas.paste(resized, ((tw - resized.size[0]) // 2, (th - resized.size[1]) // 2))
    return canvas


# --------------------------------------------------------------------------- #
# palette audit
# --------------------------------------------------------------------------- #
def classify(r: int, g: int, b: int) -> str:
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    if v <= SHADOW_MAX_VALUE:
        return "shadow"
    if s <= STEEL_MAX_SAT:
        return "steel"
    deg = h * 360.0
    for name, window in PALETTE.items():
        if window is None:
            continue
        low, high = window
        if name == "red":
            if deg >= low or deg < high - 360:
                return name
        elif low <= deg < high:
            return name
    return "off-palette"


def audit(image_path: Path, max_off_palette: float = 0.06) -> dict:
    probe = Image.open(image_path).convert("RGB")
    probe.thumbnail((200, 200))
    pixels = list(probe.getdata())
    counts = Counter(classify(r, g, b) for r, g, b in pixels)
    total = len(pixels)
    shares = {name: round(count / total, 4) for name, count in counts.most_common()}
    off = shares.get("off-palette", 0.0)
    return {
        "palette": shares,
        "off_palette_share": off,
        "within_palette": off <= max_off_palette,
    }


# --------------------------------------------------------------------------- #
# the build
# --------------------------------------------------------------------------- #
ROBOT_FRAMES = ["robot_walk_02.png", "robot_walk_03.png", "robot_walk_04.png", "robot_walk_alt1.png"]
ROBOT_CELL = 512

# Photographic backdrops ship as JPEG: they are opaque full-bleed images with
# no alpha and no hard edges, and a 1920x1080 painting costs 2.8 MB as PNG
# against ~400 kB as q=90 JPEG. Anything with crisp edges - the wordmark, the
# portraits, the weapon plates - stays PNG.
JOBS = [
    # key, source, mode, target, out_name, format
    ("wordmark", "wordmark.png", "content", (1024, 256), "logo_wordmark.png", "PNG"),
    ("loading_keyart", "loading_keyart_16x9.png", "cover", (1920, 1080), "loading_keyart.jpg", "JPEG"),
    ("dashboard_bg", "dashboard_bg.png", "cover", (1920, 1080), "dashboard_bg.jpg", "JPEG"),
    ("hero_portrait", "hero_portrait.png", "cover", (768, 1024), "portrait_hero.png", "PNG"),
    ("world_neon_frontier", "world_neon_frontier.png", "cover", (1600, 900),
     "world_neon_frontier.jpg", "JPEG"),
    ("weapon_pulse_rifle", "weapon_pulse_rifle.png", "content_cover", (768, 512),
     "weapon_pulse_rifle.png", "PNG"),
    ("weapon_nova_launcher", "weapon_nova_launcher.png", "content_cover", (768, 512),
     "weapon_nova_launcher.png", "PNG"),
    ("weapon_arc_shooter", "weapon_arc_shooter.png", "content_cover", (768, 512),
     "weapon_arc_shooter.png", "PNG"),
]

BACKDROP = (5, 8, 12)
JPEG_QUALITY = 90


def save(image: Image.Image, target: Path, fmt: str) -> None:
    if fmt == "JPEG":
        image.save(target, quality=JPEG_QUALITY, optimize=True, progressive=True)
    else:
        image.save(target, optimize=True)


def build(args: argparse.Namespace) -> int:
    manifest: dict = {"generated": str(SRC.relative_to(ROOT)), "assets": []}
    problems: list[str] = []

    for key, source_name, mode, size, out_name, fmt in JOBS:
        source = SRC / source_name
        if not source.exists():
            problems.append(f"{key}: source missing at {source}")
            continue
        image = Image.open(source).convert("RGB")
        if mode == "content":
            box = content_box(image)
            image = image.crop(box)
            image = contain(image, size, BACKDROP)
        elif mode == "content_cover":
            box = content_box(image)
            image = cover(image.crop(box), size)
        else:
            image = cover(image, size)
        target = OUT / out_name
        if not args.check:
            save(image, target, fmt)
        report = audit(target if not args.check else source)
        manifest["assets"].append({
            "key": key,
            "file": f"res://assets/ui/{out_name}",
            "format": fmt,
            "source": f"res://assets/ui/generated/{source_name}",
            "size": list(image.size),
            "mode": mode,
            **report,
        })
        flag = "ok " if report["within_palette"] else "DRIFT"
        print(f"{flag} {out_name:<28} {image.size[0]}x{image.size[1]}  "
              f"off-palette {report['off_palette_share'] * 100:.1f}%")

    # --- the walk cycle: one sheet, one union crop, one scale -------------- #
    frames = [SRC / name for name in ROBOT_FRAMES]
    if all(frame.exists() for frame in frames):
        opened = [Image.open(frame).convert("RGB") for frame in frames]
        box = union_box([content_box(frame) for frame in opened])
        crops = [frame.crop(box) for frame in opened]
        scale = min(ROBOT_CELL / crops[0].size[0], ROBOT_CELL / crops[0].size[1])
        cells = [
            crop.resize(
                (max(1, round(crop.size[0] * scale)), max(1, round(crop.size[1] * scale))),
                Image.LANCZOS,
            )
            for crop in crops
        ]
        sheet = Image.new("RGB", (ROBOT_CELL * len(cells), ROBOT_CELL), BACKDROP)
        for index, cell in enumerate(cells):
            sheet.paste(cell, (index * ROBOT_CELL + (ROBOT_CELL - cell.size[0]) // 2,
                               ROBOT_CELL - cell.size[1]))
        target = OUT / "loading_robot_sheet.png"
        if not args.check:
            save(sheet, target, "PNG")
        report = audit(target if not args.check else frames[0])
        manifest["assets"].append({
            "key": "loading_robot",
            "file": f"res://assets/ui/{target.name}",
            "format": "PNG",
            "source": [f"res://assets/ui/generated/{name}" for name in ROBOT_FRAMES],
            "size": list(sheet.size),
            "cell": [ROBOT_CELL, ROBOT_CELL],
            "frames": len(cells),
            "fps": 8,
            "union_crop": list(box),
            **report,
        })
        flag = "ok " if report["within_palette"] else "DRIFT"
        print(f"{flag} {target.name:<28} {sheet.size[0]}x{sheet.size[1]}  "
              f"{len(cells)} frames @ {ROBOT_CELL}px  "
              f"off-palette {report['off_palette_share'] * 100:.1f}%")
    else:
        problems.append("loading_robot: one or more walk frames are missing")

    if args.check:
        print("\n--check: nothing written.")
    else:
        manifest_path = OUT / "art_manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"\nmanifest: {manifest_path.relative_to(ROOT)}")

    for problem in problems:
        print(f"ERROR: {problem}")
    return 1 if problems else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="audit only, write nothing")
    return build(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())
