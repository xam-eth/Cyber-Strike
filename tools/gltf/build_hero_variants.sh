#!/usr/bin/env bash
# Build the Rare/Epic GLBs from preserved source models and retarget Common's
# runtime animation set onto each skeleton. This intentionally leaves the Common
# model and every preserved source asset untouched.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PYTHON="$ROOT/.venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing $PYTHON; create the development environment and install requirements-dev.txt first." >&2
  exit 2
fi
if [[ ! -f "$ROOT/game/assets/characters/hero/hero.glb" ]]; then
  echo "Missing the Common runtime GLB required as the retarget source." >&2
  exit 2
fi
for source in \
  "$ROOT/source-assets/characters/hero_variants/hero_tier_2_rare.glb" \
  "$ROOT/source-assets/characters/hero_variants/hero_tier_3_epic.glb"; do
  if [[ ! -f "$source" ]]; then
    echo "Missing preserved hero source: $source" >&2
    exit 2
  fi
done

if [[ ! -d "$HERE/node_modules" ]]; then
  echo "Installing glTF tooling (tools/gltf)…"
  (cd "$HERE" && npm ci --no-audit --no-fund)
fi

node "$HERE/prepare_hero_variants.mjs"
"$PYTHON" "$HERE/retarget_hero_variants.py"
node "$HERE/prepare_hero_variants.mjs" --check
"$PYTHON" "$HERE/retarget_hero_variants.py" --check
