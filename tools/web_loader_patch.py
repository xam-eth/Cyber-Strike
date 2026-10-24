#!/usr/bin/env python3
"""Propagate Godot Web initialization failures to ``Engine.startGame()``.

Godot 4.7.2's generated loader accepts ``reject`` in ``doInit`` but never uses
it. If the WASM response, Godot module initialization, or filesystem setup
fails, the initialization Promise remains pending and a player sees an endless
loading screen. Add the three rejection handlers after every Web export.

The transform is deliberately exact and idempotent. A future exporter that
changes this block must be reviewed rather than patched with a loose regex.
"""

from __future__ import annotations

import argparse
from pathlib import Path

ORIGINAL_BLOCK = (
    "\t\t\t\t\t\t\t\t\tresolve();\n"
    "\t\t\t\t\t\t\t\t});\n"
    "\t\t\t\t\t\t\t});\n"
    "\t\t\t\t\t\t});\n"
    "\t\t\t\t\t});\n"
)

PATCHED_BLOCK = (
    "\t\t\t\t\t\t\t\t\tresolve();\n"
    "\t\t\t\t\t\t\t\t}, reject);\n"
    "\t\t\t\t\t\t\t}, reject);\n"
    "\t\t\t\t\t\t}, reject);\n"
    "\t\t\t\t\t});\n"
)


def patch_text(text: str) -> tuple[str, bool]:
    """Return patched JavaScript and whether this call changed it."""
    if PATCHED_BLOCK in text:
        return text, False
    if text.count(ORIGINAL_BLOCK) != 1:
        raise ValueError(
            "Godot loader initialization block did not match exactly; "
            "review the exporter output before updating web_loader_patch.py"
        )
    return text.replace(ORIGINAL_BLOCK, PATCHED_BLOCK, 1), True


def is_patched(text: str) -> bool:
    return PATCHED_BLOCK in text


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("loader", type=Path, help="path to the exported index.js")
    args = parser.parse_args(argv)
    try:
        original = args.loader.read_text(encoding="utf-8")
        patched, changed = patch_text(original)
    except (OSError, ValueError) as error:
        parser.exit(1, f"ERROR: {error}\n")
    if changed:
        args.loader.write_text(patched, encoding="utf-8")
    print(f"{args.loader}: {'patched' if changed else 'already patched'}; WASM init failures reject startGame()")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
