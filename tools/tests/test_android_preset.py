#!/usr/bin/env python3
"""Unit tests for tools/android_preset.py (run by scripts/dev_check.sh and CI)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import android_preset  # noqa: E402  (path is set above)


class AndroidPresetTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.preset_file = Path(self._tmp.name) / "export_presets.cfg"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_tool(self, *args: str) -> int:
        argv: list[str] = []
        for arg in args:
            argv.append(str(arg))
        return android_preset.main(["--preset-file", str(self.preset_file), *argv])

    def read(self) -> str:
        return self.preset_file.read_text(encoding="utf-8")

    def test_scaffold_creates_valid_android_preset(self) -> None:
        self.assertEqual(
            self.run_tool(
                "scaffold",
                "--package-id",
                "com.studio.exocomplict",
                "--app-name",
                "Exocomplict",
                "--version-code",
                "3",
                "--version-name",
                "0.2.0",
            ),
            0,
        )
        presets = android_preset.parse_presets(self.read())
        self.assertEqual(len(presets), 1)
        preset = presets[0]
        self.assertEqual(preset.name, "Android")
        self.assertEqual(preset.platform, "Android")
        self.assertEqual(preset.option("package/unique_name"), "com.studio.exocomplict")
        self.assertEqual(preset.option("version/code"), "3")
        self.assertEqual(preset.option("architectures/arm64-v8a"), "true")
        self.assertEqual(preset.option("architectures/armeabi-v7a"), "false")
        self.assertEqual(self.run_tool("check", "--preset-name", "Android"), 0)

    def test_scaffold_refuses_to_overwrite_without_force(self) -> None:
        self.run_tool("scaffold")
        original = self.read()
        self.assertEqual(self.run_tool("scaffold", "--package-id", "com.other.app"), 2)
        self.assertEqual(self.read(), original)

    def test_patch_updates_only_requested_fields_and_backs_up(self) -> None:
        self.run_tool("scaffold", "--package-id", "com.studio.exocomplict")
        self.assertEqual(
            self.run_tool(
                "patch",
                "--package-id",
                "com.studio.exocomplict",
                "--app-name",
                "Renamed",
                "--version-code",
                "9",
                "--arch",
                "arm64-v8a,armeabi-v7a",
            ),
            0,
        )
        text = self.read()
        preset = android_preset.parse_presets(text)[0]
        self.assertEqual(preset.option("package/name"), "Renamed")
        self.assertEqual(preset.option("version/code"), "9")
        self.assertEqual(preset.option("architectures/armeabi-v7a"), "true")
        backups = list(self.preset_file.parent.glob("export_presets.cfg.bak-*"))
        self.assertEqual(len(backups), 1, "patch must keep a timestamped backup")

    def test_patch_is_idempotent(self) -> None:
        self.run_tool("scaffold", "--package-id", "com.studio.exocomplict")
        args = ("patch", "--package-id", "com.studio.exocomplict", "--version-code", "2")
        self.assertEqual(self.run_tool(*args), 0)
        after_first = self.read()
        self.assertEqual(self.run_tool(*args), 0)
        self.assertEqual(self.read(), after_first, "second identical patch must not rewrite the file")

    def test_check_rejects_example_package_id(self) -> None:
        self.run_tool("scaffold", "--package-id", "com.example.exocomplict")
        self.assertEqual(self.run_tool("check", "--preset-name", "Android"), 1)
        self.run_tool("patch", "--package-id", "com.studio.exocomplict")
        self.assertEqual(self.run_tool("check", "--preset-name", "Android"), 0)

    def test_check_requires_at_least_one_architecture(self) -> None:
        self.run_tool("scaffold", "--package-id", "com.studio.exocomplict")
        self.assertEqual(self.run_tool("patch", "--arch", ""), 0)
        self.assertEqual(self.run_tool("check", "--preset-name", "Android"), 1)

    def test_emulator_only_build_passes_with_note(self) -> None:
        self.run_tool("scaffold", "--package-id", "com.studio.exocomplict", "--arch", "x86_64")
        self.assertEqual(self.run_tool("check", "--preset-name", "Android"), 0)

    def test_check_reports_missing_preset_file(self) -> None:
        self.assertEqual(self.run_tool("check"), 2)

    def test_scaffold_rejects_unknown_architecture(self) -> None:
        with self.assertRaises(SystemExit):
            self.run_tool("scaffold", "--arch", "mips")


if __name__ == "__main__":
    unittest.main()
