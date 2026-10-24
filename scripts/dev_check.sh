#!/usr/bin/env bash
# One-shot static development check for Project Overdrive.
#
# Runs every verification step that does *not* need the Godot engine binary:
#   1. GDScript syntax parse + style lint + format check (gdtoolkit)
#   2. Static project doctor (references, contracts, docs, assets)
#   3. Smoke-test inventory and documentation cross-check
#   4. Module and layer boundaries (tools/check_architecture.py)
#
# The engine itself is still required for gameplay verification; use
# scripts/run_smoke_tests.sh once Godot is installed (scripts/install_godot.sh).
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"

FAILED_STEPS=0
SKIPPED_STEPS=0

step_passed() { printf '  [PASS] %s\n' "$1"; }
step_failed() { printf '  [FAIL] %s\n' "$1"; FAILED_STEPS=$((FAILED_STEPS + 1)); }
step_skipped() { printf '  [SKIP] %s\n' "$1"; SKIPPED_STEPS=$((SKIPPED_STEPS + 1)); }

printf 'Project Overdrive — static development check\n'
printf 'Repository: %s\n\n' "$ROOT_DIR"

if [[ ! -d "$GAME_DIR" ]]; then
  printf 'ERROR: game/ directory not found. Run this script from the repository.\n' >&2
  exit 2
fi

# --------------------------------------------------------------------------- #
# 1. GDScript static analysis (gdtoolkit)
# --------------------------------------------------------------------------- #
printf '[1/6] GDScript static analysis\n'

PYTHON_BIN=""
if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
fi

GDLINT=""
GDFORMAT=""
GDPARSE=""
if [[ -x "$ROOT_DIR/.venv/bin/gdlint" ]]; then
  GDLINT="$ROOT_DIR/.venv/bin/gdlint"
  GDFORMAT="$ROOT_DIR/.venv/bin/gdformat"
  GDPARSE="$ROOT_DIR/.venv/bin/gdparse"
elif command -v gdlint >/dev/null 2>&1; then
  GDLINT="$(command -v gdlint)"
  GDFORMAT="$(command -v gdformat || true)"
  GDPARSE="$(command -v gdparse || true)"
fi

if [[ -z "$GDLINT" || -z "$GDFORMAT" ]]; then
  step_skipped 'gdtoolkit not installed (python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt)'
else
  mapfile -d '' GD_FILES < <(
    find "$GAME_DIR" -type f -name '*.gd' -not -path '*/.godot/*' -print0 | sort -z
  )
  if (( ${#GD_FILES[@]} == 0 )); then
    step_failed 'no GDScript files found under game/'
  else
    if [[ -n "$GDPARSE" ]]; then
      parse_failures=0
      for gd_file in "${GD_FILES[@]}"; do
        if ! "$GDPARSE" "$gd_file" >/dev/null 2>&1; then
          printf '         syntax error: %s\n' "${gd_file#"$ROOT_DIR"/}"
          parse_failures=$((parse_failures + 1))
        fi
      done
      if (( parse_failures == 0 )); then
        step_passed "syntax parse: ${#GD_FILES[@]} file(s) parse as valid GDScript"
      else
        step_failed "syntax parse: $parse_failures file(s) failed"
      fi
    else
      step_skipped 'gdparse not available; syntax parse skipped'
    fi

    if "$GDLINT" "${GD_FILES[@]}" >/dev/null 2>&1; then
      step_passed "gdlint: ${#GD_FILES[@]} file(s) pass the configured linter rules"
    else
      step_failed 'gdlint reported problems (run .venv/bin/gdlint on the reported files)'
      "$GDLINT" "${GD_FILES[@]}" 2>&1 | sed 's/^/         /' | head -20
    fi

    if "$GDFORMAT" --check "${GD_FILES[@]}" >/dev/null 2>&1; then
      step_passed "gdformat: ${#GD_FILES[@]} file(s) already formatted"
    else
      step_failed 'gdformat --check found files that need formatting'
      "$GDFORMAT" --check "${GD_FILES[@]}" 2>&1 | sed 's/^/         /' | head -10
    fi
  fi
fi
printf '\n'

# --------------------------------------------------------------------------- #
# 2. Static project doctor
# --------------------------------------------------------------------------- #
printf '[2/6] Static project doctor (references, contracts, assets, docs)\n'
DOCTOR="$ROOT_DIR/tools/project_doctor.py"
if [[ ! -f "$DOCTOR" ]]; then
  step_failed 'tools/project_doctor.py is missing'
elif [[ -z "$PYTHON_BIN" ]]; then
  step_skipped 'no python3 interpreter available for tools/project_doctor.py'
else
  doctor_output="$("$PYTHON_BIN" "$DOCTOR" --root "$ROOT_DIR" --quiet 2>&1)"
  doctor_code=$?
  printf '%s\n' "$doctor_output" | sed 's/^/         /'
  if (( doctor_code == 0 )); then
    step_passed 'project doctor found no structural failures'
  else
    step_failed 'project doctor reported structural failures (see above)'
  fi
fi
printf '\n'

# --------------------------------------------------------------------------- #
# 3. Smoke-test inventory
# --------------------------------------------------------------------------- #
printf '[3/6] Tooling self-tests\n'
TOOLS_DIR="$ROOT_DIR/tools"
if [[ ! -d "$TOOLS_DIR/tests" ]]; then
  step_skipped 'no tools/tests directory'
elif [[ -z "$PYTHON_BIN" ]]; then
  step_skipped 'no python3 interpreter available for tooling self-tests'
else
  unit_output="$("$PYTHON_BIN" -m unittest discover -s "$TOOLS_DIR/tests" -t "$TOOLS_DIR/tests" -p 'test_*.py' 2>&1)"
  unit_code=$?
  if (( unit_code == 0 )); then
    ran_line="$(printf '%s\n' "$unit_output" | grep -E '^Ran [0-9]+ test' | tail -n 1)"
    step_passed "tooling self-tests pass (${ran_line:-unittest suite})"
  else
    step_failed 'tooling self-tests failed (run: python3 -m unittest discover -s tools/tests -t tools/tests)'
    printf '%s\n' "$unit_output" | tail -20 | sed 's/^/         /'
  fi
fi

# export_presets.cfg is machine-local and may hold Android presets, Web presets,
# or both. Validate the presets that are actually present instead of assuming
# Android only, otherwise a local web export makes this check fail falsely.
PRESET_FILE="$GAME_DIR/export_presets.cfg"
if [[ ! -f "$PRESET_FILE" ]]; then
  step_skipped 'no local preset file (game/export_presets.cfg); create one with tools/android_preset.py or tools/web_preset.py'
elif [[ -z "$PYTHON_BIN" ]]; then
  step_skipped 'no python3 interpreter available for the preset tools'
else
  preset_platforms=0
  for platform in Android Web; do
    grep -q "platform=\"$platform\"" "$PRESET_FILE" || continue
    preset_platforms=$((preset_platforms + 1))
    tool="$TOOLS_DIR/$(printf '%s' "$platform" | tr '[:upper:]' '[:lower:]')_preset.py"
    if preset_output="$("$PYTHON_BIN" "$tool" check --preset-file "$PRESET_FILE" 2>&1)"; then
      step_passed "local $platform preset passes $(basename "$tool") check"
    else
      step_failed "local $platform preset failed validation"
      printf '%s\n' "$preset_output" | sed 's/^/         /'
    fi
  done
  if (( preset_platforms == 0 )); then
    step_passed 'local preset file has no Android/Web preset yet (nothing to validate)'
  fi
fi
printf '\n'

# --------------------------------------------------------------------------- #
# 4. Module and layer boundaries
# --------------------------------------------------------------------------- #
# A folder tree is a suggestion; this is the part that holds. The known
# violations from the phase-0 audit are recorded in the baseline so the check
# enforces "no new ones" from today, and the baseline shrinks phase by phase
# until it is empty (docs/STRUCTURE_PLAN.md §5).
printf '[4/6] Module and layer boundaries\n'
ARCH_CHECK="$ROOT_DIR/tools/check_architecture.py"
ARCH_BASELINE="$ROOT_DIR/tools/architecture_baseline.json"
if [[ ! -f "$ARCH_CHECK" ]]; then
  step_failed 'tools/check_architecture.py is missing'
elif [[ ! -f "$ARCH_BASELINE" ]]; then
  step_failed 'tools/architecture_baseline.json is missing (write it with --write-baseline)'
elif [[ -z "$PYTHON_BIN" ]]; then
  step_skipped 'no python3 interpreter available for the architecture check'
else
  if arch_output="$("$PYTHON_BIN" "$ARCH_CHECK" --baseline "$ARCH_BASELINE" --strict 2>&1)"; then
    step_passed 'no new layer or module boundary violations'
  else
    step_failed 'new layer or module boundary violations (see above)'
    printf '%s\n' "$arch_output" | sed 's/^/         /' | head -25
  fi
fi
printf '\n'

printf '[5/6] Smoke-test inventory\n'
shopt -s nullglob
# Outside game/ on purpose: a test file inside the project is an export
# candidate and ships to players (see scripts/run_smoke_tests.sh header).
SMOKE_TESTS=("$ROOT_DIR"/tests/*_smoke.gd)
shopt -u nullglob
if (( ${#SMOKE_TESTS[@]} == 0 )); then
  step_failed 'no smoke tests found under tests/'
else
  step_passed "${#SMOKE_TESTS[@]} smoke test(s) present outside res://: $(printf '%s ' "${SMOKE_TESTS[@]##*/}")"
fi

if ! command -v "${GODOT_BIN:-godot}" >/dev/null 2>&1 && ! command -v godot4 >/dev/null 2>&1; then
  step_skipped 'Godot engine not on PATH; run scripts/install_godot.sh then scripts/run_smoke_tests.sh'
else
  step_passed 'Godot engine detected on PATH; scripts/run_smoke_tests.sh can execute the tests'
fi
printf '\n'

printf '[6/6] Handover map\n'
MAP_CHECK="$ROOT_DIR/tools/module_map.py"
if [[ -z "$PYTHON_BIN" ]]; then
  step_skipped 'no python3 interpreter available for the handover map check'
elif [[ ! -f "$MAP_CHECK" ]]; then
  step_failed 'tools/module_map.py is missing'
elif map_output="$("$PYTHON_BIN" "$MAP_CHECK" --check 2>&1)"; then
  step_passed 'docs/ARCHITECTURE.md matches the tree'
else
  step_failed 'docs/ARCHITECTURE.md is out of date; regenerate it with tools/module_map.py'
  printf '%s\n' "$map_output" | sed 's/^/         /' | head -25
fi
printf '\n'

printf 'Summary: %d failed step(s), %d skipped step(s).\n' "$FAILED_STEPS" "$SKIPPED_STEPS"
if (( FAILED_STEPS > 0 )); then
  printf 'Fix the failures before claiming the change is verified.\n'
  exit 1
fi
printf 'Static checks are clean. Runtime behaviour still requires a Godot run.\n'
