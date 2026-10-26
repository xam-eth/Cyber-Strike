#!/usr/bin/env python3
"""Remove redundant rest-pose scale channels from skinned-character GLBs.

Character animation should not key bone scale: it adds hundreds of needless
tracks and can produce engine-specific import behaviour. This tool only removes
scale channels on skin joints when every sample exactly matches that node's
rest scale. Dynamic or non-rest scale tracks are treated as unsafe and are
preserved; the tool never guesses whether a real deformation is disposable.

Dry-run (default):
    python3 tools/gltf/strip_static_scale_tracks.py --check

Apply the safe cleanup:
    python3 tools/gltf/strip_static_scale_tracks.py --write

The GLB mesh, skin, animation rotations/translations, and binary payload are
left byte-for-byte unchanged. Only redundant animation channels and their
unreferenced animation samplers are removed from the JSON chunk.
"""
from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODELS = (
    ROOT / "game/assets/enemies/enemy_robot_common.glb",
    ROOT / "game/assets/enemies/enemy_robot_tier_2_rare.glb",
    ROOT / "game/assets/enemies/enemy_robot_tier_3_epic.glb",
    *(ROOT / f"game/assets/characters/human_hero_tiers/hero_human_tier_{tier}.glb" for tier in range(1, 6)),
)

GLB_MAGIC = 0x46546C67
GLB_JSON = 0x4E4F534A
GLB_BIN = 0x004E4942
COMPONENT_FORMATS = {
    5120: ("b", 1),
    5121: ("B", 1),
    5122: ("h", 2),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
TYPE_COMPONENTS = {"VEC3": 3}
# Exporters often round a nominal unit scale by a few float32 ULPs. This
# tolerance (2e-5 in scale-factor space) is still far below any visible or
# meaningful deformation and avoids treating that serialization noise as art.
TOLERANCE = 2e-5


def _parse_glb(data: bytes) -> tuple[dict[str, Any], bytes, list[tuple[int, bytes]]]:
    if len(data) < 20:
        raise ValueError("file is too short to be a GLB")
    magic, version, declared_length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2:
        raise ValueError("expected a GLB version 2 file")
    if declared_length != len(data):
        raise ValueError(f"GLB header length {declared_length} differs from file size {len(data)}")

    chunks: list[tuple[int, bytes]] = []
    document = None
    binary = b""
    offset = 12
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError("truncated GLB chunk header")
        length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        end = offset + length
        if end > len(data):
            raise ValueError("truncated GLB chunk payload")
        payload = data[offset:end]
        offset = end
        chunks.append((chunk_type, payload))
        if chunk_type == GLB_JSON:
            if document is not None:
                raise ValueError("GLB contains more than one JSON chunk")
            document = json.loads(payload.decode("utf-8").rstrip("\x00 \t\r\n"))
        elif chunk_type == GLB_BIN:
            if binary:
                raise ValueError("GLB contains more than one BIN chunk")
            binary = payload
    if document is None:
        raise ValueError("GLB has no JSON chunk")
    return document, binary, chunks


def _encode_glb(document: dict[str, Any], chunks: list[tuple[int, bytes]]) -> bytes:
    json_payload = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    json_payload += b" " * ((4 - len(json_payload) % 4) % 4)

    encoded_chunks: list[tuple[int, bytes]] = []
    replaced_json = False
    for chunk_type, payload in chunks:
        if chunk_type == GLB_JSON:
            if replaced_json:
                raise ValueError("cannot rewrite multiple JSON chunks")
            payload = json_payload
            replaced_json = True
        encoded_chunks.append((chunk_type, payload))
    if not replaced_json:
        raise ValueError("GLB JSON chunk disappeared during cleanup")

    output = bytearray()
    total_length = 12 + sum(8 + len(payload) for _, payload in encoded_chunks)
    output += struct.pack("<III", GLB_MAGIC, 2, total_length)
    for chunk_type, payload in encoded_chunks:
        output += struct.pack("<II", len(payload), chunk_type)
        output += payload
    return bytes(output)


def _accessor_vec3(document: dict[str, Any], binary: bytes, accessor_index: int) -> list[tuple[float, float, float]]:
    accessor = document["accessors"][accessor_index]
    if accessor.get("type") != "VEC3" or "bufferView" not in accessor or "sparse" in accessor:
        raise ValueError("scale output accessor is not a plain buffer-backed VEC3")
    component_type = int(accessor["componentType"])
    if component_type not in COMPONENT_FORMATS:
        raise ValueError(f"unsupported scale accessor component type {component_type}")
    fmt, component_size = COMPONENT_FORMATS[component_type]
    view_index = int(accessor["bufferView"])
    view = document["bufferViews"][view_index]
    if view.get("extensions", {}).get("EXT_meshopt_compression"):
        raise ValueError("scale output is meshopt-compressed and cannot be safely inspected without decoding")

    stride = int(view.get("byteStride", component_size * 3))
    start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    count = int(accessor["count"])
    if stride < component_size * 3 or start < 0:
        raise ValueError("invalid scale accessor stride or offset")
    end = start + (count - 1) * stride + component_size * 3 if count else start
    if end > len(binary):
        raise ValueError("scale output accessor points beyond the GLB BIN chunk")

    values: list[tuple[float, float, float]] = []
    for index in range(count):
        row = struct.unpack_from("<" + fmt * 3, binary, start + index * stride)
        values.append(tuple(float(component) for component in row))

    if accessor.get("normalized") and component_type != 5126:
        if component_type in (5120, 5122):
            maximum = 127.0 if component_type == 5120 else 32767.0
            values = [tuple(max(-1.0, component / maximum) for component in row) for row in values]
        elif component_type in (5121, 5123, 5125):
            maximum = {5121: 255.0, 5123: 65535.0, 5125: 4294967295.0}[component_type]
            values = [tuple(component / maximum for component in row) for row in values]
    return values


def _is_rest_scale(
    document: dict[str, Any], binary: bytes, channel: dict[str, Any], tolerance: float
) -> tuple[bool, str]:
    target = channel.get("target", {})
    node_index = target.get("node")
    nodes = document.get("nodes", [])
    if not isinstance(node_index, int) or node_index < 0 or node_index >= len(nodes):
        return False, "invalid-node"
    node = nodes[node_index]
    if "matrix" in node:
        return False, "matrix-rest-transform"
    rest = node.get("scale", [1.0, 1.0, 1.0])
    if not isinstance(rest, list) or len(rest) != 3:
        return False, "invalid-rest-scale"

    sampler_index = channel.get("sampler")
    animation = channel.get("_animation")
    if not isinstance(sampler_index, int) or not isinstance(animation, dict):
        return False, "invalid-sampler"
    samplers = animation.get("samplers", [])
    if sampler_index < 0 or sampler_index >= len(samplers):
        return False, "invalid-sampler"
    output_index = samplers[sampler_index].get("output")
    if not isinstance(output_index, int) or output_index < 0 or output_index >= len(document.get("accessors", [])):
        return False, "invalid-output-accessor"

    try:
        values = _accessor_vec3(document, binary, output_index)
    except (KeyError, IndexError, TypeError, ValueError, struct.error) as error:
        return False, f"unreadable-output:{error}"
    if not values:
        return False, "empty-output"
    rest_values = [float(value) for value in rest]
    matches = all(
        abs(value - rest_value) <= tolerance
        for row in values
        for value, rest_value in zip(row, rest_values)
    )
    return (True, "rest-scale") if matches else (False, "non-rest-or-dynamic-scale")


def clean_scale_channels(data: bytes, tolerance: float = TOLERANCE) -> tuple[bytes, dict[str, Any]]:
    """Return a GLB with only provably redundant skin-joint scale channels removed."""
    document, binary, chunks = _parse_glb(data)
    skin_joints = {
        int(joint)
        for skin in document.get("skins", [])
        for joint in skin.get("joints", [])
        if isinstance(joint, int)
    }
    report: dict[str, Any] = {
        "animations": {},
        "removed_scale_channels": 0,
        "remaining_bone_scale_channels": 0,
        "unsafe_reasons": {},
    }

    for animation in document.get("animations", []):
        name = str(animation.get("name", "<unnamed>"))
        original_channels = animation.get("channels", [])
        original_samplers = animation.get("samplers", [])
        kept_channels: list[dict[str, Any]] = []
        removed = 0
        remaining = 0

        for channel in original_channels:
            target = channel.get("target", {})
            if target.get("path") != "scale" or target.get("node") not in skin_joints:
                kept_channels.append(channel)
                continue

            # Attach the owning animation only for the local validation helper;
            # it is removed before serializing the glTF document.
            channel_with_animation = dict(channel)
            channel_with_animation["_animation"] = animation
            rest_match, reason = _is_rest_scale(document, binary, channel_with_animation, tolerance)
            if rest_match:
                removed += 1
                continue
            remaining += 1
            report["unsafe_reasons"][reason] = report["unsafe_reasons"].get(reason, 0) + 1
            kept_channels.append(channel)

        used_samplers = sorted({int(channel["sampler"]) for channel in kept_channels})
        sampler_map = {old_index: new_index for new_index, old_index in enumerate(used_samplers)}
        for channel in kept_channels:
            old_index = int(channel["sampler"])
            if old_index < 0 or old_index >= len(original_samplers):
                raise ValueError(f"{name}: channel references an invalid sampler {old_index}")
            channel["sampler"] = sampler_map[old_index]

        animation["channels"] = kept_channels
        animation["samplers"] = [original_samplers[index] for index in used_samplers]
        report["animations"][name] = {
            "removed_scale_channels": removed,
            "remaining_bone_scale_channels": remaining,
            "channels_after": len(kept_channels),
            "samplers_after": len(animation["samplers"]),
        }
        report["removed_scale_channels"] += removed
        report["remaining_bone_scale_channels"] += remaining

    if report["removed_scale_channels"] == 0:
        return data, report
    return _encode_glb(document, chunks), report


def strip_file(path: Path) -> dict[str, Any]:
    original = path.read_bytes()
    cleaned, report = clean_scale_channels(original)
    if report["remaining_bone_scale_channels"]:
        details = ", ".join(f"{reason}={count}" for reason, count in sorted(report["unsafe_reasons"].items()))
        raise ValueError(f"{path}: refusing cleanup; {report['remaining_bone_scale_channels']} non-rest skin scale tracks remain ({details})")
    if cleaned != original:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
        temporary = Path(temporary_name)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(cleaned)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(temporary, path.stat().st_mode)
            os.replace(temporary, path)
        finally:
            if temporary.exists():
                temporary.unlink()
    return report


def _print_report(path: Path, report: dict[str, Any], applied: bool = False) -> None:
    per_clip = ", ".join(
        f"{name}:{item['removed_scale_channels']} removed"
        for name, item in report["animations"].items()
        if item["removed_scale_channels"]
    ) or "no redundant tracks"
    remaining = report["remaining_bone_scale_channels"]
    if applied and report["removed_scale_channels"] and remaining == 0:
        state = "CLEANED"
    else:
        state = "CLEAN" if report["removed_scale_channels"] == 0 and remaining == 0 else "NEEDS CLEANUP"
    print(f"{state}: {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path} · {per_clip} · remaining={remaining}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="inspect only; return non-zero if cleanup is needed")
    mode.add_argument("--write", action="store_true", help="remove only scale tracks that exactly match rest scale")
    parser.add_argument("models", nargs="*", type=Path, help="GLB files (defaults to Robot Common, enemy robot T2/T3, and human hero T1–T5 runtime models)")
    args = parser.parse_args()
    paths = args.models or list(DEFAULT_MODELS)
    failures = 0

    for model in paths:
        path = model if model.is_absolute() else (ROOT / model)
        try:
            if args.write:
                report = strip_file(path)
                _print_report(path, report, applied=True)
                if report["remaining_bone_scale_channels"]:
                    failures += 1
            else:
                _, report = clean_scale_channels(path.read_bytes())
                _print_report(path, report)
                if report["removed_scale_channels"] or report["remaining_bone_scale_channels"]:
                    failures += 1
        except (OSError, ValueError, json.JSONDecodeError, struct.error) as error:
            print(f"ERROR: {error}", file=sys.stderr)
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
