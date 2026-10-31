#!/usr/bin/env python3
"""Check what an exported Godot payload actually contains.

The audit found the web build shipping the whole test suite: `res://tests`
appeared 27 times inside `web/index.pck`, and no export preset carried an
`exclude_filter`. Pack contents are invisible from the repository, so this
tool reads the PCK directory itself and asserts what may and may not be in
there.

Godot 4 PCK layout, read off `core/io/file_access_pack.cpp`
(`PackedSourcePCK::try_open_pack`) rather than guessed — the V4 header carries
a *directory offset* and every directory entry ends with a flags word, and both
are easy to miss:

    "GDPC" u32 version, u32 major, u32 minor, u32 patch,
    u32 pack_flags, u64 file_base,
    u64 dir_offset                      <- V3/V4 only; the directory may sit
                                           anywhere, in practice at the end
    [32-byte salt]                      <- V4 + encrypted + sparse only
    at dir_offset: u32 file_count
    then per file: u32 path_len, path bytes, u64 offset, u64 size,
                   16 bytes md5, u32 flags

V2 is different (16 reserved words, directory straight after the header), so
the version is checked and V2 is rejected instead of being misread.

Usage:
    check_payload.py <file.pck> [--json]
    check_payload.py web/index.pck
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from collections import Counter

MAGIC = b"GDPC"
# magic(4) version(4) major+minor+patch(12) flags(4) file_base(8) -> dir_offset
DIR_OFFSET_POS = 32

# Patterns that must never reach a player. The tests are 8,141 lines of
# assertions; `scripts/qa` is the keyboard review rig (see docs/DECISIONS.md
# §5 — it is currently instanced in main.tscn, so it is reported, not failed).
FORBIDDEN = {
    "tests/": ("the smoke test suite", True),
    "assets/world/real/": ("asset-forge source library; only the staged runtime world should ship", True),
    "assets/enemies/enemy_robot_": ("unactivated enemy visual/rig review candidates", True),
    "assets/enemies/enemy_iron_sentinel": ("unactivated enemy visual/rig review candidates", True),
    "scripts/qa/": ("QA-only code (keyboard review rig)", False),
}
# Extensions Godot should never pack: editor metadata.
#
# ".import" is deliberately NOT in this list even though it looks like editor
# metadata, because it is not: it is the runtime lookup table that turns
# `res://hero.glb` into the resource the exporter actually converted. Verified in
# the engine source rather than assumed:
#   * core/io/resource_importer.cpp:46 and :331 — `ResourceFormatImporter` opens
#     `p_path + ".import"` when loading and when resolving a resource path, so a
#     pack without them cannot load a single imported asset.
#   * editor/export/editor_export_platform.cpp:1632 and :1699 — the exporter
#     writes each imported file's ".import" itself, rewritten to point at
#     .godot/exported/, through the save proxy. Export filters are applied when
#     the file list is built, not in the writer, so `exclude_filter="*.import"`
#     would silently not remove them anyway.
# Flagging them as a failure here was a false positive of exactly the kind that
# gets a gate ignored, so they are reported, with the reason, and never failed.
FORBIDDEN_SUFFIXES = (".uid",)


def read_directory(
    data: bytes, start: int, count: int, validate_offsets: bool = True
) -> list[tuple[str, int, int]]:
    """Read `count` entries; sparse bundles keep payloads outside the metadata."""
    out: list[tuple[str, int, int]] = []
    pos = start
    size = len(data)
    for _ in range(count):
        if pos + 4 > size:
            return []
        (path_len,) = struct.unpack_from("<I", data, pos)
        pos += 4
        if path_len == 0 or path_len > 512 or pos + path_len > size:
            return []
        raw = data[pos : pos + path_len]
        pos += path_len
        if pos + 20 > size:  # ofs(8) size(8) md5(16) flags(4)
            return []
        offset, file_size = struct.unpack_from("<QQ", data, pos)
        pos += 16 + 16 + 4
        try:
            path = raw.rstrip(b"\x00").decode("utf-8")
        except UnicodeDecodeError:
            return []
        if path.startswith("res://"):
            path = path[6:]
        if any(ord(ch) < 32 for ch in path):
            return []
        # Offsets are relative to file_base in a self-contained pack. Sparse
        # APK entries instead name separate assets and are checked below.
        if validate_offsets and (offset > size or file_size > size):
            return []
        out.append((path, offset, file_size))
    return out


def pck_bytes(path: str) -> tuple[bytes, str]:
    """Return monolithic PCK bytes or an Android sparse-bundle directory.

    Godot 4.7 Android exports use `assets/assets.sparsepck` plus separate
    asset entries instead of a monolithic `.pck`. Both layouts contain the same
    directory records and must pass the same forbidden-content audit.
    """
    if path.endswith(".pck"):
        with open(path, "rb") as handle:
            return handle.read(), path
    import zipfile

    with zipfile.ZipFile(path) as archive:
        archive_names = archive.namelist()
        names = [name for name in archive_names if name.endswith(".pck")]
        sparse = [name for name in archive_names if name.endswith(".sparsepck")]
        if not names and len(sparse) == 1:
            return archive.read(sparse[0]), "%s::%s" % (path, sparse[0])
        if not names and len(sparse) > 1:
            raise SystemExit("%s: multiple sparse PCK directories found" % path)
        if not names:
            raise SystemExit(
                "%s: no .pck or .sparsepck found inside the archive (%d entries, %d named "
                "*.so/*.dex)"
                % (
                    path,
                    len(archive_names),
                    sum(1 for name in archive_names if name.endswith((".so", ".dex"))),
                )
            )
        names.sort()
        return archive.read(names[0]), "%s::%s" % (path, names[0])


def validate_sparse_assets(
    path: str, label: str, entries: list[tuple[str, int, int]]
) -> None:
    """Check that every sparse directory record has the matching ZIP asset."""
    import zipfile

    if "::" not in label:
        raise SystemExit("%s: sparse PCK metadata requires its containing APK" % path)
    metadata_name = label.split("::", 1)[1]
    asset_root = metadata_name.rsplit("/", 1)[0] if "/" in metadata_name else ""
    with zipfile.ZipFile(path) as archive:
        infos = {info.filename: info for info in archive.infolist()}
        for entry_path, _offset, file_size in entries:
            if not entry_path or entry_path.startswith("/") or ".." in entry_path.split("/"):
                raise SystemExit("%s: unsafe sparse asset path %r" % (path, entry_path))
            asset_name = (asset_root + "/" if asset_root else "") + entry_path
            info = infos.get(asset_name)
            if info is None:
                raise SystemExit("%s: missing sparse asset %s" % (path, asset_name))
            if info.file_size != file_size:
                raise SystemExit(
                    "%s: sparse asset %s has %d bytes; directory declares %d"
                    % (path, asset_name, info.file_size, file_size)
                )


def parse_pck(path: str) -> tuple[list[tuple[str, int, int]], int, str]:
    data, label = pck_bytes(path)
    if data[:4] != MAGIC:
        raise SystemExit("%s: not a Godot PCK (magic %r)" % (path, data[:4]))
    if len(data) < DIR_OFFSET_POS + 8:
        raise SystemExit("%s: truncated header" % path)
    version, major, minor, patch = struct.unpack_from("<IIII", data, 4)
    (pack_flags,) = struct.unpack_from("<I", data, 20)
    sparse = bool(pack_flags & 4)  # PACK_SPARSE_BUNDLE in core/io/file_access_pack.h.
    if sparse and version != 4:
        raise SystemExit("%s: sparse bundles require PCK format version 4" % path)
    engine = "%d.%d.%d" % (major, minor, patch)
    if version >= 3:
        (directory,) = struct.unpack_from("<Q", data, DIR_OFFSET_POS)
    elif version == 2:
        directory = DIR_OFFSET_POS + 8 + 16 * 4
    else:
        raise SystemExit("%s: unsupported pack format version %d" % (path, version))
    if directory + 4 > len(data):
        raise SystemExit(
            "%s: directory offset %d is past the end of a %d byte file"
            % (path, directory, len(data))
        )
    (count,) = struct.unpack_from("<I", data, directory)
    entries = read_directory(data, directory + 4, count, validate_offsets=not sparse)
    if len(entries) != count:
        raise SystemExit(
            "%s: read %d of %d directory entries — the layout does not match "
            "pack format version %d" % (path, len(entries), count, version)
        )
    if sparse:
        validate_sparse_assets(path, label, entries)
    return entries, version, engine


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pck", help="path to the exported .pck or .apk")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    entries, version, engine = parse_pck(args.pck)
    label = args.pck
    total = sum(size for _, _, size in entries)
    # Paths are stored without the `res://` prefix; the first segment is the
    # top-level folder (`.godot/exported` holds the imported resources).
    prefixes = Counter(p.split("/")[0] if "/" in p else "(file at root)" for p, _, _ in entries)

    problems: list[str] = []
    findings: list[str] = []
    # Reported, not failed: see FORBIDDEN_SUFFIXES for why these must ship.
    import_maps = [p for p, _, _ in entries if p.endswith(".import")]
    if import_maps:
        findings.append(
            "%d .import file(s) — required at runtime, not editor metadata "
            "(they map each source asset to its converted resource)" % len(import_maps)
        )
    for pattern, (description, hard_fail) in FORBIDDEN.items():
        hits = [(p, s) for p, _, s in entries if pattern in p]
        if hits:
            line = "%d file(s) matching '%s' — %s (%.0f KB)" % (
                len(hits),
                pattern,
                description,
                sum(s for _, s in hits) / 1024.0,
            )
            (problems if hard_fail else findings).append(line)
    meta = [(p, s) for p, _, s in entries if p.endswith(FORBIDDEN_SUFFIXES)]
    if meta:
        problems.append(
            "%d editor metadata file(s) packed (%s)" % (len(meta), ", ".join(sorted({p.split(".")[-1] for p, _ in meta})))
        )

    if args.json:
        print(
            json.dumps(
                {
                    "pck": args.pck,
                    "pack_version": version,
                    "engine": engine,
                    "files": len(entries),
                    "bytes": total,
                    "prefixes": dict(prefixes.most_common()),
                    "problems": problems,
                    "notes": findings,
                },
                indent=2,
            )
        )
        return 1 if problems else 0

    print("payload: %s" % label)
    print("  pack format version : %d (engine %s)" % (version, engine))
    print("  files               : %d" % len(entries))
    print("  total size          : %.1f MB" % (total / 1e6))
    print("  top-level folders   :")
    for name, count in prefixes.most_common(12):
        print("      %5d  res://%s/" % (count, name))
    for note in findings:
        print("  note: %s" % note)
    if problems:
        print("  FAIL:")
        for problem in problems:
            print("      - %s" % problem)
        print("  -> add an `exclude_filter` to the export presets and re-export")
        return 1
    print("  ok: nothing that should not ship is in the payload")
    return 0


if __name__ == "__main__":
    sys.exit(main())
