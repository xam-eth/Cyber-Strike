#!/usr/bin/env python3
"""Localization gate: the catalog is complete, symmetric, and actually used.

Three failures, in the order they bite a translator:

1. **Asymmetric keys** -- a key in one language and not the other, which shows
   up in play as an English line in an Indonesian screen (or the raw key).
2. **Placeholder drift** -- `%d` in one column and `%s` in the other, which is a
   crash in `String % args` and not a cosmetic bug.
3. **Untranslated** -- the same value in both columns for a key that is not an
   intentional shared token (weapon names, "EQUIPPED"). That is what a
   copy-paste translation looks like in review.

It also reports keys the code asks for and the catalog does not have, and keys
the catalog has and nothing asks for (dead copy, safe to delete).

Run from the repo root:  python3 tools/check_localization.py
Exit code 0 = clean, 1 = a failure above.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "game" / "scripts" / "i18n" / "aegis_text_catalog.gd"
GAME = ROOT / "game" / "scripts"
RESOURCES = ROOT / "game" / "resources"

KEY_RE = re.compile(r'"([a-z_]+\.[a-z0-9_.]+)":\s*"((?:[^"\\]|\\.)*)"')
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[sdfvx]")
# Catalog namespaces. A quoted string that starts with one of these and carries a
# dot IS a key; nothing else in the game source looks like that, so this finds
# every call site without guessing at function names.
NAMESPACES = (
    "app", "boot", "loading", "chapter", "common", "nav", "dash", "hero",
    "world", "hud", "pause", "results", "recovery", "upgrade", "armory", "wpn", "settings", "editor",
)
KEY_LITERAL = re.compile(
    r'"((?:' + "|".join(NAMESPACES) + r')\.[a-z0-9_.\-]+)"'
)
# A key built at the call site, e.g. "editor.preset_%s".
KEY_PATTERN = re.compile(r'"((?:' + "|".join(NAMESPACES) + r')\.[a-z0-9_.]*%s[a-z0-9_.]*)"')


def parse_catalog(text: str) -> dict[str, dict[str, str]]:
    """Both locale maps, key -> value, read straight out of the const."""
    en_block = text.split('\n\t"en":')[1].split('\n\t"id":')[0]
    id_block = text.split('\n\t"id":')[1]
    return {"en": dict(KEY_RE.findall(en_block)), "id": dict(KEY_RE.findall(id_block))}


def shared_values(text: str) -> set[str]:
    block = text.split("const SHARED_VALUES := [")[1].split("]")[0]
    return set(re.findall(r'"([a-z_]+\.[a-z0-9_.]+)"', block))


def used_keys() -> tuple[set[str], set[str]]:
    """(keys the code names, key patterns it builds with a %s)."""
    found: set[str] = set()
    patterns: set[str] = set()
    # Data-driven UI keeps its catalog keys in resources, not only in scripts.
    for root, pattern in ((GAME, "*.gd"), (RESOURCES, "*.tres")):
        for path in root.rglob(pattern):
            if path.name == "aegis_text_catalog.gd":
                continue
            source = path.read_text(encoding="utf-8")
            patterns.update(m.group(1) for m in KEY_PATTERN.finditer(source))
            for match in KEY_LITERAL.finditer(source):
                literal = match.group(1)
                if "%" not in literal:
                    found.add(literal)
    return found, patterns


def covers(pattern: str, key: str) -> bool:
    """`editor.preset_%s` covers `editor.preset_minimal`."""
    head, _, tail = pattern.partition("%s")
    return key.startswith(head) and key.endswith(tail)


def placeholders(value: str) -> list[str]:
    return sorted(PLACEHOLDER_RE.findall(value))


def main() -> int:
    text = CATALOG.read_text(encoding="utf-8")
    strings = parse_catalog(text)
    shared = shared_values(text)
    failures: list[str] = []

    en, id_ = strings["en"], strings["id"]
    for key in sorted(set(en) - set(id_)):
        failures.append(f"missing in id: {key}")
    for key in sorted(set(id_) - set(en)):
        failures.append(f"missing in en: {key}")

    for key in sorted(set(en) & set(id_)):
        if placeholders(en[key]) != placeholders(id_[key]):
            failures.append(
                f"placeholder drift: {key} en={placeholders(en[key])} id={placeholders(id_[key])}"
            )
        if en[key] == id_[key] and key not in shared:
            failures.append(f"untranslated: {key} reads {en[key]!r} in both columns")

    named, patterns = used_keys()
    unused = sorted(
        k for k in en if k not in named and not any(covers(p, k) for p in patterns)
    )
    missing = sorted(k for k in named if k not in en)

    print(f"catalog: {len(en)} keys en / {len(id_)} keys id")
    if patterns:
        print(f"dynamic key patterns: {', '.join(sorted(patterns))}")
    if unused:
        print(f"unused in catalog ({len(unused)}): {', '.join(unused)}")
    if missing:
        print(f"asked for but absent ({len(missing)}): {', '.join(missing)}")
    if failures:
        for line in failures:
            print(f"FAIL {line}")
        return 1
    print("OK: both languages complete, placeholders aligned, no copied values")
    return 0


if __name__ == "__main__":
    sys.exit(main())
