#!/usr/bin/env python3
"""Serve the repository's web preview with caching turned off.

    python3 tools/serve_preview.py                 # 0.0.0.0:8000, repo root
    python3 tools/serve_preview.py --port 8080
    python3 tools/serve_preview.py --root web      # just the exported build

Why this exists: `python3 -m http.server` is what the QA tools use, and for
screenshots that is fine -- every run is a fresh browser. For a *person*
looking at the preview, it is not: the payload is a 31 MB `index.pck` and a
39 MB `index.wasm`, browsers are allowed to reuse those from cache by heuristic
freshness, and the symptom is the one this project keeps paying for -- the code
changed, the frames say otherwise, and the git log is correct.

So every response here carries `Cache-Control: no-store`. A reload is always
the build that is on disk, which is what "check the preview" is supposed to
mean. It also stamps the served pack's size and mtime into `/__build`, so
"which build am I looking at" is answerable with curl instead of a feeling.

Binds 0.0.0.0 on purpose: the sandbox preview proxies to it from outside, and
127.0.0.1 would not be reachable from the browser that is showing it.
"""
from __future__ import annotations

import argparse
import functools
import http.server
import json
import os
import socketserver
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Types the engine and the shell need and that `http.server` does not know.
EXTRA_TYPES = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".worklet.js": "text/javascript",
    ".ogv": "video/ogg",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    """Static files, no store, plus a build stamp at /__build."""

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def guess_type(self, path):  # noqa: ANN001 - stdlib signature
        for suffix, content_type in EXTRA_TYPES.items():
            if str(path).endswith(suffix):
                return content_type
        return super().guess_type(path)

    def do_GET(self) -> None:  # noqa: N802 - stdlib name
        if self.path.split("?")[0] == "/__build":
            self._serve_build_stamp()
            return
        super().do_GET()

    def do_HEAD(self) -> None:  # noqa: N802 - stdlib name
        if self.path.split("?")[0] == "/__build":
            self._serve_build_stamp(head_only=True)
            return
        super().do_HEAD()

    def _serve_build_stamp(self, head_only: bool = False) -> None:
        pack = Path(self.directory) / "web" / "index.pck"
        if not pack.exists():
            pack = Path(self.directory) / "index.pck"
        stamp: dict = {"pack": str(pack), "exists": pack.exists()}
        if pack.exists():
            stat = pack.stat()
            stamp["bytes"] = stat.st_size
            stamp["mtime"] = int(stat.st_mtime)
        body = json.dumps(stamp, indent=2).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if not head_only:
            self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:  # noqa: ANN002
        # One line per request is noise for a preview; errors still print.
        if not str(args[1] if len(args) > 1 else "").startswith("2"):
            super().log_message(fmt, *args)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--root", default=".", help="directory to serve (default: the repo root)")
    args = parser.parse_args()

    directory = (ROOT / args.root).resolve() if not os.path.isabs(args.root) else Path(args.root)
    if not directory.is_dir():
        print(f"ERROR: {directory} is not a directory", file=sys.stderr)
        return 1

    handler = functools.partial(Handler, directory=str(directory))
    with Server((args.host, args.port), handler) as httpd:
        print(f"serving {directory} on http://{args.host}:{args.port} (no-store)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
