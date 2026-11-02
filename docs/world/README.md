# World Build, Assets, and Verification

This is the canonical World subsystem runbook. World identity and route intent live in [`CONCEPT.md`](CONCEPT.md). Gameplay missions, guards, rewards, and cache state belong to [`../GAMEPLAY_DESIGN.md`](../GAMEPLAY_DESIGN.md); World metadata does not implement them.

## 1. Current content shape

The theatre registry contains a single bespoke Citadel campaign world:

- **SH-01: Aetherfall** (`game/resources/worlds/aetherfall.tres` → `game/scenes/worlds/aetherfall_world.tscn` / `game/scripts/worlds/aetherfall_world.gd`), merged from `arena/939d9492-cyber-strike`.

All five repetitive legacy theatres (`frostline_relay`, `verdant_bloom`, `emberfall_foundry`, `vanguard_station`, `titans`) have been retired and removed from the runtime and payload.

For contributor package rules, the intake contract is [`../CONTENT_IMPORT.md`](../CONTENT_IMPORT.md). `WorldDefinition.environment_scene_path`, `field_size`, and `field_center` are the adapter inputs; `MissionWorld` (`game/scripts/worlds/mission_world.gd`) loads `aetherfall_world.tscn` dynamically through `ContentModuleLoader` and retains safe bounds, floor collision, and alpine lighting if visual loading ever fails.

Measured file counts, geometry, shared textures, and dimensions live in [`game/assets/world/aetherfall/MANIFEST.md`](../../game/assets/world/aetherfall/MANIFEST.md), [`game/assets/world/aetherfall/layout.json`](../../game/assets/world/aetherfall/layout.json), and [`game/assets/world/aetherfall/measurements.json`](../../game/assets/world/aetherfall/measurements.json).

## 2. Staged package → runtime

```text
game/assets/world/aetherfall/{world_layout,lighting_preset,terrain_spec,...}.json
  + 51 deduplicated GLBs + 43 shared PNGs in textures/
  → AetherfallWorld (game/scripts/worlds/aetherfall_world.gd)
  → WorldDefinition (game/resources/worlds/aetherfall.tres)
  → MissionWorld dynamic load boundary (game/scripts/worlds/mission_world.gd)
  → Main session orchestrator + 4 landmark Recovery caches + WaveDirector
```

Important locations:

| Path | Role |
|---|---|
| `game/assets/world/aetherfall/` | Extracted SH-01 JSON layout specs, 51 deduplicated `.glb` modules, and shared `textures/` |
| `game/assets/world/aetherfall/measurements.json` | Verified GLB bounding boxes enforced by `tools/kit_measure.py --check` |
| `game/scripts/worlds/aetherfall_world.gd` | Procedural/layout assembler for terrain, citadel architecture, props, FX, and landmark colliders |
| `game/scripts/worlds/mission_world.gd` | Dynamic loader, `ArenaFloor` & `BoundaryWalls` safety envelope, and `SpawnPoints` contract |
| `game/resources/worlds/aetherfall.tres` | Canonical `WorldDefinition` with player spawn and 4 landmark `RecoveryCacheDefinition` entries |
