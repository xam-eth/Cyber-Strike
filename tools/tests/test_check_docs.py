from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from check_docs import (
    ALLOWED_ROOT_MARKDOWN,
    REQUIRED_FILES,
    REQUIRED_TOKENS,
    check_documentation,
)


class DocumentationContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for name in REQUIRED_FILES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\n".join(REQUIRED_TOKENS.get(name, ())), encoding="utf-8")
        architecture = self.root / "docs/ARCHITECTURE.md"
        architecture.write_text(
            "<!-- module-map:start -->\n<!-- module-map:end -->\n", encoding="utf-8"
        )
        index_entries = sorted(
            name.removeprefix("docs/")
            for name in REQUIRED_FILES
            if name.startswith("docs/") and name != "docs/README.md"
        )
        index = self.root / "docs/README.md"
        index.write_text(
            "\n".join(REQUIRED_TOKENS["docs/README.md"] + tuple(index_entries)),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_minimal_canonical_tree_passes(self) -> None:
        errors, stats = check_documentation(self.root)
        self.assertEqual([], errors)
        self.assertEqual(len(REQUIRED_FILES), stats["canonical_files"])

    def test_missing_relative_link_fails(self) -> None:
        readme = self.root / "docs/GAMEPLAY_DESIGN.md"
        readme.write_text(
            readme.read_text(encoding="utf-8") + "\n[missing](missing-file.md)\n",
            encoding="utf-8",
        )
        errors, _ = check_documentation(self.root)
        self.assertTrue(any("missing link target" in error for error in errors))

    def test_root_report_and_retired_document_fail(self) -> None:
        (self.root / "OLD_REPORT.md").write_text("old", encoding="utf-8")
        retired = self.root / "docs/GAMEPLAY_LOOP_SPEC.md"
        retired.write_text("old", encoding="utf-8")
        errors, _ = check_documentation(self.root)
        self.assertTrue(any("unexpected root Markdown" in error for error in errors))
        self.assertTrue(any("retired document returned" in error for error in errors))

    def test_gameplay_direction_cannot_disappear_silently(self) -> None:
        gameplay = self.root / "docs/GAMEPLAY_DESIGN.md"
        gameplay.write_text("Endless Survival\n", encoding="utf-8")
        errors, _ = check_documentation(self.root)
        self.assertTrue(any("TECH HUNT 0" in error for error in errors))

    def test_new_document_must_be_indexed(self) -> None:
        extra = self.root / "docs/NEW_DOMAIN.md"
        extra.write_text("new", encoding="utf-8")
        errors, _ = check_documentation(self.root)
        self.assertTrue(any("not linked from docs/README.md" in error for error in errors))

    def test_only_two_root_guides_are_allowed(self) -> None:
        self.assertEqual({"AGENTS.md", "README.md"}, ALLOWED_ROOT_MARKDOWN)


if __name__ == "__main__":
    unittest.main()
