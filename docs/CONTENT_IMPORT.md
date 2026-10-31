# World and Character Content Import

**Status:** IMPLEMENTED integration infrastructure. It prepares isolated visual-content intake; it does not approve new gameplay, roster, enemy behavior, economy, or IAP.

This is the canonical handoff between external World/Character contributors and the internal integration branch. Read [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md) for scope and [`ARCHITECTURE.md`](ARCHITECTURE.md) for code ownership before submitting or activating a package.

## 1. Ownership and merge boundary

| Owner | Owns | Must not require from another contributor |
| --- | --- | --- |
| External World contributor | Source environment art, layout, source-generation tooling, licenses, package metadata | Edits to UI, Gameplay Core, another World, or the active registry |
| External Character contributor | Hero/enemy/weapon visual assets, rigs, clips, source tooling, licenses, package metadata | Edits to World, UI navigation, damage, waves, saves, or another Character |
| Internal integration | Review, staging, internal adapter/definition changes, registry activation, bundle and release evidence | Blind acceptance of executable package code or unapproved gameplay |
| Gameplay/Core | Combat, damage, health, weapon behavior, enemies' combat state, waves, run/session/save authority | A duplicate controller inside a visual package |
| UI/UX | Existing presentation and fallback status | Direct imports from a contributor's source tree |

Two contributors can therefore work in disjoint source directories. Only the internal integrator edits shared definitions or registries, after both sides have been read and validated.

## 2. Source package contract — `contract_version = 1`

A contributor supplies one directory:

```text
package/
├── package.json
├── LICENSE.txt                 # or the applicable license/NOTICE files
└── runtime/
    ├── entry.tscn              # or entry.glb / entry.gltf
    └── …self-contained assets…
```

Optional generators, Blender/source files, and contributor tests may live elsewhere in that contributor's branch. They are reviewed as source tooling but are not copied into the runtime package.

```json
{
  "contract_version": 1,
  "id": "example_world",
  "domain": "world",
  "entry": "runtime/entry.tscn"
}
```

- `id`: stable lower snake_case, matching `^[a-z][a-z0-9_]{0,63}$`.
- `domain`: `world` or `character`.
- `entry`: a normalized `.tscn`, `.glb`, or `.gltf` below `runtime/`.
- License/provenance files are mandatory for real submissions, even though the generic validator cannot judge whether their legal terms are correct.

The importer preserves these four manifest fields. Design notes, proposed stats, prices, and gameplay behavior do not belong in this technical manifest.

## 3. Isolation rules

A valid package is self-contained visual content:

1. No GDScript, C#, native extension, executable, symlink, generated `.godot` cache, `.import`, `.uid`, or temporary file in `runtime/`.
2. A `.tscn`/`.tres` may use engine types, but may not attach a script or reference another package. Resource references must remain beneath its eventual target id.
3. glTF/GLB buffer and image URIs must be local, present, and inside `runtime/`; remote URLs are not runtime dependencies.
4. Runtime scripts are forbidden because GDScript has no general exception/crash sandbox. Shaders and source-generation tools still require their normal visual/security review.
5. One package has a 200 MiB runtime ceiling by default. Large source libraries and generated bundles stay outside Git unless the repository's asset policy explicitly accepts them.
6. Staging is an offline development operation, not hot reload. Stop the running editor/game before replacing active content.

Target roots are fixed:

```text
world     → game/content/worlds/<id>/
character → game/content/characters/<id>/
```

For a scene authored with absolute Godot paths, use its eventual prefix, for example `res://content/worlds/example_world/runtime/…`. Relative package-local references are also accepted.

## 4. Validate, stage, and bundle

Run from the repository root:

```bash
# Read-only contributor/package check.
python3 tools/import_content.py check /path/to/package

# Validate again, copy to a sibling staging directory, then activate with rollback.
python3 tools/import_content.py stage /path/to/package

# Produce a deterministic, hashed zip without activating it.
python3 tools/import_content.py bundle /path/to/package \
  --output exports/content-packages/world-example_world.zip

# Verify every activated package; also run by scripts/dev_check.sh.
python3 tools/import_content.py check-committed
```

A failed check makes no active change. A failed replacement preserves the previous active directory. `content_import.json` records runtime file sizes and SHA-256 hashes; the bundle contains the same integrity manifest. `exports/` is the handoff/output location, not a directory to commit by default.

## 5. Internal activation is a separate review step

Staging alone does not make content selectable or change gameplay.

### World

The internal integrator adds or updates the existing `WorldDefinition` resource and registry:

- `world_scene`: the reviewed internal adapter, normally `mission_world.tscn`;
- `environment_scene_path`: the staged package entry;
- `field_size`, `field_center`, `player_spawn`, presentation text, and plate;
- `WorldDefinition.DEFINITION_PATHS` / `DEFINITION_IDS`, after compatibility review.

`MissionWorld` dynamically loads the environment. It no longer needs a new hard-coded GLB path or field-bounds entry for each imported World.

### Character and weapon visuals

- Hero roster/showcase metadata uses `HeroDefinition.model_scene_path`.
- Gameplay hero/enemy scenes use `model_scene_path`; the internal controller, collider, sockets, and fallback remain in place.
- Weapon presentation uses `model_scene_path`; the held visual uses `weapon_scene_path`.
- Projectile, damage, fire rate, ammo, enemy combat behavior, and save/unlock rules remain Gameplay/Core contracts.

Replacing the current operative's model must keep `HeroDefinition` and `player.tscn` pointing to the same file. `showcase_smoke.gd` measures this. Adding a new playable hero, a new enemy combat role, or a new weapon behavior is **not** activated by this pipeline and requires explicit Gameplay/Core scope.

### UI

UI continues to consume definitions and internal view contracts. Do not add a contributor-specific stage, navigation path, direct `preload`, or parallel health registry. A failed hero showcase reports `VISUAL OFFLINE · GAMEPLAY FALLBACK` while its metadata and navigation remain available.

## 6. Runtime failure behavior

| Failure | Contained result |
| --- | --- |
| Missing/misplaced World environment | Reject that environment; retain safe floor/bounds, lighting, wayfinders, player, HUD, and session |
| Missing hero model | Keep controller, camera, collider, capsule, weapon sockets, HUD, and gameplay |
| Missing enemy model | Keep enemy behavior/collider and fallback mesh; World and other enemies remain independent |
| Missing held weapon visual | Keep the measured fallback muzzle and combat controller; do not fabricate a weapon mesh |
| Invalid package before activation | Reject the whole submission; preserve the active package and unrelated modules |

The loader returns `{ok, code, message, path, scene}` and owns no global mutable health state. These guarantees cover validation and load/instantiation boundaries. They do **not** promise containment of native crashes, infinite loops, arbitrary executable code, or every possible runtime script error. That is why executable package code is excluded rather than “caught”.

## 7. Export, cache, and acceptance

Godot's `all_resources` export includes activated visual assets in the normal opening payload. Stable paths and the existing Web cache contract apply; the importer does not add per-world downloads or a second preload flow. Verify the actual PCK rather than inferring inclusion from a source directory.

Required checks for an integration change:

```bash
./scripts/dev_check.sh
./scripts/run_smoke_tests.sh module_isolation_smoke showcase_smoke
./scripts/run_smoke_tests.sh mission_world_smoke hero_visibility_smoke gameplay_vertical_slice_smoke
python3 tools/check_payload.py web/index.pck
```

Run the relevant browser journey after exporting an updated payload. Visual composition, animation quality, touch, performance, and Android behavior still need their separate rendered/human/device gates. No IAP or monetization concept is part of this import contract; monetization remains deferred until gameplay design explicitly calls for it.

## 8. Current contributor intake

**Status:** REVIEWED SOURCE INTEGRATION, pending the runtime gates for the commit that contains it. This section records provenance, not a claim of subjective visual approval or device validation.

| Source | Reviewed commit | Integrated content | Deliberate boundary |
| --- | --- | --- | --- |
| UI/UX | `arena/c08beb55-cyber-strike` at `2741263` | Two-language shell/engine catalog, HOME/navigation and overlay work, SABLE operative presentation, five tier cards, roster/tooling and relevant smoke tests | Generated QA evidence, agent skill documents and committed Web payloads were not copied. Shared files were three-way merged to retain five theatres, preload/cache/retry and dynamic content loading. |
| Character | `arena/0b00d4dd-cyber-strike` at `be3fe7a` | Five SABLE runtime tiers and rig sidecars, Runner/Shooter/Heavy/review-only boss visual candidates, four reference images, reusable GLB authoring tools and the isolated visual QA project | The standalone branch's framework/scene deletions were not applied. Its 194.16 MiB high-poly source GLBs remain on the contributor branch rather than being duplicated into the game repository. New enemy visuals do not register new enemy behavior. |
| World | `arena/3a7253a1-cyber-strike` at `5155b9a` | Latest Frostline, Verdant and Emberfall data layouts, rebuilt through the existing real-asset Forge and shared-texture staging pipeline | No unrelated-history merge and no standalone QA project import. Titans source and staged GLB remain unchanged; the older orphan-branch Titans artifact was not used. |

SABLE replaces the retired `exo_operative` presentation id. The profile loader migrates that one saved id to `sable`; unknown ids still fall back through the validated registry. Roster model/rig paths remain repository-relative for the HTML shell and are normalized to `res://` only at the engine accessor.

The five tiers are not presentation-only: their roster changes maximum health and incoming-damage reduction. That behavior belongs to the existing `ProgressionService` → `PlayerController` path and requires the normal gameplay tests. It is not a second health registry. Tier changes select a visual path; `ContentModuleLoader` still performs the domain-restricted load and preserves fallbacks.

The World build ran the real-asset policy and Khronos validation on the staged bytes. Emberfall-only photographic maps are capped at 512 px to keep the initial payload within its publication budget; maps shared with another World retain the common encoding so content-addressed deduplication still works. Titans and Verdant remained byte-identical in the compact-texture rebuild. These are static/build gates only. Godot import, PCK inclusion/budget, browser composition, animation quality and interactive gameplay must be recorded separately in [`VALIDATION.md`](VALIDATION.md).

Track 2 (`Endless & Guardian`) activates `game/assets/enemies/enemy_iron_warden_boss.glb` (`Iron Warden` Guardian) as live combat content via `ContentModuleLoader.CHARACTER_ROOTS` and includes it in the Web/Android export payload (~2.7 MB raw GLB, keeping `web/index.pck` well below the 100 MB plain-clone ceiling). The remaining enemy candidates (`enemy_robot_*` and `enemy_iron_sentinel*`) stay available to their authoring/retargeting tools while excluded from runtime presets and rejected by `tools/check_payload.py` until explicitly activated; Runner and Shooter continue to use their licensed models.
