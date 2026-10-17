"""Static file server for testing Godot web exports locally.

Web exports that load GDExtensions ("Extensions Support" enabled, i.e. the
`web_dlink_*` templates) are cross-origin isolated and need these response
headers, which plain `python -m http.server` does not send:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

Usage (from the repo root):

    python tools/serve_web.py [port] [directory]

Defaults to port 8060 and `godot/builds`. The export is then served at
http://127.0.0.1:<port>/index.html
"""

import http.server
import mimetypes
import os
import socketserver
import sys

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # keep the console quiet


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    default_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "builds")
    directory = sys.argv[2] if len(sys.argv) > 2 else default_dir
    os.chdir(directory)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port), Handler) as httpd:
        print(f"serving {os.getcwd()} on http://127.0.0.1:{port}/index.html")
        httpd.serve_forever()
