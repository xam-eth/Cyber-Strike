#!/usr/bin/env bash
# Rebuild the runtime hero and rifle from the source GLBs, then bake the
# aim/fire clips. The order is not optional: build_clips.py refuses to run on a
# file that already contains baked clips (the replaced accessors would stay in
# the BIN chunk), so prepare_assets.mjs must regenerate hero.glb first.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

if [[ ! -d "$HERE/node_modules" ]]; then
  echo "Installing glTF tooling (tools/gltf)…"
  (cd "$HERE" && npm ci --no-audit --no-fund)
fi

node "$HERE/prepare_assets.mjs"
"$ROOT/.venv/bin/python" "$HERE/build_clips.py"
"$ROOT/.venv/bin/python" "$HERE/build_clips.py" --check
