#!/usr/bin/env python3
"""Generate the human-evidence tracker for every Aetherfall runtime GLB.

A GLB, a source file, and a static validator result do not constitute art
approval. Every generated gate is deliberately set to ``not_started`` until
linked review evidence is supplied by the per-asset production workflow.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VALIDATION = ROOT / "docs/world/aetherfall/validation/gltf_validation.json"
OUTPUT = ROOT / "docs/world/aetherfall/asset_production_ledger.json"

BATCHES = {
    "01_hero_destination": (
        "Destination hierarchy and objective/interior read.",
        {"ice_planet/sentinel_archive.glb", "archive/archive_vestibule.glb", "archive/archive_computer.glb", "models/energy_core.glb", "models/tower_foundation.glb", "models/tower_tier.glb", "models/tower_spire.glb"},
    ),
    "02_primary_traversal": (
        "Primary deck, bridge, catwalk and service-routing construction language.",
        {"expanse/transit_spine.glb", "models/bridge_deck.glb", "models/bridge_support.glb", "models/walkway_deck.glb", "models/deck_6x6.glb", "models/deck_edge.glb", "models/connector_ramp.glb", "models/railing.glb", "models/beam.glb", "models/pillar.glb", "models/cable_bundle.glb", "models/conduit.glb"},
    ),
    "03_macro_ice_recovery": (
        "Glacier, cliff, macro terrain and recovery-space geological language.",
        {"ice_planet/glacier_shelf.glb", "ice_planet/frozen_spire.glb", "models/cliff_face.glb", "models/terrain_chunk.glb", "models/rock_boulder.glb", "phase2/glacier_berm.glb", "phase2/ice_terrace.glb", "expanse/expanse_shelf.glb", "expanse/lowland_field.glb"},
    ),
    "04_operational_cover": (
        "Function-first gates, machinery, cover and interaction assets.",
        {"models/access_gate.glb", "models/cooling_vent.glb", "models/machinery.glb", "models/wall_section.glb", "models/cover_barrier.glb", "models/cover_machine.glb", "models/damaged_slab.glb", "models/debris_cluster.glb", "phase2/cryo_bulkhead.glb", "phase2/salvage_pod.glb", "ice_planet/cryo_pylon.glb", "interactives/objective_device.glb", "interactives/tech_cache.glb"},
    ),
    "05_settlement_vertical": (
        "Distinct industrial settlement and vertical/distant silhouette language.",
        {"landmarks/field_outpost.glb", "landmarks/relay_annex.glb", "landmarks/service_hangar.glb", "landmarks/cargo_service_cluster.glb", "vertical/refinery_stack.glb", "vertical/overhead_gantry.glb", "vertical/raised_ops_deck.glb", "models/background_silhouette.glb"},
    ),
    "06_vfx_exceptions": (
        "VFX/animated assets require separate animation, overdraw and device review.",
        {"models/cloud_puff.glb", "models/energy_orbit.glb"},
    ),
}
STAGES = ("brief", "reference", "base_mesh", "high_poly", "retopology", "uv_unwrap", "bake", "pbr_texturing", "godot_visual", "target_device_profile", "export_release")
PREFIX = "assets/world/aetherfall/"

# These are deliberately drafts, not approvals. A Gate 01 brief makes the
# modelling work reviewable; it does not promote a legacy GLB to production art.
HERO_REFERENCE_DRAFTS = {
    "ice_planet/sentinel_archive.glb": "docs/world/aetherfall/hero_destination/01_sentinel_archive.md",
    "archive/archive_vestibule.glb": "docs/world/aetherfall/hero_destination/02_archive_vestibule.md",
    "archive/archive_computer.glb": "docs/world/aetherfall/hero_destination/03_archive_computer.md",
    "models/energy_core.glb": "docs/world/aetherfall/hero_destination/04_energy_core.md",
    "models/tower_foundation.glb": "docs/world/aetherfall/hero_destination/05_tower_foundation.md",
    "models/tower_tier.glb": "docs/world/aetherfall/hero_destination/06_tower_tier.md",
    "models/tower_spire.glb": "docs/world/aetherfall/hero_destination/07_tower_spire.md",
}

# These one-per-asset studies strengthen the Gate 01 draft discussion but do
# not elevate it to an accepted reference gate or authorize Base Mesh work.
HERO_WORKING_REFERENCE_IMAGES = {
    "ice_planet/sentinel_archive.glb": "docs/world/aetherfall/hero_destination/reference/sentinel_archive_exterior_concept.png",
    "archive/archive_vestibule.glb": "docs/world/aetherfall/hero_destination/reference/archive_vestibule_concept.png",
    "archive/archive_computer.glb": "docs/world/aetherfall/hero_destination/reference/archive_computer_concept.png",
    "models/energy_core.glb": "docs/world/aetherfall/hero_destination/reference/energy_core_concept.png",
    "models/tower_foundation.glb": "docs/world/aetherfall/hero_destination/reference/tower_foundation_concept.png",
    "models/tower_tier.glb": "docs/world/aetherfall/hero_destination/reference/tower_tier_concept.png",
    "models/tower_spire.glb": "docs/world/aetherfall/hero_destination/reference/tower_spire_concept.png",
}


def runtime_relative(path: str) -> str:
    if not path.startswith(PREFIX):
        raise ValueError(f"Unexpected path in validation report: {path}")
    return path[len(PREFIX):]


def batch_for(relative_path: str) -> tuple[str, str]:
    matches = [(name, value[0]) for name, value in BATCHES.items() if relative_path in value[1]]
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one batch for {relative_path}, got {matches}")
    return matches[0]


def main() -> None:
    if set(HERO_REFERENCE_DRAFTS) != set(HERO_WORKING_REFERENCE_IMAGES):
        raise RuntimeError("Every Hero draft needs exactly one asset-specific working reference image")
    for reference_path in HERO_WORKING_REFERENCE_IMAGES.values():
        if not (ROOT / reference_path).is_file():
            raise RuntimeError(f"Missing Hero working reference: {reference_path}")

    report = json.loads(VALIDATION.read_text())
    inventory = {runtime_relative(asset["runtime_path"]) for asset in report["assets"]}
    planned = set().union(*(assets for _, assets in BATCHES.values()))
    if inventory != planned:
        raise RuntimeError(f"Ledger batch map is stale; unplanned={sorted(inventory-planned)}, missing={sorted(planned-inventory)}")

    assets = []
    for validation_asset in sorted(report["assets"], key=lambda item: item["runtime_path"]):
        relative_path = runtime_relative(validation_asset["runtime_path"])
        batch, batch_intent = batch_for(relative_path)
        draft_brief = HERO_REFERENCE_DRAFTS.get(relative_path)
        gate_state = {stage: "not_started" for stage in STAGES}
        if draft_brief:
            gate_state["brief"] = "draft"
            gate_state["reference"] = "draft"
        assets.append({
            "asset_id": relative_path.removesuffix(".glb").replace("/", "__"),
            "runtime_path": validation_asset["runtime_path"],
            "source_path": validation_asset["source_path"],
            "source_owner": "unassigned",
            "production_batch": batch,
            "batch_intent": batch_intent,
            "legacy_revision_sha256": validation_asset["sha256"],
            "technical_baseline": {
                "validator_status": validation_asset["validation_status"],
                "validator_issue_counts": validation_asset["issues"],
                "stats": validation_asset["stats"],
            },
            "human_art_gate": gate_state,
            "release_decision": "unaccepted",
            "evidence": {
                "brief_document": draft_brief,
                "reference_images": [HERO_WORKING_REFERENCE_IMAGES[relative_path]] if draft_brief else [],
                "clay_review_images": [],
                "wireframe_review_images": [],
                "uv_checker_review_images": [],
                "bake_inspection_images": [],
                "godot_review_images": [],
                "target_device_profile": "docs/world/aetherfall/ANDROID_TARGET_PROFILE.md",
                "validator_exception": None,
                "approved_by": None,
                "revision": None,
            },
        })

    ledger = {
        "schema": "aetherfall.asset-production-ledger.v1",
        "purpose": "Human evidence tracker. Never infer art completion from a GLB, source script, or static validation result.",
        "technical_target": {"platform": "Android", "renderer": "Godot Mobile (configured; not performance-verified)", "target_devices": [], "performance_budget": "unresolved", "camera_distance_policy": "unresolved", "profile_document": "docs/world/aetherfall/ANDROID_TARGET_PROFILE.md"},
        "release_policy": {
            "format_validation": "zero errors and no untriaged warnings",
            "art": "each applicable human_art_gate is accepted with linked evidence",
            "engine": "exact export inspected in Godot",
            "performance": "profile recorded on declared target device/build",
        },
        "batches": {name: {"description": details[0], "asset_count": len(details[1])} for name, details in BATCHES.items()},
        "assets": assets,
    }
    OUTPUT.write_text(json.dumps(ledger, indent=2) + "\n")
    print(f"Wrote {len(assets)} unaccepted asset entries to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
