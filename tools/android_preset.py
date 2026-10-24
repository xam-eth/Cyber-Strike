#!/usr/bin/env python3
"""Create, patch, and validate the local Godot Android export preset.

``game/export_presets.cfg`` is intentionally git-ignored because it holds
machine-local SDK/keystore paths and signing settings. This tool removes the
"open the Editor GUI first" requirement for CLI/CI workflows:

    scaffold  write a complete Android preset from this repository's defaults
    patch     update selected fields of an existing preset (GUI-created or scaffolded)
    check     validate the Android preset(s) in the file and report problems
    show      print the parsed presets and their key options

The file is always backed up before the first modification and written
atomically. Nothing outside the preset file is touched, and no network access
is used.

Note: ``scaffold`` reproduces the option set that Godot 4.x writes for an
Android preset. Godot fills in any missing option with its platform default and
normalizes the file the first time the preset is saved from the Editor, so a
scaffolded preset is expected to work for CLI export but has not been validated
by an actual export in this repository yet - use ``check`` and then the real
export to confirm.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

DEFAULT_PRESET_FILE = "game/export_presets.cfg"
DEFAULT_PRESET_NAME = "Android"
DEFAULT_PACKAGE_ID = "com.example.exocomplict"
PACKAGE_ID_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$")
ARCHITECTURES = ("armeabi-v7a", "arm64-v8a", "x86", "x86_64")

# Minimal-but-complete Android preset option set. Missing keys fall back to
# Godot's platform defaults, extra keys are ignored.
SCAFFOLD_OPTIONS: list[tuple[str, str]] = [
    ("custom_template/debug", '""'),
    ("custom_template/release", '""'),
    ("gradle_build/use_gradle_build", "false"),
    ("gradle_build/gradle_build_directory", '""'),
    ("gradle_build/android_source_template", '""'),
    ("gradle_build/compress_native_libraries", "false"),
    ("gradle_build/export_format", "0"),
    ("gradle_build/min_sdk", '""'),
    ("gradle_build/target_sdk", '""'),
    ("architectures/armeabi-v7a", "false"),
    ("architectures/arm64-v8a", "true"),
    ("architectures/x86", "false"),
    ("architectures/x86_64", "false"),
    ("version/code", "1"),
    ("version/name", '"1.0"'),
    ("package/unique_name", f'"{DEFAULT_PACKAGE_ID}"'),
    ("package/name", '"Exocomplict"'),
    ("package/signed", "true"),
    ("package/app_category", "2"),
    ("package/retain_data_on_uninstall", "false"),
    ("package/exclude_from_recents", "false"),
    ("package/show_in_android_tv", "false"),
    ("package/show_in_app_library", "true"),
    ("package/show_as_launcher_app", "false"),
    ("launcher_icons/main_192x192", '""'),
    ("launcher_icons/adaptive_foreground_432x432", '""'),
    ("launcher_icons/adaptive_background_432x432", '""'),
    ("graphics/opengl_debug", "false"),
    ("xr_features/xr_mode", "0"),
    ("screen/immersive_mode", "true"),
    ("screen/support_small", "true"),
    ("screen/support_normal", "true"),
    ("screen/support_large", "true"),
    ("screen/support_xlarge", "true"),
    ("user_data_backup/allow", "false"),
    ("command_line/extra_args", '""'),
    ("apk_expansion/enable", "false"),
    ("apk_expansion/SALT", '""'),
    ("apk_expansion/public_key", '""'),
    ("permissions/custom_permissions", "PackedStringArray()"),
]

# Files that must never reach a player. `tests/*` is the whole smoke suite: 26
# scripts, 8,141 lines, found packed into the shipped web payload as compiled
# `.gdc` + `.remap` pairs because no preset carried an exclude filter
# (docs/DECISIONS.md §5). `tools/check_payload.py` is the gate that
# catches a regression here; it reads the exported .pck, not this file.
EXCLUDE_FROM_EXPORT = "tests/*"

PRESET_HEADER_OPTIONS: list[tuple[str, str]] = [
    ("runnable", "true"),
    ("advanced_options", "false"),
    ("dedicated_server", "false"),
    ("custom_features", '""'),
    ("export_filter", '"all_resources"'),
    ("include_filter", '""'),
    ("exclude_filter", '"%s"' % EXCLUDE_FROM_EXPORT),
    ("export_path", '""'),
    ("patches", "PackedStringArray()"),
    ("encryption_include_filters", '""'),
    ("encryption_exclude_filters", '""'),
    ("seed", "0"),
    ("encrypt_pck", "false"),
    ("encrypt_directory", "false"),
    ("script_export_mode", "2"),
]


@dataclass
class Preset:
    index: int
    name: str
    platform: str
    header: dict[str, str] = field(default_factory=dict)
    options: dict[str, str] = field(default_factory=dict)

    def option(self, key: str, default: str = "") -> str:
        return unquote(self.options.get(key, default))


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def quote(value: str) -> str:
    return '"%s"' % value.replace('"', '\\"')


def parse_presets(text: str) -> list[Preset]:
    presets: list[Preset] = []
    current: Preset | None = None
    section = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        section_match = re.match(r"^\[(.+)\]$", line)
        if section_match:
            section = section_match.group(1)
            preset_match = re.match(r"^preset\.(\d+)$", section)
            if preset_match:
                current = Preset(index=int(preset_match.group(1)), name="", platform="")
                presets.append(current)
            continue
        if current is None or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if section.endswith(".options"):
            current.options[key] = value
        else:
            current.header[key] = value
            if key == "name":
                current.name = unquote(value)
            elif key == "platform":
                current.platform = unquote(value)
    return presets


def android_presets(presets: list[Preset]) -> list[Preset]:
    return [preset for preset in presets if preset.platform.lower() == "android"]


def find_preset(presets: list[Preset], name: str) -> Preset | None:
    for preset in presets:
        if preset.name == name:
            return preset
    return None


def set_option(text: str, preset_index: int, key: str, value: str) -> tuple[str, bool]:
    """Set ``key`` inside ``[preset.N.options]``; returns (new_text, changed)."""
    lines = text.splitlines()
    section = f"preset.{preset_index}.options"
    start = None
    end = len(lines)
    for index, raw_line in enumerate(lines):
        stripped = raw_line.strip()
        if stripped == f"[{section}]":
            start = index
            continue
        if start is not None and stripped.startswith("[") and stripped.endswith("]"):
            end = index
            break
    if start is None:
        return text, False
    for index in range(start + 1, end):
        stripped = lines[index].strip()
        if stripped.startswith(f"{key}=") or stripped.startswith(f"{key} ="):
            new_line = f"{key}={value}"
            if lines[index] != new_line:
                lines[index] = new_line
                return "\n".join(lines) + "\n", True
            return text, False
    lines.insert(end, f"{key}={value}")
    return "\n".join(lines) + "\n", True


def build_scaffold(
    preset_name: str, package_id: str, app_name: str, version_code: str, version_name: str,
    architectures: list[str], immersive: bool, export_path: str,
) -> str:
    blocks: list[str] = [""]
    blocks.append("[preset.0]")
    blocks.append("")
    blocks.append(f"name={quote(preset_name)}")
    blocks.append('platform="Android"')
    for key, value in PRESET_HEADER_OPTIONS:
        blocks.append(f"{key}={value}")
    blocks.append("")
    blocks.append("[preset.0.options]")
    blocks.append("")
    options = dict(SCAFFOLD_OPTIONS)
    options["package/unique_name"] = quote(package_id)
    options["package/name"] = quote(app_name)
    options["version/code"] = version_code
    options["version/name"] = quote(version_name)
    options["screen/immersive_mode"] = "true" if immersive else "false"
    for arch in ARCHITECTURES:
        options[f"architectures/{arch}"] = "true" if arch in architectures else "false"
    for key, value in options.items():
        blocks.append(f"{key}={value}")
    text = "\n".join(blocks) + "\n"
    if export_path:
        text, _ = set_option(text, 0, "export_path", quote(export_path))
    return text


def write_with_backup(path: Path, text: str) -> Path | None:
    backup: Path | None = None
    if path.exists() and path.read_text(encoding="utf-8") != text:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = path.with_suffix(path.suffix + f".bak-{stamp}")
        shutil.copy2(path, backup)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8")
    temporary.replace(path)
    return backup


def validate(preset: Preset, expected_name: str) -> tuple[list[str], list[str]]:
    problems: list[str] = []
    notes: list[str] = []

    package_id = preset.option("package/unique_name")
    app_name = preset.option("package/name")
    version_code = preset.option("version/code", "1")
    version_name = preset.option("version/name", "1.0")
    enabled_arch = [arch for arch in ARCHITECTURES if preset.option(f"architectures/{arch}") == "true"]

    if preset.name != expected_name:
        problems.append(f"preset name is '{preset.name}', expected '{expected_name}'")
    if not PACKAGE_ID_RE.match(package_id):
        problems.append(f"package/unique_name '{package_id}' is not a valid application ID")
    elif "example" in package_id.lower():
        problems.append(
            f"package/unique_name '{package_id}' still contains 'example'; "
            "Google Play rejects com.example.* identifiers"
        )
    if not app_name.strip():
        problems.append("package/name is empty")
    if not version_code.isdigit() or int(version_code) < 1:
        problems.append(f"version/code '{version_code}' must be an integer >= 1")
    if not version_name.strip():
        problems.append("version/name is empty")
    if not enabled_arch:
        problems.append("no CPU architecture is enabled (arm64-v8a is the practical Android baseline)")
    elif "arm64-v8a" not in enabled_arch:
        notes.append("arm64-v8a is disabled; most test devices are 64-bit ARM")

    export_format = preset.option("gradle_build/export_format", "0")
    if export_format not in ("0", "1", "2"):
        notes.append(f"gradle_build/export_format '{export_format}' is not a known value")

    if preset.option("package/signed", "true") == "false":
        notes.append("package/signed=false produces an unsigned APK that cannot be installed on a device")

    return problems, notes


def summarise(preset: Preset) -> list[str]:
    enabled_arch = [arch for arch in ARCHITECTURES if preset.option(f"architectures/{arch}") == "true"]
    return [
        f"index: {preset.index}",
        f"name: {preset.name}",
        f"package/unique_name: {preset.option('package/unique_name')}",
        f"package/name: {preset.option('package/name')}",
        f"version: {preset.option('version/name', '1.0')} (code {preset.option('version/code', '1')})",
        f"architectures: {', '.join(enabled_arch) if enabled_arch else 'none'}",
        f"export_format: {preset.option('gradle_build/export_format', '0')} (0=APK, 1=AAB)",
        f"export_path: {preset.option('export_path') or '(unset)'}",
        f"option keys: {len(preset.options)}",
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Create, patch, and validate the local Godot Android export preset."
    )
    parser.add_argument(
        "command", choices=("scaffold", "patch", "check", "show"), help="action to perform"
    )
    parser.add_argument("--preset-file", default=DEFAULT_PRESET_FILE)
    parser.add_argument("--preset-name", default=DEFAULT_PRESET_NAME)
    parser.add_argument("--package-id", default=DEFAULT_PACKAGE_ID)
    parser.add_argument("--app-name", default="Exocomplict")
    parser.add_argument("--version-code", default="1")
    parser.add_argument("--version-name", default="1.0")
    parser.add_argument(
        "--arch",
        default="arm64-v8a",
        help="comma separated CPU architectures (default: arm64-v8a)",
    )
    parser.add_argument(
        "--no-immersive",
        action="store_true",
        help="disable screen/immersive_mode (default: enabled)",
    )
    parser.add_argument("--export-path", default="")
    parser.add_argument("--force", action="store_true", help="overwrite an existing preset file")
    parser.add_argument("--dry-run", action="store_true", help="print the result without writing")
    args = parser.parse_args(argv)

    path = Path(args.preset_file)
    architectures = [arch.strip() for arch in args.arch.split(",") if arch.strip()]
    unknown = [arch for arch in architectures if arch not in ARCHITECTURES]
    if unknown:
        parser.error("unknown architecture(s): %s (valid: %s)" % (", ".join(unknown), ", ".join(ARCHITECTURES)))

    if args.command == "scaffold":
        if path.exists() and not args.force and not args.dry_run:
            print(
                f"{path} already exists. Use 'patch' to update it, or --force to replace it.\n"
                "Replacing a GUI-created preset with a scaffold is rarely what you want.",
                file=sys.stderr,
            )
            return 2
        text = build_scaffold(
            args.preset_name,
            args.package_id,
            args.app_name,
            args.version_code,
            args.version_name,
            architectures,
            not args.no_immersive,
            args.export_path,
        )
        if args.dry_run:
            print(text)
            return 0
        backup = write_with_backup(path, text)
        print(f"Wrote Android scaffold preset to {path}")
        if backup:
            print(f"Backup: {backup}")
        print(
            "Next: point Godot at your JDK/SDK (Editor Settings > Export > Android), then run "
            "./scripts/export_android_debug.sh"
        )
        return 0

    if not path.exists():
        print(f"{path} does not exist. Run 'scaffold' first, or create the preset in the Editor.", file=sys.stderr)
        return 2

    text = path.read_text(encoding="utf-8")
    presets = parse_presets(text)

    if args.command == "show":
        if not presets:
            print(f"{path} contains no presets.")
            return 1
        for preset in presets:
            print(f"[{preset.name}] platform={preset.platform}")
            for line in summarise(preset):
                print(f"  {line}")
        return 0

    if args.command == "check":
        targets = android_presets(presets)
        if not targets:
            print(f"No Android preset found in {path}.", file=sys.stderr)
            return 1
        failed = False
        for preset in targets:
            print(f"[{preset.name}]")
            for line in summarise(preset):
                print(f"  {line}")
            problems, notes = validate(preset, args.preset_name) if preset.name == args.preset_name else ([], [])
            if preset.name != args.preset_name:
                notes.append(
                    f"preset is not named '{args.preset_name}'; export_android_debug.sh expects that name "
                    "unless ANDROID_EXPORT_PRESET is set"
                )
            for note in notes:
                print(f"  note: {note}")
            for problem in problems:
                print(f"  FAIL: {problem}")
                failed = True
        return 1 if failed else 0

    # patch
    target = find_preset(presets, args.preset_name)
    if target is None:
        print(f"Preset '{args.preset_name}' was not found in {path}.", file=sys.stderr)
        print("Available: " + ", ".join(f"'{preset.name}'" for preset in presets if preset.name), file=sys.stderr)
        return 2

    updates: list[tuple[str, str]] = [
        ("package/unique_name", quote(args.package_id)),
        ("package/name", quote(args.app_name)),
        ("version/code", args.version_code),
        ("version/name", quote(args.version_name)),
        ("package/signed", "true"),
        ("screen/immersive_mode", "false" if args.no_immersive else "true"),
    ]
    for arch in ARCHITECTURES:
        updates.append((f"architectures/{arch}", "true" if arch in architectures else "false"))
    if args.export_path:
        updates.append(("export_path", quote(args.export_path)))

    changed_keys: list[str] = []
    for key, value in updates:
        text, changed = set_option(text, target.index, key, value)
        if changed:
            changed_keys.append(key)

    if not changed_keys:
        print(f"Preset '{args.preset_name}' already matches the requested values.")
        return 0

    if args.dry_run:
        print("Would update: " + ", ".join(changed_keys))
        return 0

    backup = write_with_backup(path, text)
    print(f"Updated preset '{args.preset_name}' in {path}")
    print("Changed: " + ", ".join(changed_keys))
    if backup:
        print(f"Backup: {backup}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
