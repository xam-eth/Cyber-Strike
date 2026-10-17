#!/usr/bin/env python3
"""Create, patch, and validate the local Godot **Web** export preset.

The web build is the project's no-install preview path: a single-threaded
Godot Web export runs on WebGL 2 and needs no cross-origin isolation headers,
so it can be served by a plain ``python -m http.server`` from the repository
root (see WEB_PREVIEW.md).

``game/export_presets.cfg`` is git-ignored (it is machine-local), so this tool
generates the Web preset deterministically instead of committing it. Shared
preset parsing/writing helpers live in ``tools/android_preset.py``.

    ensure    add a Web preset when missing (keeps other presets untouched)
    check     validate the Web preset and the custom HTML shell placeholders
    show      print the parsed Web preset

Option names and defaults come from Godot 4.7
``platform/web/export/export_plugin.cpp``.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import android_preset as base  # noqa: E402  (shared preset helpers)

PLATFORM = "Web"
DEFAULT_SHELL = "res://web_shell/index.html"
SHELL_MARKER = "overdrive-shell"

# Placeholders substituted by the Godot web exporter inside the custom shell.
REQUIRED_PLACEHOLDERS = (
    "$GODOT_PROJECT_NAME",
    "$GODOT_URL",
    "$GODOT_CONFIG",
    "$GODOT_THREADS_ENABLED",
    "$GODOT_HEAD_INCLUDE",
    "$GODOT_SPLASH",
)

# (option, value) mirroring Godot 4.7's web export plugin defaults.
WEB_OPTIONS: dict[str, str] = {
    "custom_template/debug": '""',
    "custom_template/release": '""',
    "variant/extensions_support": "false",
    "variant/thread_support": "false",
    "vram_texture_compression/for_desktop": "true",
    "vram_texture_compression/for_mobile": "false",
    "html/export_icon": "true",
    "html/custom_html_shell": f'"{DEFAULT_SHELL}"',
    "html/head_include": '""',
    "html/canvas_resize_policy": "2",
    "html/focus_canvas_on_start": "true",
    "html/experimental_virtual_keyboard": "false",
    "progressive_web_app/enabled": "false",
    "progressive_web_app/ensure_cross_origin_isolation_headers": "false",
    "progressive_web_app/offline_page": '""',
    "progressive_web_app/display": "1",
    "progressive_web_app/orientation": "0",
    "progressive_web_app/icon_144x144": '""',
    "progressive_web_app/icon_180x180": '""',
    "progressive_web_app/icon_512x512": '""',
    "progressive_web_app/background_color": "Color(0, 0, 0, 1)",
    "threads/emscripten_pool_size": "8",
    "threads/godot_pool_size": "4",
}


def build_preset_block(index: int, name: str, shell: str, threads: bool, export_path: str) -> str:
    lines = ["", f"[preset.{index}]", "", f'name="{name}"', f'platform="{PLATFORM}"']
    for key, value in base.PRESET_HEADER_OPTIONS:
        if key == "export_path" and export_path:
            lines.append(f"export_path={base.quote(export_path)}")
        else:
            lines.append(f"{key}={value}")
    lines.append("")
    lines.append(f"[preset.{index}.options]")
    lines.append("")
    options = dict(WEB_OPTIONS)
    options["html/custom_html_shell"] = base.quote(shell)
    options["variant/thread_support"] = "true" if threads else "false"
    for key, value in options.items():
        lines.append(f"{key}={value}")
    return "\n".join(lines) + "\n"


def shell_path_to_file(repo_root: Path, res_path: str) -> Path | None:
    if not res_path.startswith("res://"):
        return None
    if not (repo_root / "game").exists():
        return None
    return repo_root / "game" / res_path[len("res://"):]


def check_shell(repo_root: Path, shell_res_path: str) -> tuple[list[str], list[str]]:
    problems: list[str] = []
    notes: list[str] = []
    shell_file = shell_path_to_file(repo_root, shell_res_path)
    if shell_file is None:
        problems.append(f"html/custom_html_shell '{shell_res_path}' is not a res:// path inside game/")
        return problems, notes
    if not shell_file.exists():
        problems.append(f"custom HTML shell not found: {shell_file}")
        return problems, notes
    text = shell_file.read_text(encoding="utf-8", errors="replace")
    for placeholder in REQUIRED_PLACEHOLDERS:
        if placeholder not in text:
            problems.append(f"shell {shell_file} is missing the placeholder {placeholder}")
    if SHELL_MARKER not in text:
        notes.append(
            f"shell {shell_file} does not contain the '{SHELL_MARKER}' marker; "
            "the build verifier uses it to confirm the custom shell was applied"
        )
    if "<canvas" not in text:
        problems.append(f"shell {shell_file} has no <canvas> element")
    return problems, notes


def validate(preset: base.Preset, name: str, repo_root: Path, allow_threads: bool) -> tuple[list[str], list[str]]:
    problems: list[str] = []
    notes: list[str] = []

    if preset.name != name:
        problems.append(f"preset name is '{preset.name}', expected '{name}'")
    if preset.platform != PLATFORM:
        problems.append(f"platform is '{preset.platform}', expected '{PLATFORM}'")

    threads = preset.option("variant/thread_support", "false") == "true"
    extensions = preset.option("variant/extensions_support", "false") == "true"
    ensure_headers = preset.option("progressive_web_app/ensure_cross_origin_isolation_headers", "true") == "true"
    resize_policy = preset.option("html/canvas_resize_policy", "2")
    shell = preset.option("html/custom_html_shell")

    if threads and not allow_threads:
        problems.append(
            "variant/thread_support=true requires COOP/COEP cross-origin isolation headers, which "
            "'python -m http.server' cannot send; disable threads for the static-server preview"
        )
    if not threads and ensure_headers:
        notes.append(
            "progressive_web_app/ensure_cross_origin_isolation_headers=true without threads makes the "
            "shell try to register a service worker before failing; recommend false for the static preview"
        )
    if extensions:
        notes.append("variant/extensions_support=true is only needed for GDExtension; this project uses none")
    if resize_policy not in ("0", "1", "2"):
        problems.append(f"html/canvas_resize_policy '{resize_policy}' is not a known value (0/1/2)")
    if not shell:
        problems.append("html/custom_html_shell is empty; the custom Project Overdrive shell would not be used")

    shell_problems, shell_notes = check_shell(repo_root, shell) if shell else ([], [])
    problems.extend(shell_problems)
    notes.extend(shell_notes)
    return problems, notes


def summarise(preset: base.Preset) -> list[str]:
    threads = preset.option("variant/thread_support", "false") == "true"
    return [
        f"index: {preset.index}",
        f"name: {preset.name}",
        f"platform: {preset.platform}",
        f"thread_support: {'true (needs COOP/COEP)' if threads else 'false (works on a plain static server)'}",
        f"custom_html_shell: {preset.option('html/custom_html_shell') or '(engine default)'}",
        f"canvas_resize_policy: {preset.option('html/canvas_resize_policy', '2')}",
        f"extensions_support: {preset.option('variant/extensions_support', 'false')}",
        f"export_path: {preset.option('export_path') or '(unset)'}",
        f"option keys: {len(preset.options)}",
    ]


def find_web_preset(presets: list[base.Preset]) -> base.Preset | None:
    for preset in presets:
        if preset.platform == PLATFORM:
            return preset
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Create, patch, and validate the local Godot Web export preset.")
    parser.add_argument("command", choices=("ensure", "check", "show"))
    parser.add_argument("--preset-file", default="game/export_presets.cfg")
    parser.add_argument("--preset-name", default="Web")
    parser.add_argument("--shell", default=DEFAULT_SHELL, help="custom HTML shell inside the project (res:// path)")
    parser.add_argument("--export-path", default="web/index.html")
    parser.add_argument("--threads", action="store_true", help="enable variant/thread_support (needs COOP/COEP)")
    parser.add_argument("--allow-threads", action="store_true", help="do not fail check when threads are enabled")
    parser.add_argument("--repo-root", default=".", help="repository root (for shell and project lookups)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    path = Path(args.preset_file)
    if not path.is_absolute():
        path = repo_root / path

    if args.command == "ensure":
        existing_text = path.read_text(encoding="utf-8") if path.exists() else ""
        presets = base.parse_presets(existing_text)
        web = find_web_preset(presets)

        if web is not None:
            changed: list[str] = []
            text = existing_text
            for key, value in (
                ("html/custom_html_shell", base.quote(args.shell)),
                ("variant/thread_support", "true" if args.threads else "false"),
                ("progressive_web_app/ensure_cross_origin_isolation_headers", "true" if args.threads else "false"),
            ):
                text, did_change = base.set_option(text, web.index, key, value)
                if did_change:
                    changed.append(key)
            if not changed:
                print(f"Web preset '{web.name}' already exists in {path} and matches the requested values.")
                return 0
            if args.dry_run:
                print("Would update: " + ", ".join(changed))
                return 0
            backup = base.write_with_backup(path, text)
            print(f"Updated existing Web preset in {path}: {', '.join(changed)}")
            if backup:
                print(f"Backup: {backup}")
            return 0

        next_index = max((preset.index for preset in presets), default=-1) + 1
        block = build_preset_block(next_index, args.preset_name, args.shell, args.threads, args.export_path)
        text = existing_text + block if existing_text else "\n" + block.lstrip("\n")
        if args.dry_run:
            print(text)
            return 0
        path.parent.mkdir(parents=True, exist_ok=True)
        backup = base.write_with_backup(path, text)
        print(f"Added Web preset as preset.{next_index} in {path}")
        if backup:
            print(f"Backup: {backup}")
        return 0

    if not path.exists():
        print(f"{path} does not exist. Run 'ensure' first to generate the Web preset.", file=sys.stderr)
        return 2

    presets = base.parse_presets(path.read_text(encoding="utf-8"))
    web = find_web_preset(presets)
    if web is None:
        print(f"No Web preset found in {path}.", file=sys.stderr)
        return 1

    if args.command == "show":
        for line in summarise(web):
            print(f"  {line}")
        return 0

    print(f"[{web.name}]")
    for line in summarise(web):
        print(f"  {line}")
    problems, notes = validate(web, args.preset_name, repo_root, args.allow_threads)
    for note in notes:
        print(f"  note: {note}")
    for problem in problems:
        print(f"  FAIL: {problem}")
    if problems:
        return 1
    print("  Web preset is valid for the static-server preview.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
