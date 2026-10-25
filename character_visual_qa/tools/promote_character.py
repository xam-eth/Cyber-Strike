#!/usr/bin/env python3
"""Copy a rendered-review-approved candidate into its game asset destination.

Add a new candidate to character_visual_qa/asset_manifest.json with a
promotion_destination before using this command. The visual gate, source hash,
required checklist, and every required animation clip are verified first.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from check_gate import RESULTS, load_json, validate_entry
from sync_assets import PROJECT, ROOT, STAGED_MANIFEST, load_manifest, sha256


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset-id", required=True, help="approved candidate id from asset_manifest.json")
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="replace an existing destination only after approval and hash checks pass",
    )
    args = parser.parse_args()
    try:
        entries = [entry for entry in load_manifest() if entry.get("id") == args.asset_id]
        if not entries:
            raise ValueError(f"unknown asset id: {args.asset_id}")
        entry = entries[0]
        if entry.get("baseline_already_in_game", False):
            raise ValueError("this baseline asset is already in game; it is review-only, not a promotion candidate")
        if entry.get("review_only", False):
            raise ValueError("this Drive source is for visual comparison only; promote its approved runtime candidate instead")
        destination_rel = str(entry.get("promotion_destination", ""))
        if not destination_rel:
            raise ValueError("manifest entry must define promotion_destination before promotion")
        results = load_json(RESULTS)
        staged_manifest = load_json(STAGED_MANIFEST)
        blockers = validate_entry(entry, results, staged_manifest)
        if blockers:
            print(f"BLOCKED: {args.asset_id} has not cleared the visual QA gate:", file=sys.stderr)
            for blocker in blockers:
                print(f"  - {blocker}", file=sys.stderr)
            return 1

        staged = (PROJECT / str(entry["qa_file"])).resolve()
        destination = (ROOT / destination_rel).resolve()
        if ROOT.resolve() not in destination.parents:
            raise ValueError("promotion_destination must stay inside the repository")
        resolved_destination = destination.relative_to(ROOT).as_posix()
        if not resolved_destination.startswith("game/assets/"):
            raise ValueError("promotion_destination must be inside game/assets/")
        if destination.exists():
            if sha256(destination) == sha256(staged):
                print(f"Already promoted and byte-identical: {destination_rel}")
                return 0
            if not args.overwrite:
                raise FileExistsError(
                    f"destination already exists; pass --overwrite to replace it: {destination_rel}"
                )

        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(staged, destination)
        print(f"PROMOTED: {entry['glb_label']} → {destination_rel}")
        print("Run the project's asset build/import checks before wiring it into gameplay.")
        return 0
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
