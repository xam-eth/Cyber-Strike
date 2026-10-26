#!/usr/bin/env python3
"""Validate the canonical documentation set and relative Markdown links.

This is deliberately offline and structural. It does not judge design quality or
claim that linked source/runtime behavior has been tested.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote


REQUIRED_FILES = {
    "AGENTS.md",
    "README.md",
    "docs/README.md",
    "docs/GAMEPLAY_DESIGN.md",
    "docs/DEVELOPMENT.md",
    "docs/CONTENT_IMPORT.md",
    "docs/ARCHITECTURE.md",
    "docs/DECISIONS.md",
    "docs/VALIDATION.md",
    "docs/ART_DIRECTION.md",
    "docs/FRONT_END_JOURNEY.md",
    "docs/runbooks/ANDROID.md",
    "docs/runbooks/AUDIO.md",
    "docs/runbooks/HERO_RIG.md",
    "docs/runbooks/TOOLCHAIN.md",
    "docs/runbooks/WEB_PREVIEW.md",
    "docs/world/README.md",
    "docs/world/CONCEPT.md",
}

ALLOWED_ROOT_MARKDOWN = {"AGENTS.md", "README.md"}

# These competing documents were consolidated on 2026-10-26. Restoring one
# requires an explicit documentation-contract update, not a silent reintroduction.
RETIRED_DOCUMENTS = {
    "docs/GAMEPLAY_CONTENT_CONTRACTS.md",
    "docs/GAMEPLAY_LOOP_SPEC.md",
    "docs/GAMEPLAY_MECHANICS_AUDIT.md",
    "docs/GAMEPLAY_RESEARCH_EXPEDITION_HOOK.md",
    "docs/GAMEPLAY_VALIDATION_REPORT.md",
    "docs/HOOK_AND_RETENTION_SPEC.md",
    "docs/INTEGRATION_BASELINE.md",
    "docs/INTEGRATION_VALIDATION_REPORT.md",
    "docs/WEB_LOADING_RECOVERY.md",
    "docs/WORLD_OPENING_INTEGRATION.md",
    "docs/UI_UX_REDESIGN_SPEC.md",
    "docs/world/ASSET_LIST.md",
    "docs/world/PBR_AND_VERIFICATION.md",
    "docs/world/CINEMATIC_SCI-FI.md",
}

REQUIRED_TOKENS = {
    "AGENTS.md": ("docs/GAMEPLAY_DESIGN.md",),
    "docs/README.md": ("GAMEPLAY_DESIGN.md", "DEVELOPMENT.md", "VALIDATION.md"),
    "docs/GAMEPLAY_DESIGN.md": (
        "TECH HUNT 0",
        "Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy",
        "Endless Survival",
        "Death and permanent-save contract",
    ),
    "docs/DEVELOPMENT.md": ("GAMEPLAY_DESIGN.md", "Definition of done"),
    "docs/CONTENT_IMPORT.md": (
        "contract_version = 1",
        "game/content/worlds/<id>/",
        "game/content/characters/<id>/",
        "No IAP or monetization concept",
    ),
}

LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
SCHEME_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def markdown_files(root: Path) -> list[Path]:
    files = list(root.glob("*.md"))
    docs = root / "docs"
    if docs.is_dir():
        files.extend(docs.rglob("*.md"))
    return sorted(set(files))


def link_target(raw: str) -> str:
    """Return the path portion of an inline Markdown destination."""
    target = raw.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    elif " " in target:
        # Inline optional Markdown title. Repository paths do not use spaces.
        target = target.split(" ", 1)[0]
    target = target.split("#", 1)[0].split("?", 1)[0]
    return unquote(target)


def check_documentation(root: Path) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    files = markdown_files(root)
    relative_files = {path.relative_to(root).as_posix() for path in files}

    for name in sorted(REQUIRED_FILES - relative_files):
        errors.append(f"missing canonical document: {name}")

    for path in sorted(root.glob("*.md")):
        name = path.name
        if name not in ALLOWED_ROOT_MARKDOWN:
            errors.append(f"unexpected root Markdown guide (use docs/ instead): {name}")

    for name in sorted(RETIRED_DOCUMENTS & relative_files):
        errors.append(f"retired document returned to active tree: {name}")

    docs_index = root / "docs/README.md"
    if docs_index.is_file():
        index_text = docs_index.read_text(encoding="utf-8")
        for path in sorted((root / "docs").rglob("*.md")):
            if path == docs_index:
                continue
            index_name = path.relative_to(root / "docs").as_posix()
            if index_name not in index_text:
                errors.append(f"document is not linked from docs/README.md: {index_name}")

    for name, tokens in REQUIRED_TOKENS.items():
        path = root / name
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                errors.append(f"{name}: required direction/contract text is missing: {token}")

    architecture = root / "docs/ARCHITECTURE.md"
    if architecture.is_file():
        text = architecture.read_text(encoding="utf-8")
        for marker in ("<!-- module-map:start -->", "<!-- module-map:end -->"):
            count = text.count(marker)
            if count != 1:
                errors.append(f"docs/ARCHITECTURE.md: expected one {marker}, found {count}")

    checked_links = 0
    root_resolved = root.resolve()
    for path in files:
        text = path.read_text(encoding="utf-8")
        for match in LINK_PATTERN.finditer(text):
            raw = match.group(1).strip()
            target = link_target(raw)
            if not target or target.startswith(("#", "/")) or SCHEME_PATTERN.match(target):
                continue
            checked_links += 1
            resolved = (path.parent / target).resolve()
            try:
                resolved.relative_to(root_resolved)
            except ValueError:
                errors.append(f"{path.relative_to(root)}: link leaves repository: {raw}")
                continue
            if not resolved.exists():
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{path.relative_to(root)}:{line}: missing link target: {raw}")

    stats = {
        "markdown_files": len(files),
        "canonical_files": len(REQUIRED_FILES & relative_files),
        "relative_links": checked_links,
    }
    return errors, stats


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    errors, stats = check_documentation(root)
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    if errors:
        print(f"Documentation contracts: {len(errors)} failure(s)", file=sys.stderr)
        return 1
    print(
        "PASS: documentation contracts — "
        f"{stats['canonical_files']}/{len(REQUIRED_FILES)} canonical files, "
        f"{stats['markdown_files']} Markdown files, "
        f"{stats['relative_links']} relative links"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
