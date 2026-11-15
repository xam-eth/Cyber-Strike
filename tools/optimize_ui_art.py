#!/usr/bin/env python3
"""Downscale oversized UI art to display-appropriate resolutions.

The web PCK ships imported .ctex textures whose size tracks source pixels, and
several menu/loading images were authored at 1600-2048 px while the largest
runtime surface is a 1280x720 web canvas (mobile landscape tops out at
844x390 physical). This resizes those sources in place — same filenames,
same formats, so every reference stays valid — leaving world PBR textures
and character art untouched.

    python3 tools/optimize_ui_art.py [--dry-run]
"""
import argparse
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# display-aware targets: full-screen art 1280 px wide (1x web), cards/portraits
# ~800-900 px (2x of a ~40% dashboard card), weapon cards 800 px.
TARGETS = {
    "game/assets/ui/generated/loading_keyart_16x9.png": (1280, 720),
    "game/assets/ui/loading_keyart.jpg": (1280, 720),
    "game/assets/ui/dashboard_bg.jpg": (1280, 720),
    "game/assets/ui/generated/dashboard_bg.png": (1024, 576),
    "game/assets/ui/world_aetherfall.jpg": (896, 504),
    "game/assets/ui/generated/world_aetherfall.png": (896, 486),
    "game/assets/ui/generated/hero_portrait.png": (640, 858),
    "game/assets/ui/portrait_hero.png": (640, 858),
    "game/assets/ui/generated/weapon_nova_launcher.png": (800, 597),
    "game/assets/ui/generated/weapon_arc_shooter.png": (800, 436),
    "game/assets/ui/generated/weapon_pulse_rifle.png": (800, 597),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    for rel, (tw, th) in TARGETS.items():
        path = os.path.join(ROOT, rel)
        im = Image.open(path)
        w, h = im.size
        if w <= tw and h <= th:
            print(f"keep {rel} {w}x{h}")
            continue
        im2 = im.resize((tw, th), Image.LANCZOS)
        if not args.dry_run:
            if rel.endswith(".jpg"):
                im2.save(path, "JPEG", quality=92, subsampling=0)
            else:
                im2.save(path, "PNG", optimize=True)
        print(f"{'would resize' if args.dry_run else 'resized'} {rel} {w}x{h} -> {tw}x{th}")


if __name__ == "__main__":
    main()
