#!/usr/bin/env bash
# Prepare and verify the JDK + Android SDK toolchain for a Exocomplict
# Android build. The script never writes inside this repository: environment
# files go to ~/.local/share/exocomplict/ and SDK packages are installed
# by the SDK's own sdkmanager into your Android SDK directory.
#
# Usage:
#   scripts/setup_android_sdk.sh                 # detect, verify, write env file
#   scripts/setup_android_sdk.sh --install-packages   # also install SDK packages
#   scripts/setup_android_sdk.sh --guide         # print the full manual runbook
#   scripts/setup_android_sdk.sh --env-file /tmp/android-env.sh
#
# Environment overrides:
#   JAVA_HOME              existing JDK 17+ installation
#   ANDROID_SDK_ROOT       existing Android SDK directory
#   ANDROID_SDK_PLATFORM   SDK platform package (default: android-36)
#   ANDROID_BUILD_TOOLS    build-tools package  (default: 36.0.0)
#   ANDROID_ENV_FILE       where android-env.sh is written
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/exocomplict"
ENV_FILE="${ANDROID_ENV_FILE:-$TOOLS_DIR/android-env.sh}"
SDK_PLATFORM="${ANDROID_SDK_PLATFORM:-android-36}"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-36.0.0}"
INSTALL_PACKAGES=0
GUIDE=0

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# > 0 )); do
  case "$1" in
    --install-packages) INSTALL_PACKAGES=1 ;;
    --guide) GUIDE=1 ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift
      ;;
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

print_guide() {
  cat <<'GUIDE'
Manual Android toolchain setup for Exocomplict
=====================================================

1. Godot editor + export templates (pinned 4.7.2)
     ./scripts/install_godot.sh --with-templates

2. JDK 17 or newer (Godot's Android export requires a compatible JDK)
     Debian/Ubuntu : sudo apt-get install -y openjdk-17-jdk
     Fedora        : sudo dnf install -y java-17-openjdk-devel
     Arch          : sudo pacman -S jdk17-openjdk
     macOS (brew)  : brew install --cask temurin@17
     Windows       : install Temurin 17 (or newer) and set JAVA_HOME
   Verify: java -version  (must print 17 or newer)

3. Android SDK command-line tools (no Android Studio required)
     a. Download "Command line tools only" from
        https://developer.android.com/studio#command-line-tools-only
     b. Unpack so that the SDK looks like this:
          $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager
     c. Accept licenses and install packages:
          "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses
          "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" \
            "platform-tools" "platforms;android-36" "build-tools;36.0.0"
        Use the exact platform/build-tools versions your pinned Godot documents;
        the Godot Export dialog reports the requirement if a package is missing.
     d. Add platform-tools to PATH so adb is available.

4. Point Godot at the toolchain (one time)
     Editor > Editor Settings > Export > Android:
       Android SDK Path     -> $ANDROID_SDK_ROOT
       Java SDK Path        -> your JDK directory (JAVA_HOME)
     The debug keystore is created automatically by Godot on first export.

5. Create/verify the local Android export preset (git-ignored)
     python3 tools/android_preset.py scaffold --package-id com.yourstudio.exocomplict
     python3 tools/android_preset.py check

6. Build, install, and profile
     ./scripts/export_android_debug.sh
     adb install -r exports/exocomplict-debug.apk
     adb shell monkey -p com.yourstudio.exocomplict -c android.intent.category.LAUNCHER 1
     adb logcat -s godot:V

See ANDROID_BASELINE.md for the full gate-E runbook, device test procedure, and
the profiling checklist.
GUIDE
}

if (( GUIDE == 1 )); then
  print_guide
  exit 0
fi

printf 'Exocomplict — Android toolchain setup\n\n'
FAILURES=0

# --------------------------------------------------------------------------- #
# JDK
# --------------------------------------------------------------------------- #
java_bin=""
if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
  java_bin="${JAVA_HOME}/bin/java"
elif command -v java >/dev/null 2>&1; then
  java_bin="$(command -v java)"
fi

java_major=""
if [[ -n "$java_bin" ]]; then
  java_first_line="$("$java_bin" -version 2>&1 | head -n 1)"
  java_major="$(printf '%s' "$java_first_line" | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')"
  if [[ -z "$java_major" ]]; then
    java_major="$(printf '%s' "$java_first_line" | sed -n 's/.*version "1\.\([0-9][0-9]*\).*/\1/p')"
  fi
fi

if [[ -z "$java_bin" ]]; then
  printf '[FAIL] JDK not found. Install JDK 17+ and set JAVA_HOME.\n'
  printf '       Run "%s --guide" for per-OS install commands.\n' "${BASH_SOURCE[0]##*/}"
  FAILURES=$((FAILURES + 1))
elif [[ -n "$java_major" && "$java_major" -lt 17 ]]; then
  printf '[FAIL] JDK %s detected at %s; Godot Android export needs JDK 17 or newer.\n' "$java_major" "$java_bin"
  FAILURES=$((FAILURES + 1))
else
  printf '[ OK ] JDK: %s (%s)\n' "$("$java_bin" -version 2>&1 | head -n 1)" "$java_bin"
fi

# --------------------------------------------------------------------------- #
# Android SDK
# --------------------------------------------------------------------------- #
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" ]]; then
  for candidate in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "$HOME/AppData/Local/Android/Sdk"; do
    if [[ -d "$candidate" ]]; then
      sdk_root="$candidate"
      break
    fi
  done
fi

sdkmanager=""
if [[ -n "$sdk_root" && -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ]]; then
  sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
elif [[ -n "$sdk_root" && -x "$sdk_root/tools/bin/sdkmanager" ]]; then
  sdkmanager="$sdk_root/tools/bin/sdkmanager"
elif command -v sdkmanager >/dev/null 2>&1; then
  sdkmanager="$(command -v sdkmanager)"
fi

if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  printf '[FAIL] Android SDK not found. Set ANDROID_SDK_ROOT (or install the command-line tools).\n'
  printf '       Run "%s --guide" for the download and layout steps.\n' "${BASH_SOURCE[0]##*/}"
  FAILURES=$((FAILURES + 1))
else
  printf '[ OK ] Android SDK root: %s\n' "$sdk_root"
  if [[ -x "$sdk_root/platform-tools/adb" ]]; then
    printf '[ OK ] adb: %s\n' "$sdk_root/platform-tools/adb"
  elif command -v adb >/dev/null 2>&1; then
    printf '[ OK ] adb on PATH: %s\n' "$(command -v adb)"
  else
    printf '[WARN] platform-tools/adb missing; install the "platform-tools" SDK package.\n'
  fi
  if [[ -n "$sdkmanager" ]]; then
    printf '[ OK ] sdkmanager: %s\n' "$sdkmanager"
  else
    printf '[WARN] sdkmanager not found; install "cmdline-tools" under %s\n' "$sdk_root"
  fi
fi

if (( INSTALL_PACKAGES == 1 )); then
  if [[ -z "$sdkmanager" ]]; then
    printf '[FAIL] --install-packages needs sdkmanager; see --guide.\n'
    FAILURES=$((FAILURES + 1))
  else
    printf '\nAccepting SDK licenses (interactive prompt may appear)...\n'
    set +e
    yes | "$sdkmanager" --licenses >/dev/null 2>&1
    set -e
    printf 'Installing packages: platform-tools, platforms;%s, build-tools;%s\n' "$SDK_PLATFORM" "$BUILD_TOOLS"
    if "$sdkmanager" "platform-tools" "platforms;$SDK_PLATFORM" "build-tools;$BUILD_TOOLS"; then
      printf '[ OK ] SDK packages installed.\n'
    else
      printf '[FAIL] sdkmanager failed. Check the package names for your Godot version.\n'
      FAILURES=$((FAILURES + 1))
    fi
  fi
fi

# --------------------------------------------------------------------------- #
# Environment file
# --------------------------------------------------------------------------- #
if [[ -n "$sdk_root" || -n "${JAVA_HOME:-}" ]]; then
  mkdir -p "$(dirname "$ENV_FILE")"
  {
    printf '# Generated by scripts/setup_android_sdk.sh — source this before Godot Android work.\n'
    [[ -n "$sdk_root" ]] && printf 'export ANDROID_SDK_ROOT="%s"\n' "$sdk_root"
    [[ -n "$sdk_root" ]] && printf 'export ANDROID_HOME="$ANDROID_SDK_ROOT"\n'
    [[ -n "$sdk_root" ]] && printf 'export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"\n'
    if [[ -n "${JAVA_HOME:-}" ]]; then
      printf 'export JAVA_HOME="%s"\n' "$JAVA_HOME"
    elif [[ -n "$java_bin" ]]; then
      printf '# JAVA_HOME was not set; derive it from the java binary if this build needs it.\n'
      printf '# export JAVA_HOME="/path/to/jdk"\n'
    fi
  } > "$ENV_FILE"
  printf '\nEnvironment file written: %s\n' "$ENV_FILE"
  printf 'Load it in each shell:  source "%s"\n' "$ENV_FILE"
fi

printf '\nRunning the repository preflight for confirmation...\n'
if [[ -x "$ROOT_DIR/scripts/check_toolchain.sh" ]]; then
  "$ROOT_DIR/scripts/check_toolchain.sh" || true
fi

printf '\nSetup summary: %d failure(s).\n' "$FAILURES"
if (( FAILURES > 0 )); then
  printf 'Resolve the failures above, then create the preset:\n'
  printf '  python3 tools/android_preset.py scaffold --package-id com.yourstudio.exocomplict\n'
  printf '  ./scripts/export_android_debug.sh\n'
  exit 1
fi
printf 'Toolchain looks ready. Next:\n'
printf '  python3 tools/android_preset.py scaffold --package-id com.yourstudio.exocomplict\n'
printf '  python3 tools/android_preset.py check\n'
printf '  ./scripts/export_android_debug.sh\n'
printf 'Full device test and profiling procedure: ANDROID_BASELINE.md\n'
