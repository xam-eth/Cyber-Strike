# Documentation system

This is the entry point for project knowledge. The active tree contains current direction, current technical contracts, and current runbooks—not a pile of dated reports with competing instructions.

Repository-level reminders for coding agents and developers live in [`../AGENTS.md`](../AGENTS.md).

## Read by question

| Question | Authoritative location | What it does not prove |
|---|---|---|
| What experience are we building, and why? | [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md) | That the target design is already implemented or fun |
| What is in the active prototype scope? | `GAMEPLAY_DESIGN.md` + [`DEVELOPMENT.md`](DEVELOPMENT.md) | Permission to add every future idea |
| Where should code and content live? | [`ARCHITECTURE.md`](ARCHITECTURE.md) | Product/design approval |
| How do external World/Character packages enter the game? | [`CONTENT_IMPORT.md`](CONTENT_IMPORT.md) | Gameplay/roster activation, arbitrary code sandboxing, or IAP approval |
| What does the game do today? | Source, scenes, resources, and tests | A design document by itself |
| What has actually passed? | [`VALIDATION.md`](VALIDATION.md) and linked CI | Unrun platforms, human enjoyment, or retention |
| Why does a technical rule exist? | [`DECISIONS.md`](DECISIONS.md) | A replacement for current source inspection |
| What is the player journey and presentation direction? | [`FRONT_END_JOURNEY.md`](FRONT_END_JOURNEY.md), [`ART_DIRECTION.md`](ART_DIRECTION.md), and [`world/README.md`](world/README.md) | Gameplay/reward authority |
| How do I set up, build, preview, or inspect a subsystem? | The runbooks below | That the commands were run in the current session |

**Design and code answer different questions.** Do not use old code to veto a selected direction automatically, and do not describe a selected direction as current code. Reconcile the two through an explicit implementation task and acceptance criteria.

## Canonical documents

### Product and development

| Document | Owner / role | Update trigger |
|---|---|---|
| [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md) | Gameplay Design + Gameplay/Core; player experience, active prototype scope, game rules, content boundaries | Any gameplay direction, mechanic, mission, economy, progression, save, or run-lifecycle change |
| [`DEVELOPMENT.md`](DEVELOPMENT.md) | Integration/production; workflow, sequence, ownership, definition of done | Priority, dependency, process, or quality-gate change |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Integration/Core; module map and import boundaries | Module/file/boundary change; regenerate its map with the provided tool |
| [`CONTENT_IMPORT.md`](CONTENT_IMPORT.md) | Integration + World/Character; external package, staging, fallback, and bundle contract | Package schema, target path, isolation rule, or activation workflow change |
| [`DECISIONS.md`](DECISIONS.md) | Technical/domain owners; durable measured decisions and reversals | A costly technical lesson or explicit decision replaces an earlier rule |
| [`VALIDATION.md`](VALIDATION.md) | Integration/QA; latest relevant evidence and evidence limits | A meaningful static, engine, browser, interactive, or device gate completes |

### Experience and content

| Document | Scope |
|---|---|
| [`ART_DIRECTION.md`](ART_DIRECTION.md) | Palette, type, composition, asset grading, visual verification |
| [`FRONT_END_JOURNEY.md`](FRONT_END_JOURNEY.md) | Opening, HERO, theatre selection, DEPLOY, shell/engine handoff, persistence touchpoints |
| [`world/README.md`](world/README.md) | World build entry point, shared real-asset policy, and world-specific document index |
| [`world/CONCEPT.md`](world/CONCEPT.md) | Mission-world identity, routes, atmosphere, and environmental beats |

World documents describe environment and content. They do not independently create missions, modes, rewards, or progression.

### Runbooks

| Runbook | Use |
|---|---|
| [`runbooks/TOOLCHAIN.md`](runbooks/TOOLCHAIN.md) | Pinned Godot, Android, Blender, and local setup |
| [`runbooks/WEB_PREVIEW.md`](runbooks/WEB_PREVIEW.md) | Web export, initial preload, cache behavior, browser QA, troubleshooting |
| [`runbooks/ANDROID.md`](runbooks/ANDROID.md) | APK, physical-device checklist, profiling, Android evidence boundary |
| [`runbooks/AUDIO.md`](runbooks/AUDIO.md) | Frontier Signal music/SFX ownership and audio verification |
| [`runbooks/HERO_RIG.md`](runbooks/HERO_RIG.md) | Hero/rifle source, sockets, clips, rebuild, rig verification |

## Status vocabulary

Keep these categories separate. “Selected design” is not “implemented,” and “implemented” is not “verified on every platform.”

### Design status

- **SELECTED** — approved direction for the current prototype; still requires implementation and validation.
- **PROPOSED** — a candidate requiring an explicit product/scope decision.
- **DEFERRED** — intentionally outside the current prototype, not rejected forever.
- **REJECTED** — deliberately not pursued; record the reason if it prevents repeated debate.

### Implementation status

- **IMPLEMENTED** — an executable path exists; cite source/test when useful.
- **PARTIAL** — some links exist, but the stated end-to-end behavior does not.
- **ABSENT** — source/resource inspection establishes that no path exists.
- **UNKNOWN** — the repository cannot establish the current state.

### Evidence status

- **VERIFIED** — a named check was executed against an identified checkpoint; state whether it was static, engine, automated browser, interactive human, or physical device.
- **LIKELY** — a concrete path exists but the relevant runtime condition was not fully observed.
- **ASSUMPTION** — an inference or working interpretation, not a fact.
- **UNKNOWN** — evidence or a product decision is missing.

Do not collapse these into a green “done” label. A feature can be **SELECTED + ABSENT + human experience UNKNOWN**.

## Conflict protocol

1. Determine whether the conflict concerns intended design, current implementation, ownership, or evidence.
2. Compare both sides of shared-file changes and inspect current code; never simply keep the newest-looking paragraph.
3. Preserve compatible current behavior. Do not silently replace a domain design or add a parallel compatibility manager.
4. Update the one canonical owner and all links to it in the same change.
5. If resolution changes product scope or crosses domain ownership without a clear adapter, record the open decision and escalate instead of guessing.

## Documentation lifecycle

- Root contains only `README.md` for humans and `AGENTS.md` for persistent repository instructions.
- Prefer editing an existing canonical/domain document to creating a new one.
- A new document requires a clear owner, non-overlapping role, status, and an entry in this index.
- Do not add dated “final,” gap, audit, integration, or validation reports to the active tree. Summarize the latest evidence in `VALIDATION.md`; Git history is the archive.
- Remove superseded paragraphs rather than adding contradictory addenda.
- Large evidence files belong in the established QA/artifact location, not inside design prose.

## 2026-10-26 consolidation record

The old active-tree documents were retired so they cannot compete with the canonical set. Their prior versions remain available through Git history.

| Retired material | Current successor |
|---|---|
| `GAME_CONCEPT`, `GAME_OVERVIEW`, the six gameplay loop/contract/audit/hook/research documents | [`GAMEPLAY_DESIGN.md`](GAMEPLAY_DESIGN.md) |
| Root roadmap, gap analysis, provisional decisions | [`DEVELOPMENT.md`](DEVELOPMENT.md), [`DECISIONS.md`](DECISIONS.md), [`VALIDATION.md`](VALIDATION.md) |
| Gameplay/integration validation reports, Web loading recovery, World opening integration | [`VALIDATION.md`](VALIDATION.md) plus the current Web/world runbooks |
| Old UI redesign specification | [`ART_DIRECTION.md`](ART_DIRECTION.md), [`FRONT_END_JOURNEY.md`](FRONT_END_JOURNEY.md), [`DECISIONS.md`](DECISIONS.md) |
| Old three-world asset/PBR/cinematic records | [`world/README.md`](world/README.md) and [`world/CONCEPT.md`](world/CONCEPT.md), with generated manifests for measurements |
| Resolved asset inspections, candidate research, old blockout/kit reports, issue drafts | Git history only; current subsystem documents own any still-relevant rule |
| IAP/monetization concept | Git history only; monetization remains **DEFERRED** and outside the active prototype |

Restoring a retired document requires resolving why its content is not appropriate for the canonical owner. Do not restore it merely because it contains a convenient old answer.
