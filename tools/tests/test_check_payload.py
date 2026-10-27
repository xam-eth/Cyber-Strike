"""Regression tests for monolithic PCK and Godot 4.7 Android sparse bundles."""

from __future__ import annotations

import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.check_payload import MAGIC, parse_pck


def make_pack(entries: list[tuple[str, int, int]], sparse: bool = False) -> bytes:
    flags = 4 if sparse else 0  # PACK_SPARSE_BUNDLE
    header = struct.pack("<4sIIIIIQQ", MAGIC, 4, 4, 7, 2, flags, 0, 40)
    records = [struct.pack("<I", len(entries))]
    for path, offset, size in entries:
        encoded = path.encode("utf-8")
        records.append(struct.pack("<I", len(encoded)))
        records.append(encoded)
        records.append(struct.pack("<QQ", offset, size))
        records.append(bytes(16))
        records.append(struct.pack("<I", 0))
    return header + b"".join(records)


class CheckPayloadTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write_apk(self, metadata: bytes, assets: dict[str, bytes]) -> Path:
        apk = self.root / "game.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("assets/assets.sparsepck", metadata)
            for name, payload in assets.items():
                archive.writestr("assets/" + name, payload)
        return apk

    def test_monolithic_pck_layout_remains_supported(self) -> None:
        pck = self.root / "index.pck"
        pck.write_bytes(make_pack([("scripts/main.gdc", 0, 4)]))
        entries, version, engine = parse_pck(str(pck))
        self.assertEqual(entries, [("scripts/main.gdc", 0, 4)])
        self.assertEqual(version, 4)
        self.assertEqual(engine, "4.7.2")

    def test_sparse_apk_checks_external_asset_and_ignores_metadata_offset(self) -> None:
        payload = b"x" * 123
        metadata = make_pack([("res://scripts/main.gdc", 987654321, len(payload))], sparse=True)
        apk = self.write_apk(metadata, {"scripts/main.gdc": payload})
        entries, version, _ = parse_pck(str(apk))
        self.assertEqual(entries, [("scripts/main.gdc", 987654321, 123)])
        self.assertEqual(version, 4)

    def test_sparse_apk_rejects_missing_asset(self) -> None:
        metadata = make_pack([("scripts/main.gdc", 0, 4)], sparse=True)
        apk = self.write_apk(metadata, {})
        with self.assertRaisesRegex(SystemExit, "missing sparse asset"):
            parse_pck(str(apk))

    def test_sparse_apk_rejects_size_mismatch(self) -> None:
        metadata = make_pack([("scripts/main.gdc", 0, 4)], sparse=True)
        apk = self.write_apk(metadata, {"scripts/main.gdc": b"too long"})
        with self.assertRaisesRegex(SystemExit, "directory declares 4"):
            parse_pck(str(apk))

    def test_sparse_apk_rejects_traversal(self) -> None:
        metadata = make_pack([("../secret", 0, 4)], sparse=True)
        apk = self.write_apk(metadata, {})
        with self.assertRaisesRegex(SystemExit, "unsafe sparse asset path"):
            parse_pck(str(apk))

    def test_archive_without_pack_has_explicit_error(self) -> None:
        apk = self.root / "empty.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("assets/readme.txt", "not a pack")
        with self.assertRaisesRegex(SystemExit, "no .pck or .sparsepck"):
            parse_pck(str(apk))


if __name__ == "__main__":
    unittest.main()
