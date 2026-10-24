"""The Godot SVG importer rasterizes currentColor as black.

Button icon theme colors multiply the imported pixels, so a black glyph stays
black even when the button requests white. Game icons are white alpha masks;
the theme supplies their actual color at runtime. The design-board SVGs remain
unchanged because the board renderer reads their path data and colors it itself.
"""

import unittest
from pathlib import Path
from xml.etree import ElementTree


ICON_DIR = Path(__file__).resolve().parents[2] / "game" / "assets" / "ui" / "icons"


class UiIconMaskTests(unittest.TestCase):
    def test_all_game_icons_import_as_tintable_white_masks(self):
        icons = sorted(ICON_DIR.glob("*/*.svg"))
        self.assertGreaterEqual(len(icons), 34)
        for icon in icons:
            with self.subTest(icon=icon.name):
                root = ElementTree.parse(icon).getroot()
                self.assertEqual(root.attrib.get("fill"), "#ffffff")
                self.assertGreaterEqual(len(root), 1)


if __name__ == "__main__":
    unittest.main()
