#!/usr/bin/env python3
"""Validate an exported Godot Web build before it is published as a preview.

Checks (no browser needed):
  * required files exist and are non-empty (html/js/wasm/pck)
  * file magic: WebAssembly ``\\0asm`` and Godot pack ``GDPC``
  * the custom Project Overdrive shell was applied (marker present)
  * every ``$GODOT_*`` placeholder was substituted by the exporter
  * the shell references the exported JS library and engine config
  * total size sanity (warns on unusually small/large builds)

Usage:
    python3 tools/verify_web_build.py web
    python3 tools/verify_web_build.py exports/web-preview/web --json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REQUIRED_FILES = ("index.html", "index.js", "index.wasm", "index.pck")
OPTIONAL_FILES = ("index.audio.worklet.js", "index.icon.png", "index.apple-touch-icon.png", "index.manifest.json")
SHELL_MARKER = "overdrive-shell"
WASM_MAGIC = b"\x00asm"
PCK_MAGIC = b"GDPC"
MIN_WASM_BYTES = 5 * 1024 * 1024
MIN_JS_BYTES = 20 * 1024
WARN_TOTAL_BYTES = 150 * 1024 * 1024


def verify(build_dir: Path) -> tuple[list[str], list[str], dict[str, int]]:
    problems: list[str] = []
    notes: list[str] = []
    sizes: dict[str, int] = {}

    if not build_dir.is_dir():
        return [f"build directory not found: {build_dir}"], notes, sizes

    for name in REQUIRED_FILES:
        path = build_dir / name
        if not path.exists():
            problems.append(f"missing required file: {name}")
            continue
        size = path.stat().st_size
        sizes[name] = size
        if size == 0:
            problems.append(f"file is empty: {name}")

    if problems:
        return problems, notes, sizes

    wasm = (build_dir / "index.wasm").read_bytes()[:4]
    if wasm != WASM_MAGIC:
        problems.append(f"index.wasm does not start with the WebAssembly magic bytes (found {wasm!r})")
    pck = (build_dir / "index.pck").read_bytes()[:4]
    if pck != PCK_MAGIC:
        problems.append(f"index.pck does not start with the Godot pack magic 'GDPC' (found {pck!r})")

    if sizes.get("index.wasm", 0) < MIN_WASM_BYTES:
        notes.append(
            f"index.wasm is only {sizes.get('index.wasm', 0)} bytes; a full engine build is usually > 5 MB, "
            "so this may be a stub or a truncated download"
        )

    if sizes.get("index.js", 0) < MIN_JS_BYTES:
        notes.append(
            f"index.js is only {sizes.get('index.js', 0)} bytes; the engine JS library is normally larger, "
            "so this may be a stub"
        )

    html = (build_dir / "index.html").read_text(encoding="utf-8", errors="replace")
    if SHELL_MARKER not in html:
        problems.append(
            f"index.html does not contain the '{SHELL_MARKER}' marker: the custom shell was not applied "
            "(check html/custom_html_shell in the Web preset)"
        )
    if "$GODOT_" in html:
        leftovers = sorted({part.split("<")[0].split('"')[0].strip() for part in html.split("$GODOT_")[1:6]})
        problems.append("index.html still contains unsubstituted $GODOT_ placeholders: " + ", ".join(leftovers))
    if "new Engine(" not in html:
        problems.append("index.html does not construct the Godot Engine object; the shell bootstrap is broken")
    if "index.js" not in html:
        problems.append("index.html does not reference index.js (the exported engine library)")
    for name in ("index.wasm", "index.pck"):
        if name not in html:
            notes.append(f"index.html does not mention {name}; the engine config normally lists both files")

    for name in OPTIONAL_FILES:
        if (build_dir / name).exists():
            sizes[name] = (build_dir / name).stat().st_size

    total = sum(sizes.values())
    if total > WARN_TOTAL_BYTES:
        notes.append(f"build total is {total / 1024 / 1024:.1f} MB; consider texture/asset trimming for web delivery")

    stray = sorted(path.name for path in build_dir.glob("index.*") if path.name not in sizes)
    if stray:
        notes.append("additional exported files: " + ", ".join(stray))

    return problems, notes, sizes


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate an exported Godot Web build.")
    parser.add_argument("build_dir", nargs="?", default="web", help="directory containing index.html (default: web)")
    parser.add_argument("--json", action="store_true", help="print a machine-readable report")
    args = parser.parse_args(argv)

    build_dir = Path(args.build_dir)
    problems, notes, sizes = verify(build_dir)

    if args.json:
        print(
            json.dumps(
                {
                    "build_dir": str(build_dir),
                    "ok": not problems,
                    "problems": problems,
                    "notes": notes,
                    "sizes": sizes,
                },
                indent=2,
            )
        )
        return 1 if problems else 0

    print(f"Godot Web build check: {build_dir}")
    if sizes:
        total = sum(sizes.values())
        for name in sorted(sizes):
            print(f"  {name}: {sizes[name] / 1024 / 1024:.2f} MB")
        print(f"  total: {total / 1024 / 1024:.2f} MB")
    for note in notes:
        print(f"  note: {note}")
    for problem in problems:
        print(f"  FAIL: {problem}")
    if problems:
        return 1
    print("  build looks publishable: shell applied, placeholders substituted, assets present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
