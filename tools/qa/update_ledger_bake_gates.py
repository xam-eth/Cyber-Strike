#!/usr/bin/env python3
"""Record Gate C/D/E technical-half progress in the asset production ledger.

Mirrors docs/world/aetherfall/bake_records/<asset>_bake.json into the
corresponding asset entries (human review fields stay pending; release_decision
stays unaccepted until a human signs the gates).

    python3 tools/qa/update_ledger_bake_gates.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LEDGER = os.path.join(ROOT, "docs", "world", "aetherfall", "asset_production_ledger.json")
RECORDS = os.path.join(ROOT, "docs", "world", "aetherfall", "bake_records")

BAKED = {
    "deck_6x6": "models/deck_6x6.glb",
    "wall_section": "models/wall_section.glb",
    "cryo_bulkhead": "phase2/cryo_bulkhead.glb",
    "lowland_field": "expanse/lowland_field.glb",
    "expanse_shelf": "expanse/expanse_shelf.glb",
    "cover_machine": "models/cover_machine.glb",
    "damaged_slab": "models/damaged_slab.glb",
    "cover_barrier": "models/cover_barrier.glb",
    "debris_cluster": "models/debris_cluster.glb",
    "machinery": "models/machinery.glb",
    "walkway_deck": "models/walkway_deck.glb",
    "railing": "models/railing.glb",
    "beam": "models/beam.glb",
    "connector_ramp": "models/connector_ramp.glb",
    "terrain_chunk": "models/terrain_chunk.glb",
    "cable_bundle": "models/cable_bundle.glb",
    "tower_foundation": "models/tower_foundation.glb",
    "cliff_face": "models/cliff_face.glb",
    "rock_boulder": "models/rock_boulder.glb",
    "bridge_deck": "models/bridge_deck.glb",
    "tower_tier": "models/tower_tier.glb",
    "energy_core": "models/energy_core.glb",
    "deck_edge": "models/deck_edge.glb",
    "cooling_vent": "models/cooling_vent.glb",
    "bridge_support": "models/bridge_support.glb",
    "conduit": "models/conduit.glb",
    "pillar": "models/pillar.glb",
    "background_silhouette": "models/background_silhouette.glb",
}

TECH = "technical_authored_pending_human_review"


def main():
    led = json.load(open(LEDGER, encoding="utf-8"))
    updated = 0
    for asset, rel in BAKED.items():
        rec_path = os.path.join(RECORDS, f"{asset}_bake.json")
        if not os.path.exists(rec_path):
            print(f"skip {asset}: no bake record")
            continue
        rec = json.load(open(rec_path, encoding="utf-8"))
        for entry in led["assets"]:
            if not entry["runtime_path"].endswith(rel):
                continue
            gate = entry["human_art_gate"]
            gate["high_poly"] = TECH
            gate["uv_unwrap"] = TECH
            gate["bake"] = "technical_baked_pending_human_review"
            gate["pbr_texturing"] = "technical_composite_pending_human_review"
            entry.setdefault("evidence", {})["bake_record"] = (
                f"docs/world/aetherfall/bake_records/{asset}_bake.json"
            )
            entry["evidence"]["bake_resolution"] = rec.get("resolution")
            entry["evidence"]["bake_cage_extrusion_m"] = rec.get("cage_extrusion_m")
            updated += 1
            break
        else:
            print(f"skip {asset}: runtime_path {rel} not in ledger")
    with open(LEDGER, "w", encoding="utf-8") as fh:
        json.dump(led, fh, indent=1)
        fh.write("\n")
    print(f"ledger updated: {updated} assets")


if __name__ == "__main__":
    main()
