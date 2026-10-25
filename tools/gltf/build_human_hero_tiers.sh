#!/usr/bin/env bash
# Optimize the five real human tier meshes, apply per-mesh weights on the shared
# Robot Common skeleton, and retarget its locomotion/combat clips plus weapon transitions.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PYTHON="$ROOT/.venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing $PYTHON; create the development environment and install requirements-dev.txt first." >&2
  exit 2
fi
if [[ ! -f "$ROOT/game/assets/enemies/robot_common.glb" ]]; then
  echo "Missing Robot Common, the shared 79-joint rig and animation template." >&2
  exit 2
fi
for tier in 1 2 3 4 5; do
  source="$ROOT/source-assets/characters/human_hero_tiers/Hero_Human_T${tier}.glb"
  if [[ ! -f "$source" ]]; then
    echo "Missing preserved T${tier} source mesh: $source" >&2
    exit 2
  fi
done

if [[ ! -d "$HERE/node_modules" ]]; then
  echo "Installing glTF tooling (tools/gltf)…"
  (cd "$HERE" && npm ci --no-audit --no-fund)
fi

node "$HERE/prepare_human_hero_tiers.mjs"
"$PYTHON" "$HERE/rig_human_hero_tiers.py"
"$PYTHON" "$HERE/retarget_human_hero_tiers.py"
node "$HERE/prepare_human_hero_tiers.mjs" --check
"$PYTHON" "$HERE/rig_human_hero_tiers.py" --check
"$PYTHON" "$HERE/retarget_human_hero_tiers.py" --check
