#!/usr/bin/env bash
# run_verify.sh — import the forged GLBs in the real engine and verify them.
#
# Requires a Godot 4.x binary on PATH (or GODOT=/path/to/godot). The binary is
# NOT vendored in this repository, and the sandbox this forge was developed in
# could not download one, so this script is the step that has to run on a
# machine that has the engine. Nothing here is a substitute for running it.
#
#   tools/asset-forge/godot/run_verify.sh
#   GODOT=/opt/godot4 tools/asset-forge/godot/run_verify.sh
#
# Exit codes: 0 every asset imported and matched its manifest
#             1 verification failed (see the printed failures)
#             2 the engine or the staged assets are missing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
STAGE="$ROOT/game/verify_import.gd"

if [[ -z "$GODOT" ]]; then
  echo "✗ no Godot binary found. Install Godot 4.x or set GODOT=/path/to/godot" >&2
  echo "  (the project targets Godot 4.7.2 — see TOOLCHAIN_SETUP.md)" >&2
  exit 2
fi

if [[ ! -f "$ROOT/game/assets/forge/forge_manifest.json" ]]; then
  echo "✗ game/assets/forge/forge_manifest.json missing — run:" >&2
  echo "    node tools/asset-forge/gate/run_gate.mjs      # export the GLBs" >&2
  echo "    node tools/asset-forge/gate/stage_into_game.mjs  # copy + manifest" >&2
  exit 2
fi

echo "engine: $("$GODOT" --version)"
cp "$ROOT/tools/asset-forge/godot/verify_import.gd" "$STAGE"
trap 'rm -f "$STAGE"' EXIT

echo "— import step (first run builds .import + .godot cache)"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || {
  echo "✗ import step failed; re-run without >/dev/null to see engine output" >&2
  exit 1
}

echo "— verifying"
set +e
"$GODOT" --headless --path "$ROOT/game" --script res://verify_import.gd
status=$?
set -e
exit $status
