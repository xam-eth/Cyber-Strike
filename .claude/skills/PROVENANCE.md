# Installed agent skills — provenance

These skills are **vendored copies**, not links. They are committed so that a
fresh clone has the same instructions the session that produced
`tools/asset-forge/` used. Nothing here is executed at game runtime.

| Skill set | Upstream | Commit pinned | License | Files |
| --- | --- | --- | --- | --- |
| `awesome-gamedev-agent-skills` (77 skills + `router`) | <https://github.com/gamedev-skills/awesome-gamedev-agent-skills> | `7eb1b53305fab881f4758e2eff2e371cd7869221` | Apache-2.0 (`LICENSE-awesome-gamedev-agent-skills.txt`) | `skills/<category>/<name>/SKILL.md` copied flat into `.claude/skills/<name>/` |
| `img2threejs` | <https://github.com/img2threejs/img2threejs> | `954cd5845e90efd045694bab725d68a9863c20e0` | Apache-2.0 (`LICENSE-img2threejs.txt`) | full checkout, `forge/` + `grimoire/` included |

## Install layout

The upstream installation rule for the skills collection is: *the directory that
directly contains `SKILL.md` is the skill, and its folder name equals the skill's
`name`.* Names are unique across the collection, so flattening into one directory
is the documented bulk install (`.claude/skills/` is the project-local directory
Claude Code reads). The `router` skill is installed too — the upstream docs are
explicit that the dispatcher must be present.

```bash
# what was run, from a checkout of the repository
mkdir -p .claude/skills
for d in $(cd awesome-gamedev-agent-skills && find skills -name SKILL.md -exec dirname {} \;); do
  cp -R "awesome-gamedev-agent-skills/$d" .claude/skills/
done
cp -R awesome-gamedev-agent-skills/router .claude/skills/router
cp -R img2threejs .claude/skills/img2threejs        # .git removed
```

## Verification (re-run, do not trust this table)

```bash
# 1. upstream validator: parses every SKILL.md, checks names/wiring
python3 <upstream>/scripts/validate-skills.py     # "Validated 77 skill file(s) … All checks passed."
# 2. the img2threejs state machine actually starts
cd .claude/skills/img2threejs && python3 forge/state.py init --help
```

Both were run against this copy. `validate-skills.py` lives in the upstream
checkout's `scripts/` directory and is not vendored here — it validates the
skill *format*, so it has to run from the upstream tree.

## What was actually used

* `create-game-assets` — asset manifest, family generation, deterministic
  normalisation, "do not call an asset production-ready from a prompt result
  alone" gate. This is why `tools/asset-forge/` has `catalog.json`,
  `references/` and a `quality-report.json` instead of loose demo files.
* `threejs-scene-setup`, `threejs-materials-lighting`, `threejs-gltf-loading` —
  the gallery/render harness and the GLB export path.
* `godot-3d-essentials`, `godot-shaders` — how the exported GLB is expected to
  land in the Godot project (`game/assets/`), and why the palette matches
  `game/scripts/ui/aegis_tokens.gd` rather than an invented one.
* `img2threejs` — provides the *shape* of the pipeline: reference image → spec →
  pass-by-pass code build → deterministic gate + vision review, and the rule
  that a state file, not conversation memory, is the checklist authority.

The `img2threejs` **scripts** were not used as the build driver for the whole
batch: `forge/state.py` models one reconstruction at a time and its profiles
(`generic` / `character`) do not know about a 36-asset, palette-locked game kit.
Its rules were implemented as `tools/asset-forge/gate/` (state file + evidence +
deterministic gate + visual review), which is the same contract in this repo's
own tooling. Per-asset reconstructions can still be driven through
`forge/state.py` one at a time; `tools/asset-forge/README.md` documents how.
