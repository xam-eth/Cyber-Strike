#!/usr/bin/env python3
"""Check that one or all character assets passed rendered visual review.

This is the pre-integration gate. Promotion must use promote_character.py,
which refuses assets with stale copies or anything other than a complete PASS.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from sync_assets import PROJECT, ROOT, STAGED_MANIFEST, load_manifest, sha256

RESULTS = PROJECT / "review_results.json"


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return data


def validate_entry(
    entry: dict[str, Any],
    review_data: dict[str, Any] | None = None,
    staged_data: dict[str, Any] | None = None,
) -> list[str]:
    """Return blockers for one manifest entry; an empty list means approved."""
    review_data = review_data if review_data is not None else load_json(RESULTS)
    staged_data = staged_data if staged_data is not None else load_json(STAGED_MANIFEST)
    asset_id = str(entry.get("id", ""))
    blockers: list[str] = []

    source = (ROOT / str(entry.get("source", ""))).resolve()
    staged = (PROJECT / str(entry.get("qa_file", ""))).resolve()
    if ROOT.resolve() not in source.parents or not source.is_file():
        blockers.append(f"source file is missing or outside the repo: {entry.get('source')}")
        return blockers
    if PROJECT.resolve() not in staged.parents or not staged.is_file():
        blockers.append("staged GLB is missing; run character_visual_qa/tools/sync_assets.py")
        return blockers

    source_hash = sha256(source)
    staged_hash = sha256(staged)
    staged_record = staged_data.get("assets", {}).get(asset_id, {})
    if source_hash != staged_hash:
        blockers.append("staged GLB is stale; sync again and repeat the rendered review")
    if staged_record.get("source_sha256") != source_hash or staged_record.get("staged_sha256") != staged_hash:
        blockers.append("staged_assets.json does not match current files; run sync_assets.py")

    result = review_data.get("assets", {}).get(asset_id, {})
    if result.get("status") != "PASS":
        blockers.append(f"review status is {result.get('status', 'MISSING')}, not PASS")
    if result.get("asset_sha256") != source_hash:
        blockers.append("reviewed GLB hash is stale or missing; repeat the visual review")
    if not result.get("reviewed_at"):
        blockers.append("review timestamp is missing")

    checklist = result.get("checklist", {})
    missing_checks = [
        str(check_id)
        for check_id in entry.get("required_checks", [])
        if checklist.get(str(check_id)) is not True
    ]
    if missing_checks:
        blockers.append("required visual checklist incomplete: " + ", ".join(missing_checks))

    expected_clips = {str(name) for name in entry.get("expected_animation_names", [])}
    reviewed_clips = {str(name) for name in result.get("reviewed_clips", [])}
    missing_clips = sorted(expected_clips - reviewed_clips)
    if missing_clips:
        blockers.append("animation clips not individually reviewed: " + ", ".join(missing_clips))

    automated = result.get("automated", {})
    if not automated.get("passed", False):
        blockers.append("Godot's imported-scene contract checks did not pass")
    if automated.get("joint_count") != int(entry.get("expected_joint_count", 0)):
        blockers.append("review report's skeleton joint count does not match the manifest")
    if bool(entry.get("requires_skin", False)) and int(automated.get("skinned_mesh_count", 0)) < 1:
        blockers.append("review report contains no skinned mesh")
    available_clips = {str(name) for name in automated.get("animation_clips", [])}
    missing_imported_clips = sorted(expected_clips - available_clips)
    if missing_imported_clips:
        blockers.append("required clips are absent from imported GLB: " + ", ".join(missing_imported_clips))
    return blockers


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--asset-id", help="check one id from character_visual_qa/asset_manifest.json")
    selection.add_argument("--all", action="store_true", help="check every manifest entry (the default)")
    args = parser.parse_args()
    try:
        entries = load_manifest()
        if args.asset_id:
            entries = [entry for entry in entries if entry.get("id") == args.asset_id]
            if not entries:
                print(f"ERROR: asset id not found: {args.asset_id}", file=sys.stderr)
                return 2
        elif args.all:
            entries = load_manifest()
        review_data = load_json(RESULTS)
        staged_data = load_json(STAGED_MANIFEST)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    failed = False
    for entry in entries:
        blockers = validate_entry(entry, review_data, staged_data)
        label = f"{entry.get('id')} · {entry.get('glb_label')}"
        if blockers:
            failed = True
            print(f"BLOCKED: {label}")
            for blocker in blockers:
                print(f"  - {blocker}")
        else:
            print(f"PASS: {label} is approved for integration.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
