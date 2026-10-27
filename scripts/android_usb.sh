#!/usr/bin/env bash
# Build (optional), install, and relaunch the offline Android APK over USB.
# The APK contains the game and its assets; no web server is used on the phone.
#
# Usage:
#   scripts/android_usb.sh                         # test + build + install + launch
#   scripts/android_usb.sh --skip-build            # reinstall an existing APK
#   scripts/android_usb.sh --skip-build --no-launch
#   scripts/android_usb.sh --skip-build --logcat   # launch and follow engine logs
#   scripts/android_usb.sh --serial SERIAL_HP --profile-seconds 120
#   scripts/android_usb.sh --apk /path/to/game.apk --skip-build
#
# Environment overrides:
#   ADB_BIN, ANDROID_SERIAL, ANDROID_APK_PATH, ANDROID_PACKAGE_ID,
#   ANDROID_EXPORT_PRESET, ANDROID_PRESET_FILE, ANDROID_PROFILE_DIR, GODOT_BIN.
# --profile-seconds N records N seconds of real device evidence and writes
# report.md, summary.json, windows.csv, raw metrics, and Android dumpsys files.
# `adb install -r` preserves application data when package/signatures match.
# This is an update + process relaunch, not an in-place GDScript hot reload.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"
PRESET_NAME="${ANDROID_EXPORT_PRESET:-Android}"
PRESET_FILE="${ANDROID_PRESET_FILE:-$GAME_DIR/export_presets.cfg}"
APK_PATH="${ANDROID_APK_PATH:-$ROOT_DIR/exports/exocomplict-debug.apk}"
PACKAGE_ID="${ANDROID_PACKAGE_ID:-}"
SERIAL="${ANDROID_SERIAL:-}"
BUILD=1
LAUNCH=1
SHOW_LOGCAT=0
PROFILE_SECONDS=0
PROFILE_DIR="${ANDROID_PROFILE_DIR:-}"
CAPTURE_PID=""

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

usage() {
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# > 0 )); do
  case "$1" in
    --skip-build|--no-build) BUILD=0 ;;
    --no-launch) LAUNCH=0 ;;
    --logcat) SHOW_LOGCAT=1 ;;
    --profile-seconds)
      (( $# >= 2 )) || fail '--profile-seconds requires a positive integer.'
      [[ "$2" =~ ^[1-9][0-9]*$ ]] || fail '--profile-seconds requires a positive integer.'
      PROFILE_SECONDS="$2"
      shift
      ;;
    --profile-dir)
      (( $# >= 2 )) || fail '--profile-dir requires a directory path.'
      PROFILE_DIR="$2"
      shift
      ;;
    --serial)
      (( $# >= 2 )) || fail '--serial requires an Android device serial.'
      SERIAL="$2"
      shift
      ;;
    --apk)
      (( $# >= 2 )) || fail '--apk requires a file path.'
      APK_PATH="$2"
      shift
      ;;
    --package-id)
      (( $# >= 2 )) || fail '--package-id requires an application id.'
      PACKAGE_ID="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) fail "Unknown option: $1 (use --help for supported options)." ;;
  esac
  shift
done

if (( SHOW_LOGCAT && !LAUNCH )); then
  fail '--logcat cannot be combined with --no-launch.'
fi
if (( PROFILE_SECONDS > 0 && !LAUNCH )); then
  fail '--profile-seconds cannot be combined with --no-launch.'
fi
if (( PROFILE_SECONDS > 0 && SHOW_LOGCAT )); then
  fail 'Use either --profile-seconds or interactive --logcat, not both.'
fi
APK_PATH="$(python3 - "$APK_PATH" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser().resolve())
PY
)"

resolve_adb() {
  local candidate
  if [[ -n "${ADB_BIN:-}" ]]; then
    if [[ -x "$ADB_BIN" ]]; then
      printf '%s\n' "$ADB_BIN"
      return 0
    fi
    command -v "$ADB_BIN" 2>/dev/null && return 0
    return 1
  fi
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi
  for candidate in \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "$HOME/Android/Sdk/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "$HOME/AppData/Local/Android/Sdk/platform-tools/adb"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ADB="$(resolve_adb || true)"
[[ -n "$ADB" ]] || fail \
  'adb was not found. Set ADB_BIN or ANDROID_SDK_ROOT, or add platform-tools to PATH.'

if (( BUILD )); then
  printf 'Building the current source with the existing Android export gate...\n'
  ANDROID_APK_PATH="$APK_PATH" "$ROOT_DIR/scripts/export_android_debug.sh"
fi
[[ -s "$APK_PATH" ]] || fail "APK is missing or empty: $APK_PATH"

if [[ -z "$PACKAGE_ID" && -f "$PRESET_FILE" ]]; then
  PACKAGE_ID="$(python3 - "$ROOT_DIR" "$PRESET_FILE" "$PRESET_NAME" <<'PY'
import sys
from pathlib import Path

root, preset_file, preset_name = sys.argv[1:]
sys.path.insert(0, str(Path(root) / "tools"))
from android_preset import find_preset, parse_presets  # noqa: E402

preset = find_preset(parse_presets(Path(preset_file).read_text(encoding="utf-8")), preset_name)
if preset is None or preset.platform.lower() != "android":
    raise SystemExit(f"Android preset not found: {preset_name}")
print(preset.option("package/unique_name"))
PY
)"
fi
[[ -n "$PACKAGE_ID" ]] || fail \
  'Package id is unknown. Provide --package-id or create game/export_presets.cfg.'

DEVICE_OUTPUT="$("$ADB" devices 2>&1)" || fail "adb devices failed: $DEVICE_OUTPUT"
printf '%s\n' "$DEVICE_OUTPUT"
if [[ -n "$SERIAL" ]]; then
  SERIAL_STATE="$(awk -v serial="$SERIAL" '$1 == serial { print $2 }' <<< "$DEVICE_OUTPUT")"
  [[ "$SERIAL_STATE" == "device" ]] || fail \
    "Device '$SERIAL' is not online/authorized (state: ${SERIAL_STATE:-missing})."
else
  mapfile -t ONLINE_DEVICES < <(awk 'NR > 1 && $2 == "device" { print $1 }' <<< "$DEVICE_OUTPUT")
  if (( ${#ONLINE_DEVICES[@]} == 0 )); then
    fail 'No authorized online device. Connect USB, enable USB debugging, and accept the phone prompt.'
  elif (( ${#ONLINE_DEVICES[@]} > 1 )); then
    fail "More than one device is online. Select one with --serial <serial>."
  fi
  SERIAL="${ONLINE_DEVICES[0]}"
fi

printf '\nInstalling without clearing profile data...\n'
printf '  device:  %s\n  package: %s\n  APK:     %s\n' "$SERIAL" "$PACKAGE_ID" "$APK_PATH"
"$ADB" -s "$SERIAL" install -r "$APK_PATH"

if (( LAUNCH && PROFILE_SECONDS == 0 )); then
  printf 'Relaunching %s...\n' "$PACKAGE_ID"
  "$ADB" -s "$SERIAL" shell monkey -p "$PACKAGE_ID" \
    -c android.intent.category.LAUNCHER 1 >/dev/null
fi

cleanup_capture() {
  if [[ -n "$CAPTURE_PID" ]]; then
    kill "$CAPTURE_PID" 2>/dev/null || true
    wait "$CAPTURE_PID" 2>/dev/null || true
    CAPTURE_PID=""
  fi
}
trap cleanup_capture EXIT

capture_profile() {
  local out_dir="$PROFILE_DIR"
  local started_utc ended_utc model android_version abi screen
  if [[ -z "$out_dir" ]]; then
    out_dir="$ROOT_DIR/artifacts/android/$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  mkdir -p "$out_dir"
  if [[ -e "$out_dir/logcat.txt" || -e "$out_dir/summary.json" ]]; then
    fail "Profile directory already contains evidence; choose a new --profile-dir: $out_dir"
  fi
  out_dir="$(python3 - "$out_dir" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser().resolve())
PY
)"
  printf '\nRecording %s seconds on the physical device.\n' "$PROFILE_SECONDS"
  printf 'Evidence directory: %s\n' "$out_dir"
  printf 'Repeat the same scenario; only background the app for lifecycle tests.\n'

  model="$("$ADB" -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
  android_version="$("$ADB" -s "$SERIAL" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)"
  abi="$("$ADB" -s "$SERIAL" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r' || true)"
  screen="$("$ADB" -s "$SERIAL" shell wm size 2>/dev/null | tr -d '\r' || true)"
  "$ADB" -s "$SERIAL" shell dumpsys display >"$out_dir/display.txt" 2>&1 || true
  "$ADB" -s "$SERIAL" shell dumpsys battery >"$out_dir/battery-before.txt" 2>&1 || true
  "$ADB" -s "$SERIAL" shell dumpsys thermalservice >"$out_dir/thermal-before.txt" 2>&1 || true
  "$ADB" -s "$SERIAL" shell dumpsys meminfo "$PACKAGE_ID" >"$out_dir/meminfo-before.txt" 2>&1 || true

  "$ADB" -s "$SERIAL" logcat -c
  "$ADB" -s "$SERIAL" logcat -v threadtime >"$out_dir/logcat.txt" 2>"$out_dir/logcat-errors.txt" &
  CAPTURE_PID=$!
  "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE_ID"
  started_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  "$ADB" -s "$SERIAL" shell monkey -p "$PACKAGE_ID" \
    -c android.intent.category.LAUNCHER 1 >/dev/null
  kill -0 "$CAPTURE_PID" 2>/dev/null || fail 'adb logcat stopped unexpectedly; inspect logcat-errors.txt.'
  sleep "$PROFILE_SECONDS"
  ended_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cleanup_capture

  "$ADB" -s "$SERIAL" shell dumpsys gfxinfo "$PACKAGE_ID" framestats >"$out_dir/gfxinfo.txt" 2>&1 || true
  "$ADB" -s "$SERIAL" shell dumpsys meminfo "$PACKAGE_ID" >"$out_dir/meminfo-after.txt" 2>&1 || true
  "$ADB" -s "$SERIAL" shell dumpsys thermalservice >"$out_dir/thermal-after.txt" 2>&1 || true
  "$ADB" -s "$SERIAL" shell dumpsys battery >"$out_dir/battery-after.txt" 2>&1 || true

  python3 - "$out_dir/device.json" "$out_dir/display.txt" "$APK_PATH" \
    "$model" "$android_version" "$abi" "$screen" "$PACKAGE_ID" \
    "$started_utc" "$ended_utc" "$PROFILE_SECONDS" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path

(out, display, apk, model, version, abi, screen, package, started, ended, seconds) = sys.argv[1:]
display_text = Path(display).read_text(encoding="utf-8", errors="replace")
refresh = re.findall(r"(?:fps|refreshRate)[= ]+([0-9]+(?:\.[0-9]+)?)", display_text)
metadata = {
    "model": model.strip(),
    "os": "Android",
    "os_version": version.strip(),
    "abi": abi.strip(),
    "screen": screen.strip().splitlines()[-1] if screen.strip() else "unknown",
    "refresh_hz_candidates": sorted(set(refresh)),
    "package_id": package,
    "apk_sha256": hashlib.sha256(Path(apk).read_bytes()).hexdigest(),
    "capture_started_utc": started,
    "capture_ended_utc": ended,
    "capture_requested_s": int(seconds),
}
Path(out).write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
PY
  python3 "$ROOT_DIR/tools/android_perf_report.py" "$out_dir/logcat.txt" \
    --metadata "$out_dir/device.json" --out "$out_dir"
  printf '\nReal-device capture complete: %s/report.md\n' "$out_dir"
  printf 'Profiler output is diagnostic; verify the final uninstrumented release separately.\n'
}

if (( PROFILE_SECONDS > 0 )); then
  capture_profile
  exit 0
fi

printf '\nUSB update complete. The installed game does not need the web server.\n'
printf 'Save preservation requires the same package id and signing key; do not uninstall.\n'
if (( SHOW_LOGCAT )); then
  printf 'Following Godot/AndroidRuntime logs; press Ctrl+C to stop.\n'
  exec "$ADB" -s "$SERIAL" logcat -s godot:V AndroidRuntime:E
fi
printf 'Logs: %s\n' "$ADB -s $SERIAL logcat -s godot:V AndroidRuntime:E"
