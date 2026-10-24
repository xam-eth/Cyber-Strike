#!/usr/bin/env bash
# Install the pinned Godot editor build (and optionally the matching export
# templates) into the user's home directory — never into this repository.
#
# Usage:
#   scripts/install_godot.sh                    # install the pinned editor build
#   scripts/install_godot.sh --with-templates   # also install export templates
#   scripts/install_godot.sh --dry-run          # print the plan only
#   scripts/install_godot.sh --version 4.7.2 --install-dir "$HOME/godot-tools"
#
# Environment:
#   GODOT_VERSION        version to install           (default: .godot-version)
#   GODOT_RELEASE_BASE   release download base URL    (default: GitHub releases)
#   GODOT_INSTALL_DIR    install root                 (default: ~/.local/share/project-overdrive/godot)
#   GODOT_BIN_DIR        directory for the `godot` symlink (default: ~/.local/bin)
#   GODOT_SKIP_CHECKSUM  1 = do not fail when SHA512-SUMS.txt cannot be fetched
#
# The script downloads and verifies the official archive, extracts it outside
# the repository, and links `godot` into a user bin directory. Android export
# still needs JDK + Android SDK; this script only prepares the engine.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_VERSION="4.7.2"
if [[ -f "$ROOT_DIR/.godot-version" ]]; then
  DEFAULT_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/.godot-version")"
fi

VERSION="${GODOT_VERSION:-$DEFAULT_VERSION}"
RELEASE_BASE="${GODOT_RELEASE_BASE:-https://github.com/godotengine/godot/releases/download}"
INSTALL_ROOT="${GODOT_INSTALL_DIR:-$HOME/.local/share/project-overdrive/godot}"
BIN_DIR="${GODOT_BIN_DIR:-$HOME/.local/bin}"
WITH_TEMPLATES=0
DRY_RUN=0
FORCE=0

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# > 0 )); do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift
      ;;
    --install-dir)
      INSTALL_ROOT="${2:-}"
      shift
      ;;
    --bin-dir)
      BIN_DIR="${2:-}"
      shift
      ;;
    --with-templates) WITH_TEMPLATES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$VERSION" || -z "$INSTALL_ROOT" || -z "$BIN_DIR" ]]; then
  printf 'ERROR: --version, --install-dir and --bin-dir need non-empty values.\n' >&2
  exit 2
fi

RELEASE_DIR="$RELEASE_BASE/$VERSION-stable"

# --------------------------------------------------------------------------- #
# Platform detection
# --------------------------------------------------------------------------- #
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64 | amd64) PLATFORM_ASSET="linux.x86_64"; BINARY_REL="Godot_v${VERSION}-stable_linux.x86_64" ;;
      aarch64 | arm64) PLATFORM_ASSET="linux.arm64"; BINARY_REL="Godot_v${VERSION}-stable_linux.arm64" ;;
      armv7l) PLATFORM_ASSET="linux.arm32"; BINARY_REL="Godot_v${VERSION}-stable_linux.arm32" ;;
      i686 | i386) PLATFORM_ASSET="linux.x86_32"; BINARY_REL="Godot_v${VERSION}-stable_linux.x86_32" ;;
      *)
        printf 'ERROR: unsupported Linux architecture: %s\n' "$ARCH" >&2
        exit 2
        ;;
    esac
    TEMPLATES_OS="linux"
    ;;
  Darwin)
    PLATFORM_ASSET="macos.universal"
    BINARY_REL="Godot.app/Contents/MacOS/Godot"
    TEMPLATES_OS="macos"
    ;;
  MINGW* | MSYS* | CYGWIN* | Windows_NT)
    printf 'ERROR: on Windows, download Godot_v%s-stable_win64.exe.zip from:\n' "$VERSION" >&2
    printf '  %s/Godot_v%s-stable_win64.exe.zip\n' "$RELEASE_DIR" "$VERSION" >&2
    printf 'Then unpack it next to the project and run the CLI with that .exe as GODOT_BIN.\n' >&2
    exit 2
    ;;
  *)
    printf 'ERROR: unsupported operating system: %s\n' "$OS" >&2
    exit 2
    ;;
esac

EDITOR_ZIP="Godot_v${VERSION}-stable_${PLATFORM_ASSET}.zip"
EDITOR_URL="$RELEASE_DIR/$EDITOR_ZIP"
CHECKSUM_URL="$RELEASE_DIR/SHA512-SUMS.txt"
TEMPLATES_ZIP="Godot_v${VERSION}-stable_export_templates.tpz"
TEMPLATES_URL="$RELEASE_DIR/$TEMPLATES_ZIP"
TARGET_DIR="$INSTALL_ROOT/godot-$VERSION-stable"
TARGET_BINARY="$TARGET_DIR/$BINARY_REL"
GODOT_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot"
TEMPLATE_DIR="$GODOT_DATA_DIR/export_templates/${VERSION}.stable"

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
DOWNLOADER=""
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
else
  printf 'ERROR: neither curl nor wget is available for downloading Godot.\n' >&2
  exit 2
fi

download() {
  local url="$1" destination="$2"
  if [[ "$DOWNLOADER" == "curl" ]]; then
    curl -fsSL --retry 3 -o "$destination" "$url"
  else
    wget -q -O "$destination" "$url"
  fi
}

sha512_of() {
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 512 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha512 "$1" | awk '{print $NF}'
  else
    printf ''
  fi
}

extract_zip() {
  local archive="$1" destination="$2"
  mkdir -p "$destination"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$archive" -d "$destination"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
      "$archive" "$destination"
  else
    printf 'ERROR: need unzip or python3 to extract %s\n' "$archive" >&2
    return 1
  fi
}

# --------------------------------------------------------------------------- #
# Plan
# --------------------------------------------------------------------------- #
printf 'Project Overdrive — Godot installer\n'
printf 'Version:     %s-stable\n' "$VERSION"
printf 'Platform:    %s/%s → %s\n' "$OS" "$ARCH" "$EDITOR_ZIP"
printf 'Editor URL:  %s\n' "$EDITOR_URL"
printf 'Install to:  %s\n' "$TARGET_DIR"
printf 'Symlink:     %s/godot\n' "$BIN_DIR"
if (( WITH_TEMPLATES == 1 )); then
  printf 'Templates:   %s → %s\n' "$TEMPLATES_ZIP" "$TEMPLATE_DIR"
fi
printf '\n'

if (( DRY_RUN == 1 )); then
  printf 'Dry run: nothing downloaded or written.\n'
  exit 0
fi

if [[ -x "$TARGET_BINARY" && "$FORCE" != "1" ]]; then
  printf 'Godot %s is already installed at %s\n' "$VERSION" "$TARGET_BINARY"
  printf 'Use --force to reinstall.\n'
  "$TARGET_BINARY" --version 2>&1 | head -n 1
  exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# --------------------------------------------------------------------------- #
# Editor download, checksum, extraction
# --------------------------------------------------------------------------- #
printf 'Downloading editor archive...\n'
if ! download "$EDITOR_URL" "$WORK_DIR/$EDITOR_ZIP"; then
  printf 'ERROR: download failed: %s\n' "$EDITOR_URL" >&2
  printf 'Check network/proxy access to the release host, or set GODOT_RELEASE_BASE to a mirror.\n' >&2
  exit 1
fi
printf '  %s (%s bytes)\n' "$EDITOR_ZIP" "$(wc -c < "$WORK_DIR/$EDITOR_ZIP" | tr -d ' ')"

printf 'Verifying SHA-512 checksum...\n'
if download "$CHECKSUM_URL" "$WORK_DIR/SHA512-SUMS.txt" 2>/dev/null; then
  expected="$(awk -v name="$EDITOR_ZIP" '{ file=$2; sub(/^\*/, "", file); sub(/^\.\//, "", file); if (file == name) { print $1; exit } }' "$WORK_DIR/SHA512-SUMS.txt")"
  actual="$(sha512_of "$WORK_DIR/$EDITOR_ZIP")"
  if [[ -z "$expected" ]]; then
    printf '  WARNING: %s is not listed in SHA512-SUMS.txt; cannot verify.\n' "$EDITOR_ZIP"
  elif [[ -z "$actual" ]]; then
    printf '  WARNING: no sha512sum/shasum/openssl available; skipping verification.\n'
  elif [[ "$expected" != "$actual" ]]; then
    printf 'ERROR: checksum mismatch for %s\n  expected %s\n  actual   %s\n' \
      "$EDITOR_ZIP" "$expected" "$actual" >&2
    exit 1
  else
    printf '  checksum ok\n'
  fi
else
  printf '  WARNING: could not fetch SHA512-SUMS.txt; skipping verification.\n'
  if [[ "${GODOT_SKIP_CHECKSUM:-0}" != "1" ]]; then
    printf '  Set GODOT_SKIP_CHECKSUM=1 to accept this silently, or verify the archive manually.\n'
  fi
fi

printf 'Extracting editor...\n'
if ! extract_zip "$WORK_DIR/$EDITOR_ZIP" "$WORK_DIR/editor"; then
  printf 'ERROR: extraction failed.\n' >&2
  exit 1
fi
mkdir -p "$TARGET_DIR"
cp -R "$WORK_DIR/editor/." "$TARGET_DIR/"
if [[ ! -e "$TARGET_BINARY" ]]; then
  printf 'ERROR: expected binary not found after extraction: %s\n' "$TARGET_BINARY" >&2
  printf 'Extracted tree:\n' >&2
  find "$TARGET_DIR" -maxdepth 2 -mindepth 1 | sed 's/^/  /' >&2
  exit 1
fi
chmod +x "$TARGET_BINARY" 2>/dev/null || true

installed_version="$("$TARGET_BINARY" --version 2>&1 | head -n 1)"
if [[ "$installed_version" != "$VERSION"* ]]; then
  printf 'ERROR: installed binary reports "%s", expected %s.x\n' "$installed_version" "$VERSION" >&2
  exit 1
fi
printf '  editor ready: %s (%s)\n' "$installed_version" "$TARGET_BINARY"

mkdir -p "$BIN_DIR"
ln -sf "$TARGET_BINARY" "$BIN_DIR/godot"
printf '  symlink: %s/godot\n' "$BIN_DIR"

# --------------------------------------------------------------------------- #
# Optional export templates
# --------------------------------------------------------------------------- #
if (( WITH_TEMPLATES == 1 )); then
  printf 'Downloading export templates (%s, ~1.2 GB)...\n' "$TEMPLATES_OS"
  if ! download "$TEMPLATES_URL" "$WORK_DIR/$TEMPLATES_ZIP"; then
    printf 'ERROR: template download failed: %s\n' "$TEMPLATES_URL" >&2
    exit 1
  fi
  printf 'Extracting templates...\n'
  if ! extract_zip "$WORK_DIR/$TEMPLATES_ZIP" "$WORK_DIR/templates"; then
    printf 'ERROR: template extraction failed.\n' >&2
    exit 1
  fi
  mkdir -p "$TEMPLATE_DIR"
  if [[ -d "$WORK_DIR/templates/templates" ]]; then
    cp -R "$WORK_DIR/templates/templates/." "$TEMPLATE_DIR/"
  else
    cp -R "$WORK_DIR/templates/." "$TEMPLATE_DIR/"
  fi
  template_count="$(find "$TEMPLATE_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  printf '  %s template file(s) installed in %s\n' "$template_count" "$TEMPLATE_DIR"
fi

# --------------------------------------------------------------------------- #
# Report
# --------------------------------------------------------------------------- #
printf '\nInstall complete.\n'
printf 'Add the symlink directory to PATH if needed:\n'
printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
printf 'Then verify and run:\n'
printf '  godot --version\n'
printf '  ./scripts/check_toolchain.sh\n'
printf '  ./scripts/run_smoke_tests.sh\n'
printf '\nAndroid export additionally needs a JDK and the Android SDK (platform-tools,\n'
printf 'build-tools, one SDK platform) plus a local Android export preset — see TOOLCHAIN_SETUP.md.\n'
