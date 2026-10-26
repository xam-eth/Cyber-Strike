# World Build, Assets, and Verification

This is the canonical World subsystem runbook. World identity and route intent live in [`CONCEPT.md`](CONCEPT.md). Gameplay missions, guards, rewards, and cache state belong to [`../GAMEPLAY_DESIGN.md`](../GAMEPLAY_DESIGN.md); World metadata does not implement them.

## 1. Current content shape

The theatre registry contains five definitions:

- Four shared-builder Forge worlds: **Frostline Relay**, **Verdant Bloom**, **Emberfall Foundry**, and **The Titans**.
- **Vanguard Station**, which remains a separate imported-kit station implementation.

The four Forge worlds share `MissionWorld` and the asset-forge build pipeline while loading their own staged GLB, mood, markers, collision/configuration, and registry metadata. Vanguard is not replaced by that pipeline.

Measured file counts, geometry, textures, hashes, and dimensions are generated data. Use [`game/assets/forge/forge_manifest.json`](../../game/assets/forge/forge_manifest.json) and [`tools/asset-forge/real/real-manifest.json`](../../tools/asset-forge/real/real-manifest.json) rather than copying those values into prose.

## 2. Source → staged world → runtime

```text
licensed source GLBs + provenance ledger
  → tools/asset-forge/src/worlds/{frostline,verdant,emberfall,titans}.js
  → shared roles / terrain / composition / atmosphere
  → rendered review + asset-policy gate
  → staged GLBs + content-addressed shared textures
  → game/assets/forge/ + forge_manifest.json
  → MissionWorld + WorldDefinition registry
  → selected theatre gameplay
```

Important locations:

| Path | Role |
|---|---|
| `game/assets/world/real/` | Licensed source model libraries used by the Forge pipeline |
| `tools/asset-forge/real/real-manifest.json` | Upstream source, license, and hash ledger |
| `tools/asset-forge/src/worlds/` | World data, roles, composition, terrain, moods, and build registry |
| `tools/asset-forge/gate/` | Review renders, validation, shared-texture staging, and Godot handoff |
| `game/assets/forge/worlds/` | Runtime world GLBs imported by Godot |
| `game/assets/forge/textures/` | Content-addressed images shared across runtime GLBs |
| `game/assets/forge/forge_manifest.json` | Generated measurements and staging contract |
| `game/resources/worlds/` | Five `WorldDefinition` resources consumed by shell/engine |
| `game/scripts/worlds/mission_world.gd` | Shared runtime adapter for the four Forge worlds |

## 3. Real-asset and provenance policy

For Forge world geometry, every visible mesh must come from a licensed, pre-authored GLB in the approved source library. The review gate inspects mesh provenance tags and fails when an untagged/procedural mesh enters the scene.

The current ledger includes:

| Library | License | Use |
|---|---|---|
| Kenney Space Kit | CC0-1.0 | Modular hardware and structures |
| Kenney Nature Kit | CC0-1.0 | Organics, rocks, foliage, and terrain dressing |
| Cinder Yard / Power Plant, derived set pieces, and ground plate | CC-BY-4.0 | Industrial landmarks and scanned surfaces; attribution required |

Keep attribution in the manifest and shipping notices where required. Slicing a real model into set pieces must preserve its geometry/material provenance; it does not make the result an original CC0 asset.

## 4. Build and review

Install the asset-tool dependencies as required by the existing lockfiles, then use the established entry points:

```bash
# Verify licensed source files and hashes
node tools/asset-forge/real/fetch_real_assets.mjs --verify

# Build/review all currently registered Forge worlds
node tools/asset-forge/gate/world_shot.mjs

# Build one world/vantage while iterating
node tools/asset-forge/gate/world_shot.mjs --world verdant --shot overview

# Stage validated worlds and shared textures into Godot
node tools/asset-forge/gate/stage_worlds_into_game.mjs
```

For interactive authoring review, serve the repository and open `tools/asset-forge/world.html?world=<id>` for a registered Forge id.

Do not edit staged GLBs or generated manifests by hand. Change the source data/pipeline, rebuild, inspect the affected renders, and stage again. Keep generated caches and unneeded large review output out of Git according to existing ignore conventions.

## 5. Shared textures and download behavior

Byte-identical images are externalized to content-addressed shared files so Godot does not import a separate copy for every world reference. This is a packaging/deduplication contract, not permission to change image pixels or geometry silently.

After staging:

- verify GLB relative texture URIs and keep the sibling texture directory with the worlds;
- compare source/non-image buffer integrity through the existing checks;
- inspect the generated manifest rather than inferring the texture count;
- run the payload audit to ensure required runtime resources are included and source-only libraries are not shipped accidentally.

The player opening downloads the required main pack before MASUK and DEPLOY reuses it. Unchanged development assets should revalidate rather than requiring repeated full downloads. See [`../runbooks/WEB_PREVIEW.md`](../runbooks/WEB_PREVIEW.md).

## 6. Godot and browser verification

Applicable checks include:

```bash
./scripts/dev_check.sh
./scripts/run_smoke_tests.sh
python3 tools/check_payload.py web/index.pck
node tools/web_qa.mjs
node tools/web_loading_qa.mjs
```

World-specific tests and the forge import verifier inspect actual imported geometry/materials/animation/configuration where applicable. Browser selection checks must prove the authoritative world id and real selected-world gameplay, not only a card click.

Record the exact source/payload commit and results in [`../VALIDATION.md`](../VALIDATION.md). Static GLB inspection, headless import, and automated Chromium do not prove physical-device performance, free-roam traversal, final visual acceptance, or human mission comprehension.

## 7. World change checklist

- [ ] Registry id and source module are intentional and stable.
- [ ] Source assets have provenance/license and pass hash verification.
- [ ] No unapproved procedural mesh or generated texture enters the Forge policy path.
- [ ] Shared route/collision/markers and `MissionWorld` configuration agree.
- [ ] World mood and card art use the current STELLAR HORIZON direction.
- [ ] The four-world shared builder and separate Vanguard path are not accidentally conflated.
- [ ] Initial pack, shared textures, payload, and warm-cache behavior still pass applicable gates.
- [ ] Gameplay behavior is not inferred from World metadata; mission/guardian/reward changes are coordinated with Gameplay/Core.
- [ ] Canonical docs and validation are updated without copying soon-to-be-stale measurements into prose.
