#!/usr/bin/env bash
# Read-only preflight for Exocomplict development tools.
# Does not install tools, write project files, or change tool versions.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0
WARNINGS=0

ok()   { printf '  [OK]   %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

find_command() {
  local candidate
  for candidate in "$@"; do
    if [[ -n "$candidate" ]] && command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

printf 'Exocomplict toolchain preflight\n'
printf 'Repository: %s\n\n' "$ROOT_DIR"

# Version control is required for every phase.
if command -v git >/dev/null 2>&1; then
  ok "Git: $(git --version)"
else
  fail 'Git was not found on PATH.'
fi

# Godot editor/CLI is required for Phase 0. Standard (non-.NET) Godot 4.x is the plan.
godot_bin=""
if [[ -n "${GODOT_BIN:-}" ]] && command -v "$GODOT_BIN" >/dev/null 2>&1; then
  godot_bin="$(command -v "$GODOT_BIN")"
else
  godot_bin="$(find_command godot godot4 || true)"
fi
if [[ -n "$godot_bin" ]]; then
  godot_version="$("$godot_bin" --version 2>&1 | head -n 1 || true)"
  godot_help="$("$godot_bin" --help 2>&1 || true)"
  expected_godot_version="${EXPECTED_GODOT_VERSION:-}"
  if [[ -z "$expected_godot_version" && -f "$ROOT_DIR/.godot-version" ]]; then
    expected_godot_version="$(tr -d '[:space:]' < "$ROOT_DIR/.godot-version")"
  fi
  expected_godot_version="${expected_godot_version:-4.7.2}"
  if [[ "$godot_version" == "$expected_godot_version"* ]]; then
    if grep -Fq 'this build = editor' <<< "$godot_help"; then
      ok "Godot Editor baseline $expected_godot_version: $godot_version ($godot_bin)"
    elif grep -Fq 'this build = debug export template' <<< "$godot_help" \
      || grep -Fq 'this build = release export template' <<< "$godot_help"; then
      fail "Godot $godot_version ditemukan sebagai export template, bukan Editor. Template dapat menjalankan game, tetapi Phase 0 memerlukan build Editor ($godot_bin)."
    else
      warn "Godot $godot_version ditemukan, tetapi jenis build tidak dapat diverifikasi sebagai Editor. Pastikan ini build Standard Editor, bukan export template."
    fi
  elif [[ "$godot_version" == 4.* ]]; then
    warn "Godot $godot_version tersedia, tetapi baseline proyek $expected_godot_version. Cocokkan editor/export templates atau perbarui pin secara sengaja."
  else
    fail "Godot ditemukan, tetapi versi tidak tampak 4.x ('$godot_version'). Periksa versi proyek yang dipin."
  fi
else
  fail 'Godot 4.7.2-stable editor/CLI tidak ditemukan. Install build Standard dan export templates versi yang sama.'
fi

# Android export requires a compatible JDK and SDK. Resolve Java via JAVA_HOME first.
java_bin=""
if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
  java_bin="${JAVA_HOME}/bin/java"
else
  java_bin="$(find_command java || true)"
fi
if [[ -n "$java_bin" ]]; then
  java_version="$("$java_bin" -version 2>&1 | head -n 1 || true)"
  ok "Java ditemukan: $java_version ($java_bin); kompatibilitas tetap harus dicocokkan dengan Godot yang dipilih."
else
  fail 'Java/JDK tidak ditemukan. Diperlukan untuk Android export sesuai versi Godot yang dipilih.'
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -n "$sdk_root" && -d "$sdk_root" ]]; then
  ok "Android SDK root ditemukan: $sdk_root"
  if [[ -x "$sdk_root/platform-tools/adb" ]]; then
    ok "ADB ditemukan di SDK: $sdk_root/platform-tools/adb"
  elif command -v adb >/dev/null 2>&1; then
    ok "ADB tersedia di PATH: $(command -v adb)"
  else
    warn 'SDK ditemukan, tetapi adb/platform-tools tidak ditemukan; diperlukan untuk deploy dan debug perangkat.'
  fi
  if [[ -d "$sdk_root/platforms" && -d "$sdk_root/build-tools" ]]; then
    ok 'Folder SDK platforms dan build-tools tersedia; pastikan versinya cocok dengan Godot/target Play.'
  else
    warn 'Folder SDK platforms/build-tools belum ditemukan; pasang paket yang diminta dokumentasi versi Godot.'
  fi
else
  fail 'ANDROID_SDK_ROOT/ANDROID_HOME tidak menunjuk ke Android SDK yang ada. Diperlukan untuk Android export.'
fi

# Blender and Git LFS are needed later, not to open this docs-only checkout.
blender_bin=""
if [[ -n "${BLENDER_BIN:-}" ]] && command -v "$BLENDER_BIN" >/dev/null 2>&1; then
  blender_bin="$(command -v "$BLENDER_BIN")"
else
  blender_bin="$(find_command blender || true)"
fi
if [[ -n "$blender_bin" ]]; then
  blender_version="$("$blender_bin" --version 2>&1 | head -n 1 || true)"
  ok "Blender tersedia: $blender_version ($blender_bin)"
else
  warn 'Blender belum ditemukan. Perlu sebelum pembuatan/validasi aset 3D final; boleh ditunda untuk greybox.'
fi

if git lfs version >/dev/null 2>&1; then
  ok "Git LFS tersedia: $(git lfs version)"
else
  warn 'Git LFS belum ditemukan. Pertimbangkan memasangnya sebelum aset biner besar ditambahkan.'
fi

if [[ -f "$ROOT_DIR/project.godot" || -f "$ROOT_DIR/game/project.godot" ]]; then
  ok 'project.godot ditemukan.'
else
  warn 'project.godot belum ada. Ini repository dokumen; bootstrap project Godot adalah pekerjaan Phase 0.'
fi

printf '\nRingkasan: %d fail, %d warning.\n' "$FAILURES" "$WARNINGS"
if (( FAILURES > 0 )); then
  printf 'Selesaikan tool Android/Godot yang ditandai FAIL sebelum menyatakan Phase 0 siap.\n'
  exit 1
fi
printf 'Tool wajib yang dicek tersedia. Verifikasi export template dan build di perangkat tetap diperlukan.\n'
