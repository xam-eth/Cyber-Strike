#!/usr/bin/env python3
"""Canonical role/tier identity for runtime character and enemy rig profiles.

Asset filenames, rig profiles, build checks, and the standalone QA manifest all
use this registry so human hero tiers cannot silently become robot enemy tiers.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any


ASSET_IDENTITIES: dict[str, dict[str, Any]] = {
    "hero": {
        "asset_id": "hero",
        "role": "hero",
        "species": "human",
        "tier_number": 1,
        "tier_label": "T1",
        "rarity": "common",
        "progression_track_id": "human_operative",
        "enemy_class": None,
        "animation_reference_for": None,
    },
    **{
        f"hero_human_tier_{tier}": {
            "asset_id": f"hero_human_tier_{tier}",
            "role": "hero",
            "species": "human",
            "tier_number": tier,
            "tier_label": f"T{tier}",
            "rarity": None,
            "progression_track_id": "human_operative",
            "enemy_class": None,
            "animation_reference_for": None,
        }
        for tier in range(1, 6)
    },
    "enemy_robot_common": {
        "asset_id": "enemy_robot_common",
        "role": "enemy",
        "species": "robot",
        "tier_number": None,
        "tier_label": "Common",
        "rarity": "common",
        "progression_track_id": None,
        "enemy_class": "common",
        "animation_reference_for": None,
    },
    "enemy_robot_tier_2_rare": {
        "asset_id": "enemy_robot_tier_2_rare",
        "role": "enemy",
        "species": "robot",
        "tier_number": 2,
        "tier_label": "T2 Rare",
        "rarity": "rare",
        "progression_track_id": None,
        "enemy_class": "robot_variant",
        "animation_reference_for": "human_operative",
    },
    "enemy_robot_tier_3_epic": {
        "asset_id": "enemy_robot_tier_3_epic",
        "role": "enemy",
        "species": "robot",
        "tier_number": 3,
        "tier_label": "T3 Epic",
        "rarity": "epic",
        "progression_track_id": None,
        "enemy_class": "robot_variant",
        "animation_reference_for": "human_operative",
    },
    "enemy_iron_sentinel": {
        "asset_id": "enemy_iron_sentinel",
        "role": "enemy",
        "species": "robot",
        "tier_number": None,
        "tier_label": None,
        "rarity": None,
        "progression_track_id": None,
        "enemy_class": "sentinel",
        "animation_reference_for": None,
    },
    "enemy_iron_warden_boss": {
        "asset_id": "enemy_iron_warden_boss",
        "role": "enemy",
        "species": "robot",
        "tier_number": None,
        "tier_label": None,
        "rarity": None,
        "progression_track_id": None,
        "enemy_class": "boss",
        "animation_reference_for": None,
    },
}


def identity_for(asset_id: str) -> dict[str, Any]:
    """Return an independent canonical identity record or reject unknown IDs."""
    try:
        return deepcopy(ASSET_IDENTITIES[asset_id])
    except KeyError as error:
        raise ValueError(f"unknown character/enemy asset identity: {asset_id!r}") from error


def set_profile_identity(profile: dict[str, Any], asset_id: str) -> dict[str, Any]:
    """Stamp a generated rig profile with its canonical role/tier identity."""
    profile["asset_identity"] = identity_for(asset_id)
    return profile


def validate_profile_identity(profile: dict[str, Any], asset_id: str) -> None:
    """Fail if a rig profile's role, species, or tier was assigned incorrectly."""
    expected = identity_for(asset_id)
    actual = profile.get("asset_identity")
    if actual != expected:
        raise RuntimeError(
            f"{asset_id}: rig asset_identity mismatch; expected {expected!r}, got {actual!r}"
        )
    if profile.get("model") != f"{asset_id}.glb":
        raise RuntimeError(
            f"{asset_id}: rig profile model must be {asset_id}.glb, got {profile.get('model')!r}"
        )
