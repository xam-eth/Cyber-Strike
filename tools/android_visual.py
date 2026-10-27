#!/usr/bin/env python3
"""Capture native Android screenshots/video without treating them as a visual pass.

Use ``shot`` for the currently displayed state or ``record`` for a timed video
with before/after screenshots. The tool does not build, install, clear data, or
measure FPS. Pair it with the Godot remote-deploy loop or ``android_usb.sh``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from android_preset import (
    DEFAULT_PRESET_FILE,
    PACKAGE_ID_RE,
    find_preset,
    parse_presets,
)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_ROOT = ROOT / "artifacts" / "android" / "visual"
LABEL_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class CaptureError(RuntimeError):
    """An expected capture/setup failure with an actionable message."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def resolve_adb(explicit: str | None = None) -> str:
    candidates = [explicit or os.environ.get("ADB_BIN", ""), "adb"]
    for variable in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        value = os.environ.get(variable)
        if value:
            candidates.append(str(Path(value) / "platform-tools" / "adb"))
    candidates.extend(
        [
            str(Path.home() / "Android/Sdk/platform-tools/adb"),
            str(Path.home() / "Library/Android/sdk/platform-tools/adb"),
            str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb"),
        ]
    )
    for candidate in candidates:
        if not candidate:
            continue
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
        path = Path(candidate).expanduser()
        if path.is_file() and os.access(path, os.X_OK):
            return str(path.resolve())
    raise CaptureError(
        "adb was not found. Set ADB_BIN or ANDROID_SDK_ROOT, or add platform-tools to PATH."
    )


def run_command(
    command: list[str],
    *,
    stdout: Any = subprocess.PIPE,
    check: bool = True,
) -> subprocess.CompletedProcess[Any]:
    try:
        result = subprocess.run(command, stdout=stdout, stderr=subprocess.PIPE, check=False)
    except OSError as error:
        raise CaptureError(f"Could not execute {command[0]}: {error}") from error
    if check and result.returncode != 0:
        if isinstance(result.stderr, bytes):
            detail = result.stderr.decode("utf-8", errors="replace")
        else:
            detail = result.stderr or ""
        if not detail and isinstance(result.stdout, bytes):
            detail = result.stdout.decode("utf-8", errors="replace")
        elif not detail:
            detail = result.stdout or ""
        raise CaptureError(
            f"Command failed ({result.returncode}): {' '.join(command)}\n{str(detail).strip()}"
        )
    return result


def select_serial(adb: str, requested: str | None) -> str:
    result = run_command([adb, "devices"])
    output = result.stdout.decode("utf-8", errors="replace")
    devices: dict[str, str] = {}
    for line in output.splitlines():
        fields = line.strip().split()
        if len(fields) >= 2 and fields[0] != "List" and fields[1] in {
            "device",
            "unauthorized",
            "offline",
            "recovery",
            "sideload",
            "bootloader",
        }:
            devices[fields[0]] = fields[1]
    if requested:
        state = devices.get(requested, "missing")
        if state != "device":
            raise CaptureError(
                f"Device '{requested}' is not online/authorized (state: {state})."
            )
        return requested
    online = [serial for serial, state in devices.items() if state == "device"]
    if not online:
        raise CaptureError(
            "No authorized online device. Connect USB, enable USB debugging, and accept the phone prompt."
        )
    if len(online) > 1:
        raise CaptureError("More than one device is online. Select one with --serial <serial>.")
    return online[0]


def resolve_package(explicit: str | None) -> str:
    package = explicit or os.environ.get("ANDROID_PACKAGE_ID", "")
    preset_file = Path(
        os.environ.get("ANDROID_PRESET_FILE", str(ROOT / DEFAULT_PRESET_FILE))
    ).expanduser()
    preset_name = os.environ.get("ANDROID_EXPORT_PRESET", "Android")
    if not package and preset_file.is_file():
        presets = parse_presets(preset_file.read_text(encoding="utf-8"))
        preset = find_preset(presets, preset_name)
        if preset is not None and preset.platform.lower() == "android":
            package = preset.option("package/unique_name")
    if not package:
        raise CaptureError(
            "Package id is unknown. Provide --package-id or create game/export_presets.cfg."
        )
    if not PACKAGE_ID_RE.fullmatch(package):
        raise CaptureError(f"Invalid Android package id: {package}")
    return package


def adb_command(adb: str, serial: str, *arguments: str) -> list[str]:
    return [adb, "-s", serial, *arguments]


def optional_text(command: list[str], warnings: list[str]) -> str:
    try:
        result = run_command(command)
        return result.stdout.decode("utf-8", errors="replace").strip()
    except CaptureError as error:
        warnings.append(str(error))
        return ""


def source_context() -> dict[str, Any]:
    context: dict[str, Any] = {
        "checkout_commit": "unknown",
        "checkout_dirty": "unknown",
        "installed_build_matches_checkout": "UNKNOWN",
    }
    if not (ROOT / ".git").exists():
        return context
    head = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if head.returncode == 0:
        context["checkout_commit"] = head.stdout.strip()
    status = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain=v1"],
        capture_output=True,
        text=True,
        check=False,
    )
    if status.returncode == 0:
        context["checkout_dirty"] = bool(status.stdout.strip())
    return context


def device_metadata(adb: str, serial: str, package: str) -> tuple[dict[str, Any], list[str]]:
    warnings: list[str] = []

    def shell(*arguments: str) -> str:
        return optional_text(adb_command(adb, serial, "shell", *arguments), warnings)

    package_dump = shell("dumpsys", "package", package)
    version_name = re.search(r"versionName=([^\s]+)", package_dump)
    version_code = re.search(r"versionCode=([^\s]+)", package_dump)
    window_dump = shell("dumpsys", "window", "windows")
    focus = re.search(r"mCurrentFocus=([^\n]+)", window_dump)
    if focus is None:
        focus = re.search(r"mFocusedApp=([^\n]+)", window_dump)
    return (
        {
            "model": shell("getprop", "ro.product.model") or "unknown",
            "android_version": shell("getprop", "ro.build.version.release") or "unknown",
            "android_sdk": shell("getprop", "ro.build.version.sdk") or "unknown",
            "abi": shell("getprop", "ro.product.cpu.abi") or "unknown",
            "screen": shell("wm", "size") or "unknown",
            "density": shell("wm", "density") or "unknown",
            "package_id": package,
            "installed_version_name": version_name.group(1) if version_name else "unknown",
            "installed_version_code": version_code.group(1) if version_code else "unknown",
            "current_focus": focus.group(1).strip() if focus else "unknown",
        },
        warnings,
    )


def read_png_size(data: bytes) -> tuple[int, int]:
    """Validate PNG chunk boundaries/CRCs and return its native pixel size."""
    if not data.startswith(PNG_SIGNATURE):
        raise CaptureError("screencap did not return a PNG (bad signature).")
    offset = len(PNG_SIGNATURE)
    width = height = 0
    seen_ihdr = seen_idat = seen_iend = False
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise CaptureError("screencap returned a truncated PNG chunk.")
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        actual_crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise CaptureError("screencap returned a PNG with an invalid chunk CRC.")
        if kind == b"IHDR":
            if seen_ihdr or offset != 8 or length != 13:
                raise CaptureError("screencap returned an invalid PNG IHDR.")
            width, height = struct.unpack(">II", payload[:8])
            seen_ihdr = True
        elif kind == b"IDAT":
            seen_idat = True
        elif kind == b"IEND":
            if length != 0 or end != len(data):
                raise CaptureError("screencap returned an invalid PNG IEND.")
            seen_iend = True
            offset = end
            break
        offset = end
    if not seen_ihdr or not seen_idat or not seen_iend or width <= 0 or height <= 0:
        raise CaptureError("screencap returned an incomplete or empty PNG.")
    return width, height


def capture_screenshot(adb: str, serial: str, destination: Path) -> dict[str, Any]:
    partial = destination.with_name(destination.name + ".part")
    try:
        with partial.open("wb") as handle:
            run_command(adb_command(adb, serial, "exec-out", "screencap", "-p"), stdout=handle)
        data = partial.read_bytes()
        width, height = read_png_size(data)
        partial.replace(destination)
    except Exception:
        partial.unlink(missing_ok=True)
        raise
    orientation = "landscape" if width > height else "portrait" if height > width else "square"
    return {
        "path": destination.name,
        "width": width,
        "height": height,
        "orientation": orientation,
        "bytes": destination.stat().st_size,
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def validate_mp4(path: Path) -> None:
    data = path.read_bytes()
    if len(data) < 16 or data[4:8] != b"ftyp":
        raise CaptureError("Pulled screen recording is empty or is not an MP4 container.")


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def markdown_report(run: dict[str, Any]) -> str:
    device = run.get("device", {})
    source = run.get("source", {})
    lines = [
        "# Android native visual capture",
        "",
        f"- Capture status: **{run['capture_status']}**",
        "- Human visual review: **PENDING** — capture existence is not approval.",
        "- Performance evidence: **NO** — do not read FPS or thermal acceptance from this run.",
        f"- Mode / label: **{run['mode']} / {run['label']}**",
        f"- Device: **{device.get('model', 'unknown')} / Android {device.get('android_version', 'unknown')}**",
        f"- Package / installed version: **{device.get('package_id', 'unknown')} / {device.get('installed_version_name', 'unknown')} ({device.get('installed_version_code', 'unknown')})**",
        f"- Display metadata: **{device.get('screen', 'unknown')} / {device.get('density', 'unknown')}**",
        f"- Current focus: **{device.get('current_focus', 'unknown')}**",
        f"- Checkout context: **{source.get('checkout_commit', 'unknown')} / dirty={source.get('checkout_dirty', 'unknown')}**",
        "",
        "> Checkout context does not prove which source built the installed package. Native screenshot dimensions do not prove the internal 3D render resolution.",
        "",
    ]
    if run.get("error"):
        lines.extend(["## Failure", "", str(run["error"]), ""])
    artifacts = run.get("artifacts", [])
    if artifacts:
        lines.extend(
            [
                "## Artifacts",
                "",
                "| File | Pixels | Bytes | SHA-256 |",
                "|---|---|---:|---|",
            ]
        )
        for artifact in artifacts:
            pixels = (
                f"{artifact['width']}x{artifact['height']}"
                if "width" in artifact
                else "video/container only"
            )
            lines.append(
                f"| `{artifact['path']}` | {pixels} | {artifact['bytes']} | `{artifact['sha256']}` |"
            )
        lines.append("")
    lines.extend(
        [
            "## Review boundary",
            "",
            "- Confirm the intended game state, HUD, World, character, animation, and transitions by watching the actual files.",
            "- Video has no audio evidence and may add rendering/recording overhead.",
            "- Run performance capture separately on the same installed build and scenario.",
            "",
        ]
    )
    return "\n".join(lines)


def finish_run(output: Path, run: dict[str, Any]) -> None:
    run["capture_ended_utc"] = utc_now()
    write_json(output / "run.json", run)
    (output / "report.md").write_text(markdown_report(run), encoding="utf-8")


def capture(args: argparse.Namespace) -> int:
    if not LABEL_RE.fullmatch(args.label):
        raise CaptureError("--label must be 1-64 characters: letters, digits, dot, underscore, or dash.")
    if args.mode == "record" and not 1 <= args.seconds <= 180:
        raise CaptureError("--seconds must be between 1 and 180 (Android screenrecord limit).")
    settle = args.settle_seconds
    if settle is None:
        settle = 2.0 if args.launch else 0.0
    if not 0 <= settle <= 30:
        raise CaptureError("--settle-seconds must be between 0 and 30.")

    adb = resolve_adb(args.adb)
    serial = select_serial(adb, args.serial)
    package = resolve_package(args.package_id)
    output = args.output.expanduser().resolve() if args.output else None
    if output is None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        output = DEFAULT_OUTPUT_ROOT / f"{stamp}-{args.label}"
    if output.exists() and not output.is_dir():
        raise CaptureError(f"Evidence output is not a directory: {output}")
    if output.exists() and any(output.iterdir()):
        raise CaptureError(f"Evidence directory is not empty; choose a new --output: {output}")
    output.mkdir(parents=True, exist_ok=True)

    run: dict[str, Any] = {
        "schema": 1,
        "capture_status": "running",
        "visual_review": "PENDING",
        "performance_evidence": False,
        "mode": args.mode,
        "label": args.label,
        "requested_seconds": args.seconds if args.mode == "record" else 0,
        "capture_started_utc": utc_now(),
        "source": source_context(),
        "artifacts": [],
        "metadata_warnings": [],
    }
    remote_video = ""
    try:
        if args.launch:
            run_command(
                adb_command(
                    adb,
                    serial,
                    "shell",
                    "monkey",
                    "-p",
                    package,
                    "-c",
                    "android.intent.category.LAUNCHER",
                    "1",
                )
            )
            if settle:
                time.sleep(settle)

        # Read focus after an optional launch so it describes the captured state,
        # not the application that happened to be foreground before launch.
        device, warnings = device_metadata(adb, serial, package)
        run["device"] = device
        run["metadata_warnings"] = warnings

        if args.mode == "shot":
            run["artifacts"].append(capture_screenshot(adb, serial, output / "screen.png"))
        else:
            run["artifacts"].append(capture_screenshot(adb, serial, output / "before.png"))
            remote_video = f"/sdcard/cyber-strike-visual-{os.getpid()}.mp4"
            started = time.monotonic()
            recording = run_command(
                adb_command(
                    adb,
                    serial,
                    "shell",
                    "screenrecord",
                    "--time-limit",
                    str(args.seconds),
                    remote_video,
                ),
                check=False,
            )
            run["record_wall_seconds"] = round(time.monotonic() - started, 3)
            log = recording.stdout + recording.stderr
            (output / "screenrecord.log").write_bytes(log)
            if recording.returncode != 0:
                raise CaptureError(
                    f"Android screenrecord failed ({recording.returncode}); see screenrecord.log."
                )
            partial_video = output / "motion.mp4.part"
            try:
                run_command(adb_command(adb, serial, "pull", remote_video, str(partial_video)))
                validate_mp4(partial_video)
                partial_video.replace(output / "motion.mp4")
            except Exception:
                partial_video.unlink(missing_ok=True)
                raise
            run["artifacts"].append(capture_screenshot(adb, serial, output / "after.png"))

        # Hash only after every required capture exists. A partial run never becomes "captured".
        for artifact in run["artifacts"]:
            if "sha256" not in artifact:
                path = output / artifact["path"]
                artifact["bytes"] = path.stat().st_size
                artifact["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        if args.mode == "record":
            video = output / "motion.mp4"
            run["artifacts"].insert(
                1,
                {
                    "path": video.name,
                    "bytes": video.stat().st_size,
                    "sha256": hashlib.sha256(video.read_bytes()).hexdigest(),
                },
            )
        run["capture_status"] = "captured"
        finish_run(output, run)
    except KeyboardInterrupt:
        run["capture_status"] = "interrupted"
        run["error"] = "Capture interrupted by user; visual review remains pending."
        finish_run(output, run)
        return 130
    except (CaptureError, OSError) as error:
        run["capture_status"] = "failed"
        run["error"] = str(error)
        finish_run(output, run)
        print(f"ERROR: {error}", file=sys.stderr)
        print(f"Failed-capture diagnostics: {output / 'report.md'}", file=sys.stderr)
        return 1
    finally:
        if remote_video:
            run_command(
                adb_command(adb, serial, "shell", "rm", "-f", remote_video), check=False
            )

    print(f"Native visual capture: {output / 'report.md'}")
    print("Capture complete; human visual review remains PENDING. This is not performance evidence.")
    return 0


def main() -> int:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL"), help="ADB device serial")
    common.add_argument("--package-id", help="installed application id (or use the local Android preset)")
    common.add_argument("--adb", help="adb executable/path (default: ADB_BIN or SDK detection)")
    common.add_argument("--label", default="capture", help="short state/change label for the evidence")
    common.add_argument("--output", type=Path, help="new/empty evidence directory")
    common.add_argument("--launch", action="store_true", help="launch the installed package before capture")
    common.add_argument(
        "--settle-seconds",
        type=float,
        help="wait after --launch (default 2; no state-readiness claim)",
    )

    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    shot = modes.add_parser("shot", parents=[common], help="capture one native screenshot")
    shot.set_defaults(seconds=0)
    record = modes.add_parser("record", parents=[common], help="capture timed video and before/after screenshots")
    record.add_argument("--seconds", type=int, default=30, help="recording duration, 1-180 seconds")
    args = parser.parse_args()
    try:
        return capture(args)
    except (CaptureError, OSError) as error:
        parser.exit(1, f"ERROR: {error}\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
