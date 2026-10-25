#!/usr/bin/env python3
"""Serve the repository's web preview with revalidated browser caching.

    python3 tools/serve_preview.py                 # 0.0.0.0:8000, repo root
    python3 tools/serve_preview.py --port 8080
    python3 tools/serve_preview.py --root web      # just the exported build

A person's preview browser is not a fresh CI browser. The exported pack and
WASM are tens of megabytes, so forbidding storage on every response makes each
reload download them again. Instead, files carry a strong content ETag and
`Cache-Control: no-cache`: the browser may keep the bytes, but must revalidate
before using them. An unchanged build is a cheap 304; a changed build is always
fetched. HTML is still read afresh by the shell, so this does not reintroduce
the stale-preview problem that the old blanket `no-store` policy was avoiding.

The server also stamps the served pack's size and mtime into `/__build`, so
"which build am I looking at" is answerable with curl instead of a feeling.

Binds 0.0.0.0 on purpose: the sandbox preview proxies to it from outside, and
127.0.0.1 would not be reachable from the browser that is showing it.
"""
from __future__ import annotations

import argparse
import functools
import hashlib
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
    """Static files with revalidated caching, plus a /__build stamp."""

    # Chromium does not use the strong ETag for revalidation on the stdlib's
    # default HTTP/1.0 responses (it falls back to Last-Modified or full GETs).
    protocol_version = "HTTP/1.1"

    @staticmethod
    def _entity_tag(path: Path) -> str:
        # Hash the bytes on every revalidation. Caching this digest by stat
        # metadata is not safe: filesystems with coarse timestamps can report
        # the same size/mtime/ctime for a rapid in-place replacement. Reading
        # local bytes is cheap compared with sending another 119 MB over a
        # forwarded preview connection, and correctness must win here.
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        return '"%s"' % digest.hexdigest()

    def send_head(self):
        # Use only strong content validators. The stdlib's If-Modified-Since
        # path can return 304 for a rapid replacement whose timestamp did not
        # change, and Chromium may send that timestamp without If-None-Match.
        # A legacy timestamp-only request therefore gets a safe full response;
        # the absence of Last-Modified makes later requests use the ETag.
        self._current_entity_tag = None
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        path = Path(self.translate_path(self.path))
        if path.is_file():
            try:
                self._current_entity_tag = self._entity_tag(path)
            except OSError:
                # Let the base handler produce its normal 404/permission page.
                return super().send_head()
            candidates = self.headers.get("If-None-Match", "")
            matches = [item.strip() for item in candidates.split(",")]
            if "*" in matches or self._current_entity_tag in matches:
                self.send_response(304)
                self.end_headers()
                return None
        return super().send_head()

    def send_header(self, keyword, value) -> None:  # noqa: ANN001 - stdlib signature
        if keyword.lower() == "last-modified":
            return
        super().send_header(keyword, value)

    def end_headers(self) -> None:
        # no-cache means "store, but revalidate", unlike no-store. This is the
        # distinction that lets unchanged WASM/PCK bytes stay on local disk.
        self.send_header("Cache-Control", "no-cache, must-revalidate")
        if getattr(self, "_current_entity_tag", None):
            self.send_header("ETag", self._current_entity_tag)
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
        # HTTP/1.1 connections are persistent; never leak the previous static
        # file's validator onto this dynamic JSON response.
        self._current_entity_tag = None
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

    def handle_error(self, request, client_address) -> None:  # noqa: ANN001 - stdlib signature
        error = sys.exc_info()[1]
        # HTTP/1.1 keep-alive peers commonly close while the server awaits the
        # next request. That is a normal browser disconnect, not a preview fault.
        if isinstance(error, (BrokenPipeError, ConnectionResetError)):
            return
        super().handle_error(request, client_address)


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
        print(f"serving {directory} on http://{args.host}:{args.port} (revalidated cache)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
