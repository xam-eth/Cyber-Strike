#!/usr/bin/env python3
"""Serve the repository's web preview with ETag revalidation (not no-store).

    python3 tools/serve_preview.py                 # 0.0.0.0:8000, repo root
    python3 tools/serve_preview.py --port 8080
    python3 tools/serve_preview.py --root web      # just the exported build

Why this exists: `python3 -m http.server` is what the QA tools use, and for
screenshots that is fine -- every run is a fresh browser. For a *person*
looking at the preview, it is not: the payload is a 31 MB `index.pck` and a
39 MB `index.wasm`, browsers are allowed to reuse those from cache by heuristic
freshness, and the symptom is the one this project keeps paying for -- the code
changed, the frames say otherwise, and the git log is correct.

So every response here carries `Cache-Control: public, max-age=0, must-revalidate`
with ETag/Last-Modified. The browser caches the bytes but revalidates each
reload: if unchanged it gets 304 Not Modified (~0.5 KB) instead of 70 MB,
so the second open is instant. If the build changed, the ETag differs and
fresh bytes are fetched — a reload is still always the build on disk, just
without re-downloading ratusan MB when nothing changed. It also stamps the served pack's size and mtime into `/__build`, so
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
    """Static files with ETag revalidation — cached but always fresh."""

    def end_headers(self) -> None:
        # `no-store` forced a full 70 MB download on every reload.
        # `max-age=0, must-revalidate` still checks freshness every time (so
        # a new build is seen immediately) but lets the browser keep the
        # previous bytes and get a 304 when nothing changed — preview opens
        # in ~30 ms instead of re-downloading ratusan MB.
        self.send_header("Cache-Control", "public, max-age=0, must-revalidate")
        if hasattr(self, "_etag"):
            self.send_header("ETag", self._etag)  # type: ignore
            self.send_header("Last-Modified", self._last_mod)  # type: ignore
            delattr(self, "_etag")
            delattr(self, "_last_mod")
        if hasattr(self, "_gzip"):
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
            delattr(self, "_gzip")
        # Allow range requests for large assets
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def send_head(self):  # noqa: N802
        # Add ETag / Last-Modified and honour If-None-Match for 304.
        # Also serve precompressed .gz when client accepts gzip and it saves bytes.
        # Store etag BEFORE calling super().send_head so end_headers can emit it.
        orig_path = self.translate_path(self.path.split("?")[0].split("#")[0])
        # only for files, not directories or /__build
        if self.path.split("?")[0] == "/__build" or os.path.isdir(orig_path) or not os.path.isfile(orig_path):
            return super().send_head()
        # gzip negotiation: if client accepts gzip and .gz exists and is smaller, serve it
        path = orig_path
        use_gzip = False
        try:
            accept_enc = self.headers.get("Accept-Encoding", "")
            gz_path = orig_path + ".gz"
            if "gzip" in accept_enc and os.path.isfile(gz_path):
                try:
                    orig_st = os.stat(orig_path)
                    gz_st = os.stat(gz_path)
                    # only use gzip if it actually saves >5%
                    if gz_st.st_size < orig_st.st_size * 0.95:
                        path = gz_path
                        use_gzip = True
                        # rewrite self.path so super().send_head serves the gz file
                        self.path = self.path + ".gz"
                except OSError:
                    pass
        except Exception:
            pass
        try:
            st = os.stat(path)
            etag = f'"{st.st_mtime_ns:x}-{st.st_size:x}"'
            last_mod = self.date_time_string(st.st_mtime)
            inm = self.headers.get("If-None-Match")
            # If-None-Match takes precedence per RFC
            if inm == etag:
                self.send_response(304)
                self.send_header("ETag", etag)
                self.send_header("Last-Modified", last_mod)
                self.send_header("Cache-Control", "public, max-age=0, must-revalidate")
                if use_gzip:
                    self.send_header("Content-Encoding", "gzip")
                    self.send_header("Vary", "Accept-Encoding")
                self.end_headers()
                return None
            # store for end_headers to emit on 200
            self._etag = etag  # type: ignore
            self._last_mod = last_mod  # type: ignore
            if use_gzip:
                self._gzip = True  # type: ignore
        except OSError:
            pass
        # ensure guess_type sees original type when serving .gz
        return super().send_head()

    def guess_type(self, path):  # noqa: ANN001 - stdlib signature
        # strip .gz for type guessing so .wasm.gz is still application/wasm
        if path.endswith(".gz"):
            path = path[:-3]
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
        print(f"serving {directory} on http://{args.host}:{args.port} (ETag revalidate: 304 when unchanged)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
