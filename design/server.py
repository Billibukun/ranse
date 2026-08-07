"""Local design-review server for Ranse.

Serves the design selector page, auto-reload endpoint, and saves Ibukun's
selections to design-feedback.json in this folder.

Run:  python server.py   ->  http://localhost:7420
"""

import json
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 7420
HERE = os.path.dirname(os.path.abspath(__file__))
FEEDBACK_FILE = os.path.join(HERE, "design-feedback.json")


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=HERE, **kwargs)

    def end_headers(self):
        # The page may run from file:// - let it talk to us anyway.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/mtime"):
            newest = 0.0
            for name in os.listdir(HERE):
                if name.endswith((".html", ".css", ".js")):
                    newest = max(newest, os.path.getmtime(os.path.join(HERE, name)))
            body = json.dumps({"mtime": newest}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        if self.path == "/save":
            length = int(self.headers.get("Content-Length", 0))
            payload = self.rfile.read(length)
            try:
                data = json.loads(payload)
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                return
            with open(FEEDBACK_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            body = b'{"saved": true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, fmt, *args):
        pass  # keep the console quiet


if __name__ == "__main__":
    print(f"Ranse design review -> http://localhost:{PORT}")
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
