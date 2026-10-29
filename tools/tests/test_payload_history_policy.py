#!/usr/bin/env python3
"""Keep generated Web binaries out of ordinary source-pull history."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "godot-ci.yml"


class PayloadHistoryPolicyTests(unittest.TestCase):
    def test_payload_commit_requires_explicit_marker(self) -> None:
        text = WORKFLOW.read_text(encoding="utf-8")
        match = re.search(
            r"      - name: Opt in to a payload and template history commit\n(?P<body>.*?)(?=      - name:)",
            text,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "opt-in payload step is missing")
        body = match.group("body")
        self.assertIn("github.event_name == 'push'", body)
        self.assertIn("contains(github.event.head_commit.message, '[web-payload]')", body)
        self.assertIn("!contains(github.event.head_commit.message, '[skip ci]')", body)
        self.assertNotIn(
            "if: github.event_name == 'push' && !contains(github.event.head_commit.message, '[skip ci]')",
            body,
        )

    def test_every_run_still_publishes_the_artifact(self) -> None:
        text = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("- name: Upload the web preview", text)
        self.assertIn("uses: actions/upload-artifact@v4", text)
        self.assertIn("name: web-preview", text)
        self.assertIn("./scripts/export_web_preview.sh", text)
        self.assertIn("node tools/web_qa.mjs", text)

    def test_contributors_get_the_bandwidth_contract(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        runbook = (ROOT / "docs" / "runbooks" / "WEB_PREVIEW.md").read_text(encoding="utf-8")
        attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
        ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        for text in (readme, runbook, attributes, ignore):
            self.assertIn("[web-payload]", text)
        self.assertIn("--filter=blob:none", runbook)
        self.assertIn("sparse-checkout", runbook)
        self.assertIn("not a playable checkout", runbook)


if __name__ == "__main__":
    unittest.main()
