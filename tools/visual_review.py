#!/usr/bin/env python3
"""Compare reviewed PNG references with current captures and render a diff report.

``compare`` never updates references. After a person inspects the generated
HTML/report, ``approve`` copies only named case images from that exact report
and verifies their hashes before updating the golden files.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

try:
    from PIL import Image, ImageChops, UnidentifiedImageError
except ImportError:  # pragma: no cover - reported as an actionable CLI error
    Image = None
    ImageChops = None
    UnidentifiedImageError = OSError

ROOT = Path(
    os.environ.get("VISUAL_REVIEW_ROOT", str(Path(__file__).resolve().parents[1]))
).resolve()
DEFAULT_MANIFEST = ROOT / "tools" / "visual_review.json"
GOLDEN_ROOT = "qa-evidence/visual-goldens"
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,79}$")
PENDING = "BASELINE_PENDING"
MATCH = "MATCH"
REVIEW = "REVIEW_REQUIRED"
MISSING = "MISSING_CURRENT"
ERROR = "ERROR"


class ReviewError(RuntimeError):
    """Manifest, capture, or approval contract failure."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repo_path(value: str, *, golden: bool = False) -> Path:
    pure = PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts or not pure.parts:
        raise ReviewError(f"Manifest path must be relative and may not traverse: {value}")
    if golden and not pure.is_relative_to(PurePosixPath(GOLDEN_ROOT)):
        raise ReviewError(f"Reference must live under {GOLDEN_ROOT}/: {value}")
    return ROOT.joinpath(*pure.parts)


def relative_display(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path.resolve())


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ReviewError(f"Could not read manifest {path}: {error}") from error
    if not isinstance(value, dict) or value.get("schema") != 1:
        raise ReviewError("Visual manifest must be an object with schema=1.")
    profiles = value.get("profiles")
    if not isinstance(profiles, dict) or not profiles:
        raise ReviewError("Visual manifest needs at least one profile.")
    for profile_id, profile in profiles.items():
        if not ID_RE.fullmatch(profile_id) or not isinstance(profile, dict):
            raise ReviewError(f"Invalid visual profile: {profile_id}")
        if not isinstance(profile.get("current_root"), str):
            raise ReviewError(f"Profile {profile_id} needs current_root.")
        repo_path(profile["current_root"])
        cases = profile.get("cases")
        if not isinstance(cases, list) or not cases:
            raise ReviewError(f"Profile {profile_id} needs at least one case.")
        seen: set[str] = set()
        for case in cases:
            if not isinstance(case, dict) or not ID_RE.fullmatch(str(case.get("id", ""))):
                raise ReviewError(f"Invalid case id in profile {profile_id}.")
            case_id = case["id"]
            if case_id in seen:
                raise ReviewError(f"Duplicate case {profile_id}/{case_id}.")
            seen.add(case_id)
            for key in ("current", "reference"):
                if not isinstance(case.get(key), str) or not case[key].endswith(".png"):
                    raise ReviewError(f"{profile_id}/{case_id} needs a PNG {key} path.")
                repo_path(case[key], golden=key == "reference")
            for key in ("channel_tolerance", "max_diff_ratio"):
                number = case.get(key, 0.0)
                if isinstance(number, bool) or not isinstance(number, (int, float)):
                    raise ReviewError(f"{profile_id}/{case_id} {key} must be numeric.")
                if not math.isfinite(number) or not 0 <= number <= 1:
                    raise ReviewError(f"{profile_id}/{case_id} {key} must be between 0 and 1.")
    return value


def load_png(path: Path) -> Any:
    if Image is None:
        raise ReviewError(
            "Pillow is required. Install it with: python3 -m pip install -r requirements-dev.txt"
        )
    try:
        with Image.open(path) as source:
            source.load()
            return source.convert("RGBA")
    except (OSError, UnidentifiedImageError) as error:
        raise ReviewError(f"Invalid or unreadable PNG {path}: {error}") from error


def copy_artifact(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def compare_images(reference: Path, current: Path, diff_path: Path, tolerance: float) -> dict[str, Any]:
    with load_png(reference) as ref, load_png(current) as cur:
        if ref.size != cur.size:
            return {
                "dimensions_match": False,
                "reference_size": list(ref.size),
                "current_size": list(cur.size),
            }
        delta = ImageChops.difference(ref, cur)
        channels = delta.split()
        maximum = channels[0]
        for channel in channels[1:]:
            maximum = ImageChops.lighter(maximum, channel)
        histogram = maximum.histogram()
        total = ref.size[0] * ref.size[1]
        changed = total - histogram[0]
        cutoff = int(math.floor(tolerance * 255))
        different = sum(histogram[cutoff + 1 :])
        max_delta = max((index for index, count in enumerate(histogram) if count), default=0)

        beyond = maximum.point(lambda value: 255 if value > cutoff else 0)
        any_change = maximum.point(lambda value: 255 if value > 0 else 0)
        within = ImageChops.subtract(any_change, beyond)
        grey = cur.convert("L").convert("RGBA")
        background = Image.blend(Image.new("RGBA", cur.size, (250, 250, 250, 255)), grey, 0.32)
        background.paste((255, 196, 0, 255), (0, 0), within)
        background.paste((255, 32, 72, 255), (0, 0), beyond)
        diff_path.parent.mkdir(parents=True, exist_ok=True)
        background.save(diff_path, format="PNG")
        return {
            "dimensions_match": True,
            "reference_size": list(ref.size),
            "current_size": list(cur.size),
            "pixels": total,
            "changed_pixels": changed,
            "changed_ratio": changed / total,
            "different_pixels": different,
            "diff_ratio": different / total,
            "max_channel_delta": round(max_delta / 255, 6),
            "cutoff_channel_delta": round(cutoff / 255, 6),
        }


def html_report(report: dict[str, Any]) -> str:
    cards: list[str] = []
    for case in report["cases"]:
        images: list[str] = []
        for label, key in (("Approved reference", "reference_artifact"), ("Current", "current_artifact"), ("Difference", "diff_artifact")):
            artifact = case.get(key)
            if artifact:
                images.append(
                    f'<figure><figcaption>{html.escape(label)}</figcaption>'
                    f'<a href="{html.escape(artifact)}"><img src="{html.escape(artifact)}" alt="{html.escape(label)}"></a></figure>'
                )
        metrics = case.get("metrics", {})
        detail = (
            f"diff={metrics.get('diff_ratio', 'n/a')} / allowed={case['max_diff_ratio']}; "
            f"changed={metrics.get('changed_ratio', 'n/a')}; "
            f"max channel delta={metrics.get('max_channel_delta', 'n/a')}"
        )
        cards.append(
            f'<section class="case {html.escape(case["status"])}"><h2>{html.escape(case["id"])} '
            f'<span>{html.escape(case["status"])}</span></h2>'
            f'<p>{html.escape(case.get("notes", ""))}</p><p>{html.escape(detail)}</p>'
            f'<div class="frames">{"".join(images)}</div></section>'
        )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Visual review — {html.escape(report['profile'])}</title>
<style>
body{{margin:0;background:#0b1118;color:#e7eef6;font:15px system-ui,sans-serif}}main{{padding:24px;max-width:1800px;margin:auto}}
.case{{border:1px solid #33404d;border-radius:12px;padding:16px;margin:18px 0;background:#121b24}}.case h2{{margin-top:0}}
.case h2 span{{font-size:12px;color:#ffd166}}.MATCH{{border-color:#2c8c68}}.REVIEW_REQUIRED,.ERROR,.MISSING_CURRENT{{border-color:#d94b5b}}
.frames{{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px}}figure{{margin:0}}figcaption{{margin-bottom:6px;color:#a9bac8}}
img{{display:block;width:100%;height:auto;background:#000;border:1px solid #344553}}a{{color:#7bdff2}}code{{color:#c7d5e0}}
</style></head><body><main><h1>Visual review: {html.escape(report['profile'])}</h1>
<p>Overall: <strong>{report['overall_status']}</strong>. Automated matches are not human aesthetic approval. References change only through the explicit per-case approval command.</p>
<p><a href="report.md">Markdown report</a> · <a href="visual-review.json">Machine report</a></p>{''.join(cards)}</main></body></html>"""


def markdown_report(report: dict[str, Any]) -> str:
    lines = [
        f"# Visual review — {report['profile']}",
        "",
        f"- Overall: **{report['overall_status']}**",
        "- Automated MATCH is not human aesthetic approval; references never update during compare.",
        f"- Manifest: `{report['manifest']}` (`{report['manifest_sha256']}`)",
        "",
        "| Case | Status | Diff ratio | Allowed | Changed ratio | Max channel delta | Images |",
        "|---|---|---:|---:|---:|---:|---|",
    ]
    for case in report["cases"]:
        metrics = case.get("metrics", {})
        links = []
        for label, key in (("ref", "reference_artifact"), ("current", "current_artifact"), ("diff", "diff_artifact")):
            if case.get(key):
                links.append(f"[{label}]({case[key]})")
        lines.append(
            f"| {case['id']} | {case['status']} | {metrics.get('diff_ratio', '—')} "
            f"| {case['max_diff_ratio']} | {metrics.get('changed_ratio', '—')} "
            f"| {metrics.get('max_channel_delta', '—')} | {' / '.join(links) or '—'} |"
        )
    lines.extend(["", "## Case notes", ""])
    for case in report["cases"]:
        lines.append(f"- **{case['id']}:** {case.get('notes', '')} {case.get('error', '')}")
    lines.extend(
        [
            "",
            "## Approval boundary",
            "",
            "Inspect the actual reference/current/diff images. Update only intended cases with the explicit `approve --report ... --report-sha256 ... --case ... --reviewer ... --note ...` command. A failed comparison can mean either a regression or an intended change; neither is resolved automatically.",
            "",
        ]
    )
    return "\n".join(lines)


def compare(args: argparse.Namespace) -> int:
    manifest_path = args.manifest.expanduser().resolve()
    manifest = load_manifest(manifest_path)
    profile = manifest["profiles"].get(args.profile)
    if profile is None:
        raise ReviewError(f"Unknown profile {args.profile}; choose from {', '.join(manifest['profiles'])}.")
    output = args.out.expanduser().resolve() if args.out else ROOT / "exports" / "visual-review" / f"{args.profile}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ReviewError(f"Review output must be a new/empty directory: {output}")
    output.mkdir(parents=True, exist_ok=True)
    overrides: dict[str, Path] = {}
    for item in args.current or []:
        case_id, separator, filename = item.partition("=")
        if not separator or not ID_RE.fullmatch(case_id) or not filename:
            raise ReviewError("--current must be CASE_ID=/path/to/frame.png")
        overrides[case_id] = Path(filename).expanduser().resolve()
    known = {case["id"] for case in profile["cases"]}
    unknown = set(overrides) - known
    if unknown:
        raise ReviewError(f"--current names unknown case(s): {', '.join(sorted(unknown))}")

    report: dict[str, Any] = {
        "schema": 1,
        "generated_utc": utc_now(),
        "manifest": relative_display(manifest_path),
        "manifest_sha256": sha256_file(manifest_path),
        "profile": args.profile,
        "environment": profile.get("environment", {}),
        "motion_review": manifest.get("motion_review", {}),
        "overall_status": MATCH,
        "cases": [],
    }
    for case in profile["cases"]:
        case_id = case["id"]
        current = overrides.get(case_id, repo_path(profile["current_root"]) / case["current"])
        reference = repo_path(case["reference"])
        result: dict[str, Any] = {
            "id": case_id,
            "notes": case.get("notes", ""),
            "status": MATCH,
            "current_source": relative_display(current),
            "reference_target": case["reference"],
            "channel_tolerance": float(case.get("channel_tolerance", 0.0)),
            "max_diff_ratio": float(case.get("max_diff_ratio", 0.0)),
        }
        case_dir = output / "cases" / case_id
        if not current.is_file():
            result["status"] = MISSING
            result["error"] = f"Current capture is missing: {current}"
        else:
            result["current_sha256"] = sha256_file(current)
            # A missing baseline must not hide corrupt current evidence. Decode
            # every candidate even when there is nothing to compare it with.
            try:
                with load_png(current) as image:
                    result["current_size"] = list(image.size)
            except ReviewError as error:
                result["status"] = ERROR
                result["error"] = str(error)
                report["cases"].append(result)
                continue
            result["current_artifact"] = f"cases/{case_id}/current.png"
            copy_artifact(current, output / result["current_artifact"])
            if not reference.is_file():
                result["status"] = PENDING
                result["error"] = "No approved reference exists; inspect the current candidate before approval."
            else:
                result["reference_sha256"] = sha256_file(reference)
                result["reference_artifact"] = f"cases/{case_id}/reference.png"
                copy_artifact(reference, output / result["reference_artifact"])
                result["diff_artifact"] = f"cases/{case_id}/diff.png"
                try:
                    metrics = compare_images(
                        reference,
                        current,
                        output / result["diff_artifact"],
                        result["channel_tolerance"],
                    )
                    result["metrics"] = metrics
                    if not metrics["dimensions_match"]:
                        result["status"] = ERROR
                        result["error"] = "Reference/current dimensions differ; no resizing was performed."
                        Path(output / result["diff_artifact"]).unlink(missing_ok=True)
                        del result["diff_artifact"]
                    elif metrics["diff_ratio"] > result["max_diff_ratio"]:
                        result["status"] = REVIEW
                except ReviewError as error:
                    result["status"] = ERROR
                    result["error"] = str(error)
                    Path(output / result["diff_artifact"]).unlink(missing_ok=True)
                    del result["diff_artifact"]
        report["cases"].append(result)

    statuses = {case["status"] for case in report["cases"]}
    if statuses - {MATCH, PENDING}:
        report["overall_status"] = REVIEW
    elif PENDING in statuses:
        report["overall_status"] = PENDING
    report["counts"] = {
        status: sum(1 for case in report["cases"] if case["status"] == status)
        for status in sorted(statuses)
    }
    (output / "visual-review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (output / "report.md").write_text(markdown_report(report), encoding="utf-8")
    (output / "index.html").write_text(html_report(report), encoding="utf-8")
    print(f"Visual review: {output / 'index.html'}")
    print(f"Overall: {report['overall_status']} | {json.dumps(report['counts'], sort_keys=True)}")
    blocking = statuses - {MATCH, PENDING} if args.allow_pending else statuses - {MATCH}
    if blocking:
        print("Human review/correction is required; no reference was changed.")
        return 1
    return 0


def approve(args: argparse.Namespace) -> int:
    report_path = args.report.expanduser().resolve()
    expected_report_hash = args.report_sha256.lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected_report_hash):
        raise ReviewError("--report-sha256 must be the reviewed report's 64-digit SHA-256.")
    report_hash = sha256_file(report_path)
    if report_hash != expected_report_hash:
        raise ReviewError("Review report hash does not match; inspect the exact report and hash again.")
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ReviewError(f"Could not read review report: {error}") from error
    if not isinstance(report, dict) or report.get("schema") != 1:
        raise ReviewError("Approval needs a schema=1 visual-review.json report.")
    if not isinstance(report.get("profile"), str) or not ID_RE.fullmatch(report["profile"]):
        raise ReviewError("Approval report has an invalid profile id.")
    reviewer = args.reviewer.strip()
    note = args.note.strip()
    if not reviewer or not note:
        raise ReviewError("Approval requires a non-empty reviewer and review note.")
    selected = set(args.case)
    cases = {case.get("id"): case for case in report.get("cases", [])}
    if not selected or selected - set(cases):
        raise ReviewError(f"Choose valid report case(s): {', '.join(sorted(cases))}")

    pending: list[tuple[dict[str, Any], Path, Path, str]] = []
    for case_id in sorted(selected):
        case = cases[case_id]
        if case.get("status") not in {MATCH, REVIEW, PENDING}:
            raise ReviewError(f"{case_id} has no reviewable current image ({case.get('status')}).")
        artifact = case.get("current_artifact")
        target_name = case.get("reference_target")
        if not artifact or not isinstance(target_name, str):
            raise ReviewError(f"{case_id} lacks approval paths.")
        expected_target_root = PurePosixPath(GOLDEN_ROOT) / report["profile"]
        if not PurePosixPath(target_name).is_relative_to(expected_target_root):
            raise ReviewError(f"{case_id} reference target is outside its report profile.")
        artifact_path = PurePosixPath(artifact)
        if artifact_path.is_absolute() or ".." in artifact_path.parts:
            raise ReviewError(f"{case_id} has an unsafe current artifact path.")
        source = report_path.parent.joinpath(*artifact_path.parts)
        target = repo_path(target_name, golden=True)
        if not source.is_file() or sha256_file(source) != case.get("current_sha256"):
            raise ReviewError(f"{case_id} current image changed after the report; capture and review again.")
        # Re-decode before promotion so a hash-valid but unsupported file cannot become a golden.
        with load_png(source) as image:
            size = list(image.size)
        pending.append((case, source, target, sha256_file(source)))
        case["_approved_size"] = size

    approvals_path = ROOT / GOLDEN_ROOT / report["profile"] / "approvals.json"
    if approvals_path.is_file():
        approvals = json.loads(approvals_path.read_text(encoding="utf-8"))
    else:
        approvals = {"schema": 1, "profile": report["profile"], "cases": {}}
    if approvals.get("schema") != 1 or not isinstance(approvals.get("cases"), dict):
        raise ReviewError(f"Invalid approval ledger: {approvals_path}")
    timestamp = utc_now()
    for case, source, target, source_hash in pending:
        target.parent.mkdir(parents=True, exist_ok=True)
        previous = sha256_file(target) if target.is_file() else None
        temporary = target.with_name(target.name + ".approval-tmp")
        shutil.copyfile(source, temporary)
        if sha256_file(temporary) != source_hash:
            temporary.unlink(missing_ok=True)
            raise ReviewError(f"Approval copy failed integrity check for {case['id']}.")
        temporary.replace(target)
        approvals["cases"][case["id"]] = {
            "approved_utc": timestamp,
            "reviewer": reviewer,
            "note": note,
            "reference": case["reference_target"],
            "reference_sha256": source_hash,
            "previous_reference_sha256": previous,
            "size": case["_approved_size"],
            "comparison_status_when_reviewed": case["status"],
            "comparison_metrics": case.get("metrics", {}),
            "review_report": relative_display(report_path),
            "review_report_sha256": report_hash,
        }
        case.pop("_approved_size", None)
        print(f"Approved reference: {case['id']} -> {relative_display(target)}")
    approvals_path.parent.mkdir(parents=True, exist_ok=True)
    approvals_path.write_text(json.dumps(approvals, indent=2) + "\n", encoding="utf-8")
    print(f"Approval ledger: {relative_display(approvals_path)}")
    print("Review and commit the named golden changes; unrelated cases were not promoted.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    compare_parser = commands.add_parser("compare", help="write reference/current/diff evidence without updating goldens")
    compare_parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    compare_parser.add_argument("--profile", required=True)
    compare_parser.add_argument("--out", type=Path, help="new/empty report directory")
    compare_parser.add_argument("--current", action="append", help="override a case capture: CASE_ID=/path/frame.png")
    compare_parser.add_argument("--allow-pending", action="store_true", help="allow missing baselines while bootstrapping; never ignores mismatches/errors")
    compare_parser.set_defaults(handler=compare)
    approve_parser = commands.add_parser("approve", help="promote named, human-reviewed images from an existing report")
    approve_parser.add_argument("--report", type=Path, required=True, help="visual-review.json that was actually reviewed")
    approve_parser.add_argument("--report-sha256", required=True, help="SHA-256 of the exact reviewed visual-review.json")
    approve_parser.add_argument("--case", action="append", required=True, help="case to approve; repeat for multiple named cases")
    approve_parser.add_argument("--reviewer", required=True, help="person approving the actual images")
    approve_parser.add_argument("--note", required=True, help="why the current image is intended/acceptable")
    approve_parser.set_defaults(handler=approve)
    args = parser.parse_args()
    try:
        return args.handler(args)
    except (ReviewError, OSError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
