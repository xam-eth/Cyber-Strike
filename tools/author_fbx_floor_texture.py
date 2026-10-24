"""Author restrained 2 x 2 deck-panel colour maps for the user's UV-mapped FBX floors.

The source FBX imports carry UVs, but no linked image: Floor_Squared_01_6x6
samples U/V 0..0.5 and Floor_Angle_01_6x6 samples U 0.5..1, V 0..0.5.
A 256px quadrant therefore covers one 6m FBX surface. Repeat it four times
in the 512px image rather than changing/importing new geometry or corrupting
UVs. Requires Pillow only when regenerating; Godot/Web loads the PNGs directly.
"""

from __future__ import annotations

from pathlib import Path
import random
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "game/assets/world/scifi_starter_kit/materials"


def panel_texture(alternate: bool) -> Image.Image:
    rng = random.Random(809 if alternate else 703)
    image = Image.new("RGB", (256, 256), (80, 101, 114))
    px = image.load()
    for y in range(256):
        for x in range(256):
            grain = rng.randrange(-5, 6)
            edge = min(x % 128, y % 128, 127 - x % 128, 127 - y % 128)
            # The lighter bevel and dark gasket outline separate machined
            # 3m plates without a full-size glowing grid under the crosshair.
            if edge < 2:
                base = (32, 48, 59)
            elif edge < 5:
                base = (51, 70, 81)
            elif edge < 7:
                base = (109, 132, 141)
            else:
                base = (84, 103, 115) if (x // 128 + y // 128) % 2 else (93, 112, 123)
            # Subtle horizontal rolling marks; no random high-energy speckles.
            micro = 3 if y % 19 == 0 else (-2 if y % 23 == 0 else 0)
            px[x, y] = tuple(max(0, min(255, c + grain + micro)) for c in base)
    d = ImageDraw.Draw(image, "RGB")
    for row in range(2):
        for col in range(2):
            x0, y0 = col * 128, row * 128
            # Recessed access rectangle and short linework read in perspective
            # as manufactured panels rather than hand-drawn checkerboard.
            d.line([(x0 + 20, y0 + 32), (x0 + 105, y0 + 32)], fill=(74, 92, 102), width=2)
            d.line([(x0 + 22, y0 + 29), (x0 + 91, y0 + 29)], fill=(117, 139, 149), width=1)
            d.line([(x0 + 25, y0 + 94), (x0 + 99, y0 + 94)], fill=(64, 81, 93), width=2)
            for bx, by in ((x0 + 15, y0 + 15), (x0 + 112, y0 + 112)):
                d.ellipse((bx - 2, by - 2, bx + 2, by + 2), fill=(32, 47, 57))
                d.point((bx, by), fill=(147, 165, 175))
    if alternate:
        # One scuffed amber warning chevron in each 6m alternative plate. It
        # guides direction without coating the imported floor in neon paint.
        d.line([(138, 14), (236, 14), (236, 112)], fill=(130, 92, 42), width=3)
        d.line([(142, 17), (233, 17), (233, 106)], fill=(172, 123, 58), width=2)
        for off in (0, 18, 36, 54):
            d.line([(27 + off, 107), (42 + off, 107)], fill=(133, 101, 61), width=2)
    # The meshes use individual atlas quadrants, not a full 0..1 UV square.
    # Fill every quadrant so either imported UV island sees a complete deck.
    atlas = Image.new("RGB", (512, 512))
    for y in (0, 256):
        for x in (0, 256):
            atlas.paste(image, (x, y))
    return atlas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for key, alt in (("fbx_deck", False), ("fbx_deck_caution", True)):
        panel_texture(alt).save(OUT / (key + ".png"), optimize=True)
        print(OUT / (key + ".png"))


if __name__ == "__main__":
    main()
