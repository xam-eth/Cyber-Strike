#!/usr/bin/env python3
"""Validate, stage, and bundle independent World/Character content packages.

A contributor owns a source package. Integration owns activation beneath
``game/content``. Runtime GDScript is deliberately not accepted from a package:
visual assets are data, while internal adapters retain gameplay authority.

    python3 tools/import_content.py check /path/to/package
    python3 tools/import_content.py stage /path/to/package
    python3 tools/import_content.py bundle /path/to/package --output out.zip
    python3 tools/import_content.py check-committed

See docs/CONTENT_IMPORT.md for the contract and its failure-isolation limits.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import re
import shutil
import struct
import sys
import uuid
import zipfile
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
CONTRACT_VERSION = 1
DOMAIN_DIRS = {"world": "worlds", "character": "characters"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
ENTRY_SUFFIXES = {".glb", ".gltf", ".tscn"}
RUNTIME_SUFFIXES = {
    ".bin",
    ".gdshader",
    ".glb",
    ".gltf",
    ".jpeg",
    ".jpg",
    ".json",
    ".material",
    ".ogg",
    ".otf",
    ".png",
    ".res",
    ".svg",
    ".tres",
    ".tscn",
    ".ttf",
    ".wav",
    ".webp",
}
GENERATED_SUFFIXES = {".import", ".tmp", ".uid"}
SCRIPT_MARKERS = (
    re.compile(r'type\s*=\s*"(?:Script|GDExtension)"', re.I),
    re.compile(r"^\s*script\s*=", re.I | re.M),
    re.compile(r"\b(?:GDScript|GDExtension|NativeScript)\b"),
)
MAX_PACKAGE_BYTES = 200 * 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _report(manifest: dict | None = None) -> dict:
    manifest = manifest or {}
    return {
        "ok": False,
        "contract_version": manifest.get("contract_version"),
        "id": manifest.get("id", ""),
        "domain": manifest.get("domain", ""),
        "entry": manifest.get("entry", ""),
        "errors": [],
        "warnings": [],
        "files": [],
        "total_bytes": 0,
    }


def _safe_relative(value: str) -> bool:
    if not value or "\\" in value or value.startswith("/") or "\x00" in value:
        return False
    return not any(part in {"", ".", ".."} for part in value.split("/"))


def _inside_runtime(relative: str) -> bool:
    return _safe_relative(relative) and (relative == "runtime" or relative.startswith("runtime/"))


def _resolve_uri(source: Path, owner: Path, uri: str) -> tuple[str, Path | None]:
    """Return an error or the referenced package file for a glTF URI."""
    if not uri or uri.startswith("data:"):
        return "", None
    if re.match(r"^[a-z][a-z0-9+.-]*:", uri, re.I) or uri.startswith("/"):
        return f"remote/absolute glTF URI is not self-contained: {uri}", None
    decoded = unquote(uri.split("?", 1)[0].split("#", 1)[0]).replace("\\", "/")
    base = owner.parent.relative_to(source).as_posix()
    resolved = posixpath.normpath(posixpath.join(base, decoded))
    if not _inside_runtime(resolved):
        return f"glTF URI escapes runtime/: {uri}", None
    target = source / resolved
    if not target.is_file():
        return f"glTF dependency is missing: {uri}", None
    return "", target


def _glb_json(path: Path) -> tuple[dict | None, str]:
    try:
        data = path.read_bytes()
        if len(data) < 20 or data[:4] != b"glTF":
            return None, "not a glTF 2 binary"
        version, declared = struct.unpack_from("<II", data, 4)
        if version != 2 or declared != len(data):
            return None, "invalid glTF version or declared length"
        chunk_size, chunk_type = struct.unpack_from("<II", data, 12)
        if chunk_type != 0x4E4F534A or 20 + chunk_size > len(data):
            return None, "missing first JSON chunk"
        return json.loads(data[20 : 20 + chunk_size].decode("utf-8")), ""
    except (OSError, UnicodeError, ValueError, struct.error) as exc:
        return None, f"unreadable GLB: {exc}"


def _validate_gltf(source: Path, path: Path, errors: list[str]) -> None:
    if path.suffix.lower() == ".glb":
        document, error = _glb_json(path)
        if error:
            errors.append(f"{path.relative_to(source)}: {error}")
            return
    else:
        try:
            document = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"{path.relative_to(source)}: unreadable glTF JSON: {exc}")
            return
    if not isinstance(document, dict):
        errors.append(f"{path.relative_to(source)}: glTF root must be an object")
        return
    for section in ("buffers", "images"):
        entries = document.get(section, [])
        if not isinstance(entries, list):
            errors.append(f"{path.relative_to(source)}: {section} must be an array")
            continue
        for entry in entries:
            if isinstance(entry, dict) and "uri" in entry:
                error, _ = _resolve_uri(source, path, str(entry["uri"]))
                if error:
                    errors.append(f"{path.relative_to(source)}: {error}")


def _validate_scene_text(source: Path, path: Path, target_prefix: str, errors: list[str]) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"{path.relative_to(source)}: unreadable text resource: {exc}")
        return
    for marker in SCRIPT_MARKERS:
        if marker.search(text):
            errors.append(f"{path.relative_to(source)}: runtime scripts/native extensions are forbidden")
            break
    for reference in re.findall(r'["\'](res://[^"\']+)["\']', text):
        if not reference.startswith(target_prefix):
            errors.append(f"{path.relative_to(source)}: cross-package reference: {reference}")
            continue
        # Everything below the declared target id maps to the source package
        # root; another domain or package is never a valid dependency.
        relative = reference[len(target_prefix) :]
        if not _inside_runtime(relative) or not (source / relative).is_file():
            errors.append(f"{path.relative_to(source)}: missing package dependency: {reference}")
    for reference in re.findall(r'\bpath="([^"]+)"', text):
        if reference.startswith("res://"):
            continue
        base = path.parent.relative_to(source).as_posix()
        resolved = posixpath.normpath(posixpath.join(base, reference))
        if not _inside_runtime(resolved) or not (source / resolved).is_file():
            errors.append(f"{path.relative_to(source)}: missing relative dependency: {reference}")


def validate_package(source: Path, max_bytes: int = MAX_PACKAGE_BYTES) -> dict:
    source = source.resolve()
    report = _report()
    manifest_path = source / "package.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if not isinstance(manifest, dict):
            raise ValueError("manifest root must be an object")
    except (OSError, UnicodeError, ValueError) as exc:
        report["errors"].append(f"package.json: {exc}")
        return report
    report = _report(manifest)
    errors = report["errors"]
    if manifest.get("contract_version") != CONTRACT_VERSION or isinstance(
        manifest.get("contract_version"), bool
    ):
        errors.append(f"contract_version must be {CONTRACT_VERSION}")
    package_id = manifest.get("id")
    domain = manifest.get("domain")
    if not isinstance(package_id, str) or not ID_PATTERN.fullmatch(package_id):
        errors.append("id must match ^[a-z][a-z0-9_]{0,63}$")
    if domain not in DOMAIN_DIRS:
        errors.append("domain must be 'world' or 'character'")
    entry = manifest.get("entry")
    if not isinstance(entry, str) or not _inside_runtime(entry):
        errors.append("entry must be a normalized path beneath runtime/")
    if errors:
        return report

    target_prefix = f"res://content/{DOMAIN_DIRS[domain]}/{package_id}/"
    entry_path = source / entry
    if not entry_path.is_file() or entry_path.suffix.lower() not in ENTRY_SUFFIXES:
        errors.append("entry must be an existing .glb, .gltf, or .tscn file")
    runtime = source / "runtime"
    if not runtime.is_dir():
        errors.append("runtime/ directory is missing")
        return report

    files: list[Path] = []
    for path in sorted(runtime.rglob("*")):
        relative = path.relative_to(source).as_posix()
        if path.is_symlink():
            errors.append(f"{relative}: symlinks are forbidden")
        elif path.is_dir():
            continue
        elif not path.is_file():
            errors.append(f"{relative}: only regular files are accepted")
            continue
        files.append(path)
        suffix = path.suffix.lower()
        if suffix in GENERATED_SUFFIXES or ".godot" in path.parts:
            errors.append(f"{relative}: generated caches/import files are not accepted")
        elif suffix not in RUNTIME_SUFFIXES:
            errors.append(f"{relative}: file type is not in the visual-content allowlist")
        size = path.stat().st_size
        report["total_bytes"] += size
        report["files"].append({"path": relative, "bytes": size, "sha256": sha256(path)})
        if suffix in {".glb", ".gltf"}:
            _validate_gltf(source, path, errors)
        elif suffix in {".tscn", ".tres", ".material", ".gdshader"}:
            _validate_scene_text(source, path, target_prefix, errors)
    if not files:
        errors.append("runtime/ contains no files")
    if report["total_bytes"] > max_bytes:
        errors.append(f"package exceeds {max_bytes} bytes")
    report["ok"] = not errors
    return report


def _license_files(source: Path) -> list[Path]:
    return [
        path
        for path in sorted(source.iterdir())
        if path.is_file() and not path.is_symlink() and path.name.upper().startswith(("LICENSE", "NOTICE"))
    ]


def _import_manifest(report: dict) -> str:
    payload = {
        "contract_version": CONTRACT_VERSION,
        "id": report["id"],
        "domain": report["domain"],
        "entry": report["entry"],
        "files": report["files"],
        "total_bytes": report["total_bytes"],
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def _copy_validated(source: Path, staging: Path, report: dict) -> None:
    staging.mkdir(parents=True)
    manifest = {
        "contract_version": CONTRACT_VERSION,
        "id": report["id"],
        "domain": report["domain"],
        "entry": report["entry"],
    }
    (staging / "package.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for item in report["files"]:
        target = staging / item["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / item["path"], target)
    for path in _license_files(source):
        shutil.copy2(path, staging / path.name)
    (staging / "content_import.json").write_text(_import_manifest(report), encoding="utf-8")


def stage_package(source: Path, repo_root: Path = ROOT) -> dict:
    source = source.resolve()
    report = validate_package(source)
    if not report["ok"]:
        return report
    target = repo_root / "game" / "content" / DOMAIN_DIRS[report["domain"]] / report["id"]
    target.parent.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    staging = target.parent / f".{target.name}.staging-{token}"
    backup = target.parent / f".{target.name}.backup-{token}"
    try:
        _copy_validated(source, staging, report)
        staged_check = validate_package(staging)
        if not staged_check["ok"]:
            report["errors"].extend(f"staged: {error}" for error in staged_check["errors"])
            return report
        if target.exists():
            os.replace(target, backup)
        try:
            os.replace(staging, target)
        except Exception:
            if backup.exists() and not target.exists():
                os.replace(backup, target)
            raise
        if backup.exists():
            shutil.rmtree(backup)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
        # A backup is restored on activation failure. Do not silently delete the
        # only remaining copy if an unexpected exception happened before that.
    report["ok"] = True
    report["staged"] = True
    report["target"] = f"res://content/{DOMAIN_DIRS[report['domain']]}/{report['id']}"
    return report


def _zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    return info


def _zip_write_file(archive: zipfile.ZipFile, path: Path, name: str) -> None:
    with path.open("rb") as source, archive.open(_zip_info(name), "w") as target:
        shutil.copyfileobj(source, target, length=1024 * 1024)


def bundle_package(source: Path, output: Path) -> dict:
    source = source.resolve()
    output = output.resolve()
    report = validate_package(source)
    if not report["ok"]:
        return report
    if output == source or source in output.parents:
        report["ok"] = False
        report["errors"].append("bundle output must be outside the source package")
        return report
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.{uuid.uuid4().hex}.tmp")
    prefix = f"{report['domain']}/{report['id']}"
    try:
        with zipfile.ZipFile(temporary, "w") as archive:
            manifest = {
                "contract_version": CONTRACT_VERSION,
                "id": report["id"],
                "domain": report["domain"],
                "entry": report["entry"],
            }
            archive.writestr(_zip_info(f"{prefix}/package.json"), json.dumps(manifest, indent=2) + "\n")
            for item in report["files"]:
                _zip_write_file(archive, source / item["path"], f"{prefix}/{item['path']}")
            for path in _license_files(source):
                _zip_write_file(archive, path, f"{prefix}/{path.name}")
            archive.writestr(_zip_info(f"{prefix}/content_import.json"), _import_manifest(report))
        os.replace(temporary, output)
    finally:
        if temporary.exists():
            temporary.unlink()
    report["ok"] = True
    report["bundle"] = str(output)
    report["bundle_sha256"] = sha256(output)
    return report


def check_committed(repo_root: Path = ROOT) -> list[dict]:
    reports: list[dict] = []
    for domain, directory in DOMAIN_DIRS.items():
        root = repo_root / "game" / "content" / directory
        if not root.exists():
            continue
        for child in sorted(root.iterdir()):
            if child.name.startswith("."):
                continue
            if not child.is_dir() or not (child / "package.json").is_file():
                reports.append({"ok": False, "id": child.name, "domain": domain, "errors": ["missing package.json"]})
                continue
            reports.append(validate_package(child))
    return reports


def _print_report(report: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(report, indent=2, sort_keys=True))
        return
    label = f"{report.get('domain', '?')}/{report.get('id', '?')}"
    if report.get("ok"):
        suffix = f" — {len(report.get('files', []))} runtime files, {report.get('total_bytes', 0)} bytes"
        print(f"PASS: {label}{suffix}")
        if report.get("target"):
            print(f"  staged: {report['target']}")
        if report.get("bundle"):
            print(f"  bundle: {report['bundle']} (sha256 {report['bundle_sha256']})")
    else:
        print(f"FAIL: {label}")
        for error in report.get("errors", []):
            print(f"  - {error}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: inferred)")
    parser.add_argument("--json", action="store_true", help="machine-readable report")
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("check", "stage", "bundle"):
        sub = commands.add_parser(name)
        sub.add_argument("source", type=Path)
        if name == "bundle":
            sub.add_argument("--output", type=Path)
    commands.add_parser("check-committed")
    args = parser.parse_args()

    if args.command == "check-committed":
        reports = check_committed(args.root)
        if args.json:
            print(json.dumps({"packages": reports, "ok": all(r["ok"] for r in reports)}, indent=2))
        else:
            for report in reports:
                _print_report(report, False)
            print(f"Committed content packages: {len(reports)} checked, {sum(not r['ok'] for r in reports)} failed")
        return 0 if all(report["ok"] for report in reports) else 1

    if args.command == "check":
        report = validate_package(args.source)
    elif args.command == "stage":
        report = stage_package(args.source, args.root)
    else:
        output = args.output
        if output is None:
            probe = validate_package(args.source)
            name = f"{probe.get('domain', 'content')}-{probe.get('id', 'package')}.zip"
            output = args.root / "exports" / "content-packages" / name
        report = bundle_package(args.source, output)
    _print_report(report, args.json)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
