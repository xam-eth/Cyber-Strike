#!/usr/bin/env python3
"""Stage the manifest's GLBs inside the standalone Godot QA project.

The staged copies are ignored by Git so character binaries are not duplicated
in the repository. Source GLBs stay in game/assets (baseline review) or
source-assets (new candidates); this command makes the QA project portable and
keeps its local copies byte-identical to the declared source.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "character_visual_qa"
MANIFEST = PROJECT / "asset_manifest.json"
STAGED_MANIFEST = PROJECT / "staged_assets.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_manifest() -> list[dict[str, Any]]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assets = data.get("assets")
    if not isinstance(assets, list) or not assets:
        raise ValueError("asset_manifest.json must contain a non-empty assets array")
    ids: set[str] = set()
    outputs: set[str] = set()
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
        qa_path = (PROJECT / qa_file).resolve()
        if PROJECT.resolve() not in qa_path.parents:
            raise ValueError(f"{asset_id}: qa_file must stay inside character_visual_qa/")
        if qa_file in outputs:
            raise ValueError(f"multiple manifest entries write to {qa_file}")
        ids.add(asset_id)
        outputs.add(qa_file)
    return assets


def run(check_only: bool) -> int:
    assets = load_manifest()
    report: dict[str, Any] = {"schema_version": 1, "assets": {}}
    problems: list[str] = []
    for entry in assets:
        asset_id = str(entry["id"])
        source = (ROOT / str(entry["source"])).resolve()
        destination = (PROJECT / str(entry["qa_file"])).resolve()
        if ROOT.resolve() not in source.parents:
            problems.append(f"{asset_id}: source resolves outside the repository: {source}")
            continue
        if not source.is_file():
            problems.append(f"{asset_id}: source GLB is missing: {source.relative_to(ROOT)}")
            continue

        source_hash = sha256(source)
        if check_only:
            if not destination.is_file():
                problems.append(f"{asset_id}: staged GLB is missing; run sync_assets.py")
                continue
            staged_hash = sha256(destination)
            if staged_hash != source_hash:
                problems.append(f"{asset_id}: staged GLB is stale; run sync_assets.py")
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_suffix(destination.suffix + ".tmp")
            shutil.copy2(source, temporary)
            temporary.replace(destination)
            staged_hash = sha256(destination)

        report["assets"][asset_id] = {
            "source": str(entry["source"]),
            "qa_file": str(entry["qa_file"]),
            "source_sha256": source_hash,
            "staged_sha256": staged_hash,
        }
        print(f"{asset_id}: {'current' if staged_hash == source_hash else 'STALE'} · {entry['glb_label']}")

    if not check_only and not problems:
        STAGED_MANIFEST.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"\nStaged {len(assets)} GLB(s) in character_visual_qa/assets/.")
    elif check_only and not problems:
        print(f"\nAll {len(assets)} staged GLB(s) match their manifest sources.")

    for problem in problems:
        print(f"ERROR: {problem}", file=sys.stderr)
    return 1 if problems else 0


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
