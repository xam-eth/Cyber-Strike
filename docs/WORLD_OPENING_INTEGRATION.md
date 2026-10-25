# World Design + initial-opening preload integration

Date: 2026-10-25
Target branch: `arena/0b0dc2fd-cyber-strike`
World source: `arena/3a7253a1-cyber-strike` at `6a03e6c9c838fc9417de2baa207af36defd82c1b`

## Status

**VERIFIED on the integrated source and committed final payload.**

- World merge: `fdd80f1e4cb8c85802323a610c7f0432189b9d7c`, with parents
  `8b42deee07a0051f642520dbf1f79b59cb571055` and the World tip above.
- Integration repairs: `1d95ba6c4c2a3403720322629549959b42ace03c`.
- Lossless shared-texture staging: `7ec17b0eb52e0199fbeab9435e5e3164e1848fd2`.
- Final generated payload: `0ce9d3b0cca7b6fe95968a5d481a544947152499`.
- Final CI: [40164193789](https://github.com/xam-eth/Cyber-Strike/actions/runs/40164193789)
  — **SUCCESS** for static checks, 28/28 import-OK Godot 4.7.2 tests, export,
  payload audit/delivery, browser boots, opening, recovery, and strict Vanguard.

The older `ad586eb1` results remain historical evidence for the previous UI
checkpoint, not for this World payload.

## Source and merge audit

- Natural merge base: `2bd09b05cd665aa5ac8d877461aa1208d2115aae`. An empty
  merge-base was first caused by shallow grafts, not unrelated repositories;
  deepening the World fetch exposed the ancestry. `--allow-unrelated-histories`
  was not used.
- Validated target before this merge: `8b42deee07a0051f642520dbf1f79b59cb571055`.
- World source contains the three-GLB `MissionWorld` implementation and retains
  `VanguardStation`. Its tip CI `40154542201` passed static and 28/28 headless
  Godot tests but failed the Web payload commit after Godot extracted untracked
  JPG textures beside the new forge GLBs. That was not accepted as Web evidence.
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

### Technical integration: initial opening download

The root opening uses Godot's official Web API in two phases:

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
GLB is instantiated or GPU-warmed during the HTML opening. The selected GLB is
still instantiated only when that theatre enters gameplay.

Failures expose **Coba lagi** at the actual opening/launch failure surface and
keep the canvas hidden. A direct DEPLOY deep link retains `qa_world` and
`weapon`, so retry/reload returns to that selected gameplay. The existing
post-export `web_loader_patch.py` remains necessary for WASM initialization
rejections.

### Technical integration: publishable, lossless texture sharing

The first merged export passed runtime/browser gates but produced a
124,579,772-byte PCK, too large for the repository's plain-clone, non-LFS
publication path. The three GLBs carried 117 embedded image references but only
69 distinct JPEG byte sequences. Godot was importing a separate `.ctex` for each
embedded copy.

`tools/asset-forge/gate/shared_textures.mjs` now stages content-addressed images
in `game/assets/forge/textures/` and gives every GLB relative URIs to those
shared files. This is not texture resizing, recompression, or a visual design
change:

- every ordered image hash remained identical;
- every non-image bufferView hash remained identical;
- all three externalized GLBs passed Khronos validation with zero errors;
- a Node regression test covers URI deduplication and non-image buffer
  preservation;
- the final PCK contains exactly 69 shared texture resources.

The final PCK is **76,767,668 bytes / 873 files**, 47,812,104 bytes smaller than
the first merged candidate. The source asset library remains excluded from the
PCK; only staged runtime resources ship.

### Test integration and repair history

`tools/web_loading_qa.mjs` has two independent gates:

- **Opening contract:** cache disabled; one WASM and one PCK request; aggregate
  bytes complete before MASUK; no gameplay/`engine.start()` behind the opening;
  DEPLOY starts once with the preloaded pack and emits no second PCK request;
  authoritative selection and safe Explore are required.
- **Interrupted recovery:** each large asset is aborted on a direct selected-
  world DEPLOY; readable retry and a hidden canvas are required; reload must
  reach the same world's real gameplay with one fresh download per asset.

The first merged CI `40163018037` exposed two integration fixture/layout
failures. `1d95ba6c` retained the stronger existing tests, moved the cover
fixture from the retired Neon prop to Frostline's real flanking cover, and
bounded the roadmap pin to one line inside its 64 px card. The next CI passed
28/28 tests and all browser gates. Its 124.58 MB payload could not be published,
which motivated the lossless texture-sharing commit above. Neither repair
changed combat orchestration, weapon rules, wave design, or world layout.

## Final evidence

### Static, engine, and payload

- Local `scripts/dev_check.sh`: **0 failed steps, 3 skipped**; local Godot,
  gdtoolkit, and machine-local preset checks remain skipped. The Asset Forge
  shared-texture Node test passes.
- Final CI static checks: **PASS**, including gdtoolkit and the Node test.
- Final CI Godot 4.7.2: **28 passed, 0 failed, import OK**.
- Final PCK: **76,767,668 bytes / 873 files**; WASM: **39,514,754 bytes**.
  Aggregate opening download: **116,282,422 bytes** (116.3 MB, about 110.9 MiB).
- `exports/integration-audit/world-final-payload/report.json`: all four world
  resources present, 69 shared textures, zero retired Neon entries.
- `exports/integration-audit/world-final-payload/verify.json` and `check.json`:
  build verification and payload audit **PASS**, with no forbidden findings.

### Automated Chromium

Final CI passed root and raw-export boots at 844×390 and 667×375, the opening
single-download contract, interrupted WASM/PCK recovery at 100 Mbps, and strict
shell-selected Vanguard gameplay.

Final local opening reports, all **PASS** with one WASM request, one PCK request,
`116282422 / 116282422` completed bytes, no `startGame()`, no second PCK, the
authoritative selected-world build, and safe Explore:

| Theatre | Report |
| --- | --- |
| Frostline Relay | `exports/integration-audit/world-final-opening/frostline_relay/report.json` |
| Verdant Bloom | `exports/integration-audit/world-final-opening/verdant_bloom/report.json` |
| Emberfall Foundry | `exports/integration-audit/world-final-opening/emberfall_foundry/report.json` |
| Vanguard Station | `exports/integration-audit/world-final-opening/vanguard_station/report.json` |

Additional final-payload gates:

- `exports/integration-audit/world-final-vanguard/report.json`: strict shell
  Vanguard selection and direct safe Explore **PASS**.
- `exports/integration-audit/world-final-loading-frostline/report.json`:
  opening plus interrupted WASM and PCK at 100 Mbps **PASS**, including readable
  retry, hidden failed canvas, and reload into selected Frostline gameplay.
- `exports/integration-audit/world-final-ci.json`: final Actions job record.

Earlier baseline-only reports (`opening-contract-baseline-vanguard` and
`opening-recovery-baseline-vanguard`) isolated the new loader API before a World
export existed. They are superseded for final World claims by the reports above.

## Evidence limits

These are static, automated, headless Godot, and headless Chromium/WebGL results.
They do not establish Android packaging/runtime, physical touch/device
performance, thermals or memory, every real-world network/proxy failure, a full
human Endless Survival playthrough, retention improvement, or final visual and
animation acceptance. Those remain open unless separately tested.
