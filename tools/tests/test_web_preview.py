#!/usr/bin/env python3
"""Unit tests for tools/web_preset.py and tools/verify_web_build.py."""

from __future__ import annotations

import sys
import struct
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import verify_web_build  # noqa: E402
import web_preset  # noqa: E402


class WebPresetTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "game").mkdir(parents=True)
        (self.root / "game" / "project.godot").write_text("config_version=5\n", encoding="utf-8")
        shell_dir = self.root / "game" / "web_shell"
        shell_dir.mkdir(parents=True)
        (shell_dir / "index.html").write_text(
            "<html><body id=\"exocomplict-shell\"><canvas id=\"canvas\"></canvas>\n"
            "$GODOT_PROJECT_NAME $GODOT_URL $GODOT_CONFIG $GODOT_THREADS_ENABLED "
            "$GODOT_HEAD_INCLUDE $GODOT_SPLASH\n</body></html>\n",
            encoding="utf-8",
        )
        self.preset_file = self.root / "game" / "export_presets.cfg"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_tool(self, *args: str) -> int:
        return web_preset.main(
            [
                "--repo-root",
                str(self.root),
                "--preset-file",
                str(self.preset_file),
                *args,
            ]
        )

    def test_ensure_creates_valid_web_preset(self) -> None:
        self.assertEqual(self.run_tool("ensure"), 0)
        text = self.preset_file.read_text(encoding="utf-8")
        self.assertIn('platform="Web"', text)
        self.assertIn('html/custom_html_shell="res://web_shell/index.html"', text)
        self.assertIn("variant/thread_support=false", text)
        presets = web_preset.base.parse_presets(text)
        self.assertEqual(len(presets), 1)
        self.assertEqual(self.run_tool("check"), 0)

    def test_ensure_is_idempotent_and_preserves_other_presets(self) -> None:
        self.run_tool("ensure")
        text = self.preset_file.read_text(encoding="utf-8")
        self.preset_file.write_text(text.replace('platform="Web"', 'platform="Android"', 1), encoding="utf-8")
        self.assertEqual(self.run_tool("ensure"), 0)
        presets = web_preset.base.parse_presets(self.preset_file.read_text(encoding="utf-8"))
        platforms = sorted(preset.platform for preset in presets)
        self.assertEqual(platforms, ["Android", "Web"], "the existing preset must survive")
        self.assertEqual(self.run_tool("check"), 0)

    def test_check_fails_when_threads_enabled_without_coop_coep(self) -> None:
        self.assertEqual(self.run_tool("ensure"), 0)
        text = self.preset_file.read_text(encoding="utf-8")
        text = text.replace("variant/thread_support=false", "variant/thread_support=true")
        self.preset_file.write_text(text, encoding="utf-8")
        self.assertEqual(self.run_tool("check"), 1)
        self.assertEqual(self.run_tool("check", "--allow-threads"), 0)

    def test_check_fails_when_shell_placeholders_missing(self) -> None:
        (self.root / "game" / "web_shell" / "index.html").write_text(
            "<html><body><canvas></canvas></body></html>\n", encoding="utf-8"
        )
        self.run_tool("ensure")
        self.assertEqual(self.run_tool("check"), 1)

    def test_check_fails_when_shell_file_absent(self) -> None:
        self.run_tool("ensure")
        (self.root / "game" / "web_shell" / "index.html").unlink()
        self.assertEqual(self.run_tool("check"), 1)

    def test_check_without_preset_file(self) -> None:
        self.assertEqual(self.run_tool("check"), 2)


def write_build(directory: Path, wasm_size: int = 6 * 1024 * 1024, declared_pck_size: int | None = None) -> None:
    """A build directory that passes every check.

    The `fileSizes` map is generated from the files actually written, because
    `verify_web_build` compares the declared sizes against the disk: a fixture
    that hard-codes 100 for a 516-byte pack is a fixture that fails, and the
    point of `declared_pck_size` is to let a test break that on purpose.
    """
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "index.js").write_text("// engine js library\n" * 200, encoding="utf-8")
    (directory / "index.wasm").write_bytes(b"\x00asm" + struct.pack("<I", 1) + b"\x00" * wasm_size)
    (directory / "index.pck").write_bytes(b"GDPC" + struct.pack("<I", 4) + b"\x00" * 512)
    (directory / "index.audio.worklet.js").write_text("// audio worklet\n", encoding="utf-8")
    # Declared sizes are read off the files, not off the requested payload size:
    # the wasm file carries an 8-byte header on top of `wasm_size`.
    pck_size = (directory / "index.pck").stat().st_size
    real_wasm_size = (directory / "index.wasm").stat().st_size
    (directory / "index.html").write_text(
        '<html><body id="exocomplict-shell"><canvas id="canvas"></canvas>\n'
        '<script src="index.js"></script>\n'
        "const GODOT_CONFIG = {"
        '"fileSizes":{"index.pck":'
        + str(pck_size if declared_pck_size is None else declared_pck_size)
        + ',"index.wasm":' + str(real_wasm_size) + "}};\n"
        "const engine = new Engine(GODOT_CONFIG);\n"
        '<!-- index.wasm index.pck -->\n'
        "</body></html>\n",
        encoding="utf-8",
    )


class VerifyWebBuildTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.build = Path(self._tmp.name) / "web"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_valid_build_passes(self) -> None:
        write_build(self.build)
        problems, notes, sizes = verify_web_build.verify(self.build)
        self.assertEqual(problems, [])
        self.assertIn("index.pck", sizes)
        self.assertIn("index.audio.worklet.js", sizes)

    def test_stale_file_sizes_fail(self) -> None:
        # The engine sizes its loading bar from this map. A pack swapped in
        # without re-exporting the shell leaves a percentage computed from a
        # size that is not there -- a progress number that is not progress.
        write_build(self.build, declared_pck_size=100)
        problems, _, _ = verify_web_build.verify(self.build)
        self.assertTrue(any("declares index.pck" in problem for problem in problems))

    def test_missing_file_sizes_fail(self) -> None:
        write_build(self.build)
        html = (self.build / "index.html").read_text(encoding="utf-8")
        (self.build / "index.html").write_text(html.replace('"fileSizes":{', '"sizes":{'), encoding="utf-8")
        problems, _, _ = verify_web_build.verify(self.build)
        self.assertTrue(any("fileSizes" in problem for problem in problems))

    def test_missing_file_fails(self) -> None:
        write_build(self.build)
        (self.build / "index.pck").unlink()
        problems, _, _ = verify_web_build.verify(self.build)
        self.assertTrue(any("index.pck" in problem for problem in problems))

    def test_wrong_magic_fails(self) -> None:
        write_build(self.build)
        (self.build / "index.pck").write_bytes(b"NOTPACK")
        (self.build / "index.wasm").write_bytes(b"NOPE")
        problems, _, _ = verify_web_build.verify(self.build)
        self.assertTrue(any("GDPC" in problem for problem in problems))
        self.assertTrue(any("WebAssembly magic" in problem for problem in problems))

    def test_default_shell_detected(self) -> None:
        write_build(self.build)
        html = (self.build / "index.html").read_text(encoding="utf-8")
        (self.build / "index.html").write_text(html.replace("exocomplict-shell", "godot-default"), encoding="utf-8")
        problems, _, _ = verify_web_build.verify(self.build)
        self.assertTrue(any("custom shell was not applied" in problem for problem in problems))

    def test_unsubstituted_placeholder_fails(self) -> None:
        write_build(self.build)
        html = (self.build / "index.html").read_text(encoding="utf-8")
        (self.build / "index.html").write_text(html.replace("<canvas", "$GODOT_PROJECT_NAME<canvas"), encoding="utf-8")
        problems, _, _ = verify_web_build.verify(self.build)
        self.assertTrue(any("unsubstituted" in problem for problem in problems))

    def test_missing_directory_fails(self) -> None:
        problems, _, _ = verify_web_build.verify(Path(self._tmp.name) / "nope")
        self.assertTrue(problems)

    def test_cli_exit_code(self) -> None:
        write_build(self.build)
        self.assertEqual(verify_web_build.main([str(self.build)]), 0)
        (self.build / "index.wasm").unlink()
        self.assertEqual(verify_web_build.main([str(self.build)]), 1)


if __name__ == "__main__":
    unittest.main()
