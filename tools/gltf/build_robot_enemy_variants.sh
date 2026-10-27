#!/usr/bin/env bash
# Build the Rare/Epic robot enemy GLBs from preserved source models and retarget Robot Common's
# runtime animation set onto each skeleton. This intentionally leaves the Robot Common
# enemy model and every preserved source asset untouched.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PYTHON="$ROOT/.venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing $PYTHON; create the development environment and install requirements-dev.txt first." >&2
  exit 2
fi
if [[ ! -f "$ROOT/game/assets/enemies/enemy_robot_common.glb" ]]; then
  echo "Missing the Robot Common runtime GLB required as the retarget source." >&2
  exit 2
fi
for source in \
  "$ROOT/source-assets/enemies/enemy_robot_tier_2_rare_source.glb" \
  "$ROOT/source-assets/enemies/enemy_robot_tier_3_epic_source.glb"; do
  if [[ ! -f "$source" ]]; then
    echo "Missing preserved robot enemy source: $source" >&2
    exit 2
  fi
done

if [[ ! -d "$HERE/node_modules" ]]; then
  echo "Installing glTF tooling (tools/gltf)…"
  (cd "$HERE" && npm ci --no-audit --no-fund)
fi

node "$HERE/prepare_robot_enemy_variants.mjs"
"$PYTHON" "$HERE/retarget_robot_enemy_variants.py"
node "$HERE/prepare_robot_enemy_variants.mjs" --check
"$PYTHON" "$HERE/retarget_robot_enemy_variants.py" --check
