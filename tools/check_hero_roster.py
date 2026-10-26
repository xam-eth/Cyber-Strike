#!/usr/bin/env python3
"""Roster gate: every card the operative page can draw points at a real asset.

`game/resources/heroes/roster.json` is one table for both halves of the product
-- the web shell builds its hero and tier cards from it, and `HeroTier` gives the
engine the same ranks. That makes it the one place a promise can be broken
silently: a card is drawn from a path, so a path that does not exist is a card
that promises a costume nobody rendered (or, worse, a run that spawns nothing).

It checks, in the order a player would hit them:

1. the file parses and has the fields the shell reads;
2. the ladder is a ladder -- tiers 1..N, each worth at least as much as the one
   before it and each costing more runs;
3. a field-ready hero has a model, a rig sidecar and a card render at *every*
   rank, and all three files exist; a hero that is not field-ready has none of
   them (it is a named slot, not a card with a picture);
4. every `*_key` in the file exists in both language columns -- `ui/i18n.js`
   for the shell, `aegis_text_catalog.gd` for the engine;
5. the card art is the shape the card is drawn at (portrait, 3:4-ish), because a
   landscape render squashed into a tall window is the one defect a path check
   cannot see.

Run from the repo root:  python3 tools/check_hero_roster.py
Exit code 0 = clean, 1 = a promise without an asset behind it.
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

# The card is 3:4-ish (86x86 CSS box, art window cropped to a portrait). A render
# between 0.6 and 0.95 wide-per-tall covers it without letterboxing.
MIN_ASPECT = 0.55
MAX_ASPECT = 1.0

KEY_RE = re.compile(r"['\"]((?:hero|common)\.[a-z0-9_.]+)['\"]\s*:")


def png_size(path: Path) -> tuple[int, int] | None:
    """Width/height from the IHDR chunk, without an image library."""
    with path.open("rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def web_keys(locale: str) -> set[str]:
    """Keys of one language column in ui/i18n.js."""
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
    """Key sets of the two columns of `AegisTextCatalog.STRINGS`."""
    text = CATALOG.read_text(encoding="utf-8")
    body = text.split("const STRINGS := {", 1)[1]
    out: dict[str, set[str]] = {}
    for locale in ("en", "id"):
        start = body.find(f'\t"{locale}":')
        if start == -1:
            out[locale] = set()
            continue
        # A column ends at the closing brace of the column, which is the first
        # line that is exactly two tabs and a brace after the next column's
        # header -- or the end of the map for the last column.
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

    for field in ("tier_count", "tiers", "heroes"):
        expect(field in roster, f"roster.json has '{field}'")
    tiers = roster.get("tiers", [])
    heroes = roster.get("heroes", [])
    expect(int(roster.get("tier_count", 0)) == len(tiers), "tier_count equals the number of tier rows")
    expect([row.get("tier") for row in tiers] == list(range(1, len(tiers) + 1)), "tiers are numbered 1..N in order")

    # A ladder: no rank is worth less than the one below it, and no rank is
    # cheaper in runs. Equality is allowed for vitals (a rank may buy plate
    # instead of health) but not for the price.
    for index in range(1, len(tiers)):
        lower, upper = tiers[index - 1], tiers[index]
        expect(
            int(upper.get("runs_required", 0)) > int(lower.get("runs_required", 0)),
            f"tier {upper.get('tier')} costs more runs than tier {lower.get('tier')}",
        )
        expect(
            float(upper.get("vitals", 0)) >= float(lower.get("vitals", 0)),
            f"tier {upper.get('tier')} has at least the vitals of tier {lower.get('tier')}",
        )
        expect(
            float(upper.get("reduction", 0)) >= float(lower.get("reduction", 0)),
            f"tier {upper.get('tier')} has at least the plate of tier {lower.get('tier')}",
        )
    expect(int(tiers[0].get("runs_required", -1)) == 0, "tier 1 costs no runs")

    en_keys = web_keys("en")
    id_keys = web_keys("id")
    catalog = catalog_keys()
    expect(len(en_keys) > 0 and len(id_keys) > 0, "ui/i18n.js yields both language columns")

    def key_both_columns(key: str, where: str, engine: bool = True) -> None:
        """The shell needs every key; the engine only needs the ones it prints.

        A hero still in development has no definition in the engine at all, so
        its role copy has no engine column to live in -- requiring one would be
        asking the catalog to hold a line nothing can draw.
        """
        expect(key in en_keys, f"{where}: '{key}' exists in ui/i18n.js en")
        expect(key in id_keys, f"{where}: '{key}' exists in ui/i18n.js id")
        if not engine:
            return
        if key.startswith("hero.") and key.endswith((".role", ".status", ".name")):
            expect(key in catalog["en"], f"{where}: '{key}' exists in the Godot catalog en")
            expect(key in catalog["id"], f"{where}: '{key}' exists in the Godot catalog id")

    for row in tiers:
        key_both_columns(str(row.get("name_key", "")), f"tier {row.get('tier')}")

    ids: set[str] = set()
    for hero in heroes:
        hero_id = str(hero.get("id", ""))
        expect(bool(hero_id), "every hero has an id")
        expect(hero_id not in ids, f"hero id '{hero_id}' is unique")
        ids.add(hero_id)
        expect(bool(hero.get("callsign")), f"{hero_id}: has a callsign")
        expect(bool(hero.get("name")), f"{hero_id}: has a name")
        field_ready_status = str(hero.get("status", "")) == "field_ready"
        key_both_columns(str(hero.get("role_key", "")), hero_id, field_ready_status)
        key_both_columns(str(hero.get("brief_key", "")), hero_id, False)

        status = str(hero.get("status", ""))
        expect(status in ("field_ready", "in_development"), f"{hero_id}: status is field_ready or in_development")
        entries = hero.get("tiers", [])
        expect(len(entries) == len(tiers), f"{hero_id}: has one entry per tier")
        expect([item.get("tier") for item in entries] == list(range(1, len(tiers) + 1)), f"{hero_id}: tier entries are 1..N")

        for item in entries:
            label = f"{hero_id} tier {item.get('tier')}"
            paths = {field: item.get(field) for field in ("model", "rig", "art")}
            if status == "field_ready":
                for field, value in paths.items():
                    expect(isinstance(value, str) and bool(value), f"{label}: has a {field} path")
                    if isinstance(value, str) and value:
                        expect((ROOT / value).exists(), f"{label}: {value} exists")
                art = paths.get("art")
                if isinstance(art, str) and (ROOT / art).exists():
                    size = png_size(ROOT / art)
                    expect(size is not None, f"{label}: {art} is a PNG")
                    if size:
                        width, height = size
                        expect(height > 0 and MIN_ASPECT <= width / height <= MAX_ASPECT,
                               f"{label}: {art} is a portrait ({width}x{height})")
            else:
                for field, value in paths.items():
                    expect(value is None, f"{label}: an unbuilt hero has no {field} path")

        portrait = hero.get("portrait")
        if status == "field_ready":
            expect(isinstance(portrait, str) and bool(portrait), f"{hero_id}: has a portrait")
            if isinstance(portrait, str) and portrait:
                expect((ROOT / portrait).exists(), f"{hero_id}: {portrait} exists")
        else:
            expect(portrait is None, f"{hero_id}: an unbuilt hero has no portrait")

    # The Godot definition registry and the roster's *field-ready* heroes must be
    # the same set: a hero the shell can field and the engine cannot load is a
    # card that spawns nothing, and a definition with no card is a rank nobody
    # can see. A hero that is still in development has no definition on purpose
    # (that absence is what the locked slot says), so it is not compared.
    definition = (ROOT / "game" / "scripts" / "progression" / "hero_definition.gd").read_text(encoding="utf-8")
    registry = set(re.findall(r'&"([a-z0-9_]+)":\s*"res://resources/heroes/', definition))
    fieldable = {str(hero.get("id")) for hero in heroes if str(hero.get("status")) == "field_ready"}
    expect(bool(registry), "hero_definition.gd lists at least one definition")
    expect(fieldable == registry, f"field-ready heroes and HeroDefinition ids match ({sorted(fieldable)} vs {sorted(registry)})")

    if failures:
        for line in failures:
            print(f"FAIL {line}")
        print(f"{len(failures)} of {checks} checks failed")
        return 1
    print(f"OK: {checks} checks, {len(heroes)} hero(es), {len(tiers)} tiers, both languages complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
