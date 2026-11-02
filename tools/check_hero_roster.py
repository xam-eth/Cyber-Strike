#!/usr/bin/env python3
"""Roster gate: every operative card points at real, non-tiered assets.

Hero Tiers (T1-T5) are removed. Weapon Tiers remain in game/resources/weapons/tiers.json.
This check verifies:
1. roster.json parses cleanly and contains no legacy hero tier tables;
2. every field-ready operative declares an existing model, rig sidecar, and portrait PNG;
3. unbuilt slots declare null asset paths rather than broken links;
4. every `*_key` exists in both EN and ID columns of ui/i18n.js (and engine catalog for roles);
5. field-ready roster ids match `HeroDefinition` registry ids exactly.
"""

from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROSTER = ROOT / "game" / "resources" / "heroes" / "roster.json"
WEB_I18N = ROOT / "ui" / "i18n.js"
CATALOG = ROOT / "game" / "scripts" / "i18n" / "aegis_text_catalog.gd"

MIN_ASPECT = 0.55
MAX_ASPECT = 1.0

KEY_RE = re.compile(r"['\"]((?:hero|common)\.[a-z0-9_.]+)['\"]\s*:")


def png_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def web_keys(locale: str) -> set[str]:
    text = WEB_I18N.read_text(encoding="utf-8")
    blocks = text.split("const STRINGS = {")
    if len(blocks) < 2:
        return set()
    body = blocks[1]
    start = body.find(f"  {locale}: {{")
    if start == -1:
        return set()
    end = body.find("\n  },", start)
    return set(KEY_RE.findall(body[start:end]))


def catalog_keys() -> dict[str, set[str]]:
    text = CATALOG.read_text(encoding="utf-8")
    body = text.split("const STRINGS := {", 1)[1]
    out: dict[str, set[str]] = {}
    for locale in ("en", "id"):
        start = body.find(f'\t"{locale}":')
        if start == -1:
            out[locale] = set()
            continue
        following = body.find('\t"id":' if locale == "en" else "\n}\n", start + 1)
        column = body[start:] if following == -1 else body[start:following]
        out[locale] = set(re.findall(r'"([a-z_]+\.[a-z0-9_.]+)":', column))
    return out


def main() -> int:
    failures: list[str] = []
    checks = 0

    def expect(condition: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    if not ROSTER.exists():
        print(f"FAIL {ROSTER.relative_to(ROOT)} is missing")
        return 1
    roster = json.loads(ROSTER.read_text(encoding="utf-8"))

    expect("heroes" in roster, "roster.json has 'heroes'")
    expect("tiers" not in roster and "tier_count" not in roster, "roster.json has no legacy hero tiers")
    heroes = roster.get("heroes", [])
    expect(len(heroes) >= 2, "roster.json lists operatives")

    en_keys = web_keys("en")
    id_keys = web_keys("id")
    catalog = catalog_keys()
    expect(len(en_keys) > 0 and len(id_keys) > 0, "ui/i18n.js yields both language columns")

    def key_both_columns(key: str, where: str, engine: bool = True) -> None:
        expect(key in en_keys, f"{where}: '{key}' exists in ui/i18n.js en")
        expect(key in id_keys, f"{where}: '{key}' exists in ui/i18n.js id")
        if engine and key.startswith("hero.") and key.endswith((".role", ".status", ".name")):
            expect(key in catalog["en"], f"{where}: '{key}' exists in the Godot catalog en")
            expect(key in catalog["id"], f"{where}: '{key}' exists in the Godot catalog id")

    ids: set[str] = set()
    for hero in heroes:
        hero_id = str(hero.get("id", ""))
        expect(bool(hero_id), "every hero has an id")
        expect(hero_id not in ids, f"hero id '{hero_id}' is unique")
        ids.add(hero_id)
        expect("tiers" not in hero, f"{hero_id}: carries no per-hero tier array")
        expect(bool(hero.get("callsign")), f"{hero_id}: has a callsign")
        expect(bool(hero.get("name")), f"{hero_id}: has a name")
        status = str(hero.get("status", ""))
        expect(status in ("field_ready", "in_development"), f"{hero_id}: valid status")
        field_ready = status == "field_ready"
        key_both_columns(str(hero.get("role_key", "")), hero_id, field_ready)
        key_both_columns(str(hero.get("brief_key", "")), hero_id, False)

        for field in ("model", "rig", "portrait"):
            value = hero.get(field)
            if field_ready:
                expect(isinstance(value, str) and bool(value), f"{hero_id}: has a {field} path")
                if isinstance(value, str) and value:
                    expect((ROOT / value).exists(), f"{hero_id}: {value} exists")
            else:
                expect(value is None, f"{hero_id}: unbuilt hero has null {field}")

        if field_ready:
            expect(float(hero.get("vitals", 0)) > 0, f"{hero_id}: positive vitals")
            expect(0.0 <= float(hero.get("reduction", -1)) <= 90.0, f"{hero_id}: valid reduction")
            portrait = hero.get("portrait")
            if isinstance(portrait, str) and (ROOT / portrait).exists():
                size = png_size(ROOT / portrait)
                expect(size is not None, f"{hero_id}: {portrait} is a PNG")
                if size:
                    width, height = size
                    expect(
                        height > 0 and MIN_ASPECT <= width / height <= MAX_ASPECT,
                        f"{hero_id}: {portrait} is a portrait ({width}x{height})",
                    )

    definition = (ROOT / "game" / "scripts" / "progression" / "hero_definition.gd").read_text(encoding="utf-8")
    registry = set(re.findall(r'&"([a-z0-9_]+)":\s*"res://resources/heroes/', definition))
    fieldable = {str(hero.get("id")) for hero in heroes if str(hero.get("status")) == "field_ready"}
    expect(bool(registry), "hero_definition.gd lists at least one definition")
    expect(
        fieldable == registry,
        f"field-ready heroes and HeroDefinition ids match ({sorted(fieldable)} vs {sorted(registry)})",
    )

    if failures:
        for line in failures:
            print(f"FAIL {line}")
        print(f"{len(failures)} of {checks} checks failed")
        return 1
    print(f"OK: {checks} checks, {len(heroes)} hero(es), hero tiers removed, both languages complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
