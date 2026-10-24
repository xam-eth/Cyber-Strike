#!/usr/bin/env bash
# Rebuild the pinned Godot 4.7.2 editor that every script in this repository
# expects on PATH.
#
# Nothing about the toolchain is installed by the OS package manager here, and
# a fresh environment (or a sandbox reset) drops everything outside the working
# tree: the engine binary, scons, gdtoolkit and the npm packages under tools/.
# This script is the recorded answer, so the next person does not have to
# reconstruct it from a commit message.
#
# Usage:
#   scripts/rebuild_toolchain.sh          # build the engine and put it on PATH
#   scripts/rebuild_toolchain.sh --tools  # only the Python and npm dev tools
#
# Environment:
#   GODOT_VERSION   engine tag to build (default: 4.7.2-stable)
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
BUILD_DIR="${GODOT_BUILD_DIR:-/tmp/godot-$GODOT_VERSION}"
INSTALL_DIR="${GODOT_INSTALL_DIR:-/usr/local/bin}"
TOOLS_ONLY=0
[[ "${1:-}" == "--tools" ]] && TOOLS_ONLY=1

PYTHON_BIN="python3"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || { printf 'ERROR: python3 is required.\n' >&2; exit 2; }

printf '== dev tools ==\n'
# --break-system-packages because this environment has no venv set up and no
# OS packages for these; it is the same install the CI job performs in a venv.
"$PYTHON_BIN" -m pip install --quiet --break-system-packages scons gdtoolkit Pillow \
  || printf 'WARNING: pip install failed; continuing (the build needs scons).\n'

printf '== chromium for the browser QA ==\n'
if [[ -d "$ROOT_DIR/tools" ]] && command -v npm >/dev/null 2>&1; then
  (cd "$ROOT_DIR/tools" && npm install --no-audit --no-fund) \
    || printf 'WARNING: npm install failed; tools/web_qa.mjs will not run.\n'
fi

(( TOOLS_ONLY == 1 )) && { printf 'Tools only, as requested.\n'; exit 0; }

printf '== pkg-config ==\n'
# Godot's platform/linuxbsd/detect.py aborts if `pkg-config --version` fails.
# There is no package manager in this environment, and every library query it
# makes is optional (Godot falls back to the third-party copy in thirdparty/),
# so a stub that answers --version and reports "not found" for everything else
# is both sufficient and honest — it is what `x11=no wayland=no` below already
# assumes.
if ! command -v pkg-config >/dev/null 2>&1; then
  cat > "$INSTALL_DIR/pkg-config" <<'SH'
#!/bin/sh
case "$1" in
  --version) echo "0.29.2"; exit 0 ;;
  --exists) exit 1 ;;
  --cflags|--libs) exit 0 ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$INSTALL_DIR/pkg-config" 2>/dev/null \
    || printf 'WARNING: cannot write %s/pkg-config; run this as a user who can.\n' "$INSTALL_DIR"
  printf 'stub installed: %s\n' "$INSTALL_DIR/pkg-config"
else
  printf 'already present: %s\n' "$(command -v pkg-config)"
fi

printf '== engine source ==\n'
mkdir -p "$BUILD_DIR"
if [[ ! -f "$BUILD_DIR/SConstruct" ]]; then
  # release assets and raw.githubusercontent.com are not reachable from every
  # environment; the GitHub source tarball is.
  curl -sL -o "$BUILD_DIR/../godot-$GODOT_VERSION.tar.gz" \
    "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/$GODOT_VERSION" \
    && tar xzf "$BUILD_DIR/../godot-$GODOT_VERSION.tar.gz" -C "$BUILD_DIR/.." \
    || { printf 'ERROR: source download failed.\n' >&2; exit 1; }
fi

printf '== build (this takes about 30 minutes on 4 cores) ==\n'
cd "$BUILD_DIR" || exit 2
scons platform=linuxbsd target=editor arch=x86_64 "-j$(nproc)" \
  vulkan=no opengl3=yes \
  x11=no wayland=no \
  pulseaudio=no alsa=no dbus=no udev=no \
  debug_symbols=no optimize=size use_static_cpp=yes
build_status=$?
(( build_status == 0 )) || { printf 'ERROR: scons failed with %s\n' "$build_status" >&2; exit "$build_status"; }

cp "bin/godot.linuxbsd.editor.x86_64" "$INSTALL_DIR/godot"
chmod +x "$INSTALL_DIR/godot"
printf '\nGodot ready: %s\n' "$("$INSTALL_DIR/godot" --version)"

printf '\nLast step, machine-local and git-ignored:\n'
printf '  python3 tools/web_preset.py ensure\n'
printf 'Without an export preset, `godot --export-pack` exits 1 and silently\n'
printf 'leaves the previous pack in place.\n'
