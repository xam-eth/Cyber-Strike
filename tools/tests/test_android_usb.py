#!/usr/bin/env python3
"""Contract tests for the USB update path; no physical Android device needed."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "android_usb.sh"


class AndroidUsbTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.directory = Path(self._tmp.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.adb_log = self.directory / "adb.log"
        self.devices = self.directory / "devices.txt"
        self.devices.write_text("List of devices attached\nphone-1\tdevice\n", encoding="utf-8")
        self.apk = self.directory / "game.apk"
        self.apk.write_bytes(b"fake APK used only for argument-contract tests")
        self.preset = self.directory / "export_presets.cfg"
        self.preset.write_text(
            "[preset.0]\n"
            'name="Android"\n'
            'platform="Android"\n'
            "[preset.0.options]\n"
            'package/unique_name="com.test.exocomplict"\n',
            encoding="utf-8",
        )
        adb = self.bin / "adb"
        adb.write_text(
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            'printf "%s\\n" "$*" >> "$FAKE_ADB_LOG"\n'
            'if [[ "${1:-}" == "devices" ]]; then cat "$FAKE_ADB_DEVICES"; exit 0; fi\n'
            'if [[ "${1:-}" == "-s" && "${3:-}" == "install" ]]; then echo Success; exit 0; fi\n'
            'if [[ "${1:-}" == "-s" && "${3:-}" == "shell" ]]; then echo "Events injected: 1"; exit 0; fi\n'
            'if [[ "${1:-}" == "-s" && "${3:-}" == "logcat" ]]; then exit 0; fi\n'
            'echo "unexpected adb args: $*" >&2; exit 2\n',
            encoding="utf-8",
        )
        adb.chmod(0o755)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_usb(self, *args: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(
            {
                "PATH": str(self.bin) + os.pathsep + env["PATH"],
                "FAKE_ADB_LOG": str(self.adb_log),
                "FAKE_ADB_DEVICES": str(self.devices),
                "ANDROID_PRESET_FILE": str(self.preset),
                "ANDROID_APK_PATH": str(self.apk),
                "GODOT_BIN": "/must/not/be/called/in/skip-build/mode",
            }
        )
        return subprocess.run(
            [str(SCRIPT), "--skip-build", *args],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def adb_calls(self) -> str:
        return self.adb_log.read_text(encoding="utf-8") if self.adb_log.exists() else ""

    def test_install_update_relaunches_without_uninstall(self) -> None:
        result = self.run_usb()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        calls = self.adb_calls()
        self.assertIn(f"-s phone-1 install -r {self.apk}", calls)
        self.assertIn("-s phone-1 shell monkey -p com.test.exocomplict", calls)
        self.assertNotIn("uninstall", calls)
        self.assertNotIn("pm clear", calls)
        self.assertIn("does not need the web server", result.stdout)

    def test_install_only_skips_launch(self) -> None:
        result = self.run_usb("--no-launch")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        calls = self.adb_calls()
        self.assertIn("install -r", calls)
        self.assertNotIn("monkey", calls)

    def test_multiple_devices_require_an_explicit_serial(self) -> None:
        self.devices.write_text(
            "List of devices attached\nphone-1\tdevice\nphone-2\tdevice\n",
            encoding="utf-8",
        )
        result = self.run_usb()
        self.assertEqual(result.returncode, 1)
        self.assertIn("--serial", result.stderr)
        self.assertNotIn("install -r", self.adb_calls())

    def test_unauthorized_device_is_not_used(self) -> None:
        self.devices.write_text("List of devices attached\nphone-1\tunauthorized\n", encoding="utf-8")
        result = self.run_usb("--serial", "phone-1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("unauthorized", result.stderr)
        self.assertNotIn("install -r", self.adb_calls())


if __name__ == "__main__":
    unittest.main()
