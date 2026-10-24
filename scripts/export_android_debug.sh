#!/usr/bin/env bash
# Import, smoke-test, and export a debug APK using a local Godot Android preset.
# Does not install SDK packages, create signing keys, or store credentials.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"
PRESET_NAME="${ANDROID_EXPORT_PRESET:-Android}"
OUTPUT_PATH="${ANDROID_APK_PATH:-$ROOT_DIR/exports/exocomplict-debug.apk}"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/.godot-version")"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

resolve_binary() {
  local resolved="$1"
  if [[ "$resolved" != /* ]]; then
    resolved="$(cd "$(dirname "$resolved")" && pwd)/$(basename "$resolved")"
  fi
  printf '%s\n' "$resolved"
}

if [[ -n "${GODOT_BIN:-}" ]]; then
  command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "GODOT_BIN is not executable or not on PATH: $GODOT_BIN"
  GODOT="$(resolve_binary "$(command -v "$GODOT_BIN")")"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(resolve_binary "$(command -v godot)")"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT="$(resolve_binary "$(command -v godot4)")"
else
  fail 'Godot 4.7.2 Editor/CLI is missing. Set GODOT_BIN or install the pinned Standard Editor.'
fi

GODOT_VERSION="$("$GODOT" --version 2>&1)"
[[ "$GODOT_VERSION" == "$EXPECTED_VERSION"* ]] || fail \
  "Godot version mismatch: expected $EXPECTED_VERSION.x, found '$GODOT_VERSION'."

PRESET_FILE="$GAME_DIR/export_presets.cfg"
[[ -f "$PRESET_FILE" ]] || fail \
  "No local Android export preset at $PRESET_FILE. Import the project in Godot, add an Android preset, and set a package ID; the preset is intentionally git-ignored."
grep -Fq "name=\"$PRESET_NAME\"" "$PRESET_FILE" || fail \
  "Preset '$PRESET_NAME' was not found in $PRESET_FILE. Set ANDROID_EXPORT_PRESET to its exact name."

"$ROOT_DIR/scripts/check_toolchain.sh"

cd "$ROOT_DIR"
printf '\nImporting Godot project and GLTF dependencies...\n'
"$GODOT" --headless --editor --path "$GAME_DIR" --quit

shopt -s nullglob
SMOKE_TESTS=("$ROOT_DIR"/tests/*_smoke.gd)
(( ${#SMOKE_TESTS[@]} > 0 )) || fail 'No *_smoke.gd tests found under tests/.'
for test_path in "${SMOKE_TESTS[@]}"; do
  test_name="${test_path##*/}"
  printf '\nRunning %s...\n' "$test_name"
  "$GODOT" --headless --path "$GAME_DIR" --script "$test_path"
done

mkdir -p "$(dirname "$OUTPUT_PATH")"
printf '\nExporting debug APK with preset %s...\n' "$PRESET_NAME"
"$GODOT" --headless --path "$GAME_DIR" --export-debug "$PRESET_NAME" "$OUTPUT_PATH"
[[ -s "$OUTPUT_PATH" ]] || fail "Godot reported success but APK is missing or empty: $OUTPUT_PATH"
if command -v unzip >/dev/null 2>&1; then
  unzip -t "$OUTPUT_PATH" >/dev/null || fail "APK archive validation failed: $OUTPUT_PATH"
else
  printf 'WARNING: unzip not found; skipped APK archive integrity check.\n' >&2
fi
printf '\nDebug APK ready: %s\n' "$OUTPUT_PATH"
printf 'This verifies packaging only; install and test on an Android device before making device/performance claims.\n'
