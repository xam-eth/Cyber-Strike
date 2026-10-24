#!/usr/bin/env python3
"""Unit tests for tools/check_static_calls.py (run by scripts/dev_check.sh and CI).

The first test is the regression that started it: commit `0884658` shipped a
zone file whose builder had lost its `static` keyword, every static check stayed
green, and the game could not load (`Cannot call non-static function
"build_central_arena()" on the class "NeonFrontierArena" directly`).
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_static_calls  # noqa: E402  (path is set above)


class StaticCallTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def violations(self) -> list[check_static_calls.Violation]:
        return check_static_calls.check_tree(self.root)

    # -- the regression ---------------------------------------------------- #
    def test_instance_method_called_on_class_is_reported(self) -> None:
        self.write(
            "zones/arena.gd",
            "class_name ZoneArena\n"
            "extends RefCounted\n"
            "\n"
            "func build_central_arena(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tZoneArena.build_central_arena(self)\n",
        )
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0].rel, "world.gd")
        self.assertEqual(violations[0].line, 4)
        self.assertEqual(violations[0].method, "build_central_arena")
        self.assertIn("non-static", violations[0].message)
        self.assertIn("make build_central_arena() `static`", violations[0].suggestion)

    def test_static_method_called_on_class_is_clean(self) -> None:
        self.write(
            "zones/routes.gd",
            "class_name ZoneRoutes\n"
            "extends RefCounted\n"
            "\n"
            "static func build_access_routes(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tZoneRoutes.build_access_routes(self)\n",
        )
        self.assertEqual(self.violations(), [])

    # -- the false positives a grep would produce -------------------------- #
    def test_class_name_in_comment_is_not_a_call(self) -> None:
        self.write(
            "zones/arena.gd",
            "class_name ZoneArena\n"
            "extends RefCounted\n"
            "\n"
            "func build_central_arena(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "## The arena used to be built here: ZoneArena.build_central_arena(self).\n"
            "# ZoneArena.build_central_arena(self) moved out of this file.\n"
            "func _ready() -> void:\n"
            '\tprint("ZoneArena.build_central_arena(self)")\n',
        )
        self.assertEqual(self.violations(), [])

    def test_call_on_an_instance_is_not_a_class_call(self) -> None:
        self.write(
            "zones/arena.gd",
            "class_name ZoneArena\n"
            "extends RefCounted\n"
            "\n"
            "func build_central_arena(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tvar arena := ZoneArena.new()\n"
            "\tarena.build_central_arena(self)\n",
        )
        self.assertEqual(self.violations(), [])

    def test_engine_classes_are_not_our_business(self) -> None:
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tvar v := Vector3.ZERO\n"
            "\tadd_child(PackedScene.new())\n"
            "\tvar t := Transform3D(Basis.IDENTITY, v)\n",
        )
        self.assertEqual(self.violations(), [])

    # -- aliases, inheritance, missing methods ----------------------------- #
    def test_preload_alias_resolves_to_the_target_file(self) -> None:
        self.write(
            "scifi_bay_builder.gd",
            "class_name ScifiBayBuilder\n"
            "extends RefCounted\n"
            "\n"
            "func build(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "world.gd",
            'const ScifiBayBuilderAlias = preload("res://scifi_bay_builder.gd")\n'
            "\n"
            "func _ready() -> void:\n"
            "\tScifiBayBuilderAlias.build(self)\n",
        )
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0].receiver, "ScifiBayBuilderAlias")

    def test_static_method_inherited_from_a_base_class_is_clean(self) -> None:
        self.write(
            "base_zone.gd",
            "class_name BaseZone\n"
            "extends RefCounted\n"
            "\n"
            "static func build(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "arena.gd",
            "class_name ZoneArena\n"
            "extends BaseZone\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tZoneArena.build(self)\n",
        )
        self.assertEqual(self.violations(), [])

    def test_instance_method_inherited_from_a_base_class_is_reported(self) -> None:
        self.write(
            "base_zone.gd",
            "class_name BaseZone\n"
            "extends RefCounted\n"
            "\n"
            "func build(world) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "arena.gd",
            "class_name ZoneArena\n"
            "extends BaseZone\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tZoneArena.build(self)\n",
        )
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0].resolved, "base_zone.gd")

    def test_missing_method_is_reported(self) -> None:
        self.write(
            "arena.gd",
            "class_name ZoneArena\n"
            "extends RefCounted\n"
            "\n"
            "static func build(self_) -> void:\n"
            "\tpass\n",
        )
        self.write(
            "world.gd",
            "extends Node3D\n"
            "\n"
            "func _ready() -> void:\n"
            "\tZoneArena.build_arena(self)\n",
        )
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("declare build_arena()", violations[0].message)

    # -- the command line --------------------------------------------------- #
    def test_main_reports_exit_codes_and_json(self) -> None:
        self.write(
            "arena.gd",
            "class_name ZoneArena\nextends RefCounted\n\nfunc build(world) -> void:\n\tpass\n",
        )
        self.write("world.gd", "extends Node3D\n\nfunc _ready() -> void:\n\tZoneArena.build(self)\n")
        self.assertEqual(check_static_calls.main(["--root", str(self.root), "--quiet"]), 1)
        self.assertEqual(
            check_static_calls.main(["--root", str(self.root), "--json"]),
            1,
        )
        (self.root / "world.gd").write_text("extends Node3D\n", encoding="utf-8")
        self.assertEqual(check_static_calls.main(["--root", str(self.root), "--quiet"]), 0)
        self.assertEqual(check_static_calls.main(["--root", str(self.root / "nope")]), 2)


if __name__ == "__main__":
    unittest.main()
