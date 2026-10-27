#!/usr/bin/env python3
"""HTTP cache-contract tests for the human preview server."""

from __future__ import annotations

import functools
import hashlib
import http.client
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import serve_preview  # noqa: E402


class PreviewCacheTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        web = self.root / "web"
        web.mkdir()
        self.pack = web / "index.pck"
        self.pack.write_bytes(b"GDPC-old")
        (web / "index.html").write_text("<html>preview</html>", encoding="utf-8")
        handler = functools.partial(serve_preview.Handler, directory=str(self.root))
        self.server = serve_preview.Server(("127.0.0.1", 0), handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        self._tmp.cleanup()

    def request(self, target: str, headers: dict[str, str] | None = None):
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_address[1], timeout=5)
        connection.request("GET", target, headers=headers or {})
        response = connection.getresponse()
        body = response.read()
        result = response.status, dict(response.getheaders()), body
        connection.close()
        return result

    def test_unchanged_pack_is_stored_then_revalidated_without_a_body(self) -> None:
        status, headers, body = self.request("/web/index.pck")
        self.assertEqual(status, 200)
        self.assertEqual(body, b"GDPC-old")
        self.assertIn("no-cache", headers["Cache-Control"])
        self.assertNotIn("no-store", headers["Cache-Control"])
        expected = '"%s"' % hashlib.sha256(body).hexdigest()
        self.assertEqual(headers["ETag"], expected)
        self.assertNotIn("Last-Modified", headers)

        status, revalidated, body = self.request(
            "/web/index.pck", {"If-None-Match": headers["ETag"]}
        )
        self.assertEqual(status, 304)
        self.assertEqual(body, b"")
        self.assertEqual(revalidated["ETag"], expected)
        self.assertIn("no-cache", revalidated["Cache-Control"])

        # A client from an older/timestamp-only server must not receive a 304
        # based on mutable filesystem metadata. It gets one safe full response
        # with an ETag and no Last-Modified, then can revalidate by content.
        status, legacy, body = self.request(
            "/web/index.pck", {"If-Modified-Since": "Wed, 21 Oct 2026 07:28:00 GMT"}
        )
        self.assertEqual(status, 200)
        self.assertEqual(body, b"GDPC-old")
        self.assertEqual(legacy["ETag"], expected)
        self.assertNotIn("Last-Modified", legacy)

    def test_changed_pack_invalidates_even_with_same_size_and_mtime(self) -> None:
        _, headers, _ = self.request("/web/index.pck")
        old_stat = self.pack.stat()
        self.pack.write_bytes(b"GDPC-new")
        self.assertEqual(self.pack.stat().st_size, old_stat.st_size)
        os.utime(self.pack, ns=(old_stat.st_atime_ns, old_stat.st_mtime_ns))

        status, changed, body = self.request(
            "/web/index.pck",
            {
                "If-None-Match": headers["ETag"],
                "If-Modified-Since": "Wed, 21 Oct 2026 07:28:00 GMT",
            },
        )
        self.assertEqual(status, 200)
        self.assertEqual(body, b"GDPC-new")
        self.assertNotEqual(changed["ETag"], headers["ETag"])

    def test_html_and_build_stamp_also_revalidate(self) -> None:
        for target in ("/web/index.html", "/__build"):
            status, headers, body = self.request(target)
            self.assertEqual(status, 200)
            self.assertTrue(body)
            self.assertIn("no-cache", headers["Cache-Control"])
            self.assertNotIn("no-store", headers["Cache-Control"])

    def test_dynamic_stamp_does_not_inherit_etag_on_keep_alive(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_address[1], timeout=5)
        connection.request("GET", "/web/index.pck")
        pack_response = connection.getresponse()
        pack_response.read()
        self.assertTrue(pack_response.headers["ETag"])

        connection.request("GET", "/__build")
        stamp_response = connection.getresponse()
        stamp_response.read()
        self.assertEqual(stamp_response.status, 200)
        self.assertIsNone(stamp_response.headers["ETag"])
        connection.close()

    def test_human_export_instructions_use_the_revalidating_server(self) -> None:
        export_script = (ROOT / "scripts" / "export_web_preview.sh").read_text(encoding="utf-8")
        workflow = (ROOT / ".github" / "workflows" / "godot-ci.yml").read_text(encoding="utf-8")
        self.assertIn("python3 tools/serve_preview.py --port 800", export_script)
        self.assertNotIn("printf '  python -m http.server 800", export_script)
        self.assertIn("python3 tools/serve_preview.py --port 800", workflow)
        self.assertIn("docs/runbooks/WEB_PREVIEW.md", workflow)
        self.assertNotIn("echo 'python -m http.server 800", workflow)


if __name__ == "__main__":
    unittest.main()
