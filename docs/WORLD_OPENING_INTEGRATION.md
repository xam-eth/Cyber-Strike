# World Design + initial-opening preload integration

Date: 2026-10-25
Target branch: `arena/0b0dc2fd-cyber-strike`
World source: `arena/3a7253a1-cyber-strike` at `6a03e6c9c838fc9417de2baa207af36defd82c1b`

## Status

**SOURCE INTEGRATED LOCALLY; NEW-WORLD RUNTIME/PAYLOAD VALIDATION PENDING.**

The previous validated checkpoint remains payload `ad586eb1` from source
`b1528e6c`. Its browser and recovery results are historical evidence for that
payload only. They are not evidence for the three new mission worlds.

## Source and merge audit

- Natural merge base: `2bd09b05cd665aa5ac8d877461aa1208d2115aae`. An empty
  merge-base was first caused by shallow grafts, not unrelated repositories;
  deepening the World fetch exposed the ancestry. `--allow-unrelated-histories`
  was not used.
- Validated target before this merge: `8b42deee07a0051f642520dbf1f79b59cb571055`.
- World source contains the three-GLB `MissionWorld` implementation and retains
  `VanguardStation`. Its tip CI `40154542201` passed static and 28/28 headless
  Godot tests but failed the Web payload commit after Godot extracted untracked
  JPG textures beside the new forge GLBs. That is not accepted as Web evidence.
- The source's large `.claude/skills` installation and unrelated UI/gameplay
  changes are excluded. World-owned runtime, scenes, registry definitions,
  licensed source assets, forge tooling/provenance, design documents, card art,
  and World smoke tests are included.

The merge is deliberately selective rather than an ours/theirs overwrite of the
whole tree. Combat, player/enemy/weapon implementations, run lifecycle,
optimized Character content, the approved painted shell, direct selected-world
DEPLOY, and the previous loader rejection repair remain owned by their existing
modules.

## Contract classification

### Shared World/registry contract

`WorldDefinition` now exposes, in order:

1. `frostline_relay` (default),
2. `verdant_bloom`,
3. `emberfall_foundry`,
4. `vanguard_station`.

The three mission definitions share `mission_world.tscn`; `mission_world.gd`
selects the corresponding GLB. `main.tscn` retains the current gameplay nodes
and replaces only the old `NeonFrontier` world node with `MissionWorld` beside
`VanguardStation`. The old Neon registry entry, scene, script, test, forge
output, and unreferenced card art are retired with the source design. Vanguard
is not deleted.

The shell carousel presents those same four IDs. A saved unknown/Neon shell
preference is migrated to Frostline so the selected card, URL handoff, and
`ProgressionService` agree. `FrontEnd` and `ProgressionService` remain the
authoritative validators; the shell cannot invent a world or unlock a weapon.

### Technical integration

The root opening now uses Godot's official Web API in two phases:

```text
opening:  new Engine(config) -> init(executable) + preloadFile(mainPack)
DEPLOY:   engine.start({ args: ["--main-pack", mainPack] })
```

`init()` initializes WASM and `preloadFile()` downloads the PCK that contains
all four theatres. Neither starts gameplay. MASUK is enabled only after both
Promises resolve. DEPLOY later calls `start()` with the same main-pack argument;
it intentionally does not call `startGame()`, whose implementation would issue
another `preloadFile()` for the PCK.

Both opening and launch rails read the same aggregate WASM+PCK callback and the
exported `fileSizes` total. No timer-based percentage, per-file accumulation,
separate world manager, hidden gameplay scene, or duplicate fetch is used.
This is a **download/preinitialization** contract. It is not a claim that every
GLB is instantiated or GPU-warmed during the HTML opening.

Failures expose **Coba lagi** at the actual opening/launch failure surface and
keep the canvas hidden. A direct DEPLOY deep link retains `qa_world` and
`weapon`, so retry/reload returns to that selected gameplay. The existing
post-export `web_loader_patch.py` remains necessary for WASM initialization
rejections.

### Test integration

`tools/web_loading_qa.mjs` now has two independent gates:

- **Opening contract:** cache disabled; one WASM and one PCK request; aggregate
  bytes complete before MASUK; no gameplay/`engine.start()` behind the opening;
  DEPLOY starts once with the preloaded pack and emits no second PCK request;
  authoritative selection and safe Explore are required.
- **Interrupted recovery:** each large asset is aborted on a direct selected-
  world DEPLOY; readable retry and a hidden canvas are required; reload must
  reach the same world's real gameplay with one fresh download per asset.

The existing strict Vanguard shell gate remains. `mission_world_smoke.gd`
replaces the retired Neon smoke test and covers all three mission GLBs.

## Evidence so far — baseline only

These local automated Chromium runs used the **old** payload and Vanguard,
which exists in both registries. They isolate and verify the new opening API
and retry behavior before the new World export exists:

- `exports/integration-audit/opening-api-baseline-vanguard.json` — direct
  selected-Vanguard gameplay PASS.
- `exports/integration-audit/opening-contract-baseline-vanguard/report.json` —
  one WASM + one PCK, preload-before-start, no `startGame`, direct gameplay PASS.
- `exports/integration-audit/opening-recovery-baseline-vanguard/report.json` —
  opening contract plus interrupted WASM and PCK recovery PASS.
- `exports/integration-audit/world-source-static.log` — static development
  checks PASS; local Godot and local preset checks skipped.

These results do **not** verify Frostline, Verdant, Emberfall, the merged 28
Godot tests, the new PCK, or its final byte total. Those require the CI export
and subsequent new-payload browser gates.

## Required final validation

1. CI static checks and all 28 Godot tests on the merged source.
2. Web export and payload commit with no untracked imported-texture failure.
3. New-payload audit, four normal browser boots, strict Vanguard, and the
   opening + WASM/PCK recovery gate at 100 Mbps.
4. Explicit browser selection/build checks for Frostline, Verdant, and Emberfall.
5. Record final PCK/WASM sizes and update `README.md`, `WEB_PREVIEW.md`,
   `docs/WEB_LOADING_RECOVERY.md`, and `docs/INTEGRATION_VALIDATION_REPORT.md`.

Android, physical touch/device performance, full human gameplay, final visual
acceptance, and every real-world network/proxy failure remain unverified unless
separately tested.
