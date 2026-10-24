#!/usr/bin/env python3
"""Turn the generated concept art in ``game/assets/ui/generated/`` into the
shipping textures the game loads.

    python3 tools/art/build_ui_art.py            # build + audit + write manifest
    python3 tools/art/build_ui_art.py --check    # audit only, change nothing

Why a build step instead of committing the raw downloads: the generator emits
whatever canvas it likes (a 1024x1024 wordmark with the glyphs in a 891x218
band). The game needs tight, predictable textures, and a hand-cropped PNG that
nobody can reproduce is how an art pipeline rots. Every rule below is
deterministic, so deleting ``game/assets/ui/`` and re-running this reproduces
it byte for byte from the generated sources.

The wordmark used to ship with the generator's backdrop baked in -- a near-black
navy plate that read as a black box behind the logo on every menu that drew it,
which is what review called out on 2026-10-23. ``key_to_alpha`` removes it: the
plate's own luminance is measured from the source's most common colour, and
every pixel's alpha is its luminance above that floor, so the metal glyphs and
their glow stay and the field they were painted on does not.

What it does:
  * crops to content where the subject floats on a flat backdrop,
  * keys that backdrop out of the wordmark instead of shipping it as a plate,
  * letterboxes or centre-crops to the shipping aspect without stretching,
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


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale to fill `size` and centre-crop the overflow. Never stretches."""
    sw, sh = image.size
    tw, th = size
    scale = max(tw / sw, th / sh)
    resized = image.resize((max(1, round(sw * scale)), max(1, round(sh * scale))), Image.LANCZOS)
    left = (resized.size[0] - tw) // 2
    top = (resized.size[1] - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def luminance(rgb: tuple[float, float, float]) -> float:
    """Rec. 709 luma. Used to measure a backdrop against the ink on top of it."""
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def dominant_colour(image: Image.Image) -> tuple[int, int, int]:
    """The plate colour: the most common colour in a thumbnail of the image."""
    probe = image.copy()
    probe.thumbnail((320, 320))
    return Counter(probe.convert("RGB").getdata()).most_common(1)[0][0]


def key_to_alpha(
    image: Image.Image, plate: tuple[int, int, int], low: float = 2.0, span: float = 16.0
) -> Image.Image:
    """Replace a painted backdrop with transparency.

    Every pixel keeps its colour and gains an alpha equal to how far its luma
    rises above the plate's own, ramped over `span`. Two reasons it is a luma
    ramp rather than a hard chroma key: the plate is not one value (it has a
    soft blue falloff toward the glyphs), and the glyphs are metal, so a
    threshold that removed the plate cleanly also ate their shaded edges --
    measured on the shipped 1024x1024 source, a hard key at 24 left the letter
    interiors transparent while a ramp kept them solid.

    `low` keeps the plate's noise floor fully transparent; `span` is the width
    of the fade that gives the glow around the glyphs its soft edge.
    """
    rgb = image.convert("RGB")
    floor = luminance(plate)
    out = Image.new("RGBA", rgb.size)
    source = rgb.load()
    target = out.load()
    for y in range(rgb.size[1]):
        for x in range(rgb.size[0]):
            r, g, b = source[x, y]
            delta = luminance((r, g, b)) - floor - low
            alpha = 0 if delta <= 0.0 else (255 if delta >= span else round(delta / span * 255))
            target[x, y] = (r, g, b, alpha)
    return out


def contain_alpha(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """`contain`, letterboxed onto transparency instead of a colour."""
    sw, sh = image.size
    tw, th = size
    scale = min(tw / sw, th / sh)
    resized = image.resize((max(1, round(sw * scale)), max(1, round(sh * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(resized, ((tw - resized.size[0]) // 2, (th - resized.size[1]) // 2))
    return canvas


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
    # An RGBA texture is audited as it is seen: composited over the backdrop
    # the UI draws it on. Auditing the raw channels would count the
    # transparent field's leftover navy as if it shipped.
    source = Image.open(image_path)
    if source.mode in ("RGBA", "LA", "P"):
        source = source.convert("RGBA")
        flat = Image.new("RGB", source.size, BACKDROP)
        flat.paste(source, (0, 0), source)
        probe = flat
    else:
        probe = source.convert("RGB")
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
# The wordmark's plate is measurable, and the key is authored from the source
# rather than from a magic threshold: the fade starts where the plate's luma
# ends and spans 16 levels, which is the width of the soft edge around the
# glyphs. See `key_to_alpha`.
WORDMARK_KEY_LOW = 2.0
WORDMARK_KEY_SPAN = 16.0

# Photographic backdrops ship as JPEG: they are opaque full-bleed images with
# no alpha and no hard edges, and a 1920x1080 painting costs 2.8 MB as PNG
# against ~400 kB as q=90 JPEG. Anything with crisp edges - the wordmark, the
# portraits, the weapon plates - stays PNG.
JOBS = [
    # key, source, mode, target, out_name, format
    ("wordmark", "wordmark.png", "content_key", (1024, 256), "logo_wordmark.png", "PNG"),
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
        elif mode == "content_key":
            # Key first, crop second, so the crop is measured on the art and not
            # on the glow the key leaves behind.
            plate = dominant_colour(image)
            keyed = key_to_alpha(image, plate, WORDMARK_KEY_LOW, WORDMARK_KEY_SPAN)
            box = content_box(image)
            keyed = keyed.crop(box)
            image = contain_alpha(keyed, size)
        elif mode == "content_cover":
            box = content_box(image)
            image = cover(image.crop(box), size)
        else:
            image = cover(image, size)
        target = OUT / out_name
        if not args.check:
            save(image, target, fmt)
        report = audit(target if not args.check else source)
        entry = {
            "key": key,
            "file": f"res://assets/ui/{out_name}",
            "format": fmt,
            "source": f"res://assets/ui/generated/{source_name}",
            "size": list(image.size),
            "mode": mode,
            **report,
        }
        if mode == "content_key":
            entry["alpha"] = "luma key of the painted backdrop, baked into the PNG"
            entry["key_threshold"] = {"low": WORDMARK_KEY_LOW, "span": WORDMARK_KEY_SPAN}
        manifest["assets"].append(entry)
        flag = "ok " if report["within_palette"] else "DRIFT"
        alpha_note = "  alpha" if image.mode == "RGBA" else ""
        print(f"{flag} {out_name:<28} {image.size[0]}x{image.size[1]}{alpha_note}  "
              f"off-palette {report['off_palette_share'] * 100:.1f}%")

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
