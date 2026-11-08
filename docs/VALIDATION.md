# Validation Status

This document records the latest relevant evidence and its limits. It is not a design specification, a chronological collection of old reports, or proof that every current branch change has been validated.

For intended behavior, read [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md). For required gates, read [`DEVELOPMENT.md`](DEVELOPMENT.md).

## Polish pass 4 — Gate E high-poly bake pilot (tech_cache) — 2026-11-07

| Item | Current checkpoint |
|---|---|
| Source | `226b9c5` (bake pipeline + tech_cache re-UV/bake/composite + X11 stub tooling) |
| Godot/Web CI | [42425449227](https://github.com/xam-eth/Cyber-Strike/actions/runs/42425449227) — **SUCCESS** (45/45 smokes + all browser contracts) |
| Committed Web payload | `096ef21` — `web/index.pck` **97,785,528 bytes** (+795,688 B for the composite map; **2,214,472 bytes of headroom** left under the 100 MB budget) |
| Local static | `dev_check.sh` **0 failed / 2 skipped** (kit measurements 51/51 unchanged, collision 9/9) |
| Khronos ledger | **0 errors / 0 warnings / 604 infos** on 51 GLBs (tech_cache: URI_GLB 16, UNUSED_MESH_TANGENT 5 — informational) |
| Runtime QA | `exports/qa-p4`/`exports/tmp/p4retry2` — recovery battery **1/1, all checks ok** (first attempt was a boot-timing flake, retry passed every recovery/interaction contract) |

- **IMPLEMENTED (Gate C, technical):** `tools/blender/bake_flagship_detail.py` authors `HP_` high-poly objects from the low-poly parts with structured hard-surface detail only — bevel hierarchy (two angle-limited passes), panel recesses on the largest faces, hex fasteners at recess corners, vent slats — deterministic per part name. No noise/scatter/displacement is used. Artistic approval remains with the human gate (`approved_by: null`).
- **IMPLEMENTED (Gate D, technical):** per-part box-projection re-UV into a unique non-overlapping atlas (global area-proportional shelf packing, uniform scale, no aspect stretch), then a Cycles tangent-space NORMAL bake selected-to-active with cage extrusion **0.005 m** recorded in `docs/world/aetherfall/bake_records/tech_cache_bake.json`. The shipped GLB keeps node names, material names, transforms and unique positions byte-verified (`positions_match: True`); vertex splits (29,915 → 30,289) only reflect the new UV seams. `measurements.json` is unchanged.
- **IMPLEMENTED (Gate E, technical):** the baked normal is composited (whiteout reoriented blend, 0.7 procedural weight) with each island's existing procedural material normal and shipped as `textures/a2802b2f….jpg` (395 KB, 1024 px); tech_cache's five normalTexture slots now sample the composite directly (legacy KHR tile transforms dropped on this asset since the atlas is pre-scaled). Albedo/ORM keep the shared maps.
- **IMPLEMENTED (tooling):** `tools/build_x11stubs.py` builds empty-X11/GL SONAME stubs (X11 device/xkb symbol families, versioned xkb exports) so the PyPI `bpy 5.0.1` wheel runs headless in this environment; the bake tool also externalises Blender-embedded images back to the project's `../textures/<sha>.jpg` convention and re-verifies the exported GLB against the pre-bake backup.
- **VERIFIED (local):** bake record + inspection images in `docs/world/aetherfall/bake_inspection/`; Khronos 0/0/604; kit 51/51 byte-consistent; collision 9/9; dev_check 0 failed.
- **BUDGET NOTE:** the composite map costs ~395 KB source JPEG (projected ~0.5 MB in the PCK — the CI payload audit gives the exact figure). Budgeted siblings: access_gate + tower_spire at 512 px next, then refinery_stack / sentinel_archive only if headroom allows.
- **UNVERIFIED:** human review of HP/detail authorship and bake quality (gates C–E human halves), runtime look of the re-UV'd tech_cache in-engine (CI frames pending), and the remaining four flagship bakes.

## Phase 7 preparation — Android packaging lane + human playtest protocol — 2026-11-08

| Item | Current checkpoint |
| --- | --- |
| Playtest protocol (Phase E) | **REGISTERED:** [`docs/runbooks/PLAYTEST.md`](runbooks/PLAYTEST.md) fixes the pre-registration table (participants 5–8, devices, builds by sha/run), the unassisted session script, 7 fixed scenario probes (death/retry/reload reward-integrity, ADS, pause/resume, extract/continue, upgrade separation), the verbatim comprehension question set, and thresholds with severities (S1 = crash/soft-lock/duplicated reward/unreachable control blocks release). Linked from DEVELOPMENT.md Phase E and docs/README.md. The protocol is only valid if the table is filled and committed before the first session. |
| Android preset (runbook gate 2) | **VERIFIED (local):** `tools/android_preset.py scaffold` + `check` exit 0 — preset `Android`, `com.xameth.exocomplict`, arm64-v8a, APK, 40 option keys. `game/export_presets.cfg` remains gitignored; CI scaffolds its own. |
| Android APK (runbook gate 3) | **PENDING CI:** `Android debug APK` workflow (`workflow_dispatch`) is the packaging-only path (full headless smoke suite first, payload audit, profiler presence check, `android-debug-apk` artifact, 14-day retention). Result lands in the workflow run, not here. |
| UNVERIFIED (user-gated) | Filling the pre-registration table and running sessions; runbook gates 1 (local toolchain report) and 4–8 (physical install, touch checklist, FPS/thermal/memory numbers, native capture review). Debug APK is packaging only — no device or performance claim exists yet. |

## Polish pass 6 — HUD micro-polish: caption bands, chip collision, portrait menus — 2026-11-08

| Item | Current checkpoint |
| --- | --- |
| Root causes found | (1) **Ammo-chip/strip collision (844x390):** `AegisAmmoChip` is a `PanelContainer`, so its minimum height follows its content (~66 px) — taller than the 48 px slot above the action cluster, and the expanded panel overlapped the resource-strip chips (`PULSE` over `0/3 0/4`, pixel-proven `exports/tmp/p6-band-strip.png`). (2) **Clipped button captions (all viewports):** fixed 16–17 px caption bands vs the project's 16 px font floor (`FIRE` → `EIRE`). (3) **Portrait menu truncation (390x844):** rows squeezed into an ~180 px column beside the rail (`MARA...`, `DEPLOYMI...`, `READY TO...`); plus a godot quirk — a trim overrun forces single-line layout and autowrap is ignored. |
| Fixes | Chip compacts in place to a single `T1 · 24/24` row on short landscape (`set_compact_row`, 34 px slot) keeping the smoke-pinned SWAP pairing and the 96/80 px finger targets untouched; `_fit_action_caption` sizes bands from the caption's own font; dashboard re-stacks the rail below full-width rows on tall portrait (`_apply_orientation` mode-based, re-applies on resize); hero header paints `SELECT`/`PILIH` (new `hero.title_short` catalog key, EN+ID) and yields the status chip on narrow windows; world meta lines and stacked dashboard status rows carry two-line budgets with `OVERRUN_NO_TRIMMING` so copy wraps instead of reading as `STORM...`. |
| Contracts preserved | playability_hud_smoke pins FIRE 96 / AIM-EMP-SWAP 80 finger targets and the <=160x210 desktop rail (the first compression attempt violated both and was reverted); menu_layout_smoke pins every label rect on screen at 844x390 -> 667x375 (the shared one-line-per-max-lines font reserve attempt violated this and was reverted in favour of per-label density stamping). |
| VERIFIED (CI) | Run `42456220768` SUCCESS (Godot 4.7.2): all 45 headless smokes (incl. playability_hud_smoke, menu_layout_smoke, hud_safe_margin_smoke), web build + PCK payload audit (98,527,840 bytes / 746 files), browser smoke 4/4 page-viewports + recovery checks. Earlier iterations in this pass: `42448257159` (parse error caught), `42448585344` (contract violations caught), `42450418854` (one violation caught), `42455130788` (throttled recovery-route flake; retried green). |
| VERIFIED (local frames) | `exports/qa-p6-audit` vs `exports/qa-p6-after` vs `exports/flow/p6-final`: chip/strip collision gone (strip chips fully readable, chip row `PULSE T1 · 24/24` below); `FIRE` caption sits inside its bezel; dashboard portrait reads `OPERATIVE / MARA VOSS / DEPLOYMENT THEATRE / AETHERFALL / PULSE RIFFLE...` full width; hero header `SELECT` full with the status chip yielded. |
| Known remaining micro-item | The world-select reward meta (`CACHES 0/4 · SCHEMATIC · STORM CONDUCTOR`) still ellipsizes to one line at 390 px despite a two-line budget: the wrap is suppressed in-engine for that label and the exact cause is unexplained (the same loop's min-height stamp visibly applies). Presentation is bounded-ellipsis, consistent with the codebase's deliberate `_limit_lines` card bounding. Hero card copy in the ~250 px column still ellipsizes (hero column restack deliberately deferred — pins/carousel height budget risk). |
| UNVERIFIED | Human playtest of the polish (P7 gate), Android device profile (gated), physical-device touch validation of the compact chip row. |

## Polish pass 5 — SFX variety: round-robin shot banks + real enemy fire — 2026-11-08

| Item | Current checkpoint |
|---|---|
| Source | `16e21bb` (round-robin banks, richer shot layers, enemy fire) |
| Godot/Web CI | [42440535596](https://github.com/xam-eth/Cyber-Strike/actions/runs/42440535596) — **SUCCESS** (45/45 smokes incl. the extended audio contract on real Godot 4.7.2) |
| Committed Web payload | `794f6b0` — `web/index.pck` **98,525,088 bytes** (1,474,912 bytes of headroom; the audio work costs +3.5 KB) |
| Local runtime QA | `exports/qa-polish5/` — **4/4 page/viewport combinations, 86 ok / 0 fail** (engage E2E fires through the new round-robin path) |

- **IMPLEMENTED (round-robin banks):** every player weapon now ships four synthesized voices (`shot_<w>`, `_r2.._r4`) with per-variant detune, bolt/breech timing jitter and noise seed; `AudioDirector.play_variant()` rotates them per base id and `play_shot()` routes through it. Rapid fire no longer repeats one cloned transient. The pitch jitter (±3.8%) and pooled voices of the existing mixer still apply on top.
- **IMPLEMENTED (richer layering):** pulse rifle gained an air-whip crack and variant-jittered bolt timing; nova launcher gained a falling tube sweep and debris shimmer; arc shooter gained a rising capacitor whine and spark rain. All synths stay deterministic (seeded `0x5F3A17 + variant*7919`).
- **FIXED (silent enemy fire):** `enemy_shot` was played by the enforcer but had no stream behind it (unknown id no-ops silently), and the shooter robot never played a fire sound at all. `enemy_shot` is now a real 3-voice hostile servoplasma bank (cold square body + electric snap + servo clack — deliberately unlike the player arsenal) wired into `enforcer` bursts and `shooter._resolve_attack()`.
- **VERIFIED:** the extended `tests/audio_smoke.gd` contract passed on real Godot 4.7.2 in CI: `enemy_shot` required and non-silent, every bank ≥4 voices (enemy ≥3) with distinct streams, consecutive variant plays unthrottled, mute/throttle/music-mode contracts unchanged. `dev_check` 0 failed (gdformat clean, ARCHITECTURE map regenerated); tooling self-tests 95/95 with the project venv (PIL missing from sandbox system python3, not a repo issue).
- **UNVERIFIED:** human listening approval of the new gunplay mix, SFX balance on device speakers (Android profile still gated), and any surround/ducking polish.

## Polish pass 4 — Gate E high-poly bakes, all five flagship assets — 2026-11-08

| Item | Current checkpoint |
|---|---|
| Source | `226b9c5` (pilot: tech_cache + bake pipeline) → `2fd32b5` (batch 2: access_gate + tower_spire) → `072cc66` (batch 3: refinery_stack + sentinel_archive + budget trade) → `72f8f16` (payload rebuild on pruned tree) |
| Godot/Web CI | [42425449227](https://github.com/xam-eth/Cyber-Strike/actions/runs/42425449227) (pilot) **SUCCESS**, [42428998729](https://github.com/xam-eth/Cyber-Strike/actions/runs/42428998729) (batch 2) **SUCCESS**, [42434138515](https://github.com/xam-eth/Cyber-Strike/actions/runs/42434138515) (batch 3) **SUCCESS** — 45/45 smokes + all browser contracts. (Run 42433853322 failed its payload audit on a stale un-referenced texture file — the gate worked; rebuilt clean.) |
| Committed Web payload | `418b7d2` — `web/index.pck` **98,521,616 bytes** (**1,478,384 bytes of headroom** under the 100 MB budget) |
| Local runtime QA | `exports/qa-polish4/` — **4/4 page/viewport combinations, 86 ok / 0 fail** |

- **Gate E status (technical halves complete, human halves pending):** all five flagship assets now carry a high-poly-authoring → re-UV atlas → Cycles normal bake → whiteout-composite pipeline (`tools/blender/bake_flagship_detail.py`): **tech_cache** (`a2802b2f….jpg`, 1024 px, 5 normal slots), **access_gate** (`08914e29….jpg`, 4 slots), **tower_spire** (`dedfb031….jpg`), **refinery_stack** (`642851bf….jpg`, 4 slots), **sentinel_archive** (`e3525748….jpg`, 5 slots). Every bake records its cage extrusion (0.005 m) and geometry-identity verification (nodes/materials/positions/UVs unchanged) in `docs/world/aetherfall/bake_records/`; inspection images in `docs/world/aetherfall/bake_inspection/`. Ledger human gates for the five: `pending_human_review` (`approved_by: null`), `godot_visual: pending_human_review` (runtime look now seen in real recovery frames).
- **BUDGET TRADE:** the metal ORM map was demoted 1024 → 512 px (`upgrade_closeup_textures.mjs` `CAP_OVERRIDES`; low-frequency roughness data) to fund the two batch-3 composites; net PCK effect of batch 3 ≈ +334 KB for two 1024 px bake composites.
- **FIXED (tooling footgun):** the upgrade tool's representative-material discovery could latch onto a per-asset bake composite in place of the shared map (it clobbered access_gate's 4 composite refs; restored from `1c17c1b` + GLB repaired). Discovery now majority-votes across all GLBs carrying the representative material. Khronos ledger after repair: **0 errors / 0 warnings**; kit 51/51; collision 9/9; `dev_check` 0 failed.
- **UNVERIFIED:** human review of HP/detail authorship and bake quality (the art halves of gates C–E), Android device profile, SFX variety pass.

## Polish pass 3 — selective 1024px close-up maps — 2026-11-07

| Item | Current checkpoint |
|---|---|
| Source | `36bf4c5` (close-up map promotion + tooling) |
| Godot/Web CI | [42373529679](https://github.com/xam-eth/Cyber-Strike/actions/runs/42373529679) — **SUCCESS** (45/45 smokes + all browser contracts incl. TECH HUNT E2E closure) |
| Committed Web payload | `0f8325f` — `web/index.pck` **96,989,840 bytes** (+6.14 MB for the promoted maps; **3,010,160 bytes of headroom** left under the 100 MB budget) |
| Local runtime QA | `exports/qa-polish3/` — **4/4 page/viewport combinations, 86 ok / 0 fail** (root shell + raw engine × 844×390 + 667×375) |

- **IMPLEMENTED (selective resolution):** the PBR generators always produced 1024 px sets and the packer's 512 px budget profile downscaled every map. Ten maps that dominate the close-up read now ship at native 1024 px: `ice_rock` albedo+normal+ORM (ground underfoot — terrain ice, glacier shelves, IceVein), `metal` albedo+normal+ORM (structure steel — caches, gates, spires, ramps), `composite` albedo (interactable panel faces), `rock` albedo+normal (route geology), `deck` albedo (gate/spire paint). The 14 photo-scan maps (DARK/WARNING/ARCHIVE_DARK/EXPANSE_DARK families) and distance-only normals/ORMs stay at 512 px.
- **IMPLEMENTED (tooling):** `tools/gltf/upgrade_closeup_textures.mjs` + `tools/blender/gen_surface_set.py` — discovers each surface kind's current hashes from the GLB material slots (representative materials from `MAT_SURFACE`), regenerates the sets with the same `pbr_lib` seeds, encodes with the packer's JPEG profile at 1024, rewrites GLB URIs in place (sha→sha, byte-length safe), and lets the regular pack pass prune the old files. Re-runnable/idempotent.
- **VERIFIED:** Khronos ledger 0 errors / 0 warnings / 606 infos; `kit_measure` 51/51; own-faces collision grid 9/9; `dev_check` 0 failures; runtime QA 4/4 with recovery frames.
- **BUDGET NOTE:** the promoted maps cost 6.14 MB in the PCK (Basis-encoded 1024 normals/ORMs are pricier than the +4.66 MB estimate). Remaining headroom **~3.0 MB** — the Gate E bake pass (P4) must stay inside that, or trade other texture budget first.
- **UNVERIFIED:** unchanged — human visual approval of the realism direction, production gates C–E (high-poly sculpt, retopo, authored bake), Android device profile, SFX variety pass.

## Polish pass 2 — drifting polar snow, fog shaping, WORLD pin contract — 2026-11-07

| Item | Current checkpoint |
|---|---|
| Source | `896778b` (drifting snow + fog shaping) + `6f525fb` (WORLD pin announcement contract) |
| Godot/Web CI | [42331020786](https://github.com/xam-eth/Cyber-Strike/actions/runs/42331020786) (snow + fog) **SUCCESS** and [42334002844](https://github.com/xam-eth/Cyber-Strike/actions/runs/42334002844) (pin contract) **SUCCESS** — 45/45 smokes + all browser contracts incl. TECH HUNT E2E closure |
| Committed Web payload | `486726b` — `web/index.pck` 90,854,080 bytes (drifting-snow layer + fog shaping, ~9.1 MB under the 100 MB budget) |
| Local runtime QA | `exports/qa-polish2-final/` — **4/4 page/viewport combinations, 86 ok / 0 fail** (root shell + raw engine journeys × 844×390 + 667×375), recovery frames landing/engage-offer/guarded/contact captured per combination |

- **IMPLEMENTED (drifting polar snow):** `PolarSnowfall` rewritten from a static 140-flake rain over the whole map into a camera-following terminal-velocity drift field (`aetherfall_world.gd::_add_polar_snowfall` + `_process`): lateral-biased direction with 26° spread, constant-velocity fall (0.35–0.75 m/s), 12 s lifetime, 1200 flakes on hardware and a 420-flake software-WebGL fill-rate budget, soft-dot texture `game/assets/world/aetherfall/sky/snow_flake.png` (32 px, 661 B), billboarded unshaded quads. The drift box tracks the active camera so density stays constant across the run. `production_upgrade_smoke` contract (active `PolarSnowfall` node) preserved.
- **IMPLEMENTED (fog shaping):** Aetherfall environment fog shaped for depth per `ART_DIRECTION.md` (silhouettes stay readable): `fog_density` 0.0014 → 0.0032 (~12% at 40 m, ~38% at 150 m), ground-pooling height fog (`fog_height` −1.0 / `fog_height_density` 0.05), `fog_light_energy` 1.08, `fog_aerial_perspective` 0.56 → 0.62. Runtime frames show distance haze on the far gantries with gameplay zone untouched.
- **FIXED (WORLD pin interaction contract):** the WORLD stage boots with the default theatre (`WorldDefinition.DEFAULT_WORLD_ID = aetherfall`) already selected, and `_on_pin_pressed` early-returned without a log when the pressed pin matched the stage cache — so pressing `AetherfallPin` (already-selected state) never emitted `FrontEnd: world selected aetherfall` and the measured raw-engine journey could not prove selection before LAUNCH. A pin press now always announces and confirms the theatre (`select_world()`/`_refresh()` stay idempotent). Verified locally: the previously failing `/web/index.html` recovery lane now passes every check, including `WORLD pin selected aetherfall before launch`.
- **UNVERIFIED:** unchanged — human visual approval of the realism direction, production gates C–E (high-poly sculpt, retopo, authored bake), Android device profile, SFX variety pass.

## Polish pass 1 — material value range, aurora sky, QA-profile isolation — 2026-11-06

| Item | Current checkpoint |
|---|---|
| Source | `a4ef36d` (materials + sky + tangent hygiene) + this commit (web QA profile isolation) |
| Godot/Web CI | [42309808778](https://github.com/xam-eth/Cyber-Strike/actions/runs/42309808778) — **SUCCESS** (45/45 smokes, all browser contracts incl. TECH HUNT E2E closure) |
| Committed Web payload | `c8ed157` — `web/index.pck` 90,085,276 bytes (sky panorama + refreshed maps, still under the 100 MB budget) |

- **IMPLEMENTED (material realism):** `pbr_lib` `tex_ice_rock` rebuilt around a wide value ramp (deep clear ice body against bright pressure strata/frost, milky patches, cavity darkening, sparse glitter) and `tex_rock` tamed for high-frequency noise with mid-scale structure and cavity darkening — value separation per `ART_DIRECTION.md`, hue families unchanged. All 51 GLBs re-materialled (`enrich_aetherfall.py --skip-geometry`, 0 contract diffs) and repacked through the 512px/JPEG profile.
- **IMPLEMENTED (declared atmosphere):** `world_mood` declares "aurora sky and drifting snow" but the scene shipped a two-colour procedural gradient. Deterministic equirect panorama `game/assets/world/aetherfall/sky/sky_aurora.jpg` (navy zenith, cyan-teal curtains, stars; 261 KB) wired as `PanoramaSkyMaterial` in `aetherfall_world.tscn`. Drifting snow particles remain open.
- **IMPLEMENTED (tangent hygiene):** degenerate-UV triangles make MikkTSpace emit zero-length tangents (`ACCESSOR_VECTOR3_NON_UNIT` on `expanse_shelf` ×48 and `debris_cluster` ×2). `pack_world_textures.mjs` `fixTangents()` normalizes TANGENT xyz in place (zero → +X), idempotent. Ledger back to **0 errors / 0 warnings**.
- **FIXED (web QA profile isolation):** local QA runs shared Chromium's default `~/.config/chromium` profile, where the exported build persists `user://progression.cfg` (IndexedDB). A prior run's secured cache steered later runs at the wrong objective (HORIZON RELAY instead of the Arrival Tech Cache) — CI was immune (fresh VM). `web_qa.mjs` now launches every browser with a fresh temp `--user-data-dir`. Verified locally: recovery contract `failed: []` with engage/guards/GLB guard models.
- **UNVERIFIED:** unchanged from the previous checkpoint — human visual approval, production gates C–E, Android device, drifting-snow particle polish.

## World production visual enrichment & payload budget checkpoint — 2026-11-06

| Item | Current checkpoint |
|---|---|
| Enrichment + budget source | `7a52e1e`, `8218cd8`, `89ad4aa`, `ccd62f1` (this branch) |
| Godot/Web CI | [42224113406](https://github.com/xam-eth/Cyber-Strike/actions/runs/42224113406) — **SUCCESS** (`Static checks`, `Headless smoke tests 45/45` on Godot 4.7.2, `Web preview build` incl. every browser QA contract: TECH HUNT E2E closure, Recovery engagement, ADS, shell/audio, download recovery) |
| Committed Web payload | `web/index.pck` **90,075,200 bytes** (734 files; SH-01 Aetherfall + all 5 rigged robot GLBs, 0 legacy leaks) — under the 100,000,000-byte plain-clone budget |
| Khronos glTF validation | 51 GLBs: **0 errors / 0 warnings** / 606 infos — `docs/world/aetherfall/validation/gltf_validation.json` |
| Before/after visual evidence | `docs/previews/{before,after}_{world,detail}.png` (real render-pipeline captures, same camera/light rig) |

### What this checkpoint verifies

- **IMPLEMENTED (world surface enrichment, 51/51 assets):** `tools/blender/enrich_aetherfall.py` applies per-object bevels (thin-strut capped), filtered inset paneling, inward geology displacement, a `pbr_lib` material rebuild (12 procedural surfaces → 41 shared 512px JPEG maps: albedo q90 4:2:0, normal q92 4:4:4, ORM q95 4:4:4), and explicit MikkTSpace tangents (`NO_TANGENTS={"cloud_puff"}`). Export contract: `export_apply=False, use_selection=False, export_yup=True`; every node name and animation clip preserved; `measurements.json` regenerated 51/51 (`kit_measure.py --check` OK).
- **VERIFIED (CI, real Godot runtime):** run [42224113406](https://github.com/xam-eth/Cyber-Strike/actions/runs/42224113406) — 45/45 smoke suites pass (incl. `collision_integrity_smoke` with its rewritten ray grid) and every browser contract passes on the exported WebAssembly build, including TECH HUNT E2E closure with all evidence fields true (engage → guards → cursor-aim clear → Secure → schematic + 45 BP persistence → hub mirror → Kestrel redeploy).
- **VERIFIED (collision integrity):** `tests/collision_integrity_smoke.gd` now intersects its 27-ray grid directly against each body's own shape faces. The previous space-state first-hit filter was shadowed by the tower tier box colliders over the energy-core volume — a scene simulation (`tools/check_world_collision.py` + first-hit study) showed 0/27 first hits on the core with BOTH the original and enriched GLBs. The local checker replicates the smoke grid pre-CI: 9/9 ray solids block 12–27 of 27 rays with their own geometry.
- **VERIFIED (payload budget):** Godot `.ctex` size scales with source pixel count, not source bytes; the packer budget profile caps every world map at 512px + JPEG (`pack_world_textures.mjs`, `--recompress` migrates externalized trees). World texture library 32MB → 3.5MB; PCK 107.4MB (first enriched build) → 105.8MB (JPEG only) → **90.1MB** (512px cap). `godot-ci.yml` now prints the payload composition before the budget gate. Tradeoff: world albedo/normal detail is 512px — hero/enemy/UI art is untouched.
- **VERIFIED (local static):** texture integrity 41 referenced = 41 on disk (0 missing, 0 orphans), `dev_check.sh` 0 failed / 2 skipped (local Godot binary + export preset absent). Harness fix `ccd62f1`: the TECH HUNT E2E lane now guarantees cache interaction range (the scripted landing sat exactly on the 3.0m offer boundary; any tolerance overshoot lost the Engage offer) and reports leg telemetry in its evidence notice.
- **UNVERIFIED (production gates & human approval):** per-asset Gates C–E of `docs/world/aetherfall/INDUSTRY_PRODUCTION_STANDARD.md` (high-poly sculpt, retopology, authored UV/bake) remain OPEN — the shipped maps are the procedural PBR baseline. Human visual approval of the runtime look, physical Android evidence, and performance profiling are unchanged and pending.

## Full gameplay-flow bug audit & fixes (animation / spawn / guidance / collision) checkpoint — 2026-11-06

| Item | Current checkpoint |
|---|---|
| Fix source | this branch (spawn `(-6, 1.2, 9)`, airborne clips, trimesh scenery, visible wayfinding) |
| Godot/Web CI | [42196445591](https://github.com/xam-eth/Cyber-Strike/actions/runs/42196445591) — **SUCCESS** (`Static checks`, `Headless smoke tests 45/45` on Godot 4.7.2.stable.official.ed1daf0bf, `Web preview build` with all browser QA contracts: TECH HUNT E2E closure, Recovery engagement, ADS, shell) |
| Committed Web payload | `web/index.pck` 86,553,480 bytes (730 files; SH-01 Aetherfall + all 5 rigged robot GLBs, 0 legacy leaks) |
| New runtime smoke tests | `character_animation_smoke.gd`, `collision_integrity_smoke.gd`, `world_guidance_smoke.gd` (+ `hero_rig_smoke.gd` / `mission_world_smoke.gd` updated) |

### What this checkpoint verifies

- **Audit root causes (player report: incomplete animation, world problems, wrong spawn, no guidance, pass-through objects):**
  - **Pass-through ice/buildings:** 8/9 `ice_planet_phase1.json` placements (`glacier_shelf` ×4, `frozen_spire` ×2, `cryo_pylon` ×2) shipped without `collision_boxes`, and `aetherfall_world.gd`'s `NO_COLLISION` disabled colliders for `terrain_chunk` ×13 (48 m mesas), `cliff_face` ×10, `rock_boulder` ×11, `energy_core`, `railing` ×3, `debris_cluster` ×3. Fixed with exact concave (trimesh) colliders baked through placement scale (`SOLID_TRIMESH`, `SOLID_TRIMESH_SETPIECES`); decorative scenery (`background_silhouette`, `cloud_puff`, `cable_bundle`) intentionally stays pass-through.
  - **Wrong spawn:** authored spawn `(-30, 1.2, 14)` clipped the `primary_arrival_outpost` collision box by ~2 cm, sat in a 1.4 m corridor against `landing_ridge_berm`, **and stood inside the `terrain_chunk_191` glacial mass** (true ice surface 1.49 m there — the walk-through scenery the player was standing in). Two intermediate placements were rejected by measured clearance audits against the now-solid ice surfaces and the real cover boxes (`basin_west_berm`, `cover_barrier_148`, …). The final spawn is the open central deck tile `(-6, 1.2, 9)` — 4.8 m box clearance, ice surface far below, clean camera and aim lanes toward the OUTPOST CACHE — with the arrival pad / briefing sign / chevron wayfinding (below) opening on the objective from the first frame. The browser QA drive route in `tools/web_qa.mjs` now follows the baseline-validated `z = 16.5` boulevard lane (clear of `cooling_vent_159` and the basin berms) to the cache approach.
  - **No guidance:** `mission_world._add_wayfinders()` created invisible `Marker3D`s only. Replaced by `world_guidance.gd`: arrival pad + yellow ring, billboard briefing sign carrying the real first objective's `RecoveryCacheDefinition.display_name`, and ground chevrons along the spawn → cache route chain (yellow active leg, cyan follow legs). Presentation-only: zero colliders.
  - **Incomplete animation:** `raise_weapon`/`lower_weapon` existed in the GLBs but were never played; the gameplay jump had no airborne clip (walk/run legs played mid-air); aim-backpedal moon-walked. `tools/gltf/add_airborne_hero_clips.py` (idempotent, measured-pose deltas from the hero's own walk/run clips) authored `jump` 0.50 s / `fall` 0.80 s loop / `land` 0.45 s into `hero_human_tier_1.glb` **and** `kestrel_hero.glb` (15 clips each, rig JSON manifests updated; measured bone travel 17–33 cm feet, 4–10 cm head vs idle). `character_visual.gd` wires raise/lower aim transitions (interruptible), the jump/fall/land state machine, and reversed walk playback for backpedal.
- **VERIFIED (CI):** all 45 headless smoke suites and every browser QA contract pass on run [42196445591](https://github.com/xam-eth/Cyber-Strike/actions/runs/42196445591), including the new animation/collision/guidance suites and the rerouted web QA drive (validated `z = 16.5` boulevard lane to the cache approach).
- **UNVERIFIED (hardware & human playtest boundaries):** native Android device testing and subjective human playtest sessions remain separate from automated Godot/Chromium verification.

## Phase 4 — Kestrel (Second Playable Scout Operative & Recon Overdrive) checkpoint — 2026-11-01

| Item | Current checkpoint |
|---|---|
| Operative, Combat Runtime, 3D Livery, HUD, and Web Shell source | `0a82664` (over `801e342` / `e0232a1`) |
| Godot/Web CI | [41294230867](https://github.com/xam-eth/Cyber-Strike/actions/runs/41294230867) — **SUCCESS** (`Static checks`, `Headless smoke tests 41/41`, `Web preview build` including all 8 browser QA contracts) |
| Committed Web payload | `8d9ecec` |
| `web/index.pck` | 95,576,292 bytes (`1,005` files); SHA-256 `22d8a0d2eca8348e77d6ccbb170167b06d8112843046c5a1dd19d38d2f4fa347` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Phase 4 runtime visual QA screenshots | [`../qa-evidence/phase-4-kestrel/`](../qa-evidence/phase-4-kestrel/01-hero-kestrel-t1-desktop-en.png) (6 multi-viewport Web Hub & Godot 4.7.2 WebAssembly captures) |

### What this checkpoint verifies

- **VERIFIED (Single-Source Operative Registry & `<100 MB` PCK Budget — `roster.json`, `kestrel.tres`, `hero_definition.gd`, `hero_tier.gd`, `progression_service.gd`, `check_hero_roster.py`):**
  - Promoted `kestrel` (`Dian Prameswari`, `SCOUT` / `PENINJAU`) from an `in_development` placeholder to a full `field_ready` second operative across `roster.json`, `game/resources/heroes/kestrel.tres`, `HeroDefinition.DEFINITION_IDS`, and `ProgressionService.HERO_IDS`, while adding `vanguard` (`Raka Pratama`, `BREACHER` / `PENDOBRAK`) as the honest `in_development` slot (`178/178` `check_hero_roster.py` checks PASS; `369/369` EN/ID keys in parity).
  - Reused the committed rigged exo-suit `game/assets/characters/hero/hero.glb` + `hero_rig.json` with per-instance metallic alloy tier liveries (`T1` White-Cyan Recon Ceramic through `T5` Crimson-Titanium Sovereign) and rendered `340×460` RGBA portraits (`portrait_kestrel.png` + `kestrel-tier-{1..5}.png`), keeping `web/index.pck` at `95,576,292` bytes (`+80 KB` vs Phase 3, `4.42 MB` under the hard `100 MB` CI cap).
- **VERIFIED (Real Scout Gameplay Mechanics & Recon Overdrive — `player_controller.gd`, `weapon_controller.gd`, `character_visual.gd`, `model_fitter.gd`):**
  - Differentiated `Kestrel` from `Sable` (`100..126` HP, `1.00×` speed, `EMP Pulse` `9m` radial AoE) with real runtime trade-offs read directly from `roster.json` via `HeroTier`: `-10` base vitals (`90/96/102/108/116` HP across `T1..T5`), identical `0/3/6/9/12%` tier armor scaling, `+14%` base stride speed (`6.84 m/s`), and `-10%` weapon reload time without mutating shared `.tres` weapon resources.
  - Implemented `recon_pulse` (**Recon Overdrive**, `10.5s` cooldown): fires an aimed `18.0 m` (`3.6 m` corridor + `4.8 m` impact pulse) forward disruption lance dealing `22` damage and triggering ranged `apply_emp_disrupt` (`is_exposed() == true`) against `Iron Warden` shields, while granting `3.5s` of `+20%` movement speed and `+22%` weapon fire rate ([`05-gameplay-kestrel-hud-desktop-en.png`](../qa-evidence/phase-4-kestrel/05-gameplay-kestrel-hud-desktop-en.png), [`06-gameplay-kestrel-overdrive-mobile-id.png`](../qa-evidence/phase-4-kestrel/06-gameplay-kestrel-overdrive-mobile-id.png)).
  - Shared `ModelFitter.apply_livery` (`core` layer) cleanly across `CharacterVisual` (`systems`) and `ShowcaseViewport` (`ui`) using per-instance `set_surface_override_material` duplicates (`0` architecture boundary violations, `0` shared material mutations).
- **VERIFIED (Cross-Surface Native FrontEnd, Web Operations Hub, & HUD Telemetry — `stage_hero_select.gd`, `stage_dashboard.gd`, `hud_state.gd`, `hud_encounter_ui.gd`, `touch_controls.gd`, `hud_menu_ui.gd`, `ui/hero_stage.js`, `ui/shell.js`, `ui/hero.css`):**
  - Updated Web Operations Hub `#screen-hero` 3-column operative grid (`SABLE`, `KESTREL`, `VANGUARD`), Three.js `applyLivery` per-instance material cloning, `#screen-hub` Command Deck operative card & `DEPLOY | KESTREL Tn` action, Native `StageHeroSelect` / `StageDashboard`, HUD skill controls (`RECON` / `INTAI`), Overdrive status feedback (`OVERDRIVE INTAI · +20% GERAK`), and per-hero promotion copy across `1280×720`, `844×390`, and `667×375` ([`01-hero-kestrel-t1-desktop-en.png`](../qa-evidence/phase-4-kestrel/01-hero-kestrel-t1-desktop-en.png), [`02-hero-kestrel-t5-desktop-id.png`](../qa-evidence/phase-4-kestrel/02-hero-kestrel-t5-desktop-id.png), [`03-hero-kestrel-mobile-844x390-id.png`](../qa-evidence/phase-4-kestrel/03-hero-kestrel-mobile-844x390-id.png), [`04-hub-kestrel-command-deck-id.png`](../qa-evidence/phase-4-kestrel/04-hub-kestrel-command-deck-id.png)).
- **VERIFIED (Automated Godot 4.7.2 Headless `41/41`, WebAssembly `8/8`, & Static `7/7` Gates):**
  - CI run [41294230867](https://github.com/xam-eth/Cyber-Strike/actions/runs/41294230867) passed `Static checks`, **`41/41` Headless smoke tests** (including `tests/kestrel_operative_smoke.gd` + all 40 existing suites), and **all 8/8 Browser WebAssembly QA contracts** on payload `8d9ecec`.
- **UNVERIFIED (hardware & human playtest boundaries):**
  - **UNVERIFIED on physical Android hardware & human playtest:** native APK device testing and subjective human playtest sessions remain separate from automated Godot/Chromium verification.

## Phase 3 — Multi-Theatre Expeditions & Permanent Field Kit Tech Modules checkpoint — 2026-11-01

| Item | Current checkpoint |
|---|---|
| Runtime, Multi-Theatre Worlds, Field Kit Modules, and HUD/Shell source | `39f2973` (over `7345a12` / `b3e1dc6` / `a7ffda6`) |
| Godot/Web CI | [41259486079](https://github.com/xam-eth/Cyber-Strike/actions/runs/41259486079) — **SUCCESS** (`Static checks`, `Headless smoke tests 40/40`, `Web preview build` including all 8 browser QA contracts) |
| Committed Web payload | `6ef1b14` |
| `web/index.pck` | 95,496,076 bytes (`1,001` files); SHA-256 `8b51ab2b9561894ff3d300d68b96339a8fe859d4080f1339ad51167de5836ab5` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Phase 3 runtime visual QA screenshots | [`../qa-evidence/phase-3-modules/`](../qa-evidence/phase-3-modules/hub-expeditions-1280x720-en.png) (4 multi-viewport WebAssembly & Hub captures) |

### What this checkpoint verifies

- **VERIFIED (Multi-Theatre Expeditions across 4 Worlds + Defense Baseline — `world_definition.gd`, `recovery_cache_definition.gd`, `game/resources/worlds/*.tres`):**
  - Extended authored `RecoveryCacheDefinition` expeditions across four distinct 3D theatres (`8` total caches, `4` recoverable schematics) anchored to real landmark coordinates inside each world's GLB layout while keeping `frostline_relay.tres` strictly `Defense`-only (empty `recovery_caches`, no auto-wave, full regression preservation):
    - **Verdant Bloom:** `verdant_seed_vault` (`arc_shooter` weapon blueprint) + optional `verdant_crashed_lab` (`+80 BP`).
    - **Emberfall Foundry:** `emberfall_seam_core` (`breach_capacitor` module schematic + `30 BP`) + optional `emberfall_slag_vault` (`+90 BP`, `120 BP` theatre total) ([`gameplay-emberfall-expedition-1280x720.png`](../qa-evidence/phase-3-modules/gameplay-emberfall-expedition-1280x720.png)).
    - **Vanguard Station:** `vanguard_dock_manifest` (`phase_thrusters` module schematic + `25 BP`) + optional `vanguard_reactor_core` (`+85 BP`, `110 BP` theatre total, keeping the `x = 0, z ∈ [8..34]` sightline corridor clear).
    - **The Titans:** `titans_storm_vault` (`storm_conductor` module schematic + `35 BP`) + optional `titans_spire_relay` (`+105 BP`, `140 BP` theatre total).
- **VERIFIED (Permanent Field Kit Tech Modules & Real Tactical Combat Hooks — `tech_module_definition.gd`, `progression_service.gd`, `player_controller.gd`, `weapon_controller.gd`, `arc_projectile.gd`, `guardian.gd`):**
  - Authored 3 permanent Field Kit Tech Modules unlocked with existing Battle Points (`BP`) after recovering their theatre schematic, with a strict **2-slot (`MAX_EQUIPPED_MODULES = 2`)** tactical cap persisted in `user://progression.cfg`, mirrored read-only to Web `localStorage` (`aegis.progress`), and validated on `?modules=` URL handoff:
    1. **`breach_capacitor` (`140 BP`, Emberfall Foundry):** Precision ADS shots bypass `Iron Warden` frontal shield mitigation (`1.0×` vs `0.45×` hip-fire), `+18%` projectile speed, and `+20%` Nova splash radius.
    2. **`phase_thrusters` (`120 BP`, Vanguard Station):** `+14%` movement speed, `-12%` reload duration, and casting `EMP Pulse` immediately refills `35%` of the active magazine.
    3. **`storm_conductor` (`160 BP`, The Titans):** `+1` `Arc Shooter` chain target (`+2.5m` chain reach), `-18%` `EMP` cooldown, and `-0.65s` `EMP` cooldown refunded per Arc chain hit.
  - Verified architectural and visual separation between permanent Cyan/Amber Field Kit Tech Modules (`set_tech_modifiers`) and temporary Violet (`#b79cff`) in-run evolutions (`RunUpgradeManager` / `set_run_modifiers`): death/retry/explore resets wipe temporary run evolutions while keeping permanent Field Kit modules, schematics, and banked BP intact.
- **VERIFIED (Cross-Surface Armory, HUD, Native Dashboard, & Bilingual EN/ID Shell — `armory_ui.gd`, `hud_armory_bridge.gd`, `hud_encounter_ui.gd`, `hud_menu_ui.gd`, `stage_dashboard.gd`, `stage_hero_select.gd`, `aegis_text_catalog.gd`, `index.html`, `ui/shell.js`, `ui/i18n.js`, `ui/hero.css`):**
  - Upgraded `ArmoryUi` into a 2-tab tactical loadout (`WEAPONS` / `FIELD KIT (n/2)`) fitting cleanly inside `667×375` mobile landscape with procedural cyan module vector icons, blueprint lock states, live BP unlock, and `Slot 1/2` / `Slot 2/2` equip toggling ([`gameplay-armory-field-kit-667x375.png`](../qa-evidence/phase-3-modules/gameplay-armory-field-kit-667x375.png)).
  - Upgraded Web Hub (`CACHES x/8 · SCHEMATICS y/4` + per-theatre expedition intel) and `#weapon-modal` (`ARSENAL & FIELD KIT` -> `WEAPONS` / `FIELD KIT n/2`) across `1280×720`, `844×390`, and `667×375` in both English and Bahasa Indonesia (`363/363` EN/ID catalog keys) ([`hub-expeditions-1280x720-en.png`](../qa-evidence/phase-3-modules/hub-expeditions-1280x720-en.png), [`hub-field-kit-modal-844x390-id.png`](../qa-evidence/phase-3-modules/hub-field-kit-modal-844x390-id.png)).
- **VERIFIED (Automated Godot 4.7.2 Headless `40/40`, WebAssembly `8/8`, & Static `7/7` Gates):**
  - CI run [41259486079](https://github.com/xam-eth/Cyber-Strike/actions/runs/41259486079) passed `Static checks`, **`40/40` Headless smoke tests** (including `tests/multi_theatre_modules_smoke.gd` + all 39 regression suites), and **all 8/8 Browser WebAssembly QA suites** on payload `6ef1b14`.
  - Local `./scripts/dev_check.sh` passed **7/7 check groups (`0` failed steps)** across `98` GDScript files, `104` Python tests, `363/363` EN/ID keys, and `19/19` canonical docs.
- **QUEUED / UNVERIFIED (roadmap boundaries):**
  - **Queued next track:** Phase 4 (`Kestrel` — second playable operative).
  - **UNVERIFIED on physical Android hardware & human playtest:** native APK device testing and subjective human playtest sessions remain separate from automated Godot/Chromium verification.

## Phase 2.5 — Dashboard & Gameplay UI/UX Visual Overhaul checkpoint — 2026-10-31

| Item | Current checkpoint |
|---|---|
| Runtime, Web Hub, Dashboard, and HUD source | `eebf957` (over `85b40d0` / `25295de` / `276b3b0`) |
| Godot/Web CI | [41213031368](https://github.com/xam-eth/Cyber-Strike/actions/runs/41213031368) — **SUCCESS** (`Static checks`, `Headless smoke tests 39/39`, `Web preview build` including all 8 browser QA contracts) |
| Committed Web payload | `202e7c5` |
| `web/index.pck` | 95,466,360 bytes (`999` files); SHA-256 `2214e1d4dcb1e762ff3efcf9055c73b2a5721c1b347b178bcd2d1151af247e2e` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Baseline runtime screenshots | [`../qa-evidence/ui-overhaul/before/`](../qa-evidence/ui-overhaul/before/hub-1280x720-en.png) (6 captures) |
| Post-overhaul runtime screenshots | [`../qa-evidence/ui-overhaul/after/`](../qa-evidence/ui-overhaul/after/gameplay-1280x720-warden-combat.png) (8 captures) |

### What this checkpoint verifies

- **VERIFIED (Web Operations Hub Command Deck — `index.html`, `ui/art.css`, `ui/shell.js`, `ui/i18n.js`):**
  - Upgraded the Web Hub from plain uniform boxes into a dark sci-fi Command Deck backed 100% by real `localStorage` / `roster.json` progression data across `1280×720` (EN), `844×390` (ID), and `667×375` (EN) with `scrollWidth == clientWidth` (`0` overflow) and all touch targets passing `qa_touch_scroll.mjs` & `web_qa.mjs`:
    - Header telemetry chips (`CACHES n/2 · BLUEPRINT n/1` + `BP · RUNS · BEST`) ([`hub-1280x720-en.png`](../qa-evidence/ui-overhaul/after/hub-1280x720-en.png)).
    - Mode-tinted chamfered theatre cards (`WAVE DEFENSE` vs `TECH HUNT` emerald) and a structured `.hub__intel` briefing strip with mode badge, theatre summary, threat composition, and milestone/blueprint reward chips ([`hub-844x390-id.png`](../qa-evidence/ui-overhaul/after/hub-844x390-id.png), [`hub-667x375-en.png`](../qa-evidence/ui-overhaul/after/hub-667x375-en.png)).
    - Live right-rail **Operative Command Card** binding Sable's real tier portrait (`ui/art/web/hero/sable-tier-{1..5}.png`), rank chip (`T1`–`T5`), real HP/Armor stats from `tierRow()`, and equipped weapon tier.
- **VERIFIED (Native Godot Dashboard — `stage_dashboard.gd`, `aegis_text_catalog.gd`):**
  - Tuned hangar backdrop scrim (`0.74`) so the 3D hangar key art reads cleanly behind machined manifest plates; styled `01 OPERATIVE` (Cyan `INFO`), `02 DEPLOYMENT THEATRE` (Amber `ACCENT`), and `03 ARSENAL` (Emerald `OK`) with dual-layer glowing spines, optical thumbnail frames, right-aligned tier/mode badges (`DEFENSE` / `RECOVERY` compact mode at `<520px` height), non-truncated status copy (`TIER 1 · HP 100 · ARM 0% · FIELD READY`), and a structured `RecordRibbon` ([`godot-dashboard-1280x720.png`](../qa-evidence/ui-overhaul/after/godot-dashboard-1280x720.png), [`godot-dashboard-844x390.png`](../qa-evidence/ui-overhaul/after/godot-dashboard-844x390.png)).
- **VERIFIED (Gameplay HUD, Tactical Compass, Modals, & Feedback — `aegis_panel.gd`, `segmented_bar.gd`, `aegis_ammo_chip.gd`, `hud_renderer.gd`, `hud_styles.gd`, `hud_encounter_ui.gd`, `hud_combat_feedback_ui.gd`, `hud_upgrade_bridge.gd`, `touch_controls.gd`):**
  - Optical 45° corner chamfers, specular telemetry header bands, and dual-layer glowing status spines on `HealthCard`, `WaveCard`, `GuardianCard`, `UpgradeStatusCard`, and `CombatFeedback` while preserving `StyleBoxFlat` panel alpha scaling (`ui_settings_smoke.gd`) and `PausePanel`/`ResultsPanel` 22px `AegisBezel` silhouettes ([`gameplay-1280x720-en.png`](../qa-evidence/ui-overhaul/after/gameplay-1280x720-en.png)).
  - Live **Tactical Azimuth Compass** (`TacticalCompassLayer` + `HudRenderer.draw_tactical_compass`) driven by real `Camera3D` yaw, live `WaveDirector` enemy bearings (`DANGER` / `ACCENT` boss pips), and active `RecoveryCache` world waypoints (`OK` emerald diamond), centered below `SystemRow` in normal play and automatically shifting into the left safe lane when `GuardianCard` is visible ([`gameplay-1280x720-warden-combat.png`](../qa-evidence/ui-overhaul/after/gameplay-1280x720-warden-combat.png), [`gameplay-844x390-id.png`](../qa-evidence/ui-overhaul/after/gameplay-844x390-id.png)).
  - Live operative tier badge (`T1` / `T2 · 3%`) on `HealthCard`, specular 4-segment `SegmentedBar` on `HealthBar` & `GuardianHealthBar`, live `MagazineBar` on `TouchAmmoChip`, ADS framing brackets & vector joystick lines in `HudRenderer`, violet `AegisTokens.ABILITY` (`#b79cff`) visual separation on temporary `RUN MOD` widgets vs permanent `ACCENT`/`OK` progression, centered `420px`-capped `CombatFeedback` toast, and aligned `verdant_seed_vault` `interaction_radius = 6.0` matching `verdant_crashed_lab`.
- **VERIFIED (Automated CI & Local Static Gates):**
  - CI run [41213031368](https://github.com/xam-eth/Cyber-Strike/actions/runs/41213031368) passed `Static checks`, `Headless smoke tests` (**39/39 PASS** on Godot `4.7.2`), and `Web preview build` (**8/8 Browser QA suites PASS**, including full `Browser TECH HUNT E2E closure contract`).
  - Local `./scripts/dev_check.sh` passed **7/7 groups (`0` failed steps)**: `97` GDScript files parsed/linted/formatted, `104` Python tests, `337/337` EN/ID keys, and `19/19` canonical docs.
- **QUEUED / UNVERIFIED (roadmap boundaries):**
  - **Queued next tracks:** Phase 3 (`Multi-Theatre & Tech Modules`) -> Phase 4 (`Kestrel`).
  - **UNVERIFIED on physical Android hardware & human playtest:** native APK device testing and subjective human playtest sessions remain separate from automated Godot/Chromium verification.

## Track 2 — Endless Survival, Iron Warden Guardian, and EMP counterplay checkpoint — 2026-10-31

| Item | Current checkpoint |
|---|---|
| Runtime, UI/UX, and smoke-test source | `485803c` (Track 2 implementation over `7530ee9` / `23daf25`) |
| Godot/Web CI | [41193760549](https://github.com/xam-eth/Cyber-Strike/actions/runs/41193760549) — **SUCCESS** (`Static checks`, `Headless smoke tests 39/39`, `Web preview build` including all 8 browser QA contracts) |
| Committed Web payload | `07af9a5` |
| `web/index.pck` | 95,449,368 bytes (`999` files, `15` Guardian/`iron_warden` entries); SHA-256 `b9c4ca70263bf39ce68f312a38ad5246759052f80ddcdfdd5470e945e82193b1` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Runtime Guardian & Endless QA evidence | [`../qa-evidence/endless-guardian/guardian-qa-summary.json`](../qa-evidence/endless-guardian/guardian-qa-summary.json) (5 multi-viewport WebAssembly captures) |

### What this checkpoint verifies

- **VERIFIED (Godot 4.7.2 headless engine suite — `39/39` PASS):**
  - CI run [41193760549](https://github.com/xam-eth/Cyber-Strike/actions/runs/41193760549) executed all 39 smoke tests on Godot `4.7.2.stable.official.ed1daf0bf` with `0` failures and `0` script errors, including `tests/endless_guardian_smoke.gd` verifying:
    1. **Rigged `Iron Warden` Guardian (`GuardianEnemy`):** Loads `enemy_iron_warden_boss.glb` (`fitted_height = 2.350m`, `fallback=no`), mitigates frontal damage to `0.45×` while fortified, amplifies exposed core damage to `1.5×`, projects a ground salvo hazard ring during `WINDUP`/`FIRING`, enters a natural `EXPOSED` recovery punish window after firing, and immediately shatters its shield when hit by the player's `EMP Pulse` (`disrupt_shield()`).
    2. **Meaningful Endless Survival escalation (`WaveDirector`):** Scales wave composition (`Runner` + `Shooter` + `Guardian` every 3rd wave at Waves `3, 6, 9, …`), escalates HP smoothly (`scale_max_health` up to `2.2×`), grants `+15 BP` milestone bonuses at Waves `3, 5, 8, 10, …`, and enforces an anti-farming cap of `8` KOs per wave that charge `RunUpgradeManager`.
    3. **Full vertical slice (`Recovery → Continue to Endless → Guardian KO → Exact-Once Finish Run`):** Verifies `Mission Complete` → `Continue to Endless`, multi-resolution `GuardianCard` layout bounds (`1280×720`, `844×390`, `667×375`) with zero overlap against `VitalsPanel`, `WavePanel`, `TopBar`, or touch controls, `+35 BP` + `+2` `RunUpgradeManager` KO charges on Guardian elimination, `GUARDIANS DEFEATED` + `ENDLESS MILESTONE BONUS` lines in `Mission Results`, exact-once `bank_run` idempotence on repeated `_finish_run()`, and clean temporary state reset on `_return_to_explore()`.
- **VERIFIED (exported WebAssembly runtime & multi-viewport visual QA on payload `07af9a5`):**
  - CI Web preview job ([41193760549](https://github.com/xam-eth/Cyber-Strike/actions/runs/41193760549)) passed all 8 browser suites including `Browser TECH HUNT E2E closure contract`.
  - Direct Chromium WebAssembly runtime captures (`/?ui=hub&qa_guardian=1`) verified `Encounter: Guardian deployed (wave 1)` and `EnemyVisual[IronWarden_Wave1_02]: model=EnemyModel fitted_height=2.350m fallback=no` with **0 script/page errors**:
    - Desktop `1280×720` (EN): fortified hexagonal shield (`IRON WARDEN · SHIELDED · EMP · 135 / 135`) ([`desktop-1280x720-warden-fortified.png`](../qa-evidence/endless-guardian/desktop-1280x720-warden-fortified.png)), post-salvo recovery punish state (`EXPOSED 1.5X!`) with glowing red-orange core ([`desktop-1280x720-warden-exposed.png`](../qa-evidence/endless-guardian/desktop-1280x720-warden-exposed.png)), and close-range `EMP PULSE · 2 TARGETS` core damage (`108 / 135`) ([`desktop-1280x720-warden-emp-shatter.png`](../qa-evidence/endless-guardian/desktop-1280x720-warden-emp-shatter.png)).
    - Mobile landscape `844×390` (Bahasa Indonesia): localized `GELOMBANG 01`, `IRON WARDEN · PERISAI · EMP`, `MOD SESI 0 / 2`, `WARDEN MUNCUL!`, and touch controls (`ARSENAL`, `BIDIK`, `EMP`, `TEMBAK`) without overlap ([`mobile-844x390-id-warden-fortified.png`](../qa-evidence/endless-guardian/mobile-844x390-id-warden-fortified.png)).
    - Compact mobile landscape `667×375` (EN): ground salvo telegraph ring, projectile hazard, and left-stacked `SALVO LOCK · DODGE` card leaving center reticle and right-hand touch cluster clear ([`mobile-667x375-en-warden-salvo-lock.png`](../qa-evidence/endless-guardian/mobile-667x375-en-warden-salvo-lock.png)).
- **VERIFIED (local static gates):** `./scripts/dev_check.sh` passed with **0 failed steps and 2 expected local skips**: 97/97 GDScript files parsed/linted/formatted, `0 FAIL` in `project_doctor.py`, `19/19` canonical documents, `104` Python tooling unit tests, `39` smoke tests outside `res://`, `337/337` EN/ID localization keys, and synchronized `docs/ARCHITECTURE.md` (`19` modules, `96` files, `26,403` lines).
- **QUEUED / UNVERIFIED (roadmap boundaries):**
  - **Queued later tracks:** Track 3 (`Multi-Theatre & Tech Modules`) and Track 4 (`Kestrel`).
  - **UNVERIFIED on physical Android hardware & human playtest:** native APK device testing remains paused; human balance/feel playtesting across deep Endless waves remains separate from automated headless/Chromium verification.

## Track 1 — TECH HUNT end-to-end expedition, lost-player guidance, and progression checkpoint — 2026-10-30

| Item | Current checkpoint |
|---|---|
| Runtime, UI/UX, and E2E QA source | `fa9fc75` (audit stabilization over `b7794ae`) |
| Godot/Web CI | [41036347813](https://github.com/xam-eth/Cyber-Strike/actions/runs/41036347813) — **SUCCESS** (`Static checks`, `Headless smoke tests 38/38`, `Web preview build` including Step 20 `--recovery-e2e`) |
| Committed Web payload | `2ee3fb9` |
| `web/index.pck` | 90,768,108 bytes; SHA-256 `93017b017e251a1a557f051f9ea99ba902111760d3eca84f534b2e709eb44a88` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Desktop `1280×720` E2E evidence | [`../qa-evidence/tech-hunt/recovery-e2e-1280x720.json`](../qa-evidence/tech-hunt/recovery-e2e-1280x720.json) (12 runtime captures) |
| Mobile `844×390` Recovery evidence | [`../qa-evidence/tech-hunt/recovery-mobile-844x390.json`](../qa-evidence/tech-hunt/recovery-mobile-844x390.json) (5 runtime captures) |

### What this checkpoint verifies

- **VERIFIED (Automated Chromium TECH HUNT E2E — `Verdant clear → Arc Blueprint secure → Extract (+20 BP) → Tier-2 → 106-vital redeploy`):**
  - Executed both in CI ([41036347813](https://github.com/xam-eth/Cyber-Strike/actions/runs/41036347813), Step 20) and locally against payload `2ee3fb9` (`node tools/web_qa.mjs --recovery-e2e --viewport 1280x720`) with **0 failed checks and 0 page/script errors**:
    1. **Tier 1 landing & relative guidance:** Deployed Sable at `VITALS 100 / 100` (`tier=1/1 reduction=0%`) in Verdant Bloom with immediate relative objective readout (`RECOVER · SEED VAULT / ARC SHOOTER BLUEPRINT · APPROACH · AHEAD 9M`) — [`root-1280x720-recovery-landing.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-landing.png).
    2. **Real guard engagement, KO rewards, & clear:** Triggered `ENGAGE GUARDS [B]` ([`root-1280x720-recovery-engage-offer.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-engage-offer.png)), verified elevated 3D `RecoveryLabel` (`y = 2.55`), `SECURE LOCKED` with active guard bearing (`HOSTILE · AHEAD` / `LEFT`) across `Guard_verdant_seed_vault_01` and `Guard_verdant_seed_vault_02` ([`root-1280x720-recovery-guarded.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-guarded.png), [`root-1280x720-recovery-contact.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-contact.png)), and eliminated both guards through real projectile/ADS combat (`RUNNER KO · +10 BP`, `SHOOTER KO · +10 BP`, `guards=0`).
    3. **Explicit Secure & unclipped Mission Complete breakdown:** Approached the Seed Vault (`SECURE CACHE [B]`, [`root-1280x720-recovery-ready-to-secure.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-ready-to-secure.png)), secured the `arc_shooter` blueprint, and verified the unclipped `RECOVERY COMPLETE` card with `check`-icon `EXTRACT`, `ARC SHOOTER BLUEPRINT SECURED`, `NEW ARMORY ELIGIBILITY · ARC SHOOTER`, `ARMORY UNLOCK COST · 250 BP`, and `EXTRACT BANKS RUN #1 · UNLOCKS TIER 2 (106 HP · 3% ARMOR)` ([`root-1280x720-recovery-mission-complete.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-mission-complete.png)).
    4. **Exact-once Extract (+20 BP banked) & persistent IndexedDB/localStorage handoff:** Selected `EXTRACT` (`completed_runs: 0 → 1`, `balance: 0 → 20`, `best_score: 0 → 200`), verified the unclipped `EXTRACTION COMPLETE` breakdown (`+20 BP BANKED`, `RETURN TO EXPLORE` reset, `SECURED · ARC SHOOTER BLUEPRINT`, `PROMOTED · SABLE TIER 2 READY (106 HP · 3% ARMOR)`, `RESET · FIELD ENEMIES & TEMP RUN STATE CLEARED`, and `ESC` pause-overlay guard) ([`root-1280x720-recovery-results-extracted.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-results-extracted.png)), then returned via `HOME` after clean `Sfx.shutdown()` + Emscripten `IDBFS` `/userfs` flush (`20 BP · 1 RUN · BEST 200`, `arc_shooter` blueprint saved, `verdant_seed_vault` secured) ([`root-1280x720-recovery-hub-tier2-ready.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-hub-tier2-ready.png)).
    5. **Tier 2 Plated selection, Arc Shooter rack eligibility, & 106-vital redeploy:** Opened `OPERATIVE`, selected newly unlocked `T2 PLATED` (`hero_human_tier_2.glb`, `VITALS 106 +6 HP`, `ARMOUR 3% blocked`, `1 / 3 RUNS TO TIER 3`) ([`root-1280x720-recovery-operative-tier2.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-operative-tier2.png)), verified `ARC SHOOTER` transitioned from `BLUEPRINT` to `250 BP` in the weapon rack ([`root-1280x720-recovery-rack-arc-eligible.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-rack-arc-eligible.png)), and redeployed into Verdant Bloom at `VITALS 106 / 106` (`Operative: hero=sable tier=2/2 vitals=106 reduction=3%`) with Seed Vault preserved as `SECURED`, `"hud-weapon"` Armory button icon, and HUD guidance automatically retargeting the optional cache (`OPTIONAL · LAB CACHE · PERMANENT +80 BP · LEFT 44M`) ([`root-1280x720-recovery-redeploy-tier2-106hp.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-redeploy-tier2-106hp.png)).
- **VERIFIED (Pre-Track 2 Audit Stabilization across HUD, Modals, Web Shell, Native `FrontEnd`, & QA Tooling):**
  - Headless Godot `tests/recovery_smoke.gd` (`38/38` CI smoke suite) verified Area → Local (`AHEAD` / `LEFT` / `RIGHT` / `TURN AROUND` + distance) → Stuck escalation after `14s` without progress (`FOLLOW BEACON`), immediate reset on progress, combat guard tracking, Explore guard KO banking (`+20 BP`) without pre-Extract death-farming, and automatic shift from `verdant_seed_vault` to optional `verdant_crashed_lab` after primary secure.
  - Mobile landscape `844×390` and `667×375` browser verification (`web_qa.mjs --recovery`, `qa_touch_targets.mjs`, `qa_motion_touch.mjs`, `qa_touch_scroll.mjs`, `qa_flow_shots.mjs`, `web_loading_qa.mjs`, `web_support_qa.mjs`) passed with unclipped `ArmoryUi`, first-frame `48px` `HudCombatFeedbackUi`, 3-line `AegisUpgradeCard`, active `HOSTILE` bearing in `844×390` guard combat, synchronized `StageLoading` percentage (`83%` at `10 / 12`), clean `ARMOUR 0%` formatting, and full EN/ID Web shell localization ([`root-844x390-recovery-landing.png`](../qa-evidence/tech-hunt/root-844x390-recovery-landing.png), [`root-844x390-recovery-guarded.png`](../qa-evidence/tech-hunt/root-844x390-recovery-guarded.png)).
- **VERIFIED (local static gates):** `./scripts/dev_check.sh` passed with **0 failed steps and 2 expected local skips**: 96/96 GDScript files parsed/linted/formatted, `0 FAIL` in `project_doctor.py`, `19/19` canonical documents, `103` tooling tests, `0` static-call or boundary violations, `329/329` EN/ID localization keys, `123` hero/tier checks, and synchronized `docs/ARCHITECTURE.md` module map.
- **QUEUED / UNVERIFIED (roadmap boundaries):**
  - **Queued later tracks (not started in Track 1):** Track 2 (`Endless & Guardian`), Track 3 (`Multi-Theatre & Tech Modules`), and Track 4 (`Kestrel`).
  - **UNVERIFIED on physical Android hardware & human playtest:** native APK device testing remains paused; human balance/feel playtesting remains separate from automated Chromium verification.

## Gameplay loop, temporary run evolutions, and cohesive UI/UX checkpoint — 2026-10-29

| Item | Current checkpoint |
|---|---|
| Baseline commit inspected before changes | `5453420a39b186188bdee262878718eceb2e4b4b` |
| Runtime, UI/UX, and smoke-test source | `46391ca` |
| Godot/Web CI | [40898268332](https://github.com/xam-eth/Cyber-Strike/actions/runs/40898268332) — **SUCCESS** (`Static checks`, `Headless smoke tests 38/38`, `Web preview build`) |
| Committed Web payload | `6d15797dac897db3e9ac470e4fd569fbf0c072e3` |
| `web/index.pck` | 90,749,804 bytes; SHA-256 `f93c1215a6dc4a82fac531f6ab7930f49e97ed176a3c7d4cd86cef495ab4478b` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Baseline runtime screenshots | [`../qa-evidence/redesign/before/`](../qa-evidence/redesign/before/hub-844x390.png) (16 captures) |
| Post-implementation runtime screenshots | [`../qa-evidence/redesign/after/`](../qa-evidence/redesign/after/hub-844x390.png) (19 captures) |

### Phase 1 baseline audit summary (`5453420`)

Before modifying source files, the baseline project was audited statically and executed in headless Chromium against the committed WebAssembly build:

- **VERIFIED WORKING at baseline:** Web opening/preload/interrupted-download recovery (`index.html`, `ui/shell.js`), 3D player movement/ADS/shoot/reload/EMP (`player_controller.gd`, `weapon_controller.gd`), `Runner` + `Shooter` enemy waves (`wave_director.gd`), Verdant Seed Vault Recovery (`recovery_cache_node.gd`), persistent BP/weapon-tier/hero-tier/cache profile storage (`progression_service.gd`), EN/ID localization (`aegis_text_catalog.gd`), and WebAudio synthesis (`sfx.gd`, `ui/audio.js`).
- **Gaps identified at baseline (`NOT IMPLEMENTED` / `PARTIALLY WORKING`):**
  1. **Temporary mid-run upgrades (`CHOOSE → EVOLVE`):** **NOT IMPLEMENTED** — no `RunUpgradeDefinition` or `RunUpgradeManager`, no HUD evolution prompt/modal, and no non-persistent runtime modifier layer on `WeaponController`/`PlayerController`.
  2. **Reusable UI component coverage:** **PARTIALLY WORKING** — lacked reusable `AegisTierBadge`, `AegisStatChip`, `AegisUpgradeCard`, and `AegisConfirmDialog` widgets; abandoning an active Defense run from Pause had no unbanked-BP confirmation guard.
  3. **Cross-surface data sync & Armory parity:** **PARTIALLY WORKING** — Web shell only received `aegis.runs` (showing hardcoded weapon tier 1 and no wallet BP/best score/blueprint state), `StageDashboard`'s Armory modal did not connect `weapon_upgrade_requested` (leaving `T2/T3` buttons inert in native Hub), `ArmoryUi` showed `UNLOCK 250 BP` on Arc Shooter even when its blueprint was still locked, and Web `CONTROLS` listed stale keys (`1/2/3`, `Space`, `Shift`) that were not bound in GDScript.

### What this checkpoint verifies

- **VERIFIED (local static gates):** `./scripts/dev_check.sh` passed with **0 failed steps and 2 expected local skips**: 96/96 GDScript files parsed/linted/formatted, `project_doctor.py` `0 FAIL`, `19/19` canonical documents, `103` Python tooling unit tests, `0` static-call or architecture-boundary violations (`check_architecture.py`), `308/308` EN/ID localization keys with aligned placeholders (`check_localization.py`), `123` hero/tier checks, and generated module-map sync (`module_map.py --check`).
- **VERIFIED (Godot 4.7.2 headless engine suite — `38/38` PASS):** CI run [40898268332](https://github.com/xam-eth/Cyber-Strike/actions/runs/40898268332) executed all 38 smoke tests on Godot `4.7.2.stable.official.ed1daf0bf` with `0` failures and `0` script errors, including the new `tests/run_upgrade_smoke.gd` covering:
  - all 6 authored `RunUpgradeDefinition` resources (`overcharge_cells`, `rapid_autoloader`, `expanded_capacitor`, `emp_resonator`, `kinetic_servos`, `reactive_plating`);
  - `RunUpgradeManager` KO charge thresholds (`2, 3, 4, 5, 6`), milestone triggers, 3-card non-duplicate offers, max-stack filtering, and clean `reset_run()`;
  - native `StageDashboard` `ArmoryUi` `weapon_upgrade_requested` upgrading `pulse_rifle` to Tier 2 and displaying `BLUEPRINT LOCKED` on `arc_shooter` before Seed Vault recovery;
  - live `main.tscn` vertical slice: safe Explore `PauseHomeButton` immediate exit, Wave 1 start, 2 real enemy eliminations readying `UpgradeReadyButton`, multi-resolution layout bounds at `1280×720`, `844×390`, and `667×375`, `RunUpgradePanel` pause/select/resume flow, `AegisConfirmDialog` protecting unbanked Defense BP (`BANK BP & FINISH` / `STAY IN FIGHT` / `ABANDON RUN`), immutable `.tres` `WeaponDefinition` verification, exact-once `bank_run` (duplicate `_finish_run()` guard), and complete temporary modifier reset on `_return_to_explore()` while preserving banked wallet BP.
- **VERIFIED (exported WebAssembly runtime & visual inspection on payload `6d15797`):**
  - CI Web preview job passed export, 984-file PCK audit, static delivery, browser smoke, Secure Context/AudioWorklet preflight, interrupted-download recovery, shell world-selection, Titans selection/audio, mouse/touch ADS, and Verdant Recovery engagement contracts.
  - Post-pull Chromium captures verified both Web shell and Godot WASM rendering with zero script/page errors across `1280×720`, `844×390`, and `667×375`:
    - Hub & Operative shell: [`before/hub-844x390.png`](../qa-evidence/redesign/before/hub-844x390.png) → [`after/hub-844x390.png`](../qa-evidence/redesign/after/hub-844x390.png), [`after/hub-667x375.png`](../qa-evidence/redesign/after/hub-667x375.png), [`before/hero-844x390.png`](../qa-evidence/redesign/before/hero-844x390.png) → [`after/hero-844x390.png`](../qa-evidence/redesign/after/hero-844x390.png), [`after/settings-844x390.png`](../qa-evidence/redesign/after/settings-844x390.png).
    - Native Godot front-end stages: [`before/godot-dashboard-844x390.png`](../qa-evidence/redesign/before/godot-dashboard-844x390.png) → [`after/godot-dashboard-844x390.png`](../qa-evidence/redesign/after/godot-dashboard-844x390.png), [`after/godot-hero-844x390.png`](../qa-evidence/redesign/after/godot-hero-844x390.png), [`after/godot-world-844x390.png`](../qa-evidence/redesign/after/godot-world-844x390.png).
    - Combat HUD, Temporary Run Evolutions, and Blueprint-gated Armory: [`before/hud-explore-844x390.png`](../qa-evidence/redesign/before/hud-explore-844x390.png) → [`after/hud-upgrade-ready-844x390.png`](../qa-evidence/redesign/after/hud-upgrade-ready-844x390.png), [`after/hud-upgrade-modal-844x390.png`](../qa-evidence/redesign/after/hud-upgrade-modal-844x390.png), [`after/hud-upgrade-modal-667x375.png`](../qa-evidence/redesign/after/hud-upgrade-modal-667x375.png), [`after/hud-upgrade-applied-844x390.png`](../qa-evidence/redesign/after/hud-upgrade-applied-844x390.png) (`VITALS 125 / 125` + `RUN MOD PLT L1 0/3`), [`after/hud-armory-844x390.png`](../qa-evidence/redesign/after/hud-armory-844x390.png), [`after/hud-pause-844x390.png`](../qa-evidence/redesign/after/hud-pause-844x390.png), and [`after/root-1280x720-recovery-landing.png`](../qa-evidence/redesign/after/root-1280x720-recovery-landing.png).
- **UNKNOWN / UNVERIFIED (honest scope limits):**
  - **UNVERIFIED on physical Android hardware:** native APK installation, physical touch ergonomics, mobile GPU frame time/thermals/battery, and Android lifecycle soak remain unverified in this environment (APK target remains paused per earlier project decision).
  - **INTENTIONAL SCOPE / IN DEVELOPMENT:** second operative `Kestrel` (`hero_2`), Cosmetic progression (`NOT IMPLEMENTED`, separated by design from gameplay tiers), and `THEATRE 06` remain marked `IN DEVELOPMENT` rather than faking inactive systems.
  - **UNKNOWN (human playtest outcomes):** subjective combat feel, run-evolution balance across long Endless waves, audiovisual mix preference, and player retention require human playtesting.

## Website Operator and Recovery gameplay checkpoint — 2026-10-28

| Item | Current checkpoint |
|---|---|
| Runtime and browser-QA source | `d0dce51758927c8a0c2cadf3d40eb834c37eaaf0` |
| Operator hierarchy source | `ac81df2abe9808b297709ac66cf030a764a2b340` |
| Godot/Web CI | [40694414307](https://github.com/xam-eth/Cyber-Strike/actions/runs/40694414307) — **SUCCESS** |
| Committed Web payload | `2cf6c18692f618815fa50eb7a7a1729396dfddcd` |
| `web/index.pck` | 90,698,148 bytes; SHA-256 `60d25e2cc20519f5f4db50dacf1f6739e601d5ca0c04b0c91ca22dc6d4f57a0f` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |

- **IMPLEMENTED (Operator hierarchy):** the playable Sable option is the dominant bottom panel, its separate tier stepper is on the left, and the three-weapon rack remains a distinct loadout surface. Cards use roster-backed role, name, field/development status, brief, and existing run-based tier data. No unsupported hero skill, strength, BP-purchased hero tier, fourth weapon, or hero-stat progression was invented.
- **VERIFIED (Operator layout and interaction):** final `exports/ui/operator-after-2/` captures passed at 1280×720, 844×390, and 667×375 after measured overflow/clipping fixes. `exports/ui/operative-evidence-{1280x720,844x390,667x375}/` contains **36/36 passing frames**, covering EN/ID resting, hero press/refusal, tier preview/model swap, settled equipped-rifle state, and weapon rack. Tier-left, dominant-hero, weapon/group separation, 44 px target, and overflow assertions passed. `git diff ac81df2..2cf6c18 -- index.html ui` is empty, so the inspected shell is the shell in the current payload. This is automated Chromium plus agent image inspection, not human visual approval.
- **IMPLEMENTED (read-only Recovery diagnostics):** `?qa_recovery` reports actual HUD phase/action/guard/detail changes and opt-in guard camera projections. It cannot change AI, health, damage, rewards, ownership, or profile state; ordinary play does not emit it. `tools/web_qa.mjs --recovery` uses actual state transitions rather than fixed-distance guesses.
- **VERIFIED (local static and CI):** the source change completed `scripts/dev_check.sh` with **0 failed steps and 2 expected local skips**. CI passed static checks, Godot 4.7.2 **37/37 smoke tests**, Web export/audit/delivery, boot/loading/theatre/audio gates, Pulse mouse/touch ADS, and the new Browser Recovery engagement contract. Android/native remained skipped and is not evidence.
- **VERIFIED (current-payload browser engagement, real models, partial combat, and failure):** repeated real-input probes on payload `2cf6c18` reached Verdant `ENGAGE GUARDS` at 4 m and spawned `Guard_verdant_seed_vault_01` / `_02` with fitted heights 1.720/1.620 m and `fallback=no`. HUD state stayed `SECURE LOCKED` while guards were active. The guard count changed from 2 to 1 through the real elimination path, and an unsuccessful run opened the inspected `RUN ENDED · NO BP · NO RUN STARTED` Results surface; see `exports/web-qa/verdant-recovery-outcome/console.json` and the inspected `03-engage.png` / `05-combat-end.png`. This proves one guard elimination and a failure outcome, **not** a two-guard clear or mission success.
- **VERIFIED (reward accounting boundary):** Recovery guard elimination before a Defense run does not manufacture BP: `RewardService` requires active `RunStats`. The primary's permanent reward is Arc blueprint eligibility; the optional lab cache is the authored 80 BP transaction. The 37-test engine gate covers real guard elimination, blocked/duplicate Secure, blueprint persistence, optional BP, death/retry/reload, Endless coexistence, Extract, and exactly-once banking. Those engine contracts must not be misreported as a completed browser playthrough.
- **CLOSED IN 2026-10-30 CHECKPOINT ABOVE (historical 2026-10-28 browser gap):** at `2cf6c18`, no attached browser run had yet reached `guards=0`, Secure, Arc-blueprint Results, Extract, completed-run persistence, earned tier-2 selection, or 106-vital redeployment. That repeatable Chromium E2E loop is now implemented (`tools/web_qa.mjs --recovery-e2e`), enforced in CI, and verified against payload `dd7aa81` in the `2026-10-30` Track 1 checkpoint above.
- **UNKNOWN (human/device outcomes):** no physical-phone pass, final human visual/audiovisual approval, touch-performance/FPS claim, retention claim, or human mission-balance assessment is attached. APK/native remains paused. The existing three weapons and their ADS scope are preserved.

## Active target decision and local Web incident — 2026-10-27

- **USER DECISION (APK paused):** native APK/device work is **PAUSED** for now. Active development and testing target is the **Website**. The earlier APK's native presentation gap and force-close after DEPLOY remain unresolved and deferred; they are not accepted, fixed, or final-device evidence.
- **VERIFIED (real insecure-context reproduction):** before the shell correction, Chromium at `http://169.254.0.21:8000` reproduced the user's exact `Dunia gagal dimuat` / `Cannot read properties of undefined (reading 'addModule')` DEPLOY failure; see `exports/incident/insecure-context-preflight/before-800x360.png`. The generated engine calls `AudioContext.audioWorklet.addModule(...)`, while the custom root shell previously started without the raw export's Secure Context preflight.
- **IMPLEMENTED (actionable browser preflight):** the root shell now checks Secure Context and AudioWorklet, then uses the exported engine's remaining single-threaded feature probe before fetching the exported config, WASM, or PCK. Opening and direct-DEPLOY failures retain localized HTTPS/localhost or current-browser guidance and a reload/retry surface; audio is not disabled to bypass the requirement.
- **VERIFIED (automated Chromium support and normal gameplay):** `node tools/web_support_qa.mjs --timeout 30 --json` passed **3/3** cases: real insecure HTTP opening, real insecure direct DEPLOY, and simulated missing AudioWorklet on secure localhost. Every case exposed the intended guidance with **0 Engine constructions and 0 config/WASM/PCK requests**; see `exports/web-qa/support-report.json`. A separate normal `web_qa.mjs` run against the CI-refreshed payload `7216bfd` passed all **16/16** checks at 800×360 with touch, including HERO, Frostline card selection, authoritative handoff, and actual `frostline_relay` gameplay in 38.55 seconds; see `exports/incident/ci-payload-7216bfd-report.json`. Current `/__build` reports **90,682,980 bytes**, and the PCK SHA-256 is `00647b9c4fa49e4c03c24d9ab55fdfe0e9defd941df7502199930697f05e8fdd`.
- **VERIFIED (CI):** [Godot CI 40535122323](https://github.com/xam-eth/Cyber-Strike/actions/runs/40535122323) succeeded on source commit `8b205ad`: static checks, headless Godot smoke, Web export/audit, browser smoke, the new three-case support preflight, interrupted-download recovery, and Vanguard/Titans selection/audio jobs passed. Its payload commit is `7216bfd`; optional authoring/Pages jobs were skipped and are not evidence.
- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 100 tooling tests, 19/19 canonical documents with 163 relative links, and 87 GDScripts parsed/linted/formatted. The machine-local export preset and Godot binary were skipped; this shell-only change has no new Godot engine-test claim.
- **UNKNOWN (user's local cause and closure):** the sandbox reproduction proves one way to produce the reported exception, not the user's exact URL/browser condition. The user has not yet supplied the current `/__build`, exact failing URL, or browser/version. An insecure LAN HTTP URL and a browser without AudioWorklet now take different guidance paths; a localhost URL on the server machine remains the immediate local corrective test. Local gameplay is not declared fixed until the user confirms DEPLOY on that setup.

## Current Phase 1 visual-review checkpoint — 2026-10-27

This checkpoint adds review tooling and hardens existing browser capture. It does not approve a golden, change gameplay, or replace the runtime CI evidence below.

- **IMPLEMENTED (comparison and approval):** `tools/visual_review.py` and `tools/visual_review.json` provide reference/current/diff reports, per-case channel and pixel-ratio tolerances, explicit `MATCH` / `REVIEW_REQUIRED` / `BASELINE_PENDING` / missing/error states, and named-case approval from the exact reviewed report with report-digest and current-image hash verification. Compare never updates references. The reusable procedure is [`runbooks/VISUAL_REVIEW.md`](runbooks/VISUAL_REVIEW.md).
- **VERIFIED (synthetic/local static):** all **10/10** comparator contract tests passed for real changes, tolerances, dimensions, corrupt current evidence, pending baselines, report/image tamper rejection, unsafe paths, and output overwrite protection. The full `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 100 tooling tests, 19/19 canonical documents, and 87 GDScripts parsed/linted/formatted. The local preset and Godot binary remained skipped; synthetic images do not prove game appearance.
- **VERIFIED (initial automated Web capture):** against payload commit `41ccd8e51d8ee8cfaaa191480ad991f796131a60` and PCK SHA-256 `bfd82c279b38fcf2f6c2a644527003815f36da1a409b876728437d683711c70d`, two shell runs produced **10/10 nonblank 844×390 frames with 0 failures**. Two gameplay runs both passed actual journey, unpaused safe Explore, visible B-triggered Defense preparation, and WorldTour checks; each tour produced **8/8 distinct frames**. These are Chromium/SwiftShader results, not Android evidence.
- **VERIFIED (CI):** [Godot CI 40511867894](https://github.com/xam-eth/Cyber-Strike/actions/runs/40511867894) succeeded on tooling commit `641b637535c5eef643313c746fb9d8a5ed921d53`: static checks, the headless Godot smoke job, Web export/payload audit, and the registered browser/recovery/theatre/audio jobs passed. Optional asset-authoring and Pages jobs were skipped. The run committed refreshed payload `014555d57abf363fc38945fc889e172268887742`; Android workflow `40511867994` was skipped and supplies no new APK/device evidence.
- **VERIFIED (refreshed Web payload):** the CI payload's PCK SHA-256 is `e670e689fa906bc2704c8b578ace1948f159a3ec2448a253db966af9d37fd2cd`. A fresh local capture produced **5/5 nonblank shell frames**, passed gameplay/Explore/Defense preparation, and produced **8/8 distinct WorldTour frames**. All eight current images stayed inside their case tolerances in the previous-payload/new-payload comparison; see `exports/visual-review/web-payload-014555d-review/payload-review.md`. This verifies the registered Web states only and is not human or Android approval.
- **VERIFIED (repeat-capture stability, limited scope):** the initial A/B comparison on payload `41ccd8e` reports `MATCH` within each proposed tolerance for all eight registered cases. Diff ratios range from `0` to `0.002166`; this is run-to-run stability in one environment, not a golden comparison or proof on another GPU. Evidence: `exports/visual-review/web-stability-20261027/stability.md` and `stability.json`.
- **FIXED (capture harness only):** repetition exposed two harness races: a late fallback Escape could pause newly reached gameplay, and a deep-linked shell screen could capture the dock before async readiness became `ok`. `web_qa.mjs` now rechecks arrival before fallbacks and refuses Defense input from paused/unsafe Explore; `ui_shots.mjs` waits for readiness. The failed paused run was rejected as a candidate, and the final A/B runs above passed after the fix. No gameplay/runtime source changed.
- **BASELINE_PENDING (human review):** `exports/visual-review/web-candidates-final/index.html` was refreshed from payload `014555d`, contains eight unapproved candidates, and its JSON report records **8 × BASELINE_PENDING**. No golden or approval ledger has been created. A human must inspect the exact report and explicitly name each accepted case; the agent's image inspection is not approval.
- **UNKNOWN (remaining coverage):** TECH HUNT Secure/Extract/Results, high-load/damage/reward states, motion-sequence approval, and device variants remain incomplete. No physical Android capture, native visual/animation approval, touch/FPS/thermal/lifecycle/save/soak result, or Android baseline exists.

## Phase 0 development-loop tooling checkpoint — 2026-10-27

This is a source/tooling-only checkpoint. It does not replace the runtime payload identities or CI evidence below.

- **IMPLEMENTED (native visual tooling):** `scripts/android_visual.sh shot` captures a validated native PNG; `record` adds timed MP4 and before/after PNGs. Both write `run.json` and `report.md` with device/package/display/source context and artifact hashes. Reports keep human visual review **PENDING** and performance evidence **NO**. The tool does not build/install, clear data, or pretend that checkout identity proves the installed build.
- **IMPLEMENTED (workflow guidance):** [`runbooks/ANDROID.md`](runbooks/ANDROID.md) now distinguishes Godot One-click Deploy/Remote Debug/Small Deploy/scene-script synchronization, native visual capture, and the existing offline USB/profiling path. Visual recording and FPS capture are explicitly separate runs. Remote editor synchronization has not been executed in this environment.
- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 3 skipped steps**: 90 tooling tests, 18/18 canonical documents with 148 relative links, an 87-script static-call scan, architecture/module-map checks, and a 35-test smoke inventory. The skips were gdtoolkit, the machine-local export preset, and the Godot binary; no GDScript parse/lint or engine pass is claimed from this run.
- **VERIFIED (fake ADB/static fixtures):** the 90-test total includes eight visual-capture contracts for valid PNG/video artifact layout, pending-review metadata, unauthorized/ambiguous device handling, corrupt PNG rejection, recording failure, evidence overwrite protection, and Android's 180-second recording limit. Synthetic PNG/MP4/ADB results prove tooling control flow only.
- **VERIFIED (preview guidance/static HTTP):** user-facing export/CI instructions now use `tools/serve_preview.py`; cache-contract tests still cover strong ETags, 304, changed-content invalidation, and keep-alive behavior. The runbook explicitly states that changed monolithic PCK bytes download again and that no automatic source watcher/browser reload exists. No new real-browser warm-cache measurement was performed.
- **UNKNOWN (physical device and human review):** no Android Remote Debug session, native screenshot/video, installation, visual/animation approval, touch result, FPS, thermal, save, lifecycle, or soak result has been obtained. No gameplay/runtime source or committed Web/Android payload changed for this tooling checkpoint.

## Current Android profiling and packaging checkpoint — 2026-10-27

| Item | Checkpoint |
|---|---|
| Source validated by Godot/Web and Android CI | `d2eb9f70fa5b66be9c6107cda74577fa3e186556` |
| Godot/Web CI | [40488126429](https://github.com/xam-eth/Cyber-Strike/actions/runs/40488126429) — **SUCCESS** |
| Android debug APK CI | [40488126366](https://github.com/xam-eth/Cyber-Strike/actions/runs/40488126366) — **SUCCESS** |
| Committed Web payload after that gate | `41ccd8e51d8ee8cfaaa191480ad991f796131a60` |
| Documentation update | Separate source-only change; it adds no new runtime claim |

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 87 GDScript files parsed/linted/formatted, 81 tooling tests, 18/18 canonical documents, architecture boundaries, generated module map, and a 35-test inventory. The local Godot binary and machine-local export preset remained skipped.
- **VERIFIED (CI engine/browser):** Godot 4.7.2 passed **35/35 smoke tests**, including profiler window/lifecycle coverage and the existing Recovery/Defense regressions. Web export, 965-file payload audit, static delivery, and the registered browser/loading/theatre/audio gates passed in the same Godot CI run. The resulting `web/index.pck` is 90,682,980 bytes with SHA-256 `bfd82c279b38fcf2f6c2a644527003815f36da1a409b876728437d683711c70d`.
- **VERIFIED (CI Android packaging):** JDK/SDK setup, generated preset, required ETC2/ASTC import, **35/35 smoke tests**, arm64 debug APK export, Godot 4.7 sparse-bundle directory/asset-size audit, forbidden-content audit, and profiler-presence check passed. Artifact `android-debug-apk` was uploaded to the Android run. This proves packaging, not installation or device runtime.
- **IMPLEMENTED (device harness):** `scripts/android_usb.sh --profile-seconds N` records raw logcat, five-second FPS/frame-time windows with gameplay context, APK/device metadata, gfxinfo, memory, thermal, and battery evidence, then generates Markdown/CSV/JSON reports. The parser preserves window percentiles and reports weighted FPS/worst-window values rather than inventing an exact whole-run percentile.
- **UNKNOWN (physical device):** no USB installation, actual Android FPS/frame-time measurement, touch ergonomics, native-resolution behavior, thermal/throttling, battery, audiovisual quality, save preservation, or soak result has been obtained. Debug/profile output is diagnostic and is not final uninstrumented-release certification.

Earlier failed Android setup attempts (runner packages, a floating-point test fixture, missing ETC2/ASTC, and the old monolithic-PCK audit assumption) are superseded by the final successful runs above; they are not current product failures.

## 1. TECH HUNT 0 full product baseline

| Item | Checkpoint |
|---|---|
| Source validated by full CI | `b3c907e4fe5ef09db7482ecd45506259e6a4a687` |
| Full CI run | [40472922173](https://github.com/xam-eth/Cyber-Strike/actions/runs/40472922173) — **SUCCESS** |
| Committed Web payload after that gate | `adcf89e580c53d09a43a64a07438e7538b517cec` |
| Evidence date | 2026-10-27 |
| Documentation consolidation | Separate source-only change; it does not revalidate gameplay or create a new runtime checkpoint |

### TECH HUNT 0 source gate — 2026-10-27

For the Verdant Recovery implementation and its integration repairs:

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 86 GDScript files parsed/linted/formatted, 64 tooling tests, 18/18 canonical documents, 142 relative links, 86-script static-call scan, architecture boundaries, generated module map, and a 34-test inventory including `recovery_smoke.gd`.
- **VERIFIED (CI engine):** Godot `4.7.2.stable.official.ed1daf0bf` imported the project and passed **34/34 smoke tests** in [40472922173](https://github.com/xam-eth/Cyber-Strike/actions/runs/40472922173). The strict runner now fails on engine script errors even if Godot exits 0; its annotations contain no script-error failure. Recovery coverage includes real guard elimination, blocked/duplicate Secure, death/retry/reload, Endless coexistence, Extract, and exactly-once banking.
- **VERIFIED (CI deployment/traversal):** the repaired fixture completed all four authored deployment walks. Verdant settled at its authored spawn and reached `z=28.09344` with `on_floor=true`; this is automated collision/traversal evidence, not a human mission playthrough.
- **VERIFIED (CI export/browser):** Web export, 963-file PCK audit, all five Worlds plus dynamic Character/Recovery visuals, static delivery, four root/direct Chromium boots, opening/interrupted-download recovery, Vanguard selection, and Titans selection/audio steps passed in the same run.
- **VERIFIED (local static):** English and Indonesian catalogs each contain 246 keys with aligned placeholders; the cache GLB hash and provenance are recorded beside the asset.
- **SKIPPED locally:** machine-local export preset and Godot binary/runtime. CI supplies the engine/browser evidence above; it is not Android, physical-device, subjective visual/audio, human-comprehension, or retention evidence.

### Documentation consolidation gate — 2026-10-26

For the canonical-documentation/tooling consolidation itself:

- **VERIFIED (local static):** `tools/check_docs.py` accepts all 17 canonical Markdown files and their relative links, with root-guide and single module-map marker rules enforced.
- **VERIFIED (local static):** `./scripts/dev_check.sh` reports **0 failed steps**, including 56 tooling tests, static project doctor, 76-script static-call scan, architecture boundaries, generated module map, and the 28-test inventory.
- **SKIPPED locally:** gdtoolkit, machine-local export preset, and Godot binary/runtime. No new Godot, browser, Android, human, or device result is claimed for this consolidation.

### Content-module import integration — 2026-10-26

For the dynamic World/Character visual-load and package-intake change:

- **VERIFIED (local static):** `./scripts/dev_check.sh` completed with **0 failed steps and 2 skipped steps**: 77 GDScript files parsed/linted/formatted, 64 tooling tests, 18/18 canonical documents, 141 relative links, 77-script static-call scan, architecture boundaries, package validation, generated module map, and 29-test inventory.
- **VERIFIED (local static):** importer tests cover self-contained GLTF dependencies, script/cache rejection, traversal/symlinks, deterministic bundle hashes, failed-stage preservation of active content, and committed-package checks.
- **VERIFIED (CI engine):** Godot `4.7.2.stable.official.ed1daf0bf` imported the project and passed **29/29 smoke tests**, including `module_isolation_smoke` and the existing domain regressions. The preceding `2683d60` run failed only because its new enemy fixture used `VisualRoot` instead of `Visuals`; `957858c` corrected that fixture and was fully rerun.
- **VERIFIED (CI export/browser):** Web export, 793-file PCK audit, all five World assets plus dynamic hero/held-weapon/enemy visuals, static delivery, Chromium smoke, opening/interrupted-download recovery, Vanguard shell selection, and Titans selection/audio steps passed in [40339588322](https://github.com/xam-eth/Cyber-Strike/actions/runs/40339588322).
- **SKIPPED locally:** machine-local export preset and Godot binary/runtime. CI supplies the engine/browser evidence above; it is not a local Godot run and not Android, physical-device, subjective visual/audio, or retention evidence.

Older failed/partial gameplay, integration, loading, and World reports describe their own historical commits. They must not be used to override the full checkpoint above or to describe a later branch without a new run.

## 2. Automated evidence at that checkpoint

| Gate | Result | Evidence level and boundary |
|---|---|---|
| Static source/tooling | **VERIFIED PASS in CI** | Static only; not runtime or human experience |
| Godot import + smoke suite | **VERIFIED 34/34 PASS in CI** | Headless Godot 4.7.2; includes Recovery and real World/Character/UI fixtures; strict script-error gate; not rendered/device proof |
| Web export and payload audit | **VERIFIED PASS in CI** | Export/content checks; not Android packaging |
| Root/raw browser boot | **VERIFIED PASS in CI** | Automated Chromium/WebGL at configured viewports |
| Initial opening preload and interrupted recovery | **VERIFIED PASS in CI** | Tested Web paths/network controls; not every proxy/network condition |
| Theatre selection/DEPLOY | **VERIFIED for automated Vanguard and Titans selection/build paths in this CI run** | Browser gestures and runtime logs; Frostline/Verdant/Emberfall were not given a new interactive pass in this run |
| Rebuilt-world traversal | **VERIFIED: four authored deployment walks passed in this CI run** | Verdant reached `z=28.09344`, `on_floor=true`; automated route/collision evidence, not human navigation or mission completion |
| Frostline tour | **HISTORICAL: 8/8 distinct captured frames** | Earlier automated captures; not a new visual capture or final aesthetic acceptance for this change |
| Shell/gameplay audio gates | **VERIFIED for automated signal/state checks** | Does not establish human audibility or speaker/headphone quality |

### Published payload identity

| Asset | Bytes | SHA-256 |
|---|---:|---|
| `web/index.pck` | 90,676,528 | `b5c88eaa7450d45497c625190864d20c2244c79900506d09757d7b7662c21c71` |
| `web/index.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |

These hashes identify the payload commit above. Recompute them after any later export rather than carrying the numbers forward.

### Earlier cache/delivery evidence

These warm-cache measurements belong to the earlier `15e594f` payload and were not re-measured for `afc7b8f`. The current run independently passed its opening single-download and interrupted-recovery gates.

- Cold requests returned full successful responses.
- Warm unchanged WASM/PCK requests returned **304 with zero response body** using strong content ETags.
- The real Chromium warm-reload harness transferred **220 + 220 bytes** for those revalidations rather than downloading the full assets again.
- This supports the unchanged-asset Web caching contract for the tested server/browser path. It is not a universal CDN/proxy guarantee.

## 3. Gameplay evidence interpretation

The current checkpoint verifies the implemented Verdant Seed Vault Recovery contract at the automated Godot integration boundary: real Main/Profile/Wave/HUD objects cover blocked Secure, guard elimination, permanent Arc blueprint eligibility, optional cache BP, death/retry/reload, Endless coexistence, Extract, and exactly-once banking. Existing safe Explore, Defense, theatre deployments, and the Web shell also passed their registered regressions.

This does **not** mean every presentation or human outcome is proven:

- the browser gates prove boot, preload/recovery, selection, and safe gameplay, but are not a complete interactive Recovery secure/extract playthrough;
- cache-model appearance, interaction readability, combat feel, and audiovisual quality still need rendered human review;
- human understanding of the mission and optional risk remains **UNKNOWN**;
- human mastery/enjoyment of locked-shot dodge/punish remains **UNKNOWN**;
- long-run Endless decision quality and post-cap balance remain **UNKNOWN**;
- retention or engagement improvement remains **UNKNOWN**.

A selected design, a resource file, a UI card, a headless transaction, or a passing static check must not be reported as completion of those human or device outcomes.

## 4. Explicitly unverified at the full checkpoint

- Android APK/runtime on a physical device.
- Physical touch ergonomics and device-specific input behavior.
- Representative mobile frame time, thermals, memory, and battery behavior.
- Final visual, animation, and auditory acceptance by a human on target hardware.
- Every real-world network/proxy/interruption condition.
- Full human Endless Survival playthrough and long-term stability.
- Player retention, engagement improvement, or market-level appeal.

Use [`runbooks/ANDROID.md`](runbooks/ANDROID.md), [`runbooks/WEB_PREVIEW.md`](runbooks/WEB_PREVIEW.md), and the human gates in `GAMEPLAY_DESIGN.md` for the appropriate follow-up.

## 5. Recording new evidence

Replace or extend the current checkpoint only with executed results. Do not stack contradictory addenda.

Record:

```text
Date and exact source/payload commit:
Task/scope:
Environment (static / Godot / Chromium / interactive / physical device):
Commands or CI run:
Pass/fail/skip counts and named failures:
Artifacts or reports:
What the result proves:
What remains unverified:
```

Rules:

- A skipped check is **SKIPPED**, not passed.
- A harness error is not automatically a product failure; diagnose and label it.
- An aggregate suite result does not identify an individual test unless the log does.
- Browser software rendering is not physical-device performance evidence.
- A screenshot needs the correct stage/gameplay state and must not be blank or unrelated.
- Payload sizes/hashes, test counts, and world counts are checkpoint data, not timeless constants.
- Human playtest observations include setup and sample; do not generalize them to retention without suitable evidence.
