#!/usr/bin/env python3
"""Static structural validation for the Project Overdrive Godot project.

This tool inspects the project *without* running Godot. It is not a replacement
for the headless import and the smoke tests; it catches broken references,
mismatched types, and documentation drift early so the engine run only has to
answer gameplay questions.

Checks performed
----------------
1.  Scene/resource files: ``[ext_resource]`` paths exist and match their type.
2.  Scene node trees: every ``[node]`` parent resolves, sub-resources resolve,
    and ``load_steps`` matches the declared resource count.
3.  Script/node compatibility: a script's ``extends`` base class must be
    compatible with the node type it is attached to in every scene.
4.  Node paths: literal ``$Path`` / ``get_node("Path")`` references and exported
    ``NodePath`` defaults must resolve inside the scene that attaches the script.
5.  Script references: ``preload("res://...")`` / ``load("res://...")`` targets exist.
6.  Input actions: every action name used in GDScript exists in ``project.godot``.
7.  Signals: static ``connect("name", ...)`` targets are declared somewhere.
8.  Groups: ``is_in_group`` / ``get_nodes_in_group`` names are declared by code or scene.
9.  class_name uniqueness across scripts.
10. Web preview wiring: custom HTML shell placeholders, web renderer setting, landing page.
11. Weapon resources: mirror of ``WeaponDefinition.is_valid_definition()`` plus
    projectile scene/``launch()`` verification.
11. glTF/GLB assets: GLB header integrity, glTF external buffer/image files exist.
12. Documentation consistency: pinned engine version, smoke test inventory,
    orphaned scenes/scripts.

Usage
-----
    python3 tools/project_doctor.py [--root .] [--quiet]

Exit code is 1 when at least one FAIL is reported, otherwise 0.
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

# --------------------------------------------------------------------------- #
# Data model
# --------------------------------------------------------------------------- #

BUILTIN_ACTIONS = {
    "ui_accept",
    "ui_cancel",
    "ui_select",
    "ui_left",
    "ui_right",
    "ui_up",
    "ui_down",
    "ui_focus_next",
    "ui_focus_prev",
    "ui_page_up",
    "ui_page_down",
    "ui_home",
    "ui_end",
}

PASS = "PASS"
WARN = "WARN"
FAIL = "FAIL"


@dataclass
class Issue:
    level: str
    check: str
    message: str
    location: str = ""


@dataclass
class Report:
    issues: list[Issue] = field(default_factory=list)

    def add(self, level: str, check: str, message: str, location: str = "") -> None:
        self.issues.append(Issue(level, check, message, location))

    def fail(self, check: str, message: str, location: str = "") -> None:
        self.add(FAIL, check, message, location)

    def warn(self, check: str, message: str, location: str = "") -> None:
        self.add(WARN, check, message, location)

    def ok(self, check: str, message: str) -> None:
        self.add(PASS, check, message)

    @property
    def failures(self) -> list[Issue]:
        return [i for i in self.issues if i.level == FAIL]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.level == WARN]

    def render(self, quiet: bool = False) -> str:
        lines: list[str] = []
        by_check: dict[str, list[Issue]] = {}
        for issue in self.issues:
            by_check.setdefault(issue.check, []).append(issue)
        lines.append("Project Overdrive — static project doctor")
        lines.append("")
        for check_name, issues in by_check.items():
            flagged = [i for i in issues if i.level != PASS]
            if quiet and not flagged:
                continue
            lines.append(f"[{check_name}]")
            for issue in issues:
                if issue.level == PASS:
                    if not quiet:
                        lines.append(f"  ok    {issue.message}")
                    continue
                where = f" ({issue.location})" if issue.location else ""
                lines.append(f"  {issue.level.lower():5s} {issue.message}{where}")
            lines.append("")
        lines.append(
            "Summary: %d check group(s), %d FAIL, %d WARN"
            % (len(by_check), len(self.failures), len(self.warnings))
        )
        if self.failures:
            lines.append(
                "FAIL items are broken references or contracts; fix them before trusting a Godot run."
            )
        else:
            lines.append(
                "No structural failures detected. Static checks do not prove runtime behaviour; "
                "run scripts/run_smoke_tests.sh with Godot 4.7.2 installed."
            )
        return "\n".join(lines)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

ATTR_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*("(?:[^"\\]|\\.)*"|[^\s\]]+)')

# Godot single-inheritance chain for the node types used by this project.
BASE_CHAIN: dict[str, list[str]] = {
    "Node": ["Node", "Object"],
    "Node2D": ["Node2D", "CanvasItem", "Node", "Object"],
    "Node3D": ["Node3D", "Node", "Object"],
    "Control": ["Control", "CanvasItem", "Node", "Object"],
    "CanvasLayer": ["CanvasLayer", "Node", "Object"],
    "RefCounted": ["RefCounted", "Object"],
    "Resource": ["Resource", "RefCounted", "Object"],
    "CollisionObject3D": ["CollisionObject3D", "Node3D", "Node", "Object"],
    "PhysicsBody3D": ["PhysicsBody3D", "CollisionObject3D", "Node3D", "Node", "Object"],
    "CharacterBody3D": [
        "CharacterBody3D",
        "PhysicsBody3D",
        "CollisionObject3D",
        "Node3D",
        "Node",
        "Object",
    ],
    "StaticBody3D": [
        "StaticBody3D",
        "PhysicsBody3D",
        "CollisionObject3D",
        "Node3D",
        "Node",
        "Object",
    ],
    "RigidBody3D": [
        "RigidBody3D",
        "PhysicsBody3D",
        "CollisionObject3D",
        "Node3D",
        "Node",
        "Object",
    ],
    "Area3D": ["Area3D", "CollisionObject3D", "Node3D", "Node", "Object"],
    "VisualInstance3D": ["VisualInstance3D", "Node3D", "Node", "Object"],
    "MeshInstance3D": ["MeshInstance3D", "VisualInstance3D", "Node3D", "Node", "Object"],
    "Marker3D": ["Marker3D", "Node3D", "Node", "Object"],
    "Camera3D": ["Camera3D", "Node3D", "Node", "Object"],
    "SpringArm3D": ["SpringArm3D", "Node3D", "Node", "Object"],
    "CollisionShape3D": ["CollisionShape3D", "Node3D", "Node", "Object"],
    "DirectionalLight3D": ["DirectionalLight3D", "Light3D", "VisualInstance3D", "Node3D", "Node", "Object"],
    "OmniLight3D": ["OmniLight3D", "Light3D", "VisualInstance3D", "Node3D", "Node", "Object"],
    "WorldEnvironment": ["WorldEnvironment", "Node", "Object"],
    "Button": ["Button", "BaseButton", "Control", "CanvasItem", "Node", "Object"],
    "Label": ["Label", "Control", "CanvasItem", "Node", "Object"],
    "ProgressBar": ["ProgressBar", "Range", "Control", "CanvasItem", "Node", "Object"],
    "PanelContainer": ["PanelContainer", "Container", "Control", "CanvasItem", "Node", "Object"],
    "HBoxContainer": ["HBoxContainer", "BoxContainer", "Container", "Control", "CanvasItem", "Node", "Object"],
    "VBoxContainer": ["VBoxContainer", "BoxContainer", "Container", "Control", "CanvasItem", "Node", "Object"],
}


def base_class_of(node_type: str) -> list[str]:
    if node_type in BASE_CHAIN:
        return BASE_CHAIN[node_type]
    # Unknown node type: accept both Object and Node hierarchies conservatively.
    return [node_type, "Node", "Object"]


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def line_of(text: str, needle: str) -> int:
    for index, line in enumerate(text.splitlines(), start=1):
        if needle in line:
            return index
    return 0


# --------------------------------------------------------------------------- #
# Parsers
# --------------------------------------------------------------------------- #


@dataclass
class Section:
    kind: str
    attrs: dict[str, str]
    line: int


@dataclass
class SceneInfo:
    path: Path
    res_path: str
    sections: list[Section]

    @property
    def ext_resources(self) -> dict[str, dict[str, str]]:
        return {s.attrs.get("id", ""): s.attrs for s in self.sections if s.kind == "ext_resource"}

    @property
    def sub_resources(self) -> dict[str, dict[str, str]]:
        return {s.attrs.get("id", ""): s.attrs for s in self.sections if s.kind == "sub_resource"}

    @property
    def nodes(self) -> list[Section]:
        return [s for s in self.sections if s.kind == "node"]


def parse_scene(path: Path, res_path: str) -> SceneInfo:
    sections: list[Section] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    current: Section | None = None
    for index, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            head = stripped[1:-1]
            kind = head.split(" ", 1)[0]
            attrs = {k: unquote(v) for k, v in ATTR_RE.findall(head[len(kind):])}
            current = Section(kind=kind, attrs=attrs, line=index)
            sections.append(current)
        elif current is not None and "=" in stripped and not stripped.startswith(";"):
            key, _, value = stripped.partition("=")
            current.attrs[key.strip()] = value.strip()
    return SceneInfo(path=path, res_path=res_path, sections=sections)


def node_path_of(attrs: dict[str, str]) -> str:
    """Path of a node relative to its scene root (the root itself is '')."""
    parent = attrs.get("parent")
    if parent is None:
        return ""
    if parent in ("", "."):
        return attrs.get("name", "")
    return f"{parent}/{attrs.get('name', '')}"


def resolve_relative_path(base: str, target: str) -> str | None:
    """Resolve a Godot node path relative to *base* (a node path inside a scene)."""
    if target.startswith("/root/"):
        return None
    parts = [p for p in base.split("/") if p]
    for segment in target.split("/"):
        if segment in ("", "."):
            continue
        if segment == "..":
            if not parts:
                return None
            parts.pop()
        else:
            parts.append(segment)
    return "/".join(parts)


# --------------------------------------------------------------------------- #
# GDScript parsing (lightweight, regex based)
# --------------------------------------------------------------------------- #

SCRIPT_REF_RE = re.compile(r'\b(?:preload|load)\(\s*"([^"]+)"\s*\)')
# `extends` on its own line, or inline after `class_name` — both are legal
# GDScript and both appear in this project (`class_name ScifiKitLibrary
# extends RefCounted`). Matching only the first form left those scripts with no
# base class at all, so every check that compares one silently skipped them.
EXTENDS_RE = re.compile(
    r"^extends\s+([A-Za-z_][A-Za-z0-9_]*)"
    r"|^class_name\s+[A-Za-z_][A-Za-z0-9_]*\s+extends\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)
CLASS_NAME_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
SIGNAL_RE = re.compile(r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
ADD_GROUP_RE = re.compile(r'add_to_group\(\s*"([^"]+)"\s*\)')
GROUP_QUERY_RE = re.compile(r'(?:is_in_group|get_nodes_in_group|remove_from_group)\(\s*"([^"]+)"\s*\)')
CONNECT_RE = re.compile(r'\.connect\(\s*(?:"([^"]+)"|&"([^"]+)")')
EMIT_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.emit\(")
INPUT_ACTION_RE = re.compile(
    r'Input\.(?:is_action_pressed|is_action_just_pressed|is_action_released'
    r'|is_action_just_released|get_action_strength|get_axis|action_press|action_release)'
    r'\(\s*"([^"]+)"'
)
GET_VECTOR_RE = re.compile(r'Input\.get_vector\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"')
DOLLAR_PATH_RE = re.compile(r'\$"?([A-Za-z_%][A-Za-z0-9_/%]*)"?')
SELF_GET_NODE_RE = re.compile(
    r'(?<![A-Za-z0-9_.])get_node(?:_or_null)?\(\s*"([^"$%]+)"\s*\)'
)
NODE_PATH_EXPORT_RE = re.compile(r'@export\s+var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*NodePath\s*=\s*\^"([^"]*)"')


@dataclass
class ScriptInfo:
    path: Path
    res_path: str
    text: str
    class_name: str = ""
    extends: str = ""
    signals: set[str] = field(default_factory=set)
    functions: set[str] = field(default_factory=set)
    groups_declared: set[str] = field(default_factory=set)


def parse_script(path: Path, res_path: str) -> ScriptInfo:
    text = path.read_text(encoding="utf-8", errors="replace")
    info = ScriptInfo(path=path, res_path=res_path, text=text)
    if match := CLASS_NAME_RE.search(text):
        info.class_name = match.group(1)
    if match := EXTENDS_RE.search(text):
        info.extends = match.group(1) or match.group(2) or ""
    info.signals = set(SIGNAL_RE.findall(text))
    info.functions = set(FUNC_RE.findall(text))
    info.groups_declared = set(ADD_GROUP_RE.findall(text))
    return info


def strip_comments(line: str) -> str:
    """Remove a trailing ``#`` comment while respecting simple string literals."""
    in_string = False
    result = []
    for index, char in enumerate(line):
        if char == '"' and (index == 0 or line[index - 1] != "\\"):
            in_string = not in_string
        if char == "#" and not in_string:
            break
        result.append(char)
    return "".join(result)


# --------------------------------------------------------------------------- #
# Checks
# --------------------------------------------------------------------------- #


def project_root_res(root: Path) -> Path:
    return root


def game_dir(root: Path) -> Path:
    candidate = root / "game"
    return candidate if (candidate / "project.godot").exists() else root


def res_to_path(game_root: Path, res_path: str) -> Path | None:
    if not res_path.startswith("res://"):
        return None
    return game_root / res_path[len("res://"):]


def check_scene_structure(report: Report, scenes: dict[str, SceneInfo], game_root: Path) -> None:
    check = "scene structure"
    broken = 0
    for res_path, scene in sorted(scenes.items()):
        declared = {k: v for k, v in scene.ext_resources.items() if k}
        for res_id, attrs in declared.items():
            ext_path = attrs.get("path", "")
            ext_type = attrs.get("type", "")
            target = res_to_path(game_root, ext_path)
            if target is None:
                continue
            if not target.exists():
                report.fail(check, f"ext_resource '{res_id}' points to a missing file: {ext_path}", res_path)
                broken += 1
                continue
            suffix = target.suffix.lower()
            expected = {
                "Script": {".gd"},
                "PackedScene": {".tscn", ".scn", ".gltf", ".glb"},
                "Resource": {".tres", ".res"},
                "Texture2D": {".png", ".jpg", ".jpeg", ".webp", ".svg"},
                "Environment": {".tres", ".res"},
                "Material": {".tres", ".res"},
                "Mesh": {".tres", ".res"},
            }.get(ext_type)
            if expected and suffix not in expected:
                report.warn(
                    check,
                    f"ext_resource '{res_id}' declared as {ext_type} but file is '{suffix}': {ext_path}",
                    res_path,
                )

        # node parents and paths
        paths: dict[str, dict[str, str]] = {}
        for node in scene.nodes:
            attrs = node.attrs
            parent = attrs.get("parent", "")
            if parent not in ("", "."):
                if parent not in paths:
                    report.fail(
                        check,
                        f"node '{attrs.get('name', '?')}' references unknown parent '{parent}'",
                        res_path,
                    )
                    broken += 1
                    continue
            full = node_path_of(attrs)
            if full in paths:
                report.fail(check, f"duplicate node path '{full}'", res_path)
                broken += 1
            paths[full] = attrs

        # load_steps sanity
        expected_steps = 1 + len(declared) + len(scene.sub_resources)
        head = scene.sections[0].attrs if scene.sections else {}
        declared_steps = head.get("load_steps")
        if declared_steps and declared_steps.isdigit() and int(declared_steps) != expected_steps:
            report.warn(
                check,
                f"load_steps={declared_steps} but the file declares {expected_steps} resources",
                res_path,
            )
    if broken == 0:
        report.ok(check, f"{len(scenes)} scene/resource file(s) have resolvable references and node trees")


def resolve_extends(extends: str, by_class_name: dict[str, ScriptInfo]) -> str:
    """Follow a `class_name` chain down to a built-in type.

    A script that says `extends MenuStage` is attached to a Control, and
    MenuStage extends Control — but the chain has to be followed before the
    comparison means anything. Without this, every menu stage in the project
    was reported as "script base 'MenuStage' cannot be attached to node type
    'Control'", which is false and was failing the CI static job.
    """
    seen: set[str] = set()
    current = extends
    while current in by_class_name and current not in seen:
        seen.add(current)
        parent = by_class_name[current].extends
        if not parent:
            break
        current = parent
    return current


def check_script_attachment(
    report: Report, scenes: dict[str, SceneInfo], scripts: dict[str, ScriptInfo]
) -> None:
    check = "script/node types"
    problems = 0
    by_class_name: dict[str, ScriptInfo] = {
        script.class_name: script for script in scripts.values() if script.class_name
    }
    for res_path, scene in sorted(scenes.items()):
        for node in scene.nodes:
            attrs = node.attrs
            script_ref = attrs.get("script", "")
            if not script_ref.startswith("ExtResource("):
                continue
            res_id = script_ref[len("ExtResource("):-1].strip('"')
            ext = scene.ext_resources.get(res_id)
            if not ext or ext.get("type") != "Script":
                continue
            script = scripts.get(ext.get("path", ""))
            node_type = attrs.get("type", "")
            if script is None or not node_type or not script.extends:
                continue
            chain = base_class_of(node_type)
            base = resolve_extends(script.extends, by_class_name)
            if base not in chain:
                report.fail(
                    check,
                    f"script base '{script.extends}' (resolved to '{base}') cannot be attached to "
                    f"node type '{node_type}' (node '{attrs.get('name', '?')}')",
                    f"{res_path} → {script.res_path}",
                )
                problems += 1
    if problems == 0:
        report.ok(check, "every attached script's base class matches its node type")


def build_node_index(
    scene: SceneInfo,
    game_root: Path,
    scenes: dict[str, SceneInfo],
    base_path: str = "",
    visited: frozenset[str] = frozenset(),
) -> dict[str, dict[str, str]]:
    """Map every node path in *scene* (including instanced sub-scenes) to its attributes."""
    index: dict[str, dict[str, str]] = {}
    for node in scene.nodes:
        attrs = node.attrs
        parent = attrs.get("parent")
        if parent is None:
            path = base_path
        else:
            local_parent = "" if parent in ("", ".") else parent
            segments = [part for part in (base_path, local_parent) if part]
            segments.append(attrs.get("name", ""))
            path = "/".join(segments)
        index[path] = attrs
        instance_ref = attrs.get("instance", "")
        if instance_ref.startswith("ExtResource("):
            res_id = instance_ref[len("ExtResource("):-1].strip('"')
            ext = scene.ext_resources.get(res_id, {})
            child_res = ext.get("path", "")
            if child_res in visited or not child_res.endswith(".tscn"):
                continue
            child_scene = scenes.get(child_res)
            if child_scene is None:
                child_path = res_to_path(game_root, child_res)
                if child_path is None or not child_path.exists():
                    continue
                child_scene = parse_scene(child_path, child_res)
            index.update(
                build_node_index(
                    child_scene, game_root, scenes, path, visited | {child_res}
                )
            )
    return index


def collect_runtime_node_names(scripts: dict[str, ScriptInfo]) -> set[str]:
    """Names of nodes that scripts create themselves and therefore never appear in a .tscn."""
    names: set[str] = set()
    for script in scripts.values():
        for line in script.text.splitlines():
            for match in re.finditer(r'name\s*=\s*"([^"]+)"', line):
                names.add(match.group(1))
    return names


def _collect_script_path_refs(script: ScriptInfo) -> list[tuple[int, str, str]]:
    """Yield (line, kind, raw_target) for literal node path references owned by self."""
    refs: list[tuple[int, str, str]] = []
    for line_number, raw_line in enumerate(script.text.splitlines(), start=1):
        line = strip_comments(raw_line)
        for match in DOLLAR_PATH_RE.finditer(line):
            refs.append((line_number, "$", match.group(1)))
        for match in SELF_GET_NODE_RE.finditer(line):
            refs.append((line_number, "get_node", match.group(1)))
    return refs


def check_node_paths(
    report: Report, scenes: dict[str, SceneInfo], scripts: dict[str, ScriptInfo], game_root: Path
) -> None:
    check = "node paths"
    problems = 0
    runtime_warnings = 0
    runtime_names = collect_runtime_node_names(scripts)
    for res_path, scene in sorted(scenes.items()):
        node_index = build_node_index(scene, game_root, scenes)
        for node in scene.nodes:
            attrs = node.attrs
            script_ref = attrs.get("script", "")
            if not script_ref.startswith("ExtResource("):
                continue
            res_id = script_ref[len("ExtResource("):-1].strip('"')
            ext = scene.ext_resources.get(res_id)
            if not ext:
                continue
            script = scripts.get(ext.get("path", ""))
            if script is None:
                continue
            script_node_path = node_path_of(attrs)
            for line_number, kind, target in _collect_script_path_refs(script):
                if "%" in target and kind == "$":
                    continue  # unique-name shortcut, not a plain path
                if target.startswith("res://"):
                    continue
                resolved = resolve_relative_path(script_node_path, target)
                if resolved is not None and resolved in node_index:
                    continue
                created_at_runtime = any(
                    segment in runtime_names or segment.endswith("_Beacon")
                    for segment in target.split("/")
                )
                if resolved is None or created_at_runtime:
                    report.warn(
                        check,
                        f'{kind}("{target}") is not part of the scene file; it resolves only at '
                        "runtime (parent scene instantiation or script-created nodes)",
                        f"{script.res_path}:{line_number} (scene {res_path})",
                    )
                    runtime_warnings += 1
                else:
                    report.fail(
                        check,
                        f'{kind}("{target}") does not resolve in this scene',
                        f"{script.res_path}:{line_number} (scene {res_path})",
                    )
                    problems += 1
            for match in NODE_PATH_EXPORT_RE.finditer(script.text):
                var_name, target = match.group(1), match.group(2)
                if not target:
                    continue
                resolved = resolve_relative_path(script_node_path, target)
                if resolved is None or resolved not in node_index:
                    report.warn(
                        check,
                        f"exported NodePath {var_name} = ^{target} does not resolve from node "
                        f"'{script_node_path}' (expected when the node is reparented at runtime)",
                        f"{script.res_path} (scene {res_path})",
                    )
                    runtime_warnings += 1
    if problems == 0:
        report.ok(
            check,
            "every literal $/%s node path resolves in its own scene "
            "(%d cross-scene runtime lookup(s) reported)" % ("get_node", runtime_warnings),
        )


def check_script_references(report: Report, scripts: dict[str, ScriptInfo], game_root: Path) -> None:
    check = "preload/load targets"
    missing = 0
    for res_path, script in sorted(scripts.items()):
        for match in SCRIPT_REF_RE.finditer(script.text):
            target = match.group(1)
            if target == "" or not target.startswith("res://"):
                continue
            path = res_to_path(game_root, target)
            if path is None or not path.exists():
                report.fail(check, f"preload/load target missing: {target}", res_path)
                missing += 1
    if missing == 0:
        report.ok(check, f"every res:// preload/load target in {len(scripts)} script(s) exists")


def parse_input_actions(project_file: Path) -> set[str]:
    actions: set[str] = set()
    if not project_file.exists():
        return actions
    text = project_file.read_text(encoding="utf-8", errors="replace")
    in_input = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_input = stripped == "[input]"
            continue
        if not in_input or not stripped or stripped.startswith(";"):
            continue
        # Action blocks start with ``name={``; the continuation lines hold
        # "deadzone"/"events" keys and must not be read as action names.
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*\s*=\s*\{', stripped):
            actions.add(stripped.split("=", 1)[0].strip())
    return actions


def check_input_actions(report: Report, scripts: dict[str, ScriptInfo], project_file: Path) -> set[str]:
    check = "input actions"
    declared = parse_input_actions(project_file)
    used: dict[str, str] = {}
    for res_path, script in sorted(scripts.items()):
        for match in INPUT_ACTION_RE.finditer(script.text):
            used.setdefault(match.group(1), res_path)
        for match in GET_VECTOR_RE.finditer(script.text):
            for action in match.groups():
                used.setdefault(action, res_path)
    problems = 0
    for action, res_path in sorted(used.items()):
        if action in BUILTIN_ACTIONS:
            continue
        if action not in declared:
            report.fail(check, f"action '{action}' is used in script but not defined in project.godot", res_path)
            problems += 1
    for action in sorted(declared - set(used)):
        report.warn(check, f"action '{action}' is defined in project.godot but never read by GDScript", "game/project.godot")
    if problems == 0:
        report.ok(check, f"{len(used)} action(s) used by code are all defined ({len(declared)} declared)")
    return declared


def check_signals(report: Report, scripts: dict[str, ScriptInfo], scenes: dict[str, SceneInfo]) -> None:
    check = "signals"
    declared: set[str] = set()
    for script in scripts.values():
        declared |= script.signals
    problems = 0
    for res_path, scene in sorted(scenes.items()):
        for node in scene.nodes:
            raw = node.attrs.get("connection_signal", "")
            if raw and raw not in declared:
                report.fail(check, f"scene connection uses undeclared signal '{raw}'", res_path)
                problems += 1
    for res_path, script in sorted(scripts.items()):
        for line_number, raw_line in enumerate(script.text.splitlines(), start=1):
            line = strip_comments(raw_line)
            for match in CONNECT_RE.finditer(line):
                signal_name = match.group(1) or match.group(2)
                if signal_name and signal_name not in declared:
                    report.fail(
                        check,
                        f"connect(\"{signal_name}\") target signal is not declared anywhere",
                        f"{res_path}:{line_number}",
                    )
                    problems += 1
            for match in EMIT_RE.finditer(line):
                signal_name = match.group(1)
                if signal_name in ("self",):
                    continue
                if signal_name not in script.signals:
                    report.warn(
                        check,
                        f"{signal_name}.emit(...) is not declared in this file (fine for external emitters)",
                        f"{res_path}:{line_number}",
                    )
    if problems == 0:
        report.ok(check, f"{len(declared)} declared signal(s); static connect() targets resolve")


def check_groups(report: Report, scripts: dict[str, ScriptInfo], scenes: dict[str, SceneInfo]) -> None:
    check = "groups"
    declared: set[str] = set()
    for script in scripts.values():
        declared |= script.groups_declared
    for scene in scenes.values():
        for node in scene.nodes:
            raw = node.attrs.get("groups", "")
            for group in re.findall(r'"([^"]+)"', raw):
                declared.add(group)
    queried: dict[str, str] = {}
    for res_path, script in sorted(scripts.items()):
        for match in GROUP_QUERY_RE.finditer(script.text):
            queried.setdefault(match.group(1), res_path)
    problems = 0
    for group, res_path in sorted(queried.items()):
        if group not in declared:
            report.fail(check, f"group '{group}' is queried but never assigned by code or scene", res_path)
            problems += 1
    for group in sorted(declared - set(queried)):
        report.warn(check, f"group '{group}' is assigned but never queried", "project")
    if problems == 0:
        report.ok(check, f"{len(queried)} queried group(s) are all declared")


def check_class_names(report: Report, scripts: dict[str, ScriptInfo]) -> dict[str, str]:
    check = "class_name"
    seen: dict[str, str] = {}
    problems = 0
    for res_path, script in sorted(scripts.items()):
        if not script.class_name:
            continue
        if script.class_name in seen:
            report.fail(check, f"class_name '{script.class_name}' is declared twice", f"{seen[script.class_name]} and {res_path}")
            problems += 1
        seen[script.class_name] = res_path
    if problems == 0:
        report.ok(check, f"{len(seen)} unique class_name declaration(s)")
    return seen


def check_project_settings(report: Report, game_root: Path) -> None:
    """Check res:// paths referenced from project.godot (icon, main scene, autoloads...)."""
    check = "project settings"
    project_file = game_root / "project.godot"
    if not project_file.exists():
        report.fail(check, "game/project.godot not found", "game/")
        return
    text = project_file.read_text(encoding="utf-8", errors="replace")
    problems = 0
    for res_path in sorted(set(re.findall(r'"(res://[^"]+)"', text))):
        target = res_to_path(game_root, res_path)
        if target is None or not target.exists():
            report.fail(check, f"project.godot references a missing file: {res_path}", "game/project.godot")
            problems += 1
    # Godot's config parser only understands ';' comments. A '#' line is silently
    # folded into the previous key name, which is how an aspect setting once got
    # swallowed: the value looked right in the file but never reached the engine.
    bad_comments = [
        f"{number}: {line.strip()[:60]}"
        for number, line in enumerate(text.splitlines(), start=1)
        if line.lstrip().startswith("#")
    ]
    if bad_comments:
        report.fail(
            check,
            "project.godot uses '#' comments; Godot only understands ';' and folds the line into the key before it "
            f"({'; '.join(bad_comments[:3])})",
            "game/project.godot",
        )
        problems += 1

    if 'config/icon=' not in text:
        report.warn(
            check,
            "game/project.godot has no application/config/icon; the Web exporter generates favicons from it, "
            "so html/export_icon=true can fail without one",
            "game/project.godot",
        )
    if problems == 0:
        report.ok(check, "every res:// path referenced by project.godot exists")


def check_weapon_resources(report: Report, game_root: Path, scenes: dict[str, SceneInfo]) -> None:
    check = "weapon resources"
    weapon_dir = game_root / "resources" / "weapons"
    files = sorted(weapon_dir.glob("*.tres")) if weapon_dir.exists() else []
    if not files:
        report.warn(check, "no weapon definitions found under game/resources/weapons")
        return
    problems = 0
    for path in files:
        res_path = f"res://{path.relative_to(game_root).as_posix()}"
        scene = parse_scene(path, res_path)
        attrs = scene.sections[-1].attrs if scene.sections else {}
        if scene.sections and scene.sections[-1].kind != "resource":
            attrs = {}
            for section in scene.sections:
                if section.kind == "resource":
                    attrs = section.attrs

        def number(key: str, default: float) -> float:
            try:
                return float(attrs.get(key, default))
            except (TypeError, ValueError):
                return default

        weapon_id = attrs.get("weapon_id", "").strip('&"')
        display_name = attrs.get("display_name", "")
        fire_rate = number("fire_rate", 0.0)
        damage = number("damage", 0.0)
        splash_damage = number("splash_damage", 0.0)
        splash_radius = number("splash_radius", 0.0)
        chain_count = number("chain_count", 0.0)
        chain_radius = number("chain_radius", 0.0)
        chain_multiplier = number("chain_damage_multiplier", 0.0)

        if not weapon_id or not display_name:
            report.fail(check, "weapon_id/display_name missing", res_path)
            problems += 1
        if fire_rate <= 0.0 or damage <= 0.0:
            report.fail(check, "fire_rate and damage must be > 0", res_path)
            problems += 1
        if splash_damage > 0.0 and splash_radius <= 0.0:
            report.fail(check, "splash_damage > 0 requires splash_radius > 0", res_path)
            problems += 1
        if chain_count > 0 and (chain_radius <= 0.0 or chain_multiplier <= 0.0):
            report.fail(check, "chain_count > 0 requires chain_radius and chain_damage_multiplier > 0", res_path)
            problems += 1
        if chain_multiplier > 1.0:
            report.fail(check, "chain_damage_multiplier must be <= 1.0", res_path)
            problems += 1

        projectile_res = ""
        for res_id, ext in scene.ext_resources.items():
            if ext.get("type") == "PackedScene":
                projectile_res = ext.get("path", "")
        if not projectile_res:
            report.fail(check, "no projectile PackedScene referenced", res_path)
            problems += 1
            continue
        projectile_path = res_to_path(game_root, projectile_res)
        if projectile_path is None or not projectile_path.exists():
            report.fail(check, f"projectile scene missing: {projectile_res}", res_path)
            problems += 1
            continue
        projectile_scene = scenes.get(projectile_res)
        if projectile_scene is None:
            projectile_scene = parse_scene(projectile_path, projectile_res)
        root = projectile_scene.nodes[0].attrs if projectile_scene.nodes else {}
        if root.get("type") != "Node3D":
            report.fail(
                check,
                f"projectile root must be Node3D for launch(), found '{root.get('type', '?')}'",
                res_path,
            )
            problems += 1
        script_ref = root.get("script", "")
        if script_ref.startswith("ExtResource("):
            res_id = script_ref[len("ExtResource("):-1].strip('"')
            ext = projectile_scene.ext_resources.get(res_id, {})
            target = res_to_path(game_root, ext.get("path", ""))
            if target and target.exists():
                script_text = target.read_text(encoding="utf-8", errors="replace")
                if "func launch(" not in script_text:
                    report.fail(check, f"projectile script has no launch(): {ext.get('path')}", res_path)
                    problems += 1
    if problems == 0:
        report.ok(check, f"{len(files)} weapon definition(s) satisfy WeaponDefinition.is_valid_definition()")


def check_gltf_assets(report: Report, game_root: Path) -> None:
    check = "3D assets"
    assets_root = game_root / "assets"
    files = sorted(list(assets_root.rglob("*.glb")) + list(assets_root.rglob("*.gltf"))) if assets_root.exists() else []
    problems = 0
    total = 0
    for path in files:
        total += 1
        if path.suffix.lower() == ".glb":
            data = path.read_bytes()
            if len(data) < 12 or data[0:4] != b"glTF":
                report.fail(check, f"invalid GLB header ({len(data)} bytes)", str(path.relative_to(game_root)))
                problems += 1
                continue
            stored_length = struct.unpack("<I", data[8:12])[0]
            if stored_length != len(data):
                report.warn(
                    check,
                    f"GLB header length {stored_length} != file size {len(data)}",
                    str(path.relative_to(game_root)),
                )
        else:
            try:
                payload = json.loads(path.read_text(encoding="utf-8", errors="replace"))
            except json.JSONDecodeError as error:
                report.fail(check, f"glTF JSON is invalid: {error}", str(path.relative_to(game_root)))
                problems += 1
                continue
            for collection, key in (("buffers", "uri"), ("images", "uri")):
                for entry in payload.get(collection, []):
                    uri = entry.get(key, "")
                    if not uri or uri.startswith("data:"):
                        continue
                    dependency = path.parent / uri
                    if not dependency.exists():
                        report.fail(
                            check,
                            f"{collection[:-1]} dependency missing: {uri}",
                            str(path.relative_to(game_root)),
                        )
                        problems += 1
    if problems == 0:
        report.ok(check, f"{total} glTF/GLB asset(s) have valid headers and resolvable dependencies")

    stray = sorted(path for path in game_root.parent.glob("*.glb"))
    for path in stray:
        if path.stat().st_size < 12:
            report.warn(
                check,
                f"'{path.name}' at repository root is {path.stat().st_size} bytes and cannot be a valid GLB; "
                "it is not referenced by any scene",
                str(path.relative_to(game_root.parent)),
            )


def check_web_preview(report: Report, root: Path, game_root: Path) -> None:
    """Verify the wiring of the WebAssembly preview path (shell, preset, landing page)."""
    check = "web preview"
    problems = 0

    shell = game_root / "web_shell" / "index.html"
    placeholders = (
        "$GODOT_PROJECT_NAME",
        "$GODOT_URL",
        "$GODOT_CONFIG",
        "$GODOT_THREADS_ENABLED",
        "$GODOT_HEAD_INCLUDE",
        "$GODOT_SPLASH",
    )
    if not shell.exists():
        report.fail(check, "game/web_shell/index.html (custom Godot web shell) is missing", str(shell.relative_to(root)))
        problems += 1
    else:
        text = shell.read_text(encoding="utf-8", errors="replace")
        missing = [placeholder for placeholder in placeholders if placeholder not in text]
        if missing:
            report.fail(check, "web shell is missing placeholder(s): " + ", ".join(missing), str(shell.relative_to(root)))
            problems += 1
        if "<canvas" not in text:
            report.fail(check, "web shell has no <canvas> element", str(shell.relative_to(root)))
            problems += 1
        if "new Engine(" not in text:
            report.fail(check, "web shell does not construct the Godot Engine object", str(shell.relative_to(root)))
            problems += 1

    project_file = game_root / "project.godot"
    if project_file.exists() and 'rendering_method.web="gl_compatibility"' not in project_file.read_text(encoding="utf-8"):
        report.fail(
            check,
            'game/project.godot is missing renderer/rendering_method.web="gl_compatibility" '
            "(the web platform only supports the Compatibility renderer)",
            "game/project.godot",
        )
        problems += 1

    landing = root / "index.html"
    if not landing.exists():
        report.fail(check, "repository root has no index.html page for the web preview", "index.html")
        problems += 1
    else:
        text = landing.read_text(encoding="utf-8", errors="replace")
        # Each of these encodes a failure that was observed for real in a browser.
        for needle, why in (
            ("./web/index.html", "must read the export config from ./web/index.html"),
            (
                '<script src="./web/index.js"',
                "must load the engine through a static script tag; the engine derives its asset directory "
                "from document.currentScript, so a dynamically injected script sends it looking for index.wasm in the page directory",
            ),
            (
                "config.executable",
                "must set config.executable to ./web/index, otherwise index.wasm/index.pck are requested next to the page",
            ),
            ("startGame", "must call Engine.startGame()"),
        ):
            if needle not in text:
                report.fail(check, f"index.html {why}", "index.html")
                problems += 1

    payload = root / "web" / "index.html"
    if not payload.exists():
        report.warn(
            check,
            "web/ payload is not present; ./scripts/export_web_preview.sh or the web-preview CI job writes it",
            "web/",
        )
    else:
        for asset in ("index.js", "index.wasm", "index.pck"):
            if not (root / "web" / asset).exists():
                report.fail(check, f"web/{asset} is missing next to web/index.html; the payload is incomplete", "web/")
                problems += 1

    gitignore = root / ".gitignore"
    if gitignore.exists():
        patterns = {line.strip() for line in gitignore.read_text(encoding="utf-8").splitlines()}
        if "web/" in patterns or "/web/" in patterns:
            report.fail(
                check,
                "'.gitignore' ignores web/, but the export payload is carried in the repository on purpose so that a "
                "clone can play without downloading an artifact",
                ".gitignore",
            )
            problems += 1

    templates = root / "engine" / "web_templates"
    if not templates.exists() or not any(templates.glob("*.zip")):
        report.warn(
            check,
            "engine/web_templates has no web export templates; a local export then needs the full ~1.2 GB template download",
            "engine/web_templates",
        )

    if not (root / "tools" / "web_qa.mjs").exists():
        report.warn(check, "tools/web_qa.mjs (headless browser gate) is missing")

    if problems == 0:
        report.ok(check, "shell, renderer setting, root page import path, payload and browser gate are wired consistently")


def check_docs(report: Report, root: Path, game_root: Path, scenes: dict[str, SceneInfo], scripts: dict[str, ScriptInfo]) -> None:
    check = "docs consistency"
    version_file = root / ".godot-version"
    pinned = version_file.read_text(encoding="utf-8").strip() if version_file.exists() else ""
    project_file = game_root / "project.godot"
    features = ""
    if project_file.exists():
        match = re.search(r'config/features=PackedStringArray\("([^"]+)"\)', project_file.read_text(encoding="utf-8"))
        features = match.group(1) if match else ""
    problems = 0
    if pinned and features and not pinned.startswith(features):
        report.fail(check, f".godot-version {pinned} does not match project.godot feature '{features}'", ".godot-version")
        problems += 1

    tests = sorted(p.name for p in (game_root / "tests").glob("*_smoke.gd"))
    for doc_name in ("README.md", "TOOLCHAIN_SETUP.md"):
        doc = root / doc_name
        if not doc.exists():
            continue
        text = doc.read_text(encoding="utf-8", errors="replace")
        missing = [test for test in tests if test not in text]
        if missing:
            report.warn(check, f"{doc_name} does not mention smoke test(s): {', '.join(missing)}", doc_name)
        if pinned and pinned not in text and doc_name == "README.md":
            report.warn(check, f"{doc_name} does not state the pinned engine version {pinned}", doc_name)

    # orphan detection: scenes and scripts referenced by nothing
    referenced: set[str] = set()
    for script in scripts.values():
        referenced |= set(SCRIPT_REF_RE.findall(script.text))
    # A global class_name is a reference too: gameplay calls Sfx.play_ui(), the
    # facade script itself is never named by path anywhere.
    global_classes = {
        script.class_name: res_path for res_path, script in scripts.items() if script.class_name
    }
    for script in scripts.values():
        for class_name, res_path in global_classes.items():
            if re.search(r"\b%s\b" % re.escape(class_name), script.text) and res_path != script.path:
                referenced.add(res_path)
    for res_path, scene in scenes.items():
        for ext in scene.ext_resources.values():
            referenced.add(ext.get("path", ""))
    project_text = project_file.read_text(encoding="utf-8") if project_file.exists() else ""
    main_scene_match = re.search(r'run/main_scene="([^"]+)"', project_text)
    if main_scene_match:
        referenced.add(main_scene_match.group(1))
    # Autoloads live in project.godot, not in a scene: without this the audio
    # director (and any future singleton) shows up as an unreferenced script.
    if project_text:
        autoload_section = re.search(r"^\[autoload\]\s*$([\s\S]*?)(?=^\[|\Z)", project_text, re.MULTILINE)
        if autoload_section:
            referenced |= {
                match.group(1)
                for match in re.finditer(r'=\s*"\*?(res://[^"]+)"', autoload_section.group(1))
            }

    for res_path in sorted(scenes):
        if res_path not in referenced:
            report.warn(check, f"scene is not referenced by any script, scene, or main_scene: {res_path}", res_path)
    for res_path, script in sorted(scripts.items()):
        if res_path.startswith("res://tests/"):
            continue  # standalone --script smoke tests are intentionally unreferenced
        if res_path not in referenced:
            report.warn(check, f"script is not referenced by any scene or preload: {res_path}", res_path)

    if problems == 0:
        report.ok(check, f"engine pin and {len(tests)} smoke test(s) are consistent with the docs")


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #


def collect(root: Path) -> tuple[Path, dict[str, SceneInfo], dict[str, ScriptInfo]]:
    game_root = game_dir(root)
    scenes: dict[str, SceneInfo] = {}
    scripts: dict[str, ScriptInfo] = {}
    for path in sorted(game_root.rglob("*")):
        if ".godot" in path.parts or not path.is_file():
            continue
        suffix = path.suffix.lower()
        res_path = f"res://{path.relative_to(game_root).as_posix()}"
        if suffix in (".tscn", ".tres", ".res"):
            if suffix == ".res":
                continue
            scenes[res_path] = parse_scene(path, res_path)
        elif suffix == ".gd":
            scripts[res_path] = parse_script(path, res_path)
    return game_root, scenes, scripts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Static structural validation for the Godot project.")
    parser.add_argument("--root", default=".", help="repository root (default: current directory)")
    parser.add_argument("--quiet", action="store_true", help="hide PASS lines")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    if not (root / "game" / "project.godot").exists() and not (root / "project.godot").exists():
        print(f"No Godot project found under {root}", file=sys.stderr)
        return 2

    game_root, scenes, scripts = collect(root)
    report = Report()

    check_scene_structure(report, scenes, game_root)
    check_script_attachment(report, scenes, scripts)
    check_node_paths(report, scenes, scripts, game_root)
    check_script_references(report, scripts, game_root)
    check_input_actions(report, scripts, game_root / "project.godot")
    check_signals(report, scripts, scenes)
    check_groups(report, scripts, scenes)
    check_class_names(report, scripts)
    check_weapon_resources(report, game_root, scenes)
    check_gltf_assets(report, game_root)
    check_project_settings(report, game_root)
    check_web_preview(report, root, game_root)
    check_docs(report, root, game_root, scenes, scripts)

    print(report.render(quiet=args.quiet))
    return 1 if report.failures else 0


if __name__ == "__main__":
    sys.exit(main())
