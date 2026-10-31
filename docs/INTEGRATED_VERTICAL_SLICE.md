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

### Implemented source and exact final payload

**VERIFIED IN SOURCE AND EXECUTED RUNTIME:** `RunUpgradeService` owns the
exactly-once temporary offer/selection. Two resource-backed definitions feed a
reusable modal card group in the existing HUD. Main grants the offer only after
the real primary guard group clears, applies the validated modifier through
WeaponController, restores the interrupted play mode, and reports the selection
in Pause/Extraction/Results. Continue retains it; run/player reset removes it.
Permanent profile, blueprint, BP, unlock, and weapon-tier APIs were not replaced.

The final evidence is tied to an explicit source/payload boundary:

- Armory correction: `673fcec9ca7813dd0a2ca0ed73c9808f6c8826b3`;
- feedback visibility correction: `9c19abaf74d70e1faf275b85043b27a90712cd81`;
- opt-in payload request: `70eb5898634371da40ac0c2b65703cd82f04d9f8`;
- generated payload used for both final browser routes:
  `19852d7447cae0cca1419e98bdd97f9693fbc334`;
- PCK: 90,719,636 bytes, SHA-256
  `11e50265ccc1f479013438203dad2eb35543d1eddd332afc00d7eb2bc6f6a25b`;
- WASM SHA-256:
  `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.

The served PCK/HTML bytes were compared with the generated commit before the
final routes. Payload history remains opt-in; ordinary source/docs changes do not
request another binary refresh.

### Executed static and CI evidence

- **VERIFIED — local static:** the changed GDScript passes `gdformat`/`gdlint`;
  localization has 274 EN and 274 ID keys with aligned placeholders; architecture,
  static-call, module-map, and diff checks pass.
- **VERIFIED — corrected source CI `41212868947`:** Static, all **38/38** discovered
  Headless smoke scripts, Web export, secure-context/audio/download/shell/Titans/
  ADS/Recovery browser gates.
- **VERIFIED — final payload CI `41213150955`:** the same complete gate set passed
  before the opt-in payload commit was generated.
- The settled Armory assertions cover both **844×390** and **667×375**. An
  intermediate 667×375 failure was retained as a failure and corrected by
  wrapping card copy within the cards; the bounds assertion was not weakened.
- **ENVIRONMENT LIMITED, NOT A SOURCE FAILURE:** no local Godot executable is
  installed in the sparse edit checkout. CI Godot 4.7.2 is therefore the engine
  authority; excluded local assets/manifests are not counted as local passes.

### Executed before/after browser evidence

Evidence root:
[`qa-evidence/recovery-adaptation-2026-10-31/`](../qa-evidence/recovery-adaptation-2026-10-31/README.md).
Its `manifest.json` records commits, payload hashes, route scope, and report hashes.

| Route | Exact build | Executed result |
| --- | --- | --- |
| Baseline Recovery | `5453420a39b186188bdee262878718eceb2e4b4b` | **PASS:** ordinary shell, Verdant landing/Engage, two real GLB guards, Secure locked during combat. Five frames are preserved in `baseline/`; this is not represented as the later adaptation route. |
| Final English | `19852d7447cae0cca1419e98bdd97f9693fbc334` | **PASS:** 29 checks and 20 report-listed frames for the complete route below. |
| Final Indonesian, visual-only | same final payload | **PASS:** 23 checks and 11 report-listed frames through Secure and scrolled Extraction. It intentionally does not claim the later EN persistence chain. |

Only green-report frame lists were copied into the evidence directory. All 20 EN
and all 11 ID frames were inspected; older failure captures were excluded.

### Verified gameplay and progression outcome

The final EN driver used the ordinary Website, real keyboard/mouse/wheel input,
and a measured touchscreen tap. It did not inject target health, an upgrade,
a reward, or profile state.

1. Verdant booted through the shell; Engage spawned one Runner and one Shooter,
   and both attached real GLB visuals. Real ADS/projectile combat cleared them
   with the player at 4/100 HP.
2. The guard clear earned the two-card offer. Desktop and phone card/panel
   rectangles were contained and non-overlapping. A real phone tap selected
   **QUICK CYCLE**: Pulse stayed at 18 damage and reload became **1.08 s**
   (1.35 × 0.80), explicitly run only.
3. Secure performed the real `arc_shooter_blueprint` transaction. Continue
   entered actual Endless Defense; Pause and voluntary finish reached Results.
   One `Progression: banked +0 BP · wallet 0 · best 0` occurred. **+0 BP is the
   honest result of a voluntary no-KO Endless finish**, not a placeholder reward.
4. Pause Home reached the real Godot Dashboard, which showed Verdant, Pulse,
   and one completed run. Dashboard → Operative → World → Preload started a
   fresh deployment without another adaptation selection.
5. Armory showed Arc Shooter **UNLOCK 250 BP** at 0 BP after blueprint
   eligibility; Arc was not purchased. Fresh Pause showed 100/100 vitals,
   24/24 ammo, and no adaptation line. Existing duplicate-reward/result guards
   also remain covered by the green Headless suite; the browser route observed
   one bank only.

Defeat/retry is covered by the current Headless gameplay gates. This particular
browser route deliberately uses a voluntary Endless finish and does not claim a
second, scripted death.

### Verified layout and localization evidence

- **1280×720 desktop browser:** hub, gameplay, GLB guards, and the 720×340
  adaptation panel/cards were inspected.
- **844×390 touch phone browser:** adaptation cards, Secure, Extraction,
  Endless, Pause, Results, Armory, and redeploy were inspected.
- **667×375 Godot Headless:** settled Armory panel/footer physical bounds pass;
  this is a geometry assertion, not an additional screenshot claim.
- Real wheel-scrolled `08b`/`11b` EN frames expose **RUN ADAPTATION · QUICK CYCLE
  · EXPIRES ON REDEPLOY** while Extraction/Results decisions remain pinned.
- The previously empty feedback plate is **VERIFIED FIXED**: EN `07` shows
  **QUICK CYCLE · -20% reload time · THIS RUN ONLY**, ID `07` shows the complete
  Indonesian equivalent, and `07b`/`07c` retain its later disappearance. Headless
  also checks non-zero label geometry and a positive visible-line count.
- Armory retains real weapon art, identity, specs, tier/reload, ownership/price,
  and both footer actions inside the phone glass. Owned Pulse retains its real
  tier action; locked weapons do not show a misleading disabled tier purchase.
- Indonesian title, instructions, both upgrade names/effects, compatibility,
  run scope, PASANG, Secure, and scrolled Extraction copy are readable without
  clipping. Localization remains 274/274 keys.

### Remaining limits and incomplete claims

- **UNKNOWN:** physical-device touch feel, audible output, GPU frame rate, and
  human playtest/balance approval. Chromium/software-WebGL automation is not a
  substitute for those checks.
- Only Verdant Bloom has the reviewed Recovery chain. No boss, cosmetic economy,
  separate account currency, additional weapon/hero, or unique Recovery chain
  for another theatre is claimed.
- Website-only delivery is intentional; APK/native packaging remains paused.

### Reproduce

From a self-contained checkout, use the ordinary static server and locked browser
tooling:

```bash
python3 -m http.server 800 --bind 0.0.0.0
npm ci --prefix tools
node tools/qa_recovery_adaptation.mjs --url=http://127.0.0.1:800/ --lang=en
node tools/qa_recovery_adaptation.mjs --url=http://127.0.0.1:800/ --lang=id --visual-only
```

Use a fresh browser profile for each route. The reports and frames produced under
`exports/` are execution output; the curated executed evidence is the directory
linked above, not a design proposal.
