#!/usr/bin/env bash
# Run every GDScript smoke test headlessly with the pinned Godot editor build.
#
# The tests live in tests/ at the repository root, deliberately OUTSIDE game/.
# Godot can only see files under the project directory, so a test inside game/
# is an export candidate: it ships to players unless an export filter excludes
# it, and that filter is one hand-edited preset away from being dropped. A test
# outside the project cannot be packed by construction. Godot still runs it:
# --script accepts an absolute path, and preload("res://...") inside the test
# resolves against --path game.
#
# Usage:
#   scripts/run_smoke_tests.sh                  # import once, then run all tests
#   scripts/run_smoke_tests.sh --no-import      # skip the headless editor import
#   scripts/run_smoke_tests.sh --list           # print test names and exit
#   scripts/run_smoke_tests.sh wave_director_smoke weapon_system_smoke
#                                               # run a subset (filename without .gd)
#
# Environment:
#   GODOT_BIN            path/name of the Godot 4.7.2 editor build (default: godot, godot4)
#   SKIP_VERSION_CHECK   set to 1 to allow a different Godot 4.x version
#   SMOKE_LOG_DIR        log directory (default: exports/test-logs)
#   SMOKE_TEST_TIMEOUT   seconds per test before it is killed (default: 240)
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/.godot-version")"
LOG_DIR="${SMOKE_LOG_DIR:-$ROOT_DIR/exports/test-logs}"
TEST_TIMEOUT="${SMOKE_TEST_TIMEOUT:-240}"

DO_IMPORT=1
SELECTED_TESTS=()

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# > 0 )); do
  case "$1" in
    --no-import) DO_IMPORT=0 ;;
    --list) SELECTED_TESTS=("__LIST__") ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      printf 'ERROR: unknown option %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *) SELECTED_TESTS+=("${1%.gd}") ;;
  esac
  shift
done

resolve_godot() {
  local candidate
  for candidate in "${GODOT_BIN:-}" godot godot4; do
    [[ -z "$candidate" ]] && continue
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

GODOT="$(resolve_godot || true)"
if [[ -z "$GODOT" ]]; then
  printf 'ERROR: Godot editor/CLI not found.\n' >&2
  printf 'Install the pinned build with ./scripts/install_godot.sh, or set GODOT_BIN.\n' >&2
  exit 127
fi

GODOT_VERSION="$("$GODOT" --version 2>&1 | head -n 1)"
if [[ "${SKIP_VERSION_CHECK:-0}" != "1" && "$GODOT_VERSION" != "$EXPECTED_VERSION"* ]]; then
  printf 'ERROR: Godot version mismatch: expected %s.x, found %s\n' "$EXPECTED_VERSION" "$GODOT_VERSION" >&2
  printf 'Set SKIP_VERSION_CHECK=1 to run anyway (results would not match the pinned toolchain).\n' >&2
  exit 2
fi

shopt -s nullglob
ALL_TESTS=("$ROOT_DIR"/tests/*_smoke.gd)
shopt -u nullglob
if (( ${#ALL_TESTS[@]} == 0 )); then
  printf 'ERROR: no smoke tests found under tests/.\n' >&2
  exit 2
fi

if (( ${#SELECTED_TESTS[@]} == 1 )) && [[ "${SELECTED_TESTS[0]}" == "__LIST__" ]]; then
  printf 'Available smoke tests (%d):\n' "${#ALL_TESTS[@]}"
  for test_path in "${ALL_TESTS[@]}"; do
    printf '  %s\n' "${test_path##*/}"
  done
  exit 0
fi

TESTS=()
if (( ${#SELECTED_TESTS[@]} == 0 )); then
  TESTS=("${ALL_TESTS[@]}")
else
  for wanted in "${SELECTED_TESTS[@]}"; do
    match=""
    for test_path in "${ALL_TESTS[@]}"; do
      if [[ "${test_path##*/}" == "$wanted.gd" || "${test_path##*/}" == "$wanted" ]]; then
        match="$test_path"
      fi
    done
    if [[ -z "$match" ]]; then
      printf 'ERROR: unknown smoke test: %s\n' "$wanted" >&2
      exit 2
    fi
    TESTS+=("$match")
  done
fi

mkdir -p "$LOG_DIR"

printf 'Exocomplict — headless smoke test run\n'
printf 'Godot:   %s (%s)\n' "$GODOT_VERSION" "$GODOT"
printf 'Project: %s\n' "$GAME_DIR"
printf 'Tests:   %s (outside res://, cannot be exported)\n' "$ROOT_DIR/tests"
printf 'Logs:    %s\n\n' "$LOG_DIR"

if (( DO_IMPORT == 1 )); then
  printf 'Importing project and asset dependencies (headless editor)...\n'
  import_log="$LOG_DIR/import.log"
  if "$GODOT" --headless --editor --path "$GAME_DIR" --quit >"$import_log" 2>&1; then
    IMPORT_STATE="ok"
    printf '  import: ok (%s)\n\n' "${import_log#"$ROOT_DIR"/}"
  else
    printf '  import: FAILED — see %s\n' "${import_log#"$ROOT_DIR"/}"
    sed 's/^/    /' "$import_log" | tail -20
    printf '\nImport failure means the project cannot be loaded; fix before interpreting test results.\n'
    exit 1
  fi
fi

# Per-test annotations are buffered: GitHub keeps only the first ten annotations
# of a step, so printing them as tests finish could push the failure line of the
# eleventh test out of sight. The failure summary is emitted first instead.
ANNOTATIONS=()
PASSED=0
FAILED=0
FAILED_NAMES=()
IMPORT_STATE="skipped"
if (( DO_IMPORT == 1 )); then
  IMPORT_STATE="ok"
fi
for test_path in "${TESTS[@]}"; do
  test_name="${test_path##*/}"
  test_log="$LOG_DIR/${test_name%.gd}.log"
  printf 'Running %s ... ' "$test_name"
  # A hung test must fail the job with a readable reason instead of blocking CI
  # forever; the timeout is generous because the first test pays the shader warm-up.
  test_status=0
  # Absolute path, not res:// — the test is outside the project on purpose.
  timeout "${TEST_TIMEOUT}" "$GODOT" --headless --path "$GAME_DIR" \
    --script "$test_path" >"$test_log" 2>&1 || test_status=$?
  if (( test_status == 0 )); then
    printf 'PASS\n'
    PASSED=$((PASSED + 1))
  elif (( test_status == 124 )); then
    printf 'FAIL (timed out after %ss)\n' "$TEST_TIMEOUT"
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$test_name (timeout)")
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      printf '::error title=Smoke test timed out::%s exceeded %ss\n' "$test_name" "$TEST_TIMEOUT"
    fi
  else
    printf 'FAIL (exit %s)\n' "$test_status"
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$test_name")
  fi
  if grep -qE 'SCRIPT ERROR|Parse Error|ERROR: Condition' "$test_log"; then
    printf '    engine reported script errors; see %s\n' "${test_log#"$ROOT_DIR"/}"
    # The full job log is not downloadable from every environment; surface the
    # first error line as an annotation so the failing call site is never a guess.
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      error_digest="$(grep -A2 -m1 -E 'SCRIPT ERROR|Parse Error|ERROR: Condition' "$test_log" | tr '\n' '|' | cut -c1-700)"
      printf '::error title=Script error in %s::%s\n' "${test_name%.gd}" "${error_digest:-see log}"
    fi
  fi
  if grep -qiE 'FAIL:|smoke test failed:' "$test_log"; then
    printf '    assertion failures; see %s\n' "${test_log#"$ROOT_DIR"/}"
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      assertion_digest="$(grep -im6 -E 'FAIL:|smoke test failed:' "$test_log" | tr '\n' '|' | cut -c1-1400)"
      printf '::error title=Assertion failed in %s::%s\n' "${test_name%.gd}" "${assertion_digest:-see log}"
    fi
  fi
  # One annotation per test: the job log is not always retrievable (for example
  # from a restricted sandbox), and "which test hung" must never be a guess.
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    case "$test_status" in
      0) test_verdict='PASS' ;;
      124) test_verdict="FAIL (timeout ${TEST_TIMEOUT}s)" ;;
      *) test_verdict="FAIL (exit $test_status)" ;;
    esac
    ANNOTATIONS+=("::notice title=Smoke ${test_name%.gd}::$test_verdict")
  fi
done

SUMMARY_FILE="$LOG_DIR/summary.txt"
{
  printf 'engine=%s\n' "$GODOT_VERSION"
  printf 'engine_path=%s\n' "$GODOT"
  printf 'import=%s\n' "$IMPORT_STATE"
  printf 'passed=%d\n' "$PASSED"
  printf 'failed=%d\n' "$FAILED"
  printf 'total=%d\n' "${#TESTS[@]}"
  printf 'failed_tests=%s\n' "${FAILED_NAMES[*]:-none}"
} > "$SUMMARY_FILE"

printf '\nSummary: %d passed, %d failed (of %d)\n' "$PASSED" "$FAILED" "${#TESTS[@]}"
printf 'Machine-readable summary: %s\n' "${SUMMARY_FILE#"$ROOT_DIR"/}"

# Surface the evidence in GitHub Actions annotations, which stay readable from
# the API even when the full job log is not downloadable.
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if (( FAILED > 0 )); then
    printf '::error title=Failed smoke tests::%s\n' "${FAILED_NAMES[*]}"
  fi
  printf '::notice title=Godot engine::%s\n' "$GODOT_VERSION"
  printf '::notice title=Smoke tests::%d passed, %d failed (of %d, import %s)\n' \
    "$PASSED" "$FAILED" "${#TESTS[@]}" "$IMPORT_STATE"
  for annotation in "${ANNOTATIONS[@]}"; do
    printf '%s\n' "$annotation"
  done
fi
if (( FAILED > 0 )); then
  printf 'Failed tests:\n'
  for name in "${FAILED_NAMES[@]}"; do
    printf '  - %s (log: %s)\n' "$name" "${LOG_DIR#"$ROOT_DIR"/}/${name%.gd}.log"
  done
  exit 1
fi
printf 'Every selected smoke test exited with code 0. Device/render/mobile claims still need a real Android run.\n'
