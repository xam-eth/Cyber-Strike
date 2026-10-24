#!/usr/bin/env python3
"""Fail when a script calls an instance method as if it were static.

Why this exists: commit `0884658` split the world builder into zone files and
every static check passed — `gdlint`, `gdformat`, `project_doctor` and the
module map all went green — while the game could not load at all. The zone file
had lost its `static` keyword, so the composition root called

    NeonFrontierArena.build_central_arena(self)

on the class itself. Godot answers that with a parse error and drops the whole
world script, which then failed 3 of 26 smoke tests:

    SCRIPT ERROR: Parse Error: Cannot call non-static function
    "build_central_arena()" on the class "NeonFrontierArena" directly.
    Make an instance instead.

Nothing in the static gate could see it: the call is legal syntax, the method
exists, and the file it lives in is referenced. Only the *static-ness* of the
target is wrong, and that is a property of the callee, read from another file.

So this check reads both sides: it builds an index of every `class_name` in the
project (and of every `const X = preload(...)` alias), then resolves each
`SomeClass.some_method(` call site against the callee's real declaration,
following `extends` chains. A call to a non-static function on a class name is
a violation, and so is a call to a method that no class in the chain declares.

Two things make the check honest rather than decorative (docs/DECISIONS.md
§6, §12):

* Comments and string literals are stripped before the call sites are scanned,
  so a class name mentioned in a `##` doc comment is not a call. A naive scan of
  this repository reports calls that do not exist.
* It is wired into `scripts/dev_check.sh`, which CI runs, and it has negative
  controls in `tools/tests/test_static_calls.py` — a fixture that calls an
  instance method statically must fail.

Usage:
    check_static_calls.py                    # scan game/ (exit 1 on violations)
    check_static_calls.py --root DIR         # scan another tree
    check_static_calls.py --json             # machine-readable report
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Built-in static members that are legal on a class reference and are not
# declared in GDScript source.
BUILTIN_STATICS = {"new"}

CLASS_NAME_RE = re.compile(r"^class_name\s+([A-Za-z_]\w*)", re.MULTILINE)
EXTENDS_RE = re.compile(r"^extends\s+([A-Za-z_][\w/]*|\"[^\"]+\")", re.MULTILINE)
FUNC_RE = re.compile(r"^(static\s+)?func\s+([A-Za-z_]\w*)", re.MULTILINE)
CONST_PRELOAD_RE = re.compile(
    r"^const\s+([A-Za-z_]\w*)\s*(?::[^=\n]+)?=\s*preload\(\s*\"([^\"]+)\"\s*\)",
    re.MULTILINE,
)
CALL_RE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\.([A-Za-z_]\w*)\s*\(")

BS = chr(92)  # backslash, kept out of the literal regex soup below


def strip_code(text: str) -> str:
    """Blank out comments and string literals, preserving line numbers.

    GDScript has `#` line comments, `"..."` and `'...'` strings (single-line and
    triple-quoted) with `\\` escapes. Everything inside those is replaced by a
    space so offsets stay put and the line number of a call site is still the
    line number in the file.
    """
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "#":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if ch in ("\"", "'"):
            quote = text[i] * 3 if text.startswith(text[i] * 3, i) else text[i]
            out.append(" " * len(quote))
            i += len(quote)
            while i < n:
                if text.startswith(quote, i):
                    out.append(" " * len(quote))
                    i += len(quote)
                    break
                if text[i] == BS and i + 1 < n:
                    out.append("  ")
                    i += 2
                    continue
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


@dataclass
class Script:
    path: Path
    rel: str
    class_name: str | None = None
    extends: str | None = None
    functions: dict[str, bool] = field(default_factory=dict)  # name -> is_static
    aliases: dict[str, str] = field(default_factory=dict)  # const NAME -> res:// path


@dataclass
class Violation:
    rel: str
    line: int
    receiver: str
    method: str
    resolved: str
    message: str
    suggestion: str

    def to_dict(self) -> dict:
        return {
            "file": self.rel,
            "line": self.line,
            "call": f"{self.receiver}.{self.method}()",
            "resolved": self.resolved,
            "message": self.message,
            "suggestion": self.suggestion,
        }


def res_to_path(root: Path, res_path: str) -> Path | None:
    """Map `res://scripts/foo.gd` onto the scan root (which is `game/`)."""
    if not res_path.startswith("res://"):
        return None
    return root / res_path[len("res://") :]


def load_scripts(root: Path) -> list[Script]:
    scripts: list[Script] = []
    for path in sorted(root.rglob("*.gd")):
        if "/.godot/" in path.as_posix():
            continue
        raw = path.read_text(encoding="utf-8", errors="replace")
        code = strip_code(raw)
        script = Script(path=path, rel=path.relative_to(root).as_posix())
        match = CLASS_NAME_RE.search(code)
        if match:
            script.class_name = match.group(1)
        match = EXTENDS_RE.search(code)
        if match:
            script.extends = match.group(1).strip('"')
        for static, name in FUNC_RE.findall(code):
            script.functions[name] = bool(static)
        for alias, res_path in CONST_PRELOAD_RE.findall(raw):
            script.aliases[alias] = res_path
        scripts.append(script)
    return scripts


class Index:
    def __init__(self, scripts: list[Script]) -> None:
        self.by_class: dict[str, Script] = {}
        self.by_path: dict[str, Script] = {}
        for script in scripts:
            self.by_path[script.rel] = script
            if script.class_name:
                self.by_class[script.class_name] = script

    def resolve_extends(self, script: Script) -> Script | None:
        """The script `script` extends, if that base is a project script."""
        base = script.extends
        if not base:
            return None
        if base.startswith("res://"):
            return self.by_path.get(base[len("res://") :])
        if base.endswith(".gd"):
            return self.by_path.get(base)
        return self.by_class.get(base)

    def lookup(self, script: Script, method: str) -> tuple[bool, Script] | None:
        """(is_static, declaring script) for `method`, walking the extends chain."""
        seen: set[str] = set()
        current: Script | None = script
        while current is not None and current.rel not in seen:
            seen.add(current.rel)
            if method in current.functions:
                return current.functions[method], current
            current = self.resolve_extends(current)
        return None


def check_tree(root: Path) -> list[Violation]:
    scripts = load_scripts(root)
    index = Index(scripts)
    violations: list[Violation] = []

    for script in scripts:
        code = strip_code(script.path.read_text(encoding="utf-8", errors="replace"))
        for match in CALL_RE.finditer(code):
            receiver, method = match.group(1), match.group(2)
            if method in BUILTIN_STATICS:
                continue
            target: Script | None = None
            if receiver in index.by_class:
                target = index.by_class[receiver]
            elif receiver in script.aliases:
                res_path = script.aliases[receiver]
                target = index.by_path.get(res_path[len("res://") :])
            if target is None:
                continue  # engine class or a name we do not own: not our business
            line = code.count("\n", 0, match.start()) + 1
            found = index.lookup(target, method)
            if found is None:
                violations.append(
                    Violation(
                        rel=script.rel,
                        line=line,
                        receiver=receiver,
                        method=method,
                        resolved=target.rel,
                        message=(
                            f"neither {receiver} nor its bases declare {method}()"
                        ),
                        suggestion=(
                            "check the name, or the call is on the wrong class"
                        ),
                    )
                )
                continue
            is_static, declaring = found
            if not is_static:
                violations.append(
                    Violation(
                        rel=script.rel,
                        line=line,
                        receiver=receiver,
                        method=method,
                        resolved=declaring.rel,
                        message=(
                            f'Cannot call non-static function "{method}()" on the '
                            f'class "{receiver}" directly'
                        ),
                        suggestion=(
                            f"make {method}() `static` in {declaring.rel}, "
                            f"or hold an instance and call it on that"
                        ),
                    )
                )
    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Detect static calls to instance methods in GDScript.",
    )
    parser.add_argument(
        "--root",
        default=str(ROOT / "game"),
        help="project root to scan (default: game/)",
    )
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--quiet", action="store_true", help="only print the summary")
    args = parser.parse_args(argv)

    root = Path(args.root)
    if not root.is_dir():
        print(f"ERROR: scan root not found: {root}", file=sys.stderr)
        return 2

    scripts = load_scripts(root)
    violations = check_tree(root)

    if args.json:
        print(
            json.dumps(
                {
                    "root": str(root),
                    "scripts": len(scripts),
                    "violations": [violation.to_dict() for violation in violations],
                },
                indent=2,
            )
        )
        return 1 if violations else 0

    if not args.quiet:
        for violation in violations:
            print(
                f"{violation.rel}:{violation.line}: {violation.message}\n"
                f"    call: {violation.receiver}.{violation.method}()  "
                f"declared in {violation.resolved}\n"
                f"    fix:  {violation.suggestion}"
            )
        if violations:
            print()

    summary = (
        f"{len(scripts)} script(s) scanned, {len(violations)} static-call "
        f"violation(s)"
    )
    if violations:
        print(f"FAIL: {summary}")
        return 1
    print(f"PASS: {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
