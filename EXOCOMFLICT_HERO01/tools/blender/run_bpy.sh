#!/usr/bin/env bash
# Run Blender 4.5 LTS (bpy wheel) headless inside the sandbox.
# Sandbox lacks system X/GL libs; stubs/ contains minimal symbol-only stub
# libraries (libGL/libXi/libXfixes/libXrender/libICE/libSM/libXt +
# version-scripted libxkbcommon V_0.5.0) so the bpy module can dlopen.
# They are never called in background mode and do not affect asset data.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
export LD_LIBRARY_PATH="$HERE/stubs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$REPO/.venv/bin/python" "$@"
