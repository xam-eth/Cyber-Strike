#!/usr/bin/env bash
# Optimize the supplied static enemy GLBs, then apply the Common hero rig to
# each mesh. Enemy-specific animations can be authored later on the shared rig.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PYTHON="$ROOT/.venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing $PYTHON; create the development environment and install requirements-dev.txt first." >&2
  exit 2
fi
if [[ ! -f "$ROOT/game/assets/characters/hero/hero.glb" ]]; then
  echo "Missing the Common runtime hero GLB used as the shared rig template." >&2
  exit 2
fi
for source in \
  "$ROOT/source-assets/enemies/iron-sentinel-enimies.glb" \
  "$ROOT/source-assets/enemies/Iron-Warnden-Bos-enimies.glb"; do
  if [[ ! -f "$source" ]]; then
    echo "Missing preserved enemy source: $source" >&2
    exit 2
  fi
done

if [[ ! -d "$HERE/node_modules" ]]; then
  echo "Installing glTF tooling (tools/gltf)…"
  (cd "$HERE" && npm ci --no-audit --no-fund)
fi

node "$HERE/prepare_enemy_models.mjs"
"$PYTHON" "$HERE/rig_enemy_models.py"
node "$HERE/prepare_enemy_models.mjs" --check
"$PYTHON" "$HERE/rig_enemy_models.py" --check
