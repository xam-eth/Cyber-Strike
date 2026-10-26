# Agent and developer instructions

These instructions apply to the whole repository. Their purpose is to keep implementation, planning, and player-facing design aligned as the project changes.

## Required reading

Read [`docs/README.md`](docs/README.md) before changing documentation or starting a substantial task. Then read the documents for the questions your task touches:

1. [`docs/GAMEPLAY_DESIGN.md`](docs/GAMEPLAY_DESIGN.md) — **mandatory for gameplay logic, combat, enemies, weapons, missions, exploration, rewards, upgrades, progression, saves, run lifecycle, Endless Survival, and player-facing UI that exposes those systems.**
2. [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) — scope sequencing, ownership, workflow, and quality gates.
3. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — module boundaries and generated code map.
4. The relevant domain document or runbook listed in the documentation index.
5. [`docs/VALIDATION.md`](docs/VALIDATION.md) — what has actually been verified, and what must not be claimed.

Do not treat reading the design as evidence that its proposal is implemented. Inspect the current source and tests before changing behavior.

## Authority and conflict handling

- **Game direction and player experience:** `docs/GAMEPLAY_DESIGN.md`.
- **What may be built in the current prototype:** the active scope in `GAMEPLAY_DESIGN.md`, sequenced by `docs/DEVELOPMENT.md`, plus the user's explicit current request.
- **Current executable behavior:** source, resources, scenes, and tests.
- **Code placement and imports:** `docs/ARCHITECTURE.md` and the architecture checker.
- **Verification claims:** executed checks and `docs/VALIDATION.md`, never a design statement.
- **Historical reports:** Git history only. Retired documents are not active instructions.

If documents disagree, do not average them or choose the most convenient statement. Identify whether the question concerns intended design, current behavior, or evidence; update the appropriate canonical document and its references in the same change. Escalate a product or cross-domain ambiguity rather than silently inventing a contract.

## Gameplay development guardrails

- Preserve **Prepare → Deploy → Fight → Adapt → Survive → Reward → Upgrade → Redeploy** and Endless Survival.
- **TECH HUNT 0** is the active prototype scope, not an implemented feature claim. Stay inside its inclusion/exclusion list unless the user explicitly changes scope.
- Preserve permanent secured progress after death. Run-only state and unsecured objectives are a separate reset boundary.
- Keep Gameplay/Core ownership of combat orchestration, damage/health integration, weapon adapters, enemy combat state, waves, upgrades, rewards, run lifecycle, and state consistency.
- Do not add duplicate session, wave, reward, damage, upgrade, mission, or save managers. Extend the existing composition path through reviewed contracts.
- Do not mutate shared weapon `.tres` resources for run-scoped effects.
- Do not silently add currencies, monetization, modes, elites, bosses, random rarity economies, inventory chores, or named upgrade candidates.
- World metadata, UI copy, and content resources do not create gameplay behavior by themselves.
- Keep Energy Rifle ↔ `pulse_rifle` naming unresolved unless the user explicitly decides it. Prefer stable ids over save-breaking renames.
- Never claim retention, engagement, fun, Android behavior, physical touch quality, device performance, audibility, or visual acceptance without the corresponding human/device evidence.

## Change protocol

For every player-facing or shared-contract change:

1. Locate the relevant requirement and acceptance criterion in `GAMEPLAY_DESIGN.md`.
2. Check current code and tests; classify the work as correction, adapter, implementation of active scope, or a new proposal.
3. Preserve compatible behavior and other contributors' uncommitted work. Do not reset, clean, or overwrite unrelated changes.
4. Implement the smallest coherent vertical path; avoid speculative frameworks.
5. Add or update automated checks for state transitions, exactly-once transactions, and reset boundaries where applicable.
6. Update `GAMEPLAY_DESIGN.md` when intended behavior or scope changes, `ARCHITECTURE.md` through its generator when modules move, and `VALIDATION.md` with executed evidence.
7. Run the applicable gates in `DEVELOPMENT.md`. Distinguish static, engine, browser, interactive-human, and physical-device evidence.

A user request may approve new scope. When it does, record that scope and its exclusions before or alongside implementation; do not leave the decision only in chat.

## Documentation hygiene

- Keep only `README.md` and this file as repository-root Markdown guides.
- Do not create dated audit, gap, integration, or “final report” documents in the active tree. Record current evidence in `docs/VALIDATION.md`; Git history retains older checkpoints.
- Prefer updating a canonical/domain document over adding another file. A genuinely new document needs an owner, status, a link from `docs/README.md`, and no duplicated authority.
- Mark design as **SELECTED**, **PROPOSED**, **DEFERRED**, or **REJECTED**; implementation as **IMPLEMENTED**, **PARTIAL**, **ABSENT**, or **UNKNOWN**; evidence as **VERIFIED**, **LIKELY**, **ASSUMPTION**, or **UNKNOWN** with its test level.
- Remove stale statements rather than stacking addenda that contradict earlier paragraphs.
- Keep generated artifacts and large QA datasets out of documentation commits unless the repository already intentionally tracks that exact evidence.
