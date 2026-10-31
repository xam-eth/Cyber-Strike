# Integrated vertical slice — baseline and implementation contract

**Date:** 2026-10-31
**Baseline:** `5453420a39b186188bdee262878718eceb2e4b4b`
**Scope:** Website / Godot only. APK and native packaging remain paused.

This document separates the inspected baseline from the implemented run-adaptation
addition and its later execution evidence. It is not a claim that every screen or
device has received human approval.

## 1. Baseline audit before implementation

The original checkout at `/home/user/Cyber-Strike` is an older dirty worktree with
concurrent work. It was inspected read-only and was not reset, cleaned, pulled, or
used as the edit target. This audit and implementation use a separate partial
checkout of the current session branch. No screenshots were treated as evidence
of source behavior.

### Engine, rendering, and scene ownership

- **Godot:** `game/project.godot` targets the Godot 4.7 feature line; CI job
  `40841684190` executed its headless suite with **Godot 4.7.2**.
- **Rendering:** native defaults to `mobile`; Web explicitly uses
  `gl_compatibility` / WebGL 2. The design viewport is 1280×720 with
  `canvas_items` stretching and `expand` aspect behavior.
- **Entry:** the raw engine starts at `scenes/ui/front_end.tscn`. The player-facing
  Website also has an HTML shell in `index.html` / `ui/shell.js`; it defers engine
  startup until Deploy.
- **Gameplay composition:** `scenes/main.tscn` owns the selected mission world,
  player, training drone, WaveDirector, RunStats, RewardService,
  ProgressionService, and HUD. Recovery is orchestrated by `main.gd`; persistent
  rewards remain in ProgressionService and encounter ownership remains in
  WaveDirector.

### System status

`VERIFIED WORKING` below means the named supported path was exercised by the
current baseline's headless/browser automation, not merely found in source.
CI `40841684190` passed static checks, all 37 discovered smoke scripts, Web export,
browser smoke/secure-context/download/shell/Titans/ADS checks, and the Recovery
engagement gate. It does not establish physical-device performance or human
approval.

| System | Status | Inspected evidence and limits |
| --- | --- | --- |
| Boot and loading | VERIFIED WORKING | Front-end smoke walks BOOT → LOADING and checks resource-backed progress; the Web shell performs readiness checks. No fake percentage was found in the Godot loading stages. |
| Command hub and navigation | VERIFIED WORKING | The supported HTML path is opening → theatre hub → Deploy; the raw-engine path is BOOT → LOADING → CHAPTER (first launch) → DASHBOARD → HERO → WORLD → PRELOAD. DashboardReturn owns the route home. |
| Operative presentation and tiers | PARTIALLY WORKING | SABLE and five roster-defined tiers share `roster.json`; tier vitals/reduction are applied by PlayerController. KESTREL is explicitly in development and disabled. No additional hero-stat system is authorized. |
| Weapon selection and permanent upgrades | VERIFIED WORKING | Pulse/Nova/Arc retain stable ids. Ownership, BP costs, blueprint eligibility, tier multipliers, effective runtime definitions, and save/reload behavior have smoke coverage. ADS has browser mouse/touch gates. |
| Mission and map selection | PARTIALLY WORKING | Five field-ready theatre definitions resolve through one selection service and shared mission composition. Only Verdant Bloom currently authors the reviewed Recovery objective; the other theatres are not claimed to have unique mission chains. |
| Player controller and combat | VERIFIED WORKING | Movement, camera/ADS, real projectiles, ammo/reload, damage, defeat, EMP, touch look/fire, and weapon switching are implemented and covered by current automation. Human feel and device frame rate remain unverified. |
| Enemies and escalation | VERIFIED WORKING | Runner chases and melee-attacks; Shooter maintains standoff, telegraphs ranged attacks, and searches around cover. WaveDirector escalates count/mix. Both gameplay guards in the primary Recovery are real Runner/Shooter actors. |
| Enemy visual assets | VERIFIED WORKING | EnemyVisual fits real GLB models and hides its fallback only after a measurable model attaches; enemy visual smoke and browser Recovery exercise this path. Any future fallback warning must still be treated as a visual failure, not ignored. |
| Existing ability | VERIFIED WORKING | EMP applies real area damage, has a cooldown, and produces a ground pulse plus HUD feedback. No additional ability is being advertised. |
| Run rewards | VERIFIED WORKING | RunStats holds provisional score/BP/KOs/time; RewardService has duplicate guards; Main banks once at Results. Recovery cache rewards use separate permanent exactly-once transactions. |
| Persistent progression | VERIFIED WORKING | One ConfigFile profile owns BP, best score, completed runs, weapon ownership/tiers, secured caches, blueprints, intro state, and selected loadout. Operative tiers derive from completed runs. |
| HUD and mobile controls | VERIFIED WORKING | Objective, vitals, crosshair, weapon/ammo, reload, EMP, ADS, fire, movement, pause, Armory, Recovery, Results, and home controls are wired. Automated layout/input checks are not physical-device validation. |
| Audio and combat VFX | PARTIALLY WORKING | Runtime audio, muzzle/impact/projectile effects, hit/defeat feedback, and music modes exist and browser audio preflight passes. Authored final audio and human audibility are not verified. |
| Mission success/failure and results | VERIFIED WORKING | Guard clear → Secure → Extract/Continue is explicit; defeat and voluntary run finish reach Results; repeated reward/result transitions are guarded. |
| Temporary run upgrades | **NOT IMPLEMENTED** | Permanent Armory tiers are not temporary upgrades. The baseline vertical-slice test explicitly records that no milestone-choice system exists. |
| Boss encounter | **NOT IMPLEMENTED** | No boss is promised by this slice. The guarded Seed Vault Recovery is the existing major objective and will remain so. |
| Cosmetic progression | **NOT IMPLEMENTED** | No cosmetic economy or combat-power implication will be added. Existing operative tier presentation remains roster-backed. |
| Separate account/meta economy | **NOT IMPLEMENTED** | BP, run records, unlocks, and operative tiers are the smallest existing permanent set. No new currency is justified for this slice. |

### Smallest viable baseline mission path

**VERIFIED WORKING for the supported Verdant path:**

launch → hub → choose Verdant Bloom → Deploy with saved operative/weapon →
Explore → Engage one Runner and one Shooter at the Seed Vault → clear both →
Secure → receive permanent Arc blueprint eligibility → Extract to Results or
Continue to Endless Survival → bank run results once → return home → persistent
profile remains available on the next deployment.

The missing **COLLECT → CHOOSE → EVOLVE** run-adaptation stage is the focused gap.
The implementation below does not replace the already connected mission, armory,
operative, ADS, world, or reward systems.

## 2. Integrated design contract

### Loop and ownership

**EXPLORE** the existing Verdant world
→ **ENGAGE** the existing Runner + Shooter guard group
→ **COLLECT** one field-adaptation offer earned by that real guard clear
→ **CHOOSE** one of two compatible upgrade cards
→ **EVOLVE** the current run through an actual effective weapon modifier
→ **COMPLETE OBJECTIVE** with the existing explicit Seed Vault Secure
→ **EARN PERMANENT REWARD** through the existing Arc blueprint transaction
→ **CONTINUE** into Endless with the adaptation, or **EXTRACT** to actual Results
→ **DEVELOP PERMANENT PROGRESSION** through existing BP, tiers, and unlocks
→ **RETURN / REDEPLOY**, where permanent state remains and adaptation resets.

No BP is granted merely for opening the adaptation panel. The offer is the combat
reward for clearing the primary guards; ordinary KO/wave BP rules are unchanged.

### Two run-only choices, not a new economy

| Upgrade | Actual run effect | Compatibility | Scope |
| --- | --- | --- | --- |
| OVERCHARGE | Direct and splash weapon damage ×1.25 | Pulse, Nova, Arc | Current deployment only |
| QUICK CYCLE | Reload duration ×0.80 | Pulse, Nova, Arc | Current deployment only |

The multipliers compose with, and remain visually distinct from, permanent weapon
tiers. Base WeaponDefinition resources stay immutable. A selection is exactly
once per deployment, cannot field an unknown/incompatible id, and is never written
to `progression.cfg`.

### Explicit state transition

`EXPLORE/PREPARING/DEFENSE` → **UPGRADE_SELECTION** → prior play mode.

The primary guard-clear event is the only vertical-slice offer trigger. The tree
pauses while the modal owns input. A valid card selection applies the modifier,
closes the modal, restores the prior play mode, and exposes the already-earned
Secure action. Optional caches do not farm extra offers. Death before the guard
clear earns nothing. Continue preserves the adaptation; retry, return to Explore,
hub return, and redeploy clear it.

### UI component and feedback contract

- Reusable upgrade cards display identity, exact effect, weapon compatibility,
  run scope, disabled/pressed/focus state, and selected state.
- The modal uses the existing dark plates, amber primary/selected treatment,
  cyan supporting information, square/cut corners, existing type tokens, and
  physical touch-target floors.
- Gameplay controls cannot remain active behind the modal.
- Immediate feedback names the installed effect; Pause and Results retain an
  explicit **RUN ONLY** line so the effect is not confused with permanent tiers.
- Results continue to show only actual BP, blueprint, score, and profile values.

## 3. Implementation and validation register

### Source integration after the baseline

**IMPLEMENTED IN SOURCE; RUNTIME UNVERIFIED:** `RunUpgradeService` owns the
exactly-once temporary offer/selection. Two resource-backed definitions feed a
reusable modal card group in the existing HUD. Main grants the offer only after
the real primary guard group clears, applies the validated modifier through
WeaponController, restores the interrupted play mode, and reports the selection
in Pause/Extraction/Results. Continue retains it; run/player reset removes it.
Permanent profile, blueprint, BP, unlock, and weapon-tier APIs were not replaced.

### Executed local static evidence

- **VERIFIED — static:** all 92 game GDScript files pass `gdparse`, `gdlint`, and
  `gdformat --check`; the three changed smoke scripts also pass those checks.
- **VERIFIED — static:** localization has 274 EN and 274 ID keys with aligned
  placeholders and no copied values. The checker now recognizes the `upgrade`
  namespace and data-driven `.tres` key references.
- **VERIFIED — static:** architecture boundaries, static calls, diff whitespace,
  smoke inventory (38 scripts), and the generated module map pass.
- **ENVIRONMENT LIMITED, NOT A SOURCE PASS:** the complete local development gate
  cannot pass in this sparse code-only checkout. Excluded audio/icons/models and
  generated manifests cause its asset/tooling/documentation groups to fail;
  Godot and Web payloads are absent. The full local tooling run discovered 97
  tests, with only the missing-audio error and missing-icon assertion plus one
  existing skip. These limitations are not silently counted as successful tests.

### Runtime and visual evidence still required

- **UNVERIFIED:** new upgrade resources/service and modifier composition.
- **UNVERIFIED:** selection, duplicate-selection refusal, pause/resume, and reset.
- **UNVERIFIED:** real projectile damage and reload behavior after selection.
- **UNVERIFIED:** Recovery → upgrade → Secure → Extract/Endless regression path.
- **UNVERIFIED:** persistent blueprint/BP/tier behavior after returning home.
- **UNVERIFIED:** exported Website screenshots, touch targets, clipping, and EN/ID
  presentation at desktop and small-landscape sizes.
- **UNKNOWN:** physical-device controls, audible output, GPU frame rate, and human
  playtest/balance approval; no local Godot executable is available in this
  sandbox, so engine execution must come from CI or a subsequently available
  runtime.
