from __future__ import annotations

import hashlib
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools import import_content


class ContentPackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / "contributor-package"
        self.make_package()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def make_package(self, domain: str = "world", package_id: str = "test_world") -> None:
        (self.source / "runtime").mkdir(parents=True, exist_ok=True)
        manifest = {
            "contract_version": 1,
            "id": package_id,
            "domain": domain,
            "entry": "runtime/entry.tscn",
        }
        (self.source / "package.json").write_text(json.dumps(manifest), encoding="utf-8")
        (self.source / "runtime/entry.tscn").write_text(
            '[gd_scene format=3]\n\n[node name="PackageRoot" type="Node3D"]\n',
            encoding="utf-8",
        )
        (self.source / "LICENSE.txt").write_text("CC0 test fixture\n", encoding="utf-8")

    def test_valid_package_bundles_hashes_deterministically(self) -> None:
        texture = self.source / "runtime/plate.png"
        texture.write_bytes(b"test-texture")
        (self.source / "runtime/entry.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="Texture2D" '
            'path="res://content/worlds/test_world/runtime/plate.png" id="1"]\n'
            '[node name="PackageRoot" type="Node3D"]\n',
            encoding="utf-8",
        )
        report = import_content.validate_package(self.source)
        self.assertTrue(report["ok"], report["errors"])
        self.assertEqual(2, len(report["files"]))

        first = import_content.bundle_package(self.source, self.root / "one.zip")
        second = import_content.bundle_package(self.source, self.root / "two.zip")
        self.assertTrue(first["ok"], first["errors"])
        self.assertEqual(first["bundle_sha256"], second["bundle_sha256"])
        with zipfile.ZipFile(self.root / "one.zip") as archive:
            names = set(archive.namelist())
            self.assertIn("world/test_world/content_import.json", names)
            self.assertIn("world/test_world/LICENSE.txt", names)
            integrity = json.loads(archive.read("world/test_world/content_import.json"))
        hashed = next(item for item in integrity["files"] if item["path"] == "runtime/plate.png")
        self.assertEqual(hashlib.sha256(b"test-texture").hexdigest(), hashed["sha256"])

    def test_cross_package_reference_is_rejected(self) -> None:
        (self.source / "runtime/entry.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="PackedScene" '
            'path="res://content/worlds/other/runtime/other.tscn" id="1"]\n'
            '[node name="PackageRoot" type="Node3D"]\n',
            encoding="utf-8",
        )
        report = import_content.validate_package(self.source)
        self.assertFalse(report["ok"])
        self.assertTrue(any("cross-package" in error for error in report["errors"]))

    def test_runtime_scripts_and_generated_caches_are_rejected(self) -> None:
        (self.source / "runtime/bad.gd").write_text("extends Node\n", encoding="utf-8")
        (self.source / "runtime/plate.png.import").write_text("generated", encoding="utf-8")
        (self.source / "runtime/entry.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="Script" path="res://content/worlds/test_world/runtime/bad.gd" id="1"]\n'
            '[node name="PackageRoot" type="Node3D"]\nscript = ExtResource("1")\n',
            encoding="utf-8",
        )
        report = import_content.validate_package(self.source)
        self.assertFalse(report["ok"])
        self.assertTrue(any("scripts/native extensions" in error for error in report["errors"]))
        self.assertTrue(any("generated caches" in error for error in report["errors"]))

    def test_entry_traversal_and_symlink_are_rejected(self) -> None:
        manifest = json.loads((self.source / "package.json").read_text())
        manifest["entry"] = "runtime/../entry.tscn"
        (self.source / "package.json").write_text(json.dumps(manifest))
        report = import_content.validate_package(self.source)
        self.assertFalse(report["ok"])
        self.assertTrue(any("normalized path" in error for error in report["errors"]))

        self.make_package()
        outside = self.root / "outside.png"
        outside.write_bytes(b"outside")
        (self.source / "runtime/link.png").symlink_to(outside)
        report = import_content.validate_package(self.source)
        self.assertFalse(report["ok"])
        self.assertTrue(any("symlinks are forbidden" in error for error in report["errors"]))

    @staticmethod
    def write_glb(path: Path, uri: str) -> None:
        document = json.dumps(
            {"asset": {"version": "2.0"}, "buffers": [{"uri": uri, "byteLength": 4}]}
        ).encode()
        padding = (4 - len(document) % 4) % 4
        document += b" " * padding
        total = 12 + 8 + len(document)
        path.write_bytes(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<II", len(document), 0x4E4F534A) + document)

    def test_glb_dependencies_are_checked(self) -> None:
        manifest = json.loads((self.source / "package.json").read_text())
        manifest["entry"] = "runtime/model.glb"
        (self.source / "package.json").write_text(json.dumps(manifest))
        (self.source / "runtime/entry.tscn").unlink()
        self.write_glb(self.source / "runtime/model.glb", "data.bin")
        (self.source / "runtime/data.bin").write_bytes(b"1234")
        self.assertTrue(import_content.validate_package(self.source)["ok"])

        self.write_glb(self.source / "runtime/model.glb", "missing.bin")
        report = import_content.validate_package(self.source)
        self.assertFalse(report["ok"])
        self.assertTrue(any("dependency is missing" in error for error in report["errors"]))

        self.write_glb(self.source / "runtime/model.glb", "https://example.invalid/data.bin")
        report = import_content.validate_package(self.source)
        self.assertFalse(report["ok"])
        self.assertTrue(any("remote/absolute" in error for error in report["errors"]))

    def test_failed_stage_preserves_active_package(self) -> None:
        first = import_content.stage_package(self.source, self.root)
        self.assertTrue(first["ok"], first["errors"])
        target = self.root / "game/content/worlds/test_world"
        before = {path.relative_to(target): path.read_bytes() for path in target.rglob("*") if path.is_file()}

        (self.source / "runtime/entry.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="Script" path="res://content/worlds/test_world/runtime/bad.gd" id="1"]\n'
            '[node name="PackageRoot" type="Node3D"]\nscript = ExtResource("1")\n',
            encoding="utf-8",
        )
        rejected = import_content.stage_package(self.source, self.root)
        self.assertFalse(rejected["ok"])
        after = {path.relative_to(target): path.read_bytes() for path in target.rglob("*") if path.is_file()}
        self.assertEqual(before, after)
        self.assertFalse(any(path.name.startswith(".test_world.") for path in target.parent.iterdir()))

    def test_stage_and_committed_check_use_only_validated_content(self) -> None:
        report = import_content.stage_package(self.source, self.root)
        self.assertTrue(report["ok"], report["errors"])
        self.assertEqual("res://content/worlds/test_world", report["target"])
        target = self.root / "game/content/worlds/test_world"
        self.assertTrue((target / "content_import.json").is_file())
        committed = import_content.check_committed(self.root)
        self.assertEqual(1, len(committed))
        self.assertTrue(committed[0]["ok"], committed[0]["errors"])

        (self.root / "game/content/characters/unmanifested").mkdir(parents=True)
        committed = import_content.check_committed(self.root)
        self.assertEqual(2, len(committed))
        self.assertTrue(any(not report["ok"] for report in committed))

    def test_bundle_cannot_contaminate_source(self) -> None:
        report = import_content.bundle_package(self.source, self.source / "runtime/bundle.zip")
        self.assertFalse(report["ok"])
        self.assertTrue(any("outside the source" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
