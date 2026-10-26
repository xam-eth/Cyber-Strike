# Development Guide and Plan

This is the canonical guide for turning the selected game direction into verified software. It governs sequence, ownership, workflow, and completion criteria.

- **Gameplay direction and active scope:** [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md)
- **Documentation authority:** [`README.md`](README.md)
- **Code boundaries:** [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **Executed evidence:** [`VALIDATION.md`](VALIDATION.md)
- **Persistent agent reminders:** [`../AGENTS.md`](../AGENTS.md)

## 1. Current starting point

| Area | Current baseline | Next direction |
|---|---|---|
| Product | Mobile-first, single-player third-person sci-fi shooter | TECH HUNT action/adventure-survival prototype |
| Session | Safe Explore, explicit preparation, Defense, Results, retry | Recovery mission → secure tech → Extract or Endless |
| Combat | Pulse/Nova/Arc, Runner/Shooter, EMP, damage and feedback | Prove guarded tech encounters with existing content |
| Progression | Persistent BP wallet, weapon unlock/equip, profile save | Add secured blueprint/milestone semantics without a new currency |
| Endless | Structurally endless waves with capped count/composition | Preserve mode; add meaningful escalation only after measurement |
| Worlds/UI | Five registered theatre definitions, shell selection and direct DEPLOY, initial opening preload | Reuse current registries/adapters; no parallel World or UI navigation flow |
| Validation | Full automated gate recorded at the checkpoint in `VALIDATION.md` | TECH HUNT-specific engine/browser/human/device evidence still needed |

The active prototype is **TECH HUNT 0**. Its inclusion and exclusion lists are normative. Do not substitute the retired arena-only roadmap or old monetization concept.

## 2. Development principles

1. **Prove the loop before expanding content.** One understandable mission and reward are more valuable than five unfinished systems.
2. **Player-facing design leads; source establishes the baseline.** Implement selected scope deliberately, but never describe it as working before checks pass.
3. **Extend existing owners.** No duplicate session, wave, reward, save, damage, upgrade, or mission authority.
4. **Build vertical paths.** A thin path from mission card → guard → secure → save → Results is more useful than isolated mission UI, loot data, and boss art that never connect.
5. **Keep transactions explicit.** Secure, reward, bank, reset, and retry boundaries need exactly-once tests.
6. **Separate permanent and run state.** Shared base resources stay immutable; secured tech persists; temporary adaptations reset.
7. **Optimize from evidence.** Headless success is not rendering, touch, device performance, or fun.
8. **Leave no contradictory documentation.** Update canonical docs in the same change as the behavior or decision.

## 3. Classify the work before editing

| Classification | Meaning | Required action |
|---|---|---|
| **Correction** | Existing behavior violates its current contract | Add a regression check; preserve intended design |
| **Adapter/reference repair** | Two existing domains disagree at a clear boundary | Compare both sides; make the smallest compatible repair |
| **Active-scope implementation** | Implements SELECTED TECH HUNT 0 behavior | Use its acceptance criteria and ownership rules |
| **Proposal** | Adds or changes design beyond active scope | Record PROPOSED status and obtain explicit scope approval before implementation |
| **Historical cleanup** | Removes stale docs/assets without changing intended behavior | Preserve current contracts and update every active reference |

Do not label a new system an “adapter” to avoid a design decision. Do not replace a defective domain design silently when ownership is ambiguous.

## 4. Standard task workflow

### 4.1 Frame

Write a short scope statement before implementation:

```text
Player/problem:
Current executable behavior:
Target behavior and canonical requirement:
In scope:
Explicitly out of scope:
Domain owners/shared files:
Acceptance checks:
Evidence that will remain unverified:
```

For gameplay work, link the relevant section of `GAMEPLAY_DESIGN.md`. If no requirement exists, the task is a proposal until the design is updated and approved.

### 4.2 Inspect

- Read current source, resources, scenes, tests, and both sides of shared-file changes.
- Check Git status and preserve other contributors' work.
- Identify existing signals/state owners before adding new ones.
- Separate actual defects from missing selected features and old documentation claims.

### 4.3 Contract

For a cross-domain change, record:

- triggering user/world/content event;
- state owner and allowed transitions;
- inputs/outputs and existing signals reused;
- exactly-once/idempotence rule;
- death/retry/reload behavior;
- UI presentation and input isolation;
- automated acceptance test.

Resolve this before introducing a new manager, autoload, event bus, save file, or resource type.

### 4.4 Implement

- Make the smallest coherent change through the existing composition path.
- Keep stable content ids and save compatibility.
- Prefer data/content additions behind existing definitions over duplicated controller logic.
- Do not add speculative generalization for only one unproven use case.
- Keep generated artifacts and unrelated formatting out of the scoped change.

### 4.5 Verify

- Add the failing acceptance/regression check first when practical.
- Run static and engine gates for logic; browser gates for shell/gameplay handoff and rendered Web behavior.
- Use interactive human playtesting for comprehension/feel and physical devices for Android/touch/performance.
- Record the exact checkpoint, commands, results, and limits in `VALIDATION.md`.

### 4.6 Document and hand off

A change is not coherent if code and canonical docs disagree. Update:

- `GAMEPLAY_DESIGN.md` for intended behavior/scope;
- `ARCHITECTURE.md` through `tools/module_map.py` for module moves;
- `DECISIONS.md` for durable measured technical decisions;
- `VALIDATION.md` for executed evidence;
- the relevant runbook for changed commands/workflows;
- this guide for priorities, dependencies, or process changes.

## 5. Ownership and collaboration

| Domain | May lead | Must coordinate |
|---|---|---|
| Gameplay Design + Gameplay/Core | Game rules, combat/run logic, mission lifecycle, rewards, upgrades, persistent transaction semantics | Any UI, World, Character, save-schema, or shared-signal change |
| Character & Content | Hero/enemy/boss assets and behaviors, weapon/module definitions and effects | Damage signatures, spawn contracts, persistent writes, new combat roles |
| World | Environment identity, geometry, routes, markers, cache/guardian placement, world configuration | Guard activation, mission behavior, collision/traversal changes affecting Core |
| UI/UX | Opening/HERO/theatre/DEPLOY, HUD, mission card/tracker, field kit, Results, interaction presentation | State authority, navigation, reward/save transactions, touch/input ownership |
| Integration/QA | Merge classification, architecture, test strategy, Web/Android delivery, evidence | Cross-domain conflicts and claims beyond executed checks |

### Shared-file rule

When two contributors change the same file:

1. read both complete versions and the merge base when available;
2. classify edits by domain and behavior;
3. preserve compatible functionality from both;
4. do not use wholesale ours/theirs replacement for unresolved gameplay logic;
5. escalate ambiguous product direction instead of encoding a guess.

## 6. Active delivery plan

The phases below are dependency gates, not calendar promises.

### Phase A — Canonical baseline

**Goal:** one current design/plan/evidence system and a known executable checkpoint.

- Consolidate contradictory documents into the canonical set.
- Keep current source behavior unchanged during documentation cleanup.
- Establish required reading and documentation checks.
- Use the latest full CI checkpoint as the baseline; do not carry old blockers forward as current.

**Exit:** canonical links pass, repository checks pass, and no retired document remains an active instruction.

### Phase B — TECH HUNT 0 contract lock

**Goal:** resolve only the decisions needed for the first vertical path.

- Select one existing theatre, mission id, primary cache, optional cache, and first blueprint reward.
- Define the single Gameplay/Core mission-state owner and its transitions within the existing session composition.
- Define guard activation/completion and World marker inputs.
- Define blueprint fields/migration inside the existing persistent profile path.
- Define Extract/Endless handoff and death/retry semantics.
- Write acceptance fixtures before broad UI/content production.

**Exit:** no UNKNOWN remains for the first path's ids, state ownership, reward, save schema, or transition order. Later upgrades/bosses remain outside scope.

### Phase C — Guarded technology vertical path

**Goal:** one real mission can be completed and secured.

- Present the mission card and tracker from authoritative mission data.
- Activate existing guards through a legible condition.
- Drive cache Guarded → Ready → Secured from real encounter state.
- Persist the unique cache/reward exactly once.
- Show the resulting existing-capability unlock in the appropriate loadout/armory path.

**Exit:** automated tests cover blocked early secure, successful secure, duplicate interaction, reload, and reward eligibility. Browser review covers the actual player path.

### Phase D — Death, Extract, and Endless integration

**Goal:** the expedition ends cleanly in both short and extended sessions.

- Test death before and after secure, retry, and reload.
- Add explicit Extract versus Continue to Endless after the main objective.
- Preserve existing Defense/reward regression while transitions are replaced or extended.
- Ensure completion banking and run cleanup happen once.

**Exit:** no duplication, soft lock, unsolicited wave, profile loss, or ambiguous kept/reset feedback in the tested paths.

### Phase E — Human hook playtest and iteration

**Goal:** test the design hypotheses rather than declare them successful.

- Observe objective comprehension, route choice, dodge/punish understanding, secure/death comprehension, and redeploy reasoning.
- Agree on participants, devices, and thresholds before the test.
- Classify failures as guidance, combat readability, controls, balance, reward value, or motivation.
- Make the smallest correction indicated by evidence and rerun affected gates.

**Exit:** a recorded decision to continue, revise, or stop the TECH HUNT hypothesis. No retention claim without suitable longer-term evidence.

### Later phases — gated expansion

| Candidate | Entry condition |
|---|---|
| Run-scoped milestone upgrades | TECH HUNT loop is stable and upgrade definitions/lifecycle are explicitly approved |
| Post-cap Endless escalation | Long-run measurements identify the actual decision/difficulty failure |
| New guardian/boss | Existing guards prove the mission loop and a new behavior exam is justified |
| Additional mission templates/world rules | Recovery mission works and World/Core contracts are coordinated |
| New hero/weapon/module types | A missing tactical role is identified; not merely content breadth |
| Android release hardening | Core loop and target-device baseline are ready for repeated physical testing |
| Monetization or multiplayer | Separate explicit product, policy, architecture, and validation approval; currently **DEFERRED** |

## 7. First implementation dependency chain

```text
select first theatre + reward + ids
  → choose mission-state owner and save schema
  → write secure/death/duplicate acceptance fixtures
  → World markers + guard activation contract
  → mission/cache state through Gameplay/Core
  → UI tracker + secure feedback
  → persistent blueprint → existing unlock/equip path
  → Extract / Endless transition
  → death/retry/reload regression
  → browser player-path review
  → human playtest
```

Do not start boss production, a crafting economy, or a broad mission catalog in parallel to compensate for an unproven center path.

## 8. Quality gates

Use the gates appropriate to the change. A skipped gate is reported as skipped, not passed.

### 8.1 Documentation and static source

```bash
./scripts/dev_check.sh
```

This covers source/static tooling and repository contracts available in the environment. Individual optional tools may be skipped; read the summary rather than assuming all runtime checks ran.

### 8.2 Headless Godot

```bash
./scripts/run_smoke_tests.sh
./scripts/run_smoke_tests.sh --list
./scripts/run_smoke_tests.sh gameplay_vertical_slice_smoke
```

The runner imports the project and executes tests on the pinned Godot version when installed. Test count and names come from `--list`/the current test inventory, not old prose.

Required for TECH HUNT logic: real mission/session transitions, guard completion, secure idempotence, save/load, death/retry, reward duplication, and existing combat/wave regression.

### 8.3 Web export and payload

```bash
./scripts/export_web_preview.sh
python3 tools/check_payload.py web/index.pck
```

The export must include runtime resources but not tests/QA code. Preserve the official loader recovery patch and initial-opening single-download contract.

### 8.4 Automated browser

```bash
npm ci --prefix tools
node tools/web_qa.mjs
node tools/web_loading_qa.mjs
```

Use the current tool source for supported flags; some flags launch real QA rather than printing help. Browser checks must traverse the actual opening → HERO → theatre → DEPLOY flow or the explicitly supported direct-selection path.

TECH HUNT browser evidence must reach actual mission gameplay and secure feedback; a mission-card screenshot alone is insufficient.

### 8.5 Interactive human and physical device

These are separate gates:

- **Interactive human:** controls, comprehension, combat readability, enjoyment hypotheses, redeploy reasoning.
- **Physical Android device:** touch, safe areas, renderer, thermal/memory/frame-time behavior, save/reload, interruption handling.
- **Listening/visual acceptance:** actual output and human review; asset generation or screenshot existence is not enough.

See [`runbooks/ANDROID.md`](runbooks/ANDROID.md) and [`runbooks/WEB_PREVIEW.md`](runbooks/WEB_PREVIEW.md).

## 9. Evidence language

| Evidence level | May support | Does not support alone |
|---|---|---|
| Static/source inspection | Presence/absence of paths, data contracts, reference integrity | Runtime behavior or player experience |
| Headless Godot | State transitions, physics/gameplay fixtures, rewards, save logic | Rendering quality, human aiming, device performance |
| Automated Chromium/WebGL | Real Web boot, input path, selected theatre, rendered frames, loading/recovery | Android behavior, physical touch ergonomics, representative mobile FPS |
| Interactive browser | Human comprehension and feel in that browser/setup | Android/device or retention generalization |
| Physical device | Platform-specific touch/performance/runtime evidence for tested devices | Every device or long-term retention |
| Human playtest | Stated/observed understanding and behavior for that sample | Statistically representative market/retention claims |

Use **VERIFIED**, **LIKELY**, **ASSUMPTION**, and **UNKNOWN** with the relevant level. Do not convert “code exists” into “fun verified.”

## 10. Definition of done

A development task is complete only when applicable items are true:

- [ ] Scope maps to canonical design or an explicit correction/adapter.
- [ ] No out-of-scope system, currency, mode, or manager was introduced.
- [ ] Existing compatible behavior and other contributors' changes are preserved.
- [ ] State ownership and permanent/run reset boundaries are clear.
- [ ] Exactly-once and failure paths are tested where applicable.
- [ ] Required static/engine/browser/device checks were run or explicitly marked skipped.
- [ ] Player-facing feedback reflects authoritative state.
- [ ] `GAMEPLAY_DESIGN.md`, architecture, runbooks, and validation are updated as applicable.
- [ ] No stale active document contradicts the result.
- [ ] The handoff states remaining UNKNOWNs without claiming retention, device quality, or full gameplay coverage.

## 11. Repository and asset hygiene

- Work on the assigned branch; never rewrite history, force-push, or discard another contributor's changes.
- Keep commits scoped and include only intended files.
- Follow existing Git/LFS/export conventions; do not commit transient caches, local SDK paths, credentials, or unneeded large QA data.
- World/source assets use their established provenance and staging pipeline.
- Initial opening must obtain required runtime world data/assets before entry; do not defer the required pack until the world opens.
- Unchanged assets should use content validation/caching rather than repeated full downloads during development.
- Browser-facing code uses relative/service URLs appropriate to the served preview, never assumptions about the developer's localhost from a remote browser.
- Machine-local export presets and signing material stay outside Git as documented by the runbooks.

## 12. Setup and subsystem references

| Need | Document |
|---|---|
| Install pinned tools | [`runbooks/TOOLCHAIN.md`](runbooks/TOOLCHAIN.md) |
| Run/export/debug Web | [`runbooks/WEB_PREVIEW.md`](runbooks/WEB_PREVIEW.md) |
| Build/test/profile Android | [`runbooks/ANDROID.md`](runbooks/ANDROID.md) |
| Change music/SFX | [`runbooks/AUDIO.md`](runbooks/AUDIO.md) |
| Change hero/rifle rig | [`runbooks/HERO_RIG.md`](runbooks/HERO_RIG.md) |
| Build/inspect mission worlds | [`world/README.md`](world/README.md) |
| Change front-end journey | [`FRONT_END_JOURNEY.md`](FRONT_END_JOURNEY.md) |
| Change art/palette/type | [`ART_DIRECTION.md`](ART_DIRECTION.md) |
| Run smoke tests | [`../tests/README.md`](../tests/README.md) |
