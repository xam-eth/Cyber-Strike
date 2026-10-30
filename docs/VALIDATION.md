# Validation Status

This document records the latest relevant evidence and its limits. It is not a design specification, a chronological collection of old reports, or proof that every current branch change has been validated.

For intended behavior, read [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md). For required gates, read [`DEVELOPMENT.md`](DEVELOPMENT.md).

## Track 1 — TECH HUNT end-to-end expedition, lost-player guidance, and progression checkpoint — 2026-10-30

| Item | Current checkpoint |
|---|---|
| Runtime, UI/UX, and E2E QA source | `390491f286f13de6f0d153e81a22a2576996b12f` |
| Godot/Web CI | [40986603110](https://github.com/xam-eth/Cyber-Strike/actions/runs/40986603110) — **SUCCESS** (`Static checks`, `Headless smoke tests 38/38`, `Web preview build` including Step 20 `--recovery-e2e`) |
| Committed Web payload | `dd7aa81` |
| `web/index.pck` | 90,765,404 bytes; SHA-256 `38d1419656c751dbde6997e11586373cd775f22ee828359b8487057f303f9dc0` |
| `web/index.wasm` | 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| Desktop `1280×720` E2E evidence | [`../qa-evidence/tech-hunt/recovery-e2e-1280x720.json`](../qa-evidence/tech-hunt/recovery-e2e-1280x720.json) (12 runtime captures) |
| Mobile `844×390` Recovery evidence | [`../qa-evidence/tech-hunt/recovery-mobile-844x390.json`](../qa-evidence/tech-hunt/recovery-mobile-844x390.json) (5 runtime captures) |

### What this checkpoint verifies

- **VERIFIED (Automated Chromium TECH HUNT E2E — `Verdant clear → Arc Blueprint secure → Extract → Tier-2 → 106-vital redeploy`):**
  - Executed both in CI ([40986603110](https://github.com/xam-eth/Cyber-Strike/actions/runs/40986603110), Step 20) and locally against payload `dd7aa81` (`node tools/web_qa.mjs --recovery-e2e --viewport 1280x720`) with **0 failed checks and 0 page/script errors**:
    1. **Tier 1 landing & relative guidance:** Deployed Sable at `VITALS 100 / 100` (`tier=1/1 reduction=0%`) in Verdant Bloom with immediate relative objective readout (`RECOVER · SEED VAULT / ARC SHOOTER BLUEPRINT · APPROACH · AHEAD 9M`) — [`root-1280x720-recovery-landing.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-landing.png).
    2. **Real guard engagement & clear:** Triggered `ENGAGE GUARDS [B]` ([`root-1280x720-recovery-engage-offer.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-engage-offer.png)), verified `SECURE LOCKED` with active guard bearing (`HOSTILE · AHEAD` / `LEFT`) across `Guard_verdant_seed_vault_01` and `Guard_verdant_seed_vault_02` ([`root-1280x720-recovery-guarded.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-guarded.png), [`root-1280x720-recovery-contact.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-contact.png)), and eliminated both guards through real projectile/ADS combat (`guards=0`).
    3. **Explicit Secure & unclipped Mission Complete breakdown:** Approached the Seed Vault (`SECURE CACHE [B]`, [`root-1280x720-recovery-ready-to-secure.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-ready-to-secure.png)), secured the `arc_shooter` blueprint, and verified the unclipped `RECOVERY COMPLETE` card showing `ARC SHOOTER BLUEPRINT SECURED`, `NEW ARMORY ELIGIBILITY · ARC SHOOTER`, `ARMORY UNLOCK COST · 250 BP`, and `EXTRACT BANKS RUN #1 · UNLOCKS TIER 2 (106 HP · 3% ARMOR)` ([`root-1280x720-recovery-mission-complete.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-mission-complete.png)).
    4. **Exact-once Extract & persistent IndexedDB/localStorage handoff:** Selected `EXTRACT` (`completed_runs: 0 → 1`), verified the unclipped `EXTRACTION COMPLETE` breakdown separating kept permanent progress (`SECURED · ARC SHOOTER BLUEPRINT`, `PROMOTED · SABLE TIER 2 READY (106 HP · 3% ARMOR)`) from cleared temporary field state (`RESET · FIELD ENEMIES & TEMP RUN STATE CLEARED`) and next-step guidance (`NEXT · HOME > OPERATIVE > TIER 2 (106 HP) > REDEPLOY`) ([`root-1280x720-recovery-results-extracted.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-results-extracted.png)), then returned via `HOME` after clean `Sfx.shutdown()` + Emscripten `IDBFS` `/userfs` flush (`aegis.runs = "1"`, `arc_shooter` blueprint saved, `verdant_seed_vault` secured) ([`root-1280x720-recovery-hub-tier2-ready.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-hub-tier2-ready.png)).
    5. **Tier 2 Plated selection, Arc Shooter rack eligibility, & 106-vital redeploy:** Opened `OPERATIVE`, selected newly unlocked `T2 PLATED` (`hero_human_tier_2.glb`, `VITALS 106 +6 HP`, `ARMOUR 3% blocked`, `1 / 3 RUNS TO TIER 3`) ([`root-1280x720-recovery-operative-tier2.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-operative-tier2.png)), verified `ARC SHOOTER` transitioned from `BLUEPRINT` to `250 BP` in the weapon rack ([`root-1280x720-recovery-rack-arc-eligible.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-rack-arc-eligible.png)), and redeployed into Verdant Bloom at `VITALS 106 / 106` (`Operative: hero=sable tier=2/2 vitals=106 reduction=3%`) with Seed Vault preserved as `SECURED` and HUD guidance automatically retargeting the optional cache (`OPTIONAL · LAB CACHE · PERMANENT +80 BP · LEFT 44M`) ([`root-1280x720-recovery-redeploy-tier2-106hp.png`](../qa-evidence/tech-hunt/root-1280x720-recovery-redeploy-tier2-106hp.png)).
- **VERIFIED (Escalating lost-player guidance & `844×390` mobile layout):**
  - Headless Godot `tests/recovery_smoke.gd` (`38/38` CI smoke suite) verified Area → Local (`AHEAD` / `LEFT` / `RIGHT` / `TURN AROUND` + distance) → Stuck escalation after `14s` without progress (`FOLLOW BEACON`), immediate reset on progress, combat guard tracking, and automatic shift from `verdant_seed_vault` to optional `verdant_crashed_lab` after primary secure.
  - Mobile landscape `844×390` browser verification passed all checks without clipping or touch-cluster overlap ([`root-844x390-recovery-landing.png`](../qa-evidence/tech-hunt/root-844x390-recovery-landing.png), [`root-844x390-recovery-guarded.png`](../qa-evidence/tech-hunt/root-844x390-recovery-guarded.png)).
- **VERIFIED (local static gates):** `./scripts/dev_check.sh` passed with **0 failed steps and 2 expected local skips**: 96/96 GDScript files parsed/linted/formatted, `0 FAIL` in `project_doctor.py`, `19/19` canonical documents, `103` tooling tests, `0` static-call or boundary violations, `327/327` EN/ID localization keys, `123` hero/tier checks, and synchronized `docs/ARCHITECTURE.md` module map.
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
