#!/usr/bin/env bash
# Capture native Android visual evidence from an already installed application.
# This does not build/install, hot-reload, clear data, or measure performance.
#
#   scripts/android_visual.sh shot --label hud-safe-area
#   scripts/android_visual.sh record --seconds 30 --label reload-animation
#   scripts/android_visual.sh shot --serial SERIAL_HP --launch
#
# See docs/runbooks/ANDROID.md for the remote-development and review workflow.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi
exec "$PYTHON_BIN" "$ROOT_DIR/tools/android_visual.py" "$@"
