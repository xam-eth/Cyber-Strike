#!/usr/bin/env python3
"""Turn Android DeviceProfiler logcat output into reviewable performance evidence.

The engine emits five-second windows, not a stream of every frame. Consequently
this report computes weighted FPS and worst-window percentiles, while preserving
every raw window. It deliberately does not invent an exact whole-run percentile
from already-aggregated data.
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

MARKER = "EXOCOMPLICT_METRICS "
WINDOW_FIELDS = (
    "elapsed_s",
    "frames",
    "fps",
    "frame_p50_ms",
    "frame_p95_ms",
    "frame_p99_ms",
    "frame_max_ms",
    "over_33ms",
    "over_50ms",
)
CSV_FIELDS = (
    "index",
    "phase",
    "wave",
    "enemies",
    "elapsed_s",
    "frames",
    "fps",
    "frame_p50_ms",
    "frame_p95_ms",
    "frame_p99_ms",
    "frame_max_ms",
    "over_33ms",
    "over_50ms",
    "process_ms",
    "physics_ms",
    "draw_calls",
    "primitives",
    "objects",
    "static_mb",
    "video_mb",
    "texture_mb",
    "uptime_ms",
)


def load_log(path: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]], int]:
    starts: list[dict[str, Any]] = []
    windows: list[dict[str, Any]] = []
    malformed = 0
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            marker_at = line.find(MARKER)
            if marker_at < 0:
                continue
            try:
                payload = json.loads(line[marker_at + len(MARKER) :])
            except json.JSONDecodeError:
                malformed += 1
                continue
            if not isinstance(payload, dict) or payload.get("schema") != 1:
                malformed += 1
                continue
            event = payload.get("event")
            if event == "profile_start":
                starts.append(payload)
            elif event == "frame_window":
                if all(isinstance(payload.get(key), (int, float)) for key in WINDOW_FIELDS):
                    windows.append(payload)
                else:
                    malformed += 1
    return starts, windows, malformed


def summarize(windows: list[dict[str, Any]]) -> dict[str, Any]:
    elapsed = sum(float(window["elapsed_s"]) for window in windows)
    frames = sum(int(window["frames"]) for window in windows)
    over_33 = sum(int(window["over_33ms"]) for window in windows)
    over_50 = sum(int(window["over_50ms"]) for window in windows)
    return {
        "windows": len(windows),
        "elapsed_s": round(elapsed, 3),
        "frames": frames,
        "weighted_fps": round(frames / elapsed, 2) if elapsed > 0 else 0.0,
        "worst_window_p95_ms": max(float(window["frame_p95_ms"]) for window in windows),
        "worst_window_p99_ms": max(float(window["frame_p99_ms"]) for window in windows),
        "max_frame_ms": max(float(window["frame_max_ms"]) for window in windows),
        "over_33ms": over_33,
        "over_33ms_pct": round(over_33 * 100.0 / frames, 2) if frames else 0.0,
        "over_50ms": over_50,
        "over_50ms_pct": round(over_50 * 100.0 / frames, 2) if frames else 0.0,
    }


def phase_summaries(windows: list[dict[str, Any]]) -> dict[str, Any]:
    phases: dict[str, list[dict[str, Any]]] = {}
    for window in windows:
        phases.setdefault(str(window.get("phase", "unknown")), []).append(window)
    return {phase: summarize(samples) for phase, samples in sorted(phases.items())}


def markdown_report(summary: dict[str, Any], windows: list[dict[str, Any]]) -> str:
    device = summary.get("device", {})
    overall = summary["overall"]
    debug = device.get("debug_build", "unknown")
    lines = [
        "# Android device performance evidence",
        "",
        f"- Device: **{device.get('model', 'unknown')}**",
        f"- OS: **{device.get('os', 'unknown')} {device.get('os_version', '')}**",
        f"- Godot: **{device.get('godot', 'unknown')}**",
        f"- Package / APK SHA-256: **{device.get('package_id', 'unknown')} / {device.get('apk_sha256', 'unknown')}**",
        f"- Processor / GPU: **{device.get('processor', 'unknown')} / {device.get('gpu', 'unknown')} ({device.get('gpu_api', 'unknown')})**",
        f"- Renderer: **{device.get('renderer', 'unknown')}**",
        f"- Screen / refresh: **{device.get('screen', 'unknown')} @ {device.get('refresh_hz', 'unknown')} Hz**",
        f"- 3D scale / max FPS / vsync: **{device.get('scale_3d', 'unknown')} / {device.get('max_fps', 'unknown')} / {device.get('vsync_mode', 'unknown')}**",
        f"- Debug build: **{debug}**",
        f"- Profiling feature: **{device.get('profiling_feature', 'unknown')}**",
        f"- Capture requested / sampled: **{device.get('capture_requested_s', 'unknown')} s / {overall['elapsed_s']} s**",
        "",
        "> Debug/profile measurements diagnose this build; they are not release-candidate certification.",
        "> Overall p95/p99 is not calculated from pre-aggregated windows. Raw windows are preserved below and in CSV/JSON.",
        "",
        "## Run summary",
        "",
        "| Phase | Seconds | Frames | Weighted FPS | Worst window p95 | Worst window p99 | Max frame | >33 ms | >50 ms |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]

    def row(phase: str, value: dict[str, Any]) -> str:
        return (
            f"| {phase} | {value['elapsed_s']} | {value['frames']} | {value['weighted_fps']} "
            f"| {value['worst_window_p95_ms']} | {value['worst_window_p99_ms']} "
            f"| {value['max_frame_ms']} | {value['over_33ms_pct']}% | {value['over_50ms_pct']}% |"
        )

    lines.append(row("ALL", overall))
    for phase, value in summary["phases"].items():
        lines.append(row(phase, value))
    lines.extend(
        [
            "",
            "## Five-second windows",
            "",
            "| # | Phase | Wave | Enemies | FPS | p50 ms | p95 ms | p99 ms | Max ms | Draw calls | Video MB |",
            "|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for index, window in enumerate(windows, 1):
        lines.append(
            f"| {index} | {window.get('phase', 'unknown')} | {window.get('wave', 0)} "
            f"| {window.get('enemies', 0)} | {window['fps']} | {window['frame_p50_ms']} "
            f"| {window['frame_p95_ms']} | {window['frame_p99_ms']} | {window['frame_max_ms']} "
            f"| {window.get('draw_calls', '')} | {window.get('video_mb', '')} |"
        )
    lines.extend(
        [
            "",
            "## Evidence limits",
            "",
            "- FPS is frames divided by measured engine time; it is not a universal pass/fail grade.",
            "- Compare identical scenarios and release/profile settings across devices.",
            "- Process/physics/render counters are end-of-window samples, not window averages.",
            "- Use the companion thermal, memory, gfxinfo, and logcat files for system context.",
            "- Physical touch comfort, battery impact, and thermal throttling still require the recorded device protocol.",
            "",
        ]
    )
    return "\n".join(lines)


def write_report(
    log_path: Path,
    out_dir: Path,
    metadata_path: Path | None = None,
) -> dict[str, Any]:
    starts, windows, malformed = load_log(log_path)
    if not windows:
        raise ValueError(
            "No frame_window metrics found. Use an Android debug/profile build and keep the game in the foreground."
        )
    device = dict(starts[0]) if starts else {}
    if metadata_path:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        if isinstance(metadata, dict):
            device.update(metadata)
    summary = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "source_log": log_path.name,
        "device": device,
        "malformed_metric_lines": malformed,
        "overall": summarize(windows),
        "phases": phase_summaries(windows),
        "percentile_note": "Worst-window values are shown; exact whole-run percentiles require raw per-frame data.",
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (out_dir / "raw_windows.json").write_text(json.dumps(windows, indent=2) + "\n", encoding="utf-8")
    with (out_dir / "windows.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        for index, window in enumerate(windows, 1):
            writer.writerow({"index": index, **window})
    (out_dir / "report.md").write_text(markdown_report(summary, windows), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logcat", type=Path, help="text logcat containing EXOCOMPLICT_METRICS lines")
    parser.add_argument("--out", type=Path, required=True, help="directory for JSON/CSV/Markdown evidence")
    parser.add_argument("--metadata", type=Path, help="optional device metadata JSON merged into the report")
    args = parser.parse_args()
    if not args.logcat.is_file():
        parser.error(f"logcat file not found: {args.logcat}")
    if args.metadata and not args.metadata.is_file():
        parser.error(f"metadata file not found: {args.metadata}")
    try:
        summary = write_report(args.logcat, args.out, args.metadata)
    except (ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))
    overall = summary["overall"]
    print(
        f"Android performance report: {args.out / 'report.md'} | "
        f"{overall['windows']} windows, {overall['weighted_fps']} weighted FPS, "
        f"worst-window p95 {overall['worst_window_p95_ms']} ms"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
