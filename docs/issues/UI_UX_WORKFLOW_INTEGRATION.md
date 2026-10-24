# Corrected scope for GitHub issue #5

> This supersedes the original issue body, which inspected the wrong UI branch. `arena/c8558858-cyber-strike` / `e5ba023c` and its `ExoconflictFlow` are **not** the disposition of the actual UI/UX implementation. Do not reuse the old findings to accept or reject the branch below.

**Title:** UI/UX: preserve world/loadout selection and validate the integrated landscape workflow
**Owning domain:** UI/UX Workflow
**Severity:** High
**Integration status:** Technical integration is validated at source `9e82c0b` and payload `cec0fdd`: 28/28 engine tests, Web export, four boot checks, strict WORLD → Vanguard selection, Neon encounter/input/audio, and pause/settings browser checks pass. This issue remains open for the explicitly unverified human visual and physical-device acceptance gates, plus the targeted glyph/spacing review below.

## Corrected evidence

- Actual source branch: `arena/c08beb55-cyber-strike`, tip `f99fb06fbaa3943d83ccc63cd235df86cd69e19d` (PR #2).
- Implementation audit covered 35 unique commits and 113 changed files from merge-base `3eb146e`: HTML/CSS shell, self-hosted fonts, AEGIS bezel work, front-end/HUD changes, landscape-only layouts, and UI tests.
- The source `ui/shell.js` DEPLOY handler wrote `qa_stage=GAMEPLAY`. That bypassed the engine's HERO/WORLD selection journey and could silently launch the saved/default theatre instead of presenting the two registered choices.
- The engine-side `FrontEnd`, registry-driven WORLD stage, and `ProgressionService` already provide the required selection and persistence contracts. A second JavaScript content registry is neither needed nor permitted.
- Landscape-only is an explicit UI-domain behavior change, documented by the source in `docs/DECISIONS.md` §31 and `docs/UI_UX_REDESIGN_SPEC.md`; it is not to be “fixed” by silently restoring the removed portrait/desktop arrangements.
- Source CI runs `40097452933` and `40097867730` reported 26/27 headless tests. `playability_hud_smoke.gd` failed the CANCEL DEFENSE journey: the final state remained `DEFENSE IN 5`, wave 0. Its last touch was id 92 at `(823.557,553.2177)` with `hit=none`; that evidence alone did not prove a Core lifecycle defect.
- Several source smoke logs also reported `grab_focus()` while the Control was outside the scene tree.

## Reproduction steps

1. At `f99fb06`, inspect `ui/shell.js::deploy` and observe the direct `qa_stage=GAMEPLAY` hand-off.
2. Compare it with `FrontEnd.STAGE_SCENES`, `stage_world_select.gd`, and `ProgressionService.WORLD_IDS` on the integrated target.
3. Run `scripts/run_smoke_tests.sh playability_hud_smoke` on the source and inspect the pause/retry/cancel diagnostics.
4. Inspect check-run `120883798876` annotations for the same failure and the out-of-tree focus errors.
5. In a browser, select the second theatre and require the runtime `VanguardStation:` build log; a screenshot or a click alone is not proof of selection.

## Impact

Direct GAMEPLAY hand-off makes the integrated World and loadout work unreachable from the player-facing shell. The source pause/focus failures also block treating a successful static merge as a playable UI integration. Changing damage, waves, rewards, or run lifecycle to conceal those UI symptoms would violate ownership boundaries.

## Requested correction / integration adapter

- Keep the actual UI shell and landscape presentation.
- Change DEPLOY to hand off to `qa_stage=WORLD`, then use the existing engine journey and `ProgressionService`; do not duplicate hero/weapon/world data in JavaScript.
- Preserve both world definitions and the selected-world build gates.
- Make deferred focus conditional on a valid, visible, in-tree Control, and focus the primary action when a stage is entered.
- Let results teardown and pause layout settle between distinct Retry, Pause, and Cancel taps in the smoke journey; retain an explicit assertion that the pause panel is actionable before testing CANCEL DEFENSE.
- Keep combat orchestration, damage/health, waves, rewards, and run lifecycle under Gameplay Core without rule changes for this UI repair.

## Validation outcome and remaining UI-owner action

- Merge `2243a5f` has parents `c104a32` and actual UI tip `f99fb06`; repairs `66ad679` and `9e82c0b` preserve that integration.
- CI `40099367032` passed static checks, 28/28 Godot tests, Web export/delivery, four Chromium boots, and the strict WORLD → Vanguard contract. Payload `cec0fdd` passed the 873-file content audit.
- Final-payload reports under `exports/integration-audit/` verify Vanguard selection/build, Neon Explore → Preparing → Defense with firing/audio/mute, pause/settings/tab navigation, and six nonblank shell frames at 844×390 / 667×375.
- Visual diagnostic frames are not human visual acceptance. Inspect the `SETTINGS → CONTROLS` arrow glyph in the pause hint and the bottom Access action spacing. If the glyph is unsupported or an action is clipped, UI/UX should correct the font fallback/copy or layout rather than Core changing gameplay behavior.
- Reproduce the visual review with `node tools/web_qa.mjs --page '/web/index.html?qa_stage=GAMEPLAY' --viewport 844x390 --menus --settings --settings-tabs`, then repeat at 667×375 and on the intended touch device. Require readable supported glyphs, fully visible actions, and unchanged pause/resume/settings behavior.

## Acceptance criteria

- Exactly one production front-end/navigation authority is used; the HTML shell hands off to the engine WORLD stage rather than maintaining a parallel roster.
- DEPLOY exposes the existing loadout/theatre flow, and both registered worlds remain selectable through `ProgressionService`.
- Browser QA requires `FrontEnd: stage WORLD`, real gameplay entry, and the selected Vanguard Station runtime build log.
- The merged Godot 4.7.2 suite passes, including front-end journey, menu layout, showcase, data source, HUD touch, and CANCEL DEFENSE; no out-of-tree `grab_focus()` errors remain.
- Web export and committed payload checks pass; browser boot reports no script, page, request, or WebGL failures.
- Landscape-only behavior is documented explicitly. Portrait/mobile physical-device support and human visual acceptance are not claimed without new evidence.

## Integration dependencies

`index.html`, `ui/shell.js`, `front_end.tscn`, `FrontEnd`, `MenuStage`, `stage_world_select.gd`, `ProgressionService`, `main.tscn`, HUD touch dispatch/pause panels, `tools/web_qa.mjs`, and the Web export/publication workflow.

## Ownership boundary

UI/UX owns presentation, navigation, layout, interaction, and the landscape-only decision. Gameplay Core owns gameplay state and may repair only the integration adapters/contracts. World and Character registries remain authoritative for their content.

## Validation requirements

Run static checks, the complete headless engine suite, Web export, root/raw Chromium boots, and the strict WORLD → Vanguard selection contract on the merged commit and regenerated payload. Record any remaining interactive, visual, or physical-device limitation separately rather than inferring it from CI.
