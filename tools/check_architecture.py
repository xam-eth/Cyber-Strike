#!/usr/bin/env python3
"""Fail when code crosses a module or layer boundary it is not allowed to cross.

A folder tree is a suggestion; this is the part that actually holds. Every
source on modular game architecture says the same thing: the layout only pays
off when something *enforces* it, because otherwise the first deadline adds a
`content/weapon -> ui/hud` import and the boundary is gone
(docs/STRUCTURE_PLAN.md §1).

The project is currently in phase 0: the tree is still the old type-based one,
so paths are mapped onto the target layers here (see PATH_LAYERS). The mapping
understands both the old and the new layout, so the checker keeps working
through the phases instead of going quiet while things move.

Rules, in one line: **imports point downwards only.**

    tests, qa, scenes/main.gd   -> anything
    core                        -> core
    systems                     -> core
    content/<a>                 -> systems, core, ui/design, content/<a>
    ui                          -> systems (read-only), core, ui/design
    nothing                     -> ui, except ui itself

Two extra rules that matter here specifically:

* content may reach `ui/design` (a weapon card draws with the design system) but
  never `ui/hud` or `ui/menus` (gameplay must not drive the HUD).
* a module's `data/` is its public face; another module may read it, but not the
  module's `runtime/` or `view/`.

Comments and string literals are stripped before scanning. That is not
cosmetic: a naive scan of this repository reports 11 dependency cycles that do
not exist, all of them class names mentioned inside `##` doc comments
(docs/AUDIT_2026-10-21.md §6).

Usage:
    check_architecture.py                 # report (exit 0)
    check_architecture.py --strict        # fail on any violation (phases 3+)
    check_architecture.py --baseline FILE # compare against a saved baseline
    check_architecture.py --write-baseline FILE
    check_architecture.py --json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"

# Free layers: they may import anything. `data` is not a layer in the tree but a
# contract: a `*_definition.gd` registry or a `data/` folder is the public face
# of a module, and every layer is allowed to read a contract — that is what makes
# it a contract instead of an internal detail.
FREE = "free"
DATA = "data"
LAYERS = ("core", "systems", "content", "ui")

# (regex on the path relative to game/, layer, module-name-or-empty)
PATH_LAYERS: list[tuple[str, str, str]] = [
    # --- target tree -------------------------------------------------------
    (r"^core/", "core", ""),
    (r"^systems/", "systems", ""),
    (r"^ui/design/", "ui", "design"),
    (r"^ui/hud/", "ui", "hud"),
    (r"^ui/menus/", "ui", "menus"),
    (r"^ui/settings/", "ui", "settings"),
    (r"^ui/", "ui", ""),
    (r"^content/([^/]+)/", "content", r"\1"),
    (r"^scenes/", FREE, ""),
    (r"^tests/", FREE, ""),
    # --- current (phase 0) tree, mapped onto the target layers --------------
    (r"^scripts/audio/", "core", ""),
    (r"^scripts/progression/(progression_service|reward_service|run_stats)\.gd$", "systems", ""),
    (r"^scripts/progression/hero_definition\.gd$", "content", "hero"),
    (r"^scripts/progression/world_definition\.gd$", "content", "world"),
    # WeaponController is the player's weapon handling — cooldowns, ammo,
    # switching — driven by PlayerController. The projectiles it fires are
    # content; the thing that decides when they fire is a system.
    (r"^scripts/weapons/weapon_controller\.gd$", "systems", ""),
    (r"^scripts/weapons/", "content", "weapon"),
    (r"^scripts/worlds/", "content", "world"),
    (r"^scripts/enemies/", "content", "enemy"),
    # MuzzleFlash is a component the player scene owns and drives (it sits at
    # VisualRoot/WeaponSocket), not a world effect the player asks for. Same
    # reasoning as scripts/visual/: shared visual plumbing is core.
    (r"^scripts/effects/muzzle_flash\.gd$", "core", ""),
    (r"^scripts/effects/", "content", "effects"),
    (r"^scripts/arena/", "content", "world"),
    # ModelFitter fits GLB models for the player *and* the enemies: shared
    # geometry plumbing, no world rules. It is core, not world content.
    (r"^scripts/visual/", "core", ""),
    (r"^scripts/player/", "systems", ""),
    (r"^scripts/camera/", "systems", ""),
    (r"^scripts/waves/", "systems", ""),
    # ui sub-modules, current tree. The old one-line rule named aegis_panel /
    # aegis_button / aegis_ammo_chip at the top of scripts/ui/, where they have
    # never lived (they are in widgets/), so it matched nothing at all and the
    # design module was empty. Matching the folder is what was intended.
    (r"^scripts/ui/hud/", "ui", "hud"),
    (r"^scripts/ui/menus/", "ui", "menus"),
    # aegis_preferences.gd is the preferences *model*: systems, content (the
    # reduce-motion and reduce-flash flags) and every screen read it. Only the
    # panel that edits it is screen code, so the model is core and the rest of
    # ui/settings stays in the ui layer.
    (r"^scripts/ui/settings/aegis_preferences\.gd$", "core", ""),
    (r"^scripts/ui/settings/", "ui", "settings"),
    (r"^scripts/ui/widgets/", "ui", "design"),
    (r"^scripts/ui/settings/", "ui", "settings"),
    (r"^scripts/ui/widgets/", "ui", "design"),
    (r"^scripts/ui/(aegis_tokens|aegis_theme|aegis_preferences)\.gd$", "ui", "design"),
    (r"^scripts/ui/", "ui", ""),
    (r"^scripts/qa/", FREE, ""),
    (r"^scripts/main\.gd$", FREE, ""),
]

# Layer order: index 0 is the lowest. Imports may only point to a lower index
# (or sideways inside the same module), with the exceptions below.
ORDER = {"core": 0, "systems": 1, "content": 2, "ui": 3}

ALLOWED_UPWARD = {("content", "ui")}  # content may use the design system only

# Modules inside the ui layer that are shared by every screen. `design` is the
# design system (tokens, theme, widgets, shared layout geometry); `settings` is
# the preferences model plus the settings panel, which the HUD opens from pause
# and the dashboard opens from its own page. Everything else in ui is one
# screen's private code.
SHARED_UI_MODULES = frozenset({"design", "settings"})


def strip_gdscript(text: str) -> str:
    out = []
    for line in text.split("\n"):
        code = line.split("#")[0]
        code = re.sub(r'"(\\.|[^"\\])*"', '""', code)
        out.append(code)
    return "\n".join(out)


def classify(rel: str) -> tuple[str, str]:
    if rel.endswith("_definition.gd") or "/data/" in rel:
        return DATA, rel.split("/")[1] if "/" in rel else ""
    for pattern, layer, module in PATH_LAYERS:
        match = re.match(pattern, rel)
        if match:
            resolved = module
            if "\\1" in module and match.groups():
                resolved = match.group(1)
            return layer, resolved
    return FREE, ""


def imports_of(path: Path, known_classes: dict[str, str]) -> list[str]:
    """res:// paths and class names this file reaches for.

    Class names are matched as whole words against the project's own index.
    Matching only `ClassName.` would miss a bare type reference (`var x :=
    AegisTheme`, `is WeaponDefinition`), which is exactly how one of the real
    violations in this repository is written — a checker that misses those is
    worse than no checker, because it reports a clean tree.
    """
    raw = path.read_text(encoding="utf-8", errors="replace")
    code = strip_gdscript(raw)
    found: list[str] = []
    # preload/load of a res:// path: string literals are stripped from `code`,
    # so the paths have to come from the raw text.
    for match in re.finditer(r'(?:preload|load)\(\s*"(res://[^"]+)"', raw):
        found.append(match.group(1))
    own = re.search(r"^class_name\s+(\w+)", raw, re.M)
    own_name = own.group(1) if own else ""
    for name in known_classes:
        if name == own_name:
            continue
        if re.search(r"\b%s\b" % re.escape(name), code):
            found.append("class:" + name)
    # One file can reach a class through several references; count it once.
    return list(dict.fromkeys(found))


def build_class_index(files: list[Path]) -> dict[str, str]:
    index: dict[str, str] = {}
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"^class_name\s+(\w+)", text, re.M)
        if match:
            index[match.group(1)] = path.relative_to(GAME).as_posix()
    return index


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--strict", action="store_true", help="exit 1 on any violation")
    parser.add_argument("--baseline", type=Path, help="only fail on violations new to this baseline")
    parser.add_argument("--write-baseline", type=Path, help="write the found violations as the new baseline")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    files = sorted(p for p in GAME.rglob("*.gd") if ".godot" not in p.parts)
    rels = [p.relative_to(GAME).as_posix() for p in files]
    layer_of = {rel: classify(rel) for rel in rels}
    classes = build_class_index(files)

    violations: list[dict[str, str]] = []
    edges = 0
    seen_edges: set[tuple[str, str]] = set()
    for rel in rels:
        src_layer, src_module = layer_of[rel]
        if src_layer == FREE:
            continue
        for target in imports_of(GAME / rel, classes):
            if target.startswith("class:"):
                target_rel = classes.get(target[len("class:") :])
                if target_rel is None or target_rel == rel:
                    continue
            else:
                target_rel = target[len("res://") :]
            if target_rel not in layer_of:
                continue
            dst_layer, dst_module = layer_of[target_rel]
            if dst_layer == FREE:
                continue
            # The same dependency can be written twice (a preload and a type
            # annotation); it is one edge in the graph.
            if (rel, target_rel) in seen_edges:
                continue
            seen_edges.add((rel, target_rel))
            edges += 1
            why = violation(src_layer, src_module, dst_layer, dst_module, target_rel)
            if why:
                violations.append({"file": rel, "imports": target_rel, "rule": why})

    key = lambda v: (v["rule"], v["file"], v["imports"])  # noqa: E731
    violations.sort(key=key)

    baseline: list[dict[str, str]] = []
    if args.baseline and args.baseline.exists():
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    if args.write_baseline:
        args.write_baseline.write_text(json.dumps(violations, indent=2), encoding="utf-8")
        print("wrote %d violation(s) to %s" % (len(violations), args.write_baseline))

    known = {(v["file"], v["imports"], v["rule"]) for v in baseline}
    new = [v for v in violations if (v["file"], v["imports"], v["rule"]) not in known]

    if args.json:
        print(json.dumps({"checked_files": len(rels), "edges": edges,
                          "violations": violations, "new_violations": new}, indent=2))
    else:
        print("architecture check — %d scripts, %d resolved dependencies" % (len(rels), edges))
        counts: dict[str, int] = defaultdict(int)
        for v in violations:
            counts[v["rule"]] += 1
        for rule, count in sorted(counts.items(), key=lambda kv: -kv[1]):
            print("  %3d  %s" % (count, rule))
        if args.baseline:
            print("  new since baseline: %d" % len(new))
        if violations and not args.json:
            print()
            for v in violations[:40]:
                print("    %s" % v["file"])
                print("        -> %s   (%s)" % (v["imports"], v["rule"]))
            if len(violations) > 40:
                print("    ... %d more" % (len(violations) - 40))

    if args.strict and new:
        return 1
    if args.strict and violations and not args.baseline:
        return 1
    return 0


def violation(src_layer: str, src_module: str, dst_layer: str, dst_module: str, target: str) -> str:
    if DATA in (src_layer, dst_layer):
        # A definition registry is readable from anywhere and reads nothing
        # back: it is the contract, not an implementation.
        return ""
    if src_layer == dst_layer:
        if src_layer == "content" and src_module and dst_module and src_module != dst_module:
            # Cross-module is allowed only into the other module's data/.
            if "/data/" not in target and not target.endswith("_definition.gd"):
                return "content/%s reaches into content/%s internals" % (src_module, dst_module)
        if src_layer == "ui" and src_module and dst_module and src_module != dst_module:
            # The HUD and the front-end menus are two different screens and
            # must not reach into each other: a HUD that imports menu stage code
            # cannot be tested, previewed or shipped on its own, which is the
            # whole point of separating them. Shared modules are exempt.
            if dst_module not in SHARED_UI_MODULES:
                return "ui/%s reaches into ui/%s (%s)" % (src_module, dst_module, target)
        return ""
    if dst_layer == "ui":
        if (src_layer, dst_layer) in ALLOWED_UPWARD and dst_module == "design":
            return ""
        return "%s may not import ui (%s)" % (src_layer, target)
    if ORDER[dst_layer] > ORDER[src_layer]:
        return "%s may not import %s (%s)" % (src_layer, dst_layer, target)
    return ""


if __name__ == "__main__":
    sys.exit(main())
