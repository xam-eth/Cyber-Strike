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
        metric_start = '{"schema":1,"event":"profile_start","debug_build":true}'
        metric_window = (
            '{"schema":1,"event":"frame_window","phase":"defense","wave":3,"enemies":8,'
            '"elapsed_s":5.0,"frames":300,"fps":60.0,"frame_p50_ms":16.667,'
            '"frame_p95_ms":16.667,"frame_p99_ms":16.667,"frame_max_ms":16.667,'
            '"over_33ms":0,"over_50ms":0}'
        )
        adb.write_text(
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            'printf "%s\\n" "$*" >> "$FAKE_ADB_LOG"\n'
            'if [[ "${1:-}" == "devices" ]]; then cat "$FAKE_ADB_DEVICES"; exit 0; fi\n'
            'if [[ "${1:-}" == "-s" && "${3:-}" == "install" ]]; then echo Success; exit 0; fi\n'
            'if [[ "${1:-}" == "-s" && "${3:-}" == "shell" ]]; then echo "Events injected: 1"; exit 0; fi\n'
            'if [[ "${1:-}" == "-s" && "${3:-}" == "logcat" && "${4:-}" == "-v" ]]; then\n'
            '  trap "exit 0" TERM INT\n'
            f"  echo 'I/Godot: EXOCOMPLICT_METRICS {metric_start}'\n"
            f"  echo 'I/Godot: EXOCOMPLICT_METRICS {metric_window}'\n"
            '  while :; do sleep 1; done\n'
            'fi\n'
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

    def test_timed_capture_writes_real_device_evidence_layout(self) -> None:
        output = self.directory / "evidence"
        result = self.run_usb("--profile-seconds", "1", "--profile-dir", str(output))
        raw_log = (output / "logcat.txt").read_text(encoding="utf-8") if (output / "logcat.txt").exists() else "missing"
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout + raw_log)
        calls = self.adb_calls()
        self.assertIn("-s phone-1 logcat -c", calls)
        self.assertIn("-s phone-1 shell am force-stop com.test.exocomplict", calls)
        self.assertIn("shell dumpsys gfxinfo com.test.exocomplict framestats", calls)
        self.assertIn("shell dumpsys thermalservice", calls)
        for name in (
            "report.md",
            "summary.json",
            "windows.csv",
            "raw_windows.json",
            "logcat.txt",
            "device.json",
            "gfxinfo.txt",
            "meminfo-after.txt",
            "thermal-after.txt",
        ):
            self.assertTrue((output / name).is_file(), name)
        self.assertIn("final uninstrumented release", result.stdout)

    def test_timed_capture_does_not_overwrite_existing_evidence(self) -> None:
        output = self.directory / "evidence"
        output.mkdir()
        (output / "logcat.txt").write_text("keep this evidence", encoding="utf-8")
        result = self.run_usb("--profile-seconds", "1", "--profile-dir", str(output))
        self.assertEqual(result.returncode, 1)
        self.assertIn("already contains evidence", result.stderr)
        self.assertEqual((output / "logcat.txt").read_text(encoding="utf-8"), "keep this evidence")

    def test_timed_capture_requires_launch_and_rejects_interactive_logcat(self) -> None:
        no_launch = self.run_usb("--profile-seconds", "1", "--no-launch")
        self.assertEqual(no_launch.returncode, 1)
        self.assertIn("cannot be combined", no_launch.stderr)
        interactive = self.run_usb("--profile-seconds", "1", "--logcat")
        self.assertEqual(interactive.returncode, 1)
        self.assertIn("not both", interactive.stderr)


if __name__ == "__main__":
    unittest.main()
