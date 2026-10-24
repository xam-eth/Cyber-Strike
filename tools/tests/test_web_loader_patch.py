#!/usr/bin/env python3
"""Regression tests for the Godot Web initialization rejection patch."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import web_loader_patch  # noqa: E402


class WebLoaderPatchTests(unittest.TestCase):
    def test_patch_forwards_all_three_failures_and_is_idempotent(self) -> None:
        source = f"function doInit() {{\n{web_loader_patch.ORIGINAL_BLOCK}}}\n"
        patched, changed = web_loader_patch.patch_text(source)
        self.assertTrue(changed)
        self.assertEqual(patched.count("}, reject);"), 3)
        self.assertTrue(web_loader_patch.is_patched(patched))
        again, changed_again = web_loader_patch.patch_text(patched)
        self.assertFalse(changed_again)
        self.assertEqual(again, patched)

    def test_patch_refuses_changed_exporter_output(self) -> None:
        with self.assertRaisesRegex(ValueError, "did not match exactly"):
            web_loader_patch.patch_text("function differentLoader() {}\n")

    def test_cli_patches_a_real_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            loader = Path(directory) / "index.js"
            loader.write_text(web_loader_patch.ORIGINAL_BLOCK, encoding="utf-8")
            self.assertEqual(web_loader_patch.main([str(loader)]), 0)
            self.assertTrue(web_loader_patch.is_patched(loader.read_text(encoding="utf-8")))

    def test_committed_preview_has_the_rejection_patch(self) -> None:
        loader = ROOT / "web" / "index.js"
        if not loader.exists():
            self.skipTest("the optional generated Web preview is not present")
        self.assertTrue(
            web_loader_patch.is_patched(loader.read_text(encoding="utf-8")),
            "run tools/web_loader_patch.py web/index.js or export through scripts/export_web_preview.sh",
        )


if __name__ == "__main__":
    unittest.main()
