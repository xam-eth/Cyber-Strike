#!/usr/bin/env python3
"""Synthetic-image tests for visual comparison and explicit reference approval."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "visual_review.py"


class VisualReviewTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "tools").mkdir(parents=True)
        self.current_dir = self.root / "exports" / "current"
        self.current_dir.mkdir(parents=True)
        self.profile = "test-web"
        self.reference = (
            self.root / "qa-evidence" / "visual-goldens" / self.profile / "case-a.png"
        )
        self.reference.parent.mkdir(parents=True)
        self.current = self.current_dir / "current.png"
        self.manifest = self.root / "tools" / "visual_review.json"
        self.write_manifest()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    @staticmethod
    def image(path: Path, color=(0, 0, 0, 255), size=(4, 3)) -> None:
        Image.new("RGBA", size, color).save(path)

    def write_manifest(self, reference: str | None = None) -> None:
        reference = reference or "qa-evidence/visual-goldens/test-web/case-a.png"
        value = {
            "schema": 1,
            "profiles": {
                self.profile: {
                    "environment": {"platform": "test"},
                    "current_root": "exports/current",
                    "cases": [
                        {
                            "id": "case-a",
                            "current": "current.png",
                            "reference": reference,
                            "channel_tolerance": 0.0,
                            "max_diff_ratio": 0.0,
                            "notes": "synthetic test image",
                        }
                    ],
                }
            },
        }
        self.manifest.write_text(json.dumps(value), encoding="utf-8")

    def run_tool(self, *args: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["VISUAL_REVIEW_ROOT"] = str(self.root)
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=self.root,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def compare(self, name: str, *extra: str) -> tuple[subprocess.CompletedProcess[str], Path]:
        output = self.root / "exports" / name
        result = self.run_tool(
            "compare", "--profile", self.profile, "--out", str(output), *extra
        )
        return result, output

    @staticmethod
    def report(output: Path) -> dict:
        return json.loads((output / "visual-review.json").read_text(encoding="utf-8"))

    @staticmethod
    def report_sha256(output: Path) -> str:
        return hashlib.sha256((output / "visual-review.json").read_bytes()).hexdigest()

    def test_identical_images_match_and_write_all_review_surfaces(self) -> None:
        self.image(self.current, (20, 40, 60, 255))
        self.image(self.reference, (20, 40, 60, 255))
        result, output = self.compare("match")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        report = self.report(output)
        self.assertEqual(report["overall_status"], "MATCH")
        self.assertEqual(report["cases"][0]["metrics"]["diff_ratio"], 0)
        self.assertTrue((output / "cases" / "case-a" / "diff.png").is_file())
        self.assertTrue((output / "index.html").is_file())
        self.assertIn("not human aesthetic approval", (output / "report.md").read_text(encoding="utf-8"))

    def test_real_change_requires_review_even_when_pending_is_allowed(self) -> None:
        self.image(self.current, (255, 255, 255, 255))
        self.image(self.reference, (0, 0, 0, 255))
        result, output = self.compare("changed", "--allow-pending")
        self.assertEqual(result.returncode, 1)
        case = self.report(output)["cases"][0]
        self.assertEqual(case["status"], "REVIEW_REQUIRED")
        self.assertEqual(case["metrics"]["diff_ratio"], 1.0)
        with Image.open(output / case["diff_artifact"]) as diff:
            self.assertEqual(diff.convert("RGBA").getpixel((0, 0)), (255, 32, 72, 255))

    def test_channel_tolerance_is_explicit_and_separate_from_any_change(self) -> None:
        self.image(self.current, (102, 100, 100, 255))
        self.image(self.reference, (100, 100, 100, 255))
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        manifest["profiles"][self.profile]["cases"][0]["channel_tolerance"] = 0.02
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        result, output = self.compare("tolerance")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        metrics = self.report(output)["cases"][0]["metrics"]
        self.assertEqual(metrics["changed_pixels"], 12)
        self.assertEqual(metrics["changed_ratio"], 1.0)
        self.assertEqual(metrics["different_pixels"], 0)
        self.assertEqual(metrics["diff_ratio"], 0.0)

    def test_dimension_mismatch_is_an_error_and_is_never_resized(self) -> None:
        self.image(self.current, size=(5, 3))
        self.image(self.reference, size=(4, 3))
        result, output = self.compare("dimensions")
        self.assertEqual(result.returncode, 1)
        case = self.report(output)["cases"][0]
        self.assertEqual(case["status"], "ERROR")
        self.assertFalse(case["metrics"]["dimensions_match"])
        self.assertNotIn("diff_artifact", case)
        self.assertIn("no resizing", case["error"])

    def test_missing_baseline_is_pending_then_named_report_image_can_be_approved(self) -> None:
        self.image(self.current, (12, 34, 56, 255))
        blocked, _ = self.compare("pending-blocked")
        self.assertEqual(blocked.returncode, 1)
        result, output = self.compare("pending", "--allow-pending")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(self.report(output)["overall_status"], "BASELINE_PENDING")
        approved = self.run_tool(
            "approve",
            "--report",
            str(output / "visual-review.json"),
            "--report-sha256",
            self.report_sha256(output),
            "--case",
            "case-a",
            "--reviewer",
            "Test Reviewer",
            "--note",
            "Synthetic approval-contract fixture",
        )
        self.assertEqual(approved.returncode, 0, approved.stderr + approved.stdout)
        self.assertEqual(
            hashlib.sha256(self.reference.read_bytes()).hexdigest(),
            hashlib.sha256(self.current.read_bytes()).hexdigest(),
        )
        ledger = json.loads(
            (self.reference.parent / "approvals.json").read_text(encoding="utf-8")
        )
        self.assertEqual(ledger["cases"]["case-a"]["reviewer"], "Test Reviewer")
        matched, _ = self.compare("after-approval")
        self.assertEqual(matched.returncode, 0, matched.stderr + matched.stdout)

    def test_approval_rejects_an_image_changed_after_the_report(self) -> None:
        self.image(self.current, (1, 2, 3, 255))
        _, output = self.compare("tamper", "--allow-pending")
        copied = output / "cases" / "case-a" / "current.png"
        self.image(copied, (255, 0, 0, 255))
        result = self.run_tool(
            "approve",
            "--report",
            str(output / "visual-review.json"),
            "--report-sha256",
            self.report_sha256(output),
            "--case",
            "case-a",
            "--reviewer",
            "Test Reviewer",
            "--note",
            "Must fail because the reviewed bytes changed",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("changed after the report", result.stderr)
        self.assertFalse(self.reference.exists())

    def test_approval_rejects_a_different_report_hash(self) -> None:
        self.image(self.current, (1, 2, 3, 255))
        _, output = self.compare("report-tamper", "--allow-pending")
        result = self.run_tool(
            "approve",
            "--report",
            str(output / "visual-review.json"),
            "--report-sha256",
            "0" * 64,
            "--case",
            "case-a",
            "--reviewer",
            "Test Reviewer",
            "--note",
            "Must fail because this is not the reviewed report",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("report hash does not match", result.stderr)
        self.assertFalse(self.reference.exists())

    def test_invalid_current_is_an_error_even_without_a_baseline(self) -> None:
        self.current.write_bytes(b"not a PNG")
        result, output = self.compare("invalid-current", "--allow-pending")
        self.assertEqual(result.returncode, 1)
        case = self.report(output)["cases"][0]
        self.assertEqual(case["status"], "ERROR")
        self.assertIn("Invalid or unreadable PNG", case["error"])
        self.assertNotIn("current_artifact", case)

    def test_manifest_reference_cannot_escape_the_golden_root(self) -> None:
        self.image(self.current)
        self.write_manifest(reference="../outside.png")
        result, _ = self.compare("unsafe")
        self.assertEqual(result.returncode, 1)
        self.assertIn("may not traverse", result.stderr)
        self.assertFalse((self.root / "outside.png").exists())

    def test_existing_report_is_not_overwritten(self) -> None:
        self.image(self.current)
        output = self.root / "exports" / "existing"
        output.mkdir()
        marker = output / "keep.txt"
        marker.write_text("keep", encoding="utf-8")
        result = self.run_tool(
            "compare", "--profile", self.profile, "--out", str(output)
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("new/empty", result.stderr)
        self.assertEqual(marker.read_text(encoding="utf-8"), "keep")


if __name__ == "__main__":
    unittest.main()
