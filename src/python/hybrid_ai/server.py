import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        payload = {
            "service": "hybrid-ai-python-server",
            "python": os.environ.get("PYTHON_DIR", "unset"),
            "cache": os.environ.get("PIP_CACHE_DIR", "unset"),
        }
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    host = os.environ.get("HYBRID_AI_HOST", "127.0.0.1")
    port = int(os.environ.get("HYBRID_AI_PORT", "8080"))
    server = HTTPServer((host, port), Handler)
    print(f"listening on {host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
