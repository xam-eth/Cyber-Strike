#!/usr/bin/env python3
"""Fake-ADB contracts for native visual capture; never physical-device evidence."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "android_visual.sh"


class AndroidVisualTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.directory = Path(self._tmp.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.remote = self.directory / "remote"
        self.remote.mkdir()
        self.calls = self.directory / "calls.jsonl"
        self.devices = self.directory / "devices.txt"
        self.devices.write_text(
            "List of devices attached\nphone-1\tdevice\n", encoding="utf-8"
        )
        adb = self.bin / "adb"
        adb.write_text(
            r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import struct
import sys
import zlib

args = sys.argv[1:]
root = Path(os.environ["FAKE_ADB_DIR"])
with (root / "calls.jsonl").open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(args) + "\n")
if args == ["devices"]:
    sys.stdout.write((root / "devices.txt").read_text(encoding="utf-8"))
    raise SystemExit(0)
if len(args) < 3 or args[0] != "-s":
    print("unexpected adb args", args, file=sys.stderr)
    raise SystemExit(2)
args = args[2:]

def chunk(kind, payload):
    crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)

def png():
    header = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    pixels = zlib.compress(b"\x00\x00\x00\x00\x00")
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", pixels) + chunk(b"IEND", b"")

if args[:2] == ["exec-out", "screencap"]:
    if os.environ.get("FAKE_ADB_BAD_PNG") == "1":
        sys.stdout.buffer.write(b"not a png")
    else:
        sys.stdout.buffer.write(png())
    raise SystemExit(0)
if args[:2] == ["shell", "getprop"]:
    values = {
        "ro.product.model": "Fake Phone",
        "ro.build.version.release": "15",
        "ro.build.version.sdk": "35",
        "ro.product.cpu.abi": "arm64-v8a",
    }
    print(values.get(args[2], ""))
    raise SystemExit(0)
if args[:2] == ["shell", "wm"]:
    print("Physical size: 2400x1080" if args[2] == "size" else "Physical density: 420")
    raise SystemExit(0)
if args[:3] == ["shell", "dumpsys", "package"]:
    print("versionCode=42 minSdk=24\nversionName=0.4.2")
    raise SystemExit(0)
if args[:3] == ["shell", "dumpsys", "window"]:
    print("mCurrentFocus=Window{abc u0 com.test.exocomplict/com.godot.game.GodotApp}")
    raise SystemExit(0)
if args[:2] == ["shell", "monkey"]:
    print("Events injected: 1")
    raise SystemExit(0)
if args[:2] == ["shell", "screenrecord"]:
    if os.environ.get("FAKE_ADB_RECORD_FAIL") == "1":
        print("synthetic recording failure", file=sys.stderr)
        raise SystemExit(1)
    remote = root / "remote" / Path(args[-1]).name
    remote.write_bytes(struct.pack(">I4s4sI4s", 20, b"ftyp", b"isom", 0, b"isom") + b"\x00\x00\x00\x08free")
    print("synthetic recording", file=sys.stderr)
    raise SystemExit(0)
if args[0] == "pull":
    source = root / "remote" / Path(args[1]).name
    shutil.copyfile(source, args[2])
    print("1 file pulled")
    raise SystemExit(0)
if args[:2] == ["shell", "rm"]:
    (root / "remote" / Path(args[-1]).name).unlink(missing_ok=True)
    raise SystemExit(0)
print("unexpected adb args", args, file=sys.stderr)
raise SystemExit(2)
''',
            encoding="utf-8",
        )
        adb.chmod(0o755)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_visual(self, *args: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(
            {
                "ADB_BIN": str(self.bin / "adb"),
                "ANDROID_PACKAGE_ID": "com.test.exocomplict",
                "ANDROID_SERIAL": "",
                "FAKE_ADB_DIR": str(self.directory),
            }
        )
        env.pop("FAKE_ADB_BAD_PNG", None)
        env.pop("FAKE_ADB_RECORD_FAIL", None)
        return subprocess.run(
            [str(SCRIPT), *args],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def adb_calls(self) -> list[list[str]]:
        if not self.calls.exists():
            return []
        return [json.loads(line) for line in self.calls.read_text(encoding="utf-8").splitlines()]

    def test_shot_writes_native_image_and_pending_review_metadata(self) -> None:
        output = self.directory / "shot"
        result = self.run_visual(
            "shot",
            "--label",
            "hud-safe-area",
            "--output",
            str(output),
            "--launch",
            "--settle-seconds",
            "0",
        )
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        run = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run["capture_status"], "captured")
        self.assertEqual(run["visual_review"], "PENDING")
        self.assertFalse(run["performance_evidence"])
        self.assertEqual(run["device"]["model"], "Fake Phone")
        self.assertEqual(run["device"]["installed_version_name"], "0.4.2")
        self.assertEqual(run["source"]["installed_build_matches_checkout"], "UNKNOWN")
        self.assertEqual(run["artifacts"][0]["width"], 1)
        self.assertEqual(run["artifacts"][0]["height"], 1)
        self.assertTrue((output / "screen.png").is_file())
        self.assertIn("not performance evidence", result.stdout)
        self.assertIn("does not prove which source", (output / "report.md").read_text(encoding="utf-8"))
        self.assertTrue(any(call[:3] == ["-s", "phone-1", "shell"] and "monkey" in call for call in self.adb_calls()))

    def test_record_writes_video_before_after_and_no_performance_capture(self) -> None:
        output = self.directory / "record"
        result = self.run_visual(
            "record", "--seconds", "1", "--label", "reload-animation", "--output", str(output)
        )
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        run = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run["capture_status"], "captured")
        self.assertEqual(run["requested_seconds"], 1)
        self.assertEqual(
            [artifact["path"] for artifact in run["artifacts"]],
            ["before.png", "motion.mp4", "after.png"],
        )
        for name in ("before.png", "motion.mp4", "after.png", "screenrecord.log", "report.md"):
            self.assertTrue((output / name).is_file(), name)
        calls = self.adb_calls()
        self.assertTrue(any("screenrecord" in call and "--time-limit" in call for call in calls))
        self.assertFalse(any("logcat" in call or "gfxinfo" in call for call in calls))
        self.assertTrue(any("motion.mp4.part" in call[-1] for call in calls if call and call[-1].endswith(".part")))

    def test_invalid_png_is_a_failed_capture_not_a_visual_pass(self) -> None:
        output = self.directory / "invalid"
        env = os.environ.copy()
        env["FAKE_ADB_BAD_PNG"] = "1"
        # run_visual constructs a clean environment, so invoke with the failure injected through a wrapper.
        result = subprocess.run(
            [str(SCRIPT), "shot", "--output", str(output)],
            cwd=ROOT,
            env={
                **env,
                "ADB_BIN": str(self.bin / "adb"),
                "ANDROID_PACKAGE_ID": "com.test.exocomplict",
                "FAKE_ADB_DIR": str(self.directory),
            },
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        run = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run["capture_status"], "failed")
        self.assertFalse((output / "screen.png").exists())
        self.assertIn("bad signature", run["error"])
        self.assertIn("Capture status: **failed**", (output / "report.md").read_text(encoding="utf-8"))

    def test_screenrecord_failure_preserves_diagnostics_without_video_success(self) -> None:
        output = self.directory / "record-failure"
        env = os.environ.copy()
        result = subprocess.run(
            [str(SCRIPT), "record", "--seconds", "1", "--output", str(output)],
            cwd=ROOT,
            env={
                **env,
                "ADB_BIN": str(self.bin / "adb"),
                "ANDROID_PACKAGE_ID": "com.test.exocomplict",
                "FAKE_ADB_DIR": str(self.directory),
                "FAKE_ADB_RECORD_FAIL": "1",
            },
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        run = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run["capture_status"], "failed")
        self.assertFalse((output / "motion.mp4").exists())
        self.assertIn("synthetic recording failure", (output / "screenrecord.log").read_text(encoding="utf-8"))

    def test_multiple_devices_require_an_explicit_serial(self) -> None:
        self.devices.write_text(
            "List of devices attached\nphone-1\tdevice\nphone-2\tdevice\n",
            encoding="utf-8",
        )
        output = self.directory / "ambiguous"
        result = self.run_visual("shot", "--output", str(output))
        self.assertEqual(result.returncode, 1)
        self.assertIn("--serial", result.stderr)
        self.assertFalse(output.exists())

    def test_unauthorized_device_is_not_used(self) -> None:
        self.devices.write_text(
            "List of devices attached\nphone-1\tunauthorized\n", encoding="utf-8"
        )
        output = self.directory / "unauthorized"
        result = self.run_visual("shot", "--serial", "phone-1", "--output", str(output))
        self.assertEqual(result.returncode, 1)
        self.assertIn("not online/authorized", result.stderr)
        self.assertFalse(output.exists())
        self.assertFalse(any("screencap" in call for call in self.adb_calls()))

    def test_existing_evidence_is_not_overwritten(self) -> None:
        output = self.directory / "existing"
        output.mkdir()
        (output / "run.json").write_text("keep this evidence", encoding="utf-8")
        result = self.run_visual("shot", "--output", str(output))
        self.assertEqual(result.returncode, 1)
        self.assertIn("not empty", result.stderr)
        self.assertEqual((output / "run.json").read_text(encoding="utf-8"), "keep this evidence")

    def test_record_rejects_duration_beyond_android_limit(self) -> None:
        result = self.run_visual("record", "--seconds", "181")
        self.assertEqual(result.returncode, 1)
        self.assertIn("between 1 and 180", result.stderr)


if __name__ == "__main__":
    unittest.main()
