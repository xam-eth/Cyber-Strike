"""Tests for the Android performance evidence parser."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.android_perf_report import load_log, write_report


def window(phase: str, elapsed: float, frames: int, p95: float, p99: float) -> dict:
    return {
        "schema": 1,
        "event": "frame_window",
        "phase": phase,
        "wave": 3,
        "enemies": 8,
        "elapsed_s": elapsed,
        "frames": frames,
        "fps": frames / elapsed,
        "frame_p50_ms": 16.667,
        "frame_p95_ms": p95,
        "frame_p99_ms": p99,
        "frame_max_ms": p99,
        "over_33ms": 1,
        "over_50ms": 0,
        "draw_calls": 40,
        "video_mb": 120.0,
    }


class AndroidPerfReportTests(unittest.TestCase):
    def test_logcat_noise_and_malformed_lines_are_handled(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / "logcat.txt"
            log.write_text(
                "I/Godot: ordinary line\n"
                "I/Godot: EXOCOMPLICT_METRICS not-json\n"
                'I/Godot: EXOCOMPLICT_METRICS {"schema":1,"event":"profile_start","device_model":"Pixel"}\n',
                encoding="utf-8",
            )
            starts, windows, malformed = load_log(log)
            self.assertEqual(len(starts), 1)
            self.assertEqual(windows, [])
            self.assertEqual(malformed, 1)

    def test_report_preserves_windows_and_does_not_fake_global_percentiles(self) -> None:
        samples = [window("prepare", 5.0, 300, 16.0, 20.0), window("defense", 10.0, 500, 40.0, 60.0)]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            log = root / "logcat.txt"
            lines = [
                'I/Godot: EXOCOMPLICT_METRICS {"schema":1,"event":"profile_start","device_model":"Test Device","debug_build":true}'
            ]
            lines.extend("I/Godot: EXOCOMPLICT_METRICS " + json.dumps(sample) for sample in samples)
            log.write_text("\n".join(lines), encoding="utf-8")
            summary = write_report(log, root / "report")
            self.assertEqual(summary["overall"]["frames"], 800)
            self.assertEqual(summary["overall"]["elapsed_s"], 15.0)
            self.assertEqual(summary["overall"]["weighted_fps"], 53.33)
            self.assertEqual(summary["overall"]["worst_window_p95_ms"], 40.0)
            self.assertEqual(summary["overall"]["worst_window_p99_ms"], 60.0)
            self.assertNotIn("frame_p95_ms", summary["overall"])
            self.assertEqual(summary["phases"]["defense"]["weighted_fps"], 50.0)
            self.assertTrue(summary["device"]["debug_build"])
            self.assertEqual(len(json.loads((root / "report/raw_windows.json").read_text())), 2)
            self.assertIn("Worst window p95", (root / "report/report.md").read_text())
            self.assertEqual(len((root / "report/windows.csv").read_text().splitlines()), 3)

    def test_no_metrics_is_an_explicit_error(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            log = root / "logcat.txt"
            log.write_text("I/Godot: no profiler here\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "No frame_window metrics"):
                write_report(log, root / "report")


if __name__ == "__main__":
    unittest.main()
