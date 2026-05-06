#!/usr/bin/env python3
"""Serve a Flutter web build with SPA route fallback."""

from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class SpaRequestHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        if self.path.split("?", 1)[0] == "/__reset":
            self.send_response(302)
            self.send_header("Location", "/?fresh=reset")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Clear-Site-Data", '"cache", "storage", "executionContexts"')
            self.end_headers()
            return None

        translated = Path(self.translate_path(self.path))
        if translated.exists():
            return super().send_head()

        self.path = "/index.html"
        return super().send_head()

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=5555)
    parser.add_argument("--directory", default="build/web")
    args = parser.parse_args()

    directory = Path(args.directory).resolve()
    if not directory.exists():
        raise SystemExit(f"Build directory not found: {directory}")

    handler = partial(SpaRequestHandler, directory=str(directory))
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving {directory} on http://{args.host}:{args.port}/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
