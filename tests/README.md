# Smoke tests

26 GDScript tests, 8,141 lines, run headlessly on the pinned Godot 4.7.2 build.

```bash
scripts/run_smoke_tests.sh            # import once, then run all 26
scripts/run_smoke_tests.sh --list     # names
scripts/run_smoke_tests.sh audio_smoke   # one test
```

Every test exits non-zero on failure, so the runner is the gate; there is no
separate assertion framework. Logs land in `exports/test-logs/`.

## Why this folder is not `game/tests/`

Godot can only see files inside the project directory (`game/`). That means a
test file inside `game/` is an export candidate: it gets compiled to `.gdc`,
packed, and shipped to players — measured at **52 entries / 206 KB** in
`web/index.pck` before this moved (see `docs/DECISIONS.md` §5).

The first fix was `exclude_filter="tests/*"` on the export presets. That is a
setting, and settings get lost the next time someone hand-edits a preset, so the
tests moved out of the project instead. A file outside `game/` cannot be
exported, whatever the presets say.

Godot still runs them: `--script` accepts an absolute path, and
`preload("res://…")` inside the test resolves against `--path game`.

```bash
godot --headless --path game --script "$PWD/tests/audio_smoke.gd"
```

Consequences to know before adding a test:

* A test that needs to be a node in a scene, or that must be reachable as
  `res://tests/…`, does not belong here — it belongs in `game/` and it will ship.
* `.uid` sidecars are not committed here. They only mean something inside
  `res://`.
* If a test needs a new asset, the asset goes in `game/assets/` as usual; the
  test just loads it through `res://`.
