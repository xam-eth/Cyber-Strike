#!/usr/bin/env python3
"""Stage the manifest's GLBs inside the standalone Godot QA project.

The staged copies are ignored by Git so character binaries are not duplicated
in the repository. Runtime-form character assets stay in game/assets, while
original source GLBs stay in source-assets. Before staging, this command cross-checks
canonical roles, tiers, reference labels, runtime rig profiles, and source paths; the
staged copies are then kept byte-identical to their sources.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "character_visual_qa"
MANIFEST = PROJECT / "asset_manifest.json"
STAGED_MANIFEST = PROJECT / "staged_assets.json"
GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
sys.path.insert(0, str(ROOT / "tools/gltf"))
from asset_identity import ASSET_IDENTITIES, identity_for, validate_profile_identity  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_glb_document(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("file is too short to be a GLB 2.0 container")
    magic, version, total_length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError("invalid GLB magic number")
    if version != 2:
        raise ValueError(f"expected GLB version 2, found {version}")
    if total_length != len(data):
        raise ValueError(f"GLB header length {total_length} differs from file length {len(data)}")

    document: dict[str, Any] | None = None
    offset = 12
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError("truncated GLB chunk header")
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        chunk_start = offset + 8
        chunk_end = chunk_start + chunk_length
        if chunk_end > len(data):
            raise ValueError("GLB chunk extends beyond the end of the file")
        if chunk_type == JSON_CHUNK:
            if document is not None:
                raise ValueError("GLB contains more than one JSON chunk")
            try:
                parsed = json.loads(
                    data[chunk_start:chunk_end].decode("utf-8").rstrip("\x00 \t\r\n")
                )
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise ValueError(f"invalid GLB JSON chunk: {error}") from error
            if not isinstance(parsed, dict):
                raise ValueError("GLB JSON root must be an object")
            document = parsed
        offset = chunk_end
    if offset != len(data):
        raise ValueError("GLB chunk table does not end at the file boundary")
    if document is None:
        raise ValueError("GLB has no JSON chunk")
    asset = document.get("asset")
    if not isinstance(asset, dict) or str(asset.get("version", "")) != "2.0":
        raise ValueError("glTF asset.version must be 2.0")
    return document


def validate_glb_contract(entry: dict[str, Any], path: Path) -> None:
    document = _read_glb_document(path)
    nodes = document.get("nodes", [])
    if not isinstance(nodes, list) or not nodes:
        raise ValueError("GLB contains no nodes")
    empty_children = [
        index
        for index, node in enumerate(nodes)
        if isinstance(node, dict) and node.get("children") == []
    ]
    if empty_children:
        raise ValueError(f"GLB nodes contain empty children arrays: {empty_children}")
    if document.get("animations") == []:
        raise ValueError("GLB contains an empty animations array; omit it when no clips exist")

    meshes = document.get("meshes", [])
    if not isinstance(meshes, list) or not meshes:
        raise ValueError("GLB contains no meshes")
    if any(
        not isinstance(mesh, dict)
        or not isinstance(mesh.get("primitives", []), list)
        or not mesh.get("primitives")
        for mesh in meshes
    ):
        raise ValueError("GLB contains a mesh with no primitives")

    skins = document.get("skins", [])
    if not isinstance(skins, list) or any(not isinstance(skin, dict) for skin in skins):
        raise ValueError("GLB skins member must be an array of objects")
    joint_counts = [len(skin.get("joints", [])) for skin in skins]
    requires_skin = bool(entry.get("requires_skin", False))
    expected_joints = int(entry.get("expected_joint_count", 0))
    if requires_skin and not joint_counts:
        raise ValueError("manifest requires a skin, but the GLB contains none")
    if expected_joints > 0 and expected_joints not in joint_counts:
        found = ", ".join(str(count) for count in joint_counts) or "none"
        raise ValueError(f"expected a {expected_joints}-joint skin, found {found}")
    if not requires_skin and any(joint_counts):
        raise ValueError(
            f"manifest expects an unskinned model, but found skin joint counts {joint_counts}"
        )

    animations = document.get("animations", [])
    if not isinstance(animations, list) or any(not isinstance(item, dict) for item in animations):
        raise ValueError("GLB animations member must be an array of objects")
    available_clips = {str(animation.get("name", "")) for animation in animations}
    missing_clips = sorted(
        set(map(str, entry.get("expected_animation_names", []))) - available_clips
    )
    if missing_clips:
        raise ValueError(f"GLB is missing required animation clips: {', '.join(missing_clips)}")


def _resolve_repository_file(asset_id: str, field: str, raw_path: str) -> Path:
    relative = Path(raw_path)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"{asset_id}: {field} must be a repository-relative path")
    resolved = (ROOT / relative).resolve()
    if ROOT.resolve() not in resolved.parents:
        raise ValueError(f"{asset_id}: {field} resolves outside the repository")
    if not resolved.is_file():
        raise FileNotFoundError(f"{asset_id}: {field} is missing: {relative}")
    return resolved


def _repo_path(raw: str, asset_id: str, field: str) -> Path:
    relative = Path(raw)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"{asset_id}: {field} must be repository-relative")
    resolved = (ROOT / relative).resolve()
    if ROOT.resolve() not in resolved.parents:
        raise ValueError(f"{asset_id}: {field} resolves outside the repository")
    return resolved


def _validate_asset_identity(entry: dict[str, Any], asset_id: str) -> None:
    identity = entry.get("asset_identity")
    if not isinstance(identity, dict):
        raise ValueError(f"{asset_id}: missing canonical asset_identity metadata")
    identity_id = str(identity.get("asset_id", ""))
    if not identity_id:
        raise ValueError(f"{asset_id}: asset_identity.asset_id is required")
    expected_identity = identity_for(identity_id)
    if identity != expected_identity:
        raise ValueError(f"{asset_id}: manifest identity does not match canonical {identity_id!r}")

    asset_kind = entry.get("asset_kind")
    if asset_kind not in {"runtime", "source_review"}:
        raise ValueError(f"{asset_id}: asset_kind must be 'runtime' or 'source_review'")
    source_path = Path(str(entry.get("source", "")))
    qa_path = Path(str(entry.get("qa_file", "")))
    glb_label = str(entry.get("glb_label", ""))
    expected_glb_name = (
        f"{identity_id}.glb" if asset_kind == "runtime" else f"{identity_id}_source.glb"
    )
    expected_qa_name = (
        f"{identity_id}_runtime.glb" if asset_kind == "runtime"
        else f"{identity_id}_source_review.glb"
    )
    expected_source_prefix = (
        ("game", "assets") if asset_kind == "runtime" else ("source-assets",)
    )
    if (
        source_path.name != expected_glb_name
        or glb_label != expected_glb_name
        or tuple(source_path.parts[: len(expected_source_prefix)]) != expected_source_prefix
    ):
        expected_source_root = "/".join(expected_source_prefix)
        raise ValueError(
            f"{asset_id}: {asset_kind} name/path must identify {identity_id!r}; "
            f"expected {expected_source_root}/…/{expected_glb_name}, "
            f"got source={source_path.as_posix()!r}, label={glb_label!r}"
        )
    if qa_path != Path("assets") / expected_qa_name:
        raise ValueError(f"{asset_id}: qa_file must be assets/{expected_qa_name}")

    role = identity.get("role")
    species = identity.get("species")
    category = str(entry.get("category", "")).upper()
    label = str(entry.get("label", ""))
    if role == "hero":
        tier = int(identity["tier_number"])
        if (
            species != "human"
            or "PLAYER HERO" not in category
            or "HUMAN" not in category
            or "ENEMY" in category
        ):
            raise ValueError(
                f"{asset_id}: human tier asset is not clearly classified as a player hero"
            )
        if f"T{tier}" not in label or f"TIER {tier}" not in category:
            raise ValueError(f"{asset_id}: player hero label/category does not match T{tier}")
        if entry.get("upgrade_track_id") != identity.get("progression_track_id"):
            raise ValueError(
                f"{asset_id}: human tiers must use their one canonical hero progression track"
            )
        if int(entry.get("upgrade_tier", 0)) != tier:
            raise ValueError(f"{asset_id}: manifest upgrade_tier does not match canonical T{tier}")
    elif role == "enemy":
        if species != "robot" or "ENEMY" not in category or "PLAYER HERO" in category:
            raise ValueError(f"{asset_id}: robot asset is not clearly classified as an enemy")
        if entry.get("upgrade_track_id") is not None or entry.get("upgrade_tier") is not None:
            raise ValueError(
                f"{asset_id}: enemy identity must not use the human hero progression track"
            )
        tier = identity.get("tier_number")
        if identity_id == "enemy_robot_common":
            if tier is not None or identity.get("rarity") != "common":
                raise ValueError(
                    "Robot Common must remain Common and must not be assigned an inferred T1"
                )
            if "TIER 1" in category or "T1" in label:
                raise ValueError("Robot Common must not be labeled as T1")
        elif tier is not None:
            if f"TIER {tier}" not in category:
                raise ValueError(f"{asset_id}: enemy category does not match tier {tier}")
            rarity = identity.get("rarity")
            if rarity and rarity.upper() not in category:
                raise ValueError(f"{asset_id}: enemy category does not match {rarity} rarity")
        enemy_class = identity.get("enemy_class")
        if enemy_class in {"sentinel", "boss"} and enemy_class.upper() not in category:
            raise ValueError(f"{asset_id}: enemy category does not identify class {enemy_class!r}")
        reference_track = identity.get("animation_reference_for")
        if reference_track:
            if (
                reference_track != "human_operative"
                or "HUMAN HERO ANIMATION REFERENCE" not in category
            ):
                raise ValueError(f"{asset_id}: human-hero animation-reference role is mislabeled")
    else:
        raise ValueError(f"{asset_id}: unsupported canonical role {role!r}")

    if asset_kind == "runtime":
        rig_profile = entry.get("rig_profile")
        if not isinstance(rig_profile, str) or not rig_profile:
            raise ValueError(f"{asset_id}: runtime asset must name its rig_profile")
        profile_path = _repo_path(rig_profile, asset_id, "rig_profile")
        runtime_source = _repo_path(str(entry["source"]), asset_id, "source")
        if (
            profile_path.name != f"{identity_id}_rig.json"
            or profile_path.parent != runtime_source.parent
        ):
            raise ValueError(f"{asset_id}: rig profile path does not match its runtime GLB")
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
        try:
            validate_profile_identity(profile, identity_id)
        except RuntimeError as error:
            raise ValueError(f"{asset_id}: {error}") from error
        if role == "hero":
            if profile.get("character_role") != "player_hero":
                raise ValueError(f"{asset_id}: rig profile is not marked as a player hero")
            if profile.get("upgrade_track_id") != identity.get("progression_track_id"):
                raise ValueError(f"{asset_id}: rig profile has the wrong shared hero track")
            if int(profile.get("upgrade_tier", 0)) != int(identity["tier_number"]):
                raise ValueError(f"{asset_id}: rig profile tier is swapped or mislabeled")
        elif profile.get("character_role") != "enemy":
            raise ValueError(f"{asset_id}: robot rig profile must be classified as an enemy")
        elif profile.get("upgrade_track_id") is not None or profile.get("upgrade_tier") is not None:
            raise ValueError(f"{asset_id}: enemy rig profile must not use hero progression fields")
    else:
        if not bool(entry.get("review_only", False)):
            raise ValueError(f"{asset_id}: source_review entries must remain review-only")

    original_source = entry.get("original_source")
    if role == "hero" and asset_kind == "runtime" and not original_source:
        raise ValueError(
            f"{asset_id}: hero runtime entry must retain its original source reference"
        )
    if original_source is not None:
        original_path = Path(str(original_source))
        expected_original_name = str(
            entry.get("original_source_name", f"{identity_id}_source.glb")
        )
        if (
            original_path.name != expected_original_name
            or Path(expected_original_name).name != expected_original_name
            or Path(expected_original_name).suffix.lower() != ".glb"
            or not original_path.parts
            or original_path.parts[0] != "source-assets"
        ):
            raise ValueError(
                f"{asset_id}: original_source does not match its declared source file identity"
            )
        resolved_original = _repo_path(str(original_source), asset_id, "original_source")
        if not resolved_original.is_file():
            raise ValueError(f"{asset_id}: original source is missing: {original_source}")


def load_manifest() -> list[dict[str, Any]]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("asset_manifest.json must be a JSON object")
    assets = data.get("assets")
    if not isinstance(assets, list) or not assets:
        raise ValueError("asset_manifest.json must contain a non-empty assets array")
    ids: set[str] = set()
    outputs: set[str] = set()
    identities_by_kind: dict[str, set[str]] = {"runtime": set(), "source_review": set()}
    for entry in assets:
        if not isinstance(entry, dict):
            raise ValueError("every manifest asset must be a JSON object")
        asset_id = str(entry.get("id", ""))
        source = str(entry.get("source", ""))
        qa_file = str(entry.get("qa_file", ""))
        if not asset_id or asset_id in ids:
            raise ValueError(f"missing or duplicate asset id: {asset_id!r}")
        if not source.lower().endswith(".glb") or not qa_file.lower().endswith(".glb"):
            raise ValueError(f"{asset_id}: source and qa_file must both be .glb files")
        source_path = Path(source)
        qa_relative = Path(qa_file)
        if source_path.is_absolute() or ".." in source_path.parts:
            raise ValueError(f"{asset_id}: source must be a repository-relative path")
        if qa_relative.is_absolute() or ".." in qa_relative.parts:
            raise ValueError(f"{asset_id}: qa_file must stay inside character_visual_qa/")
        if not isinstance(entry.get("expected_animation_names", []), list):
            raise ValueError(f"{asset_id}: expected_animation_names must be an array")
        if not isinstance(entry.get("required_checks", []), list):
            raise ValueError(f"{asset_id}: required_checks must be an array")
        _validate_asset_identity(entry, asset_id)
        identity_id = str(entry["asset_identity"]["asset_id"])
        asset_kind = str(entry["asset_kind"])
        if identity_id in identities_by_kind[asset_kind]:
            raise ValueError(f"{identity_id}: duplicate {asset_kind} manifest entry")
        identities_by_kind[asset_kind].add(identity_id)
        qa_path = (PROJECT / qa_file).resolve()
        if PROJECT.resolve() not in qa_path.parents:
            raise ValueError(f"{asset_id}: qa_file must stay inside character_visual_qa/")
        if qa_file in outputs:
            raise ValueError(f"multiple manifest entries write to {qa_file}")
        ids.add(asset_id)
        outputs.add(qa_file)

    expected_runtime = set(ASSET_IDENTITIES)
    expected_source_reviews = {
        asset_id for asset_id, identity in ASSET_IDENTITIES.items() if identity["role"] == "enemy"
    }
    for asset_kind, expected in (
        ("runtime", expected_runtime),
        ("source_review", expected_source_reviews),
    ):
        actual = identities_by_kind[asset_kind]
        if actual != expected:
            missing = sorted(expected - actual)
            unexpected = sorted(actual - expected)
            raise ValueError(
                f"manifest {asset_kind} identity set is incomplete or swapped; "
                f"missing={missing}, unexpected={unexpected}"
            )
    return assets


def run(check_only: bool) -> int:
    assets = load_manifest()
    problems: list[str] = []
    prepared: list[tuple[dict[str, Any], Path, Path, str]] = []

    # Validate every dependency and source GLB before copying anything. This keeps
    # a stale path or malformed model from leaving a partially refreshed QA set.
    for entry in assets:
        asset_id = str(entry["id"])
        try:
            source = _resolve_repository_file(asset_id, "source", str(entry["source"]))
            for related_field in ("original_source", "rig_profile"):
                related = str(entry.get(related_field, ""))
                if related:
                    _resolve_repository_file(asset_id, related_field, related)
            validate_glb_contract(entry, source)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            problems.append(str(error))
            continue
        destination = (PROJECT / str(entry["qa_file"])).resolve()
        prepared.append((entry, source, destination, sha256(source)))

    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        return 1

    staged_dir = PROJECT / "assets"
    expected_destinations = {destination.resolve() for _, _, destination, _ in prepared}
    stale_files: list[Path] = []
    if staged_dir.exists():
        stale_files = [
            stale
            for stale in staged_dir.glob("*.glb")
            if stale.resolve() not in expected_destinations
        ]
    if check_only:
        problems.extend(
            f"stale staged GLB is not in the manifest: {stale.relative_to(PROJECT)}"
            for stale in stale_files
        )
    else:
        for stale in stale_files:
            stale.unlink()
            print(f"Removed stale staged GLB · {stale.name}")

    report: dict[str, Any] = {"schema_version": 1, "assets": {}}
    for entry, source, destination, source_hash in prepared:
        asset_id = str(entry["id"])
        if check_only:
            if not destination.is_file():
                problems.append(f"{asset_id}: staged GLB is missing; run sync_assets.py")
                continue
            staged_hash = sha256(destination)
            if staged_hash != source_hash:
                problems.append(f"{asset_id}: staged GLB is stale; run sync_assets.py")
                continue
            try:
                validate_glb_contract(entry, destination)
            except (OSError, ValueError) as error:
                problems.append(f"{asset_id}: staged GLB failed validation: {error}")
                continue
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_suffix(destination.suffix + ".tmp")
            shutil.copy2(source, temporary)
            temporary.replace(destination)
            staged_hash = sha256(destination)
            try:
                validate_glb_contract(entry, destination)
            except (OSError, ValueError) as error:
                problems.append(f"{asset_id}: staged GLB failed validation: {error}")
                continue

        report["assets"][asset_id] = {
            "source": str(entry["source"]),
            "qa_file": str(entry["qa_file"]),
            "asset_kind": str(entry["asset_kind"]),
            "asset_identity": entry["asset_identity"],
            "rig_profile": entry.get("rig_profile"),
            "source_sha256": source_hash,
            "staged_sha256": staged_hash,
        }
        print(f"{asset_id}: current · {entry['glb_label']}")

    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        return 1
    if not check_only:
        STAGED_MANIFEST.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"\nStaged {len(assets)} structurally valid GLB(s) in character_visual_qa/assets/.")
    else:
        print(f"\nAll {len(assets)} staged GLB(s) match their sources and pass structure checks.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify staged copies match manifest sources without copying",
    )
    args = parser.parse_args()
    try:
        return run(args.check)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
