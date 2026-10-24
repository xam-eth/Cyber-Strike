#!/usr/bin/env bash
# Export the Godot **Web** build used for the no-install browser preview.
#
# The web build is what lets the game be reviewed without installing Godot,
# the Android SDK, or any device tooling: a single-threaded Web export runs on
# WebGL 2 and needs no cross-origin isolation headers, so a plain
# `python -m http.server` from the repository root is enough.
#
# Usage:
#   scripts/export_web_preview.sh                  # export into ./web
#   scripts/export_web_preview.sh --output dist    # custom output directory
#   scripts/export_web_preview.sh --no-import      # skip the headless import step
#   scripts/export_web_preview.sh --debug          # debug build (larger, better errors)
#
# Environment:
#   GODOT_BIN          Godot 4.7.2 editor/CLI (default: godot, godot4)
#   WEB_EXPORT_PRESET  preset name (default: Web)
#   SKIP_VERSION_CHECK 1 = allow a different Godot 4.x version
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/.godot-version")"
PRESET_NAME="${WEB_EXPORT_PRESET:-Web}"
OUTPUT_DIR="$ROOT_DIR/web"
DO_IMPORT=1
EXPORT_MODE="--export-release"

while (( $# > 0 )); do
  case "$1" in
    --output)
      OUTPUT_DIR="${2:-}"
      shift
      ;;
    --no-import) DO_IMPORT=0 ;;
    --debug) EXPORT_MODE="--export-debug" ;;
    -h | --help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

[[ -n "$OUTPUT_DIR" ]] || { printf 'ERROR: --output needs a directory.\n' >&2; exit 2; }

# Godot resolves a relative export path against the *project* directory, not the
# current working directory, so always hand it an absolute path.
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
fi
OUTPUT_DIR="${OUTPUT_DIR%/}"
cd "$ROOT_DIR" || exit 2

# Logs are written before the export step, so the directory must exist up front.
mkdir -p "$ROOT_DIR/exports"

PYTHON_BIN=""
if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
else
  printf 'ERROR: python3 is required (used for the preset and build verification steps).\n' >&2
  exit 2
fi

# --------------------------------------------------------------------------- #
# Preset
# --------------------------------------------------------------------------- #
printf 'Exocomplict — Web preview export\n\n'
printf '[1/5] Writing the local Web export preset (git-ignored export_presets.cfg)...\n'
if ! "$PYTHON_BIN" "$ROOT_DIR/tools/web_preset.py" ensure --repo-root "$ROOT_DIR" \
  --preset-file "$GAME_DIR/export_presets.cfg" --preset-name "$PRESET_NAME" --export-path "$OUTPUT_DIR/index.html"; then
  printf 'ERROR: could not prepare the Web preset.\n' >&2
  exit 1
fi
printf '\n[2/5] Validating the Web preset and the custom HTML shell...\n'
if ! "$PYTHON_BIN" "$ROOT_DIR/tools/web_preset.py" check --repo-root "$ROOT_DIR" \
  --preset-file "$GAME_DIR/export_presets.cfg" --preset-name "$PRESET_NAME"; then
  printf 'ERROR: the Web preset is not valid for a static-server preview.\n' >&2
  printf 'Fix the FAIL lines above (or pass --allow-threads to web_preset.py check if you serve COOP/COEP headers).\n' >&2
  exit 1
fi

# --------------------------------------------------------------------------- #
# Godot
# --------------------------------------------------------------------------- #
GODOT=""
for candidate in "${GODOT_BIN:-}" godot godot4; do
  [[ -z "$candidate" ]] && continue
  if command -v "$candidate" >/dev/null 2>&1; then
    GODOT="$(command -v "$candidate")"
    break
  fi
done
if [[ -z "$GODOT" ]]; then
  printf 'ERROR: Godot editor/CLI not found.\n' >&2
  printf 'Install the pinned build (./scripts/install_godot.sh --with-templates) or set GODOT_BIN.\n' >&2
  printf 'On a machine without Godot you can instead download the CI artifact — see WEB_PREVIEW.md.\n' >&2
  exit 127
fi

GODOT_VERSION="$("$GODOT" --version 2>&1 | head -n 1)"
if [[ "${SKIP_VERSION_CHECK:-0}" != "1" && "$GODOT_VERSION" != "$EXPECTED_VERSION"* ]]; then
  printf 'ERROR: Godot version mismatch: expected %s.x, found %s\n' "$EXPECTED_VERSION" "$GODOT_VERSION" >&2
  exit 2
fi
printf '\n[3/5] Godot %s\n' "$GODOT_VERSION"

if (( DO_IMPORT == 1 )); then
  printf '      importing project and asset dependencies (headless editor)...\n'
  if ! "$GODOT" --headless --editor --path "$GAME_DIR" --quit >"$ROOT_DIR/exports/web-import.log" 2>&1; then
    printf 'ERROR: headless import failed; see exports/web-import.log\n' >&2
    tail -n 20 "$ROOT_DIR/exports/web-import.log" >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------- #
# Export
# --------------------------------------------------------------------------- #
mkdir -p "$OUTPUT_DIR"
printf '\n[4/5] Exporting preset "%s" (%s) to %s ...\n' "$PRESET_NAME" "${EXPORT_MODE#--export-}" "${OUTPUT_DIR#"$ROOT_DIR"/}"
mkdir -p "$ROOT_DIR/exports"
export_log="$ROOT_DIR/exports/web-export.log"
if ! "$GODOT" --headless --path "$GAME_DIR" "$EXPORT_MODE" "$PRESET_NAME" "$OUTPUT_DIR/index.html" >"$export_log" 2>&1; then
  printf 'ERROR: web export failed; see exports/web-export.log\n' >&2
  tail -n 25 "$export_log" >&2
  printf '\nCommon causes: web export templates missing (run ./scripts/install_godot.sh --with-templates)\n' >&2
  printf 'or a preset/platform mismatch (see tools/web_preset.py check output above).\n' >&2
  exit 1
fi

# --------------------------------------------------------------------------- #
# Verify
# --------------------------------------------------------------------------- #
printf '\n[5/5] Verifying the exported build...\n'
if ! "$PYTHON_BIN" "$ROOT_DIR/tools/verify_web_build.py" "$OUTPUT_DIR"; then
  printf 'ERROR: build verification failed; the output is not publishable as a preview.\n' >&2
  exit 1
fi

printf '\nWeb preview ready.\n'
printf 'Serve the repository root and open the preview page:\n\n'
printf '  python -m http.server 800 --bind 0.0.0.0\n'
printf '  -> http://localhost:800/            (game page, loads ./web/)\n'
# Only advertise the raw build when it actually sits under the repository root, so
# an absolute --output does not print a nonsense URL.
if [[ "$OUTPUT_DIR" == "$ROOT_DIR"/* ]]; then
  printf '  -> http://localhost:800/%s/index.html  (raw Godot page)\n\n' "${OUTPUT_DIR#"$ROOT_DIR"/}"
else
  printf '  (this run wrote the build outside the repository: %s)\n\n' "$OUTPUT_DIR"
fi
printf 'From another device on the same network use http://<your-ip>:800/ .\n'
printf 'Details, limitations, and troubleshooting: WEB_PREVIEW.md\n'
