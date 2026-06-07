from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .backend import BackendError, BackendService


class HybridAIServer(ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], service: BackendService):
        self.service = service
        super().__init__(server_address, Handler)


class Handler(BaseHTTPRequestHandler):
    server: HybridAIServer

    def do_GET(self) -> None:
        if self.path == "/health":
            self._write_json(200, self.server.service.health_payload())
            return

        if self.path == "/ready":
            payload = self.server.service.readiness_payload()
            self._write_json(200 if payload["ready"] else 503, payload)
            return

        if self.path == "/v1/conversations":
            self._write_json(200, {"conversation_ids": self.server.service.list_conversations()})
            return

        self._write_error(404, "not_found", "endpoint not found")

    def do_POST(self) -> None:
        if self.path == "/v1/conversations":
            body = self._read_json_body(required=False)
            system_prompt = None if body is None else body.get("system_prompt")
            self._handle_service_call(lambda: self.server.service.create_conversation(system_prompt), success_status=201)
            return

        if self.path.startswith("/v1/conversations/") and self.path.endswith("/messages"):
            conversation_id = self.path.removeprefix("/v1/conversations/").removesuffix("/messages")
            conversation_id = conversation_id.strip("/")
            body = self._read_json_body(required=True)
            if body is None:
                return
            text = body.get("text")
            if not isinstance(text, str):
                self._write_error(400, "invalid_request", "message body must include a text string")
                return

            self._handle_service_call(lambda: self.server.service.send_message(conversation_id, text))
            return

        self._write_error(404, "not_found", "endpoint not found")

    def do_DELETE(self) -> None:
        if self.path.startswith("/v1/conversations/"):
            conversation_id = self.path.removeprefix("/v1/conversations/").strip("/")
            self.server.service.delete_conversation(conversation_id)
            self._write_json(204, None)
            return

        self._write_error(404, "not_found", "endpoint not found")

    def log_message(self, format: str, *args) -> None:
        return

    def _handle_service_call(self, operation, *, success_status: int = 200) -> None:
        try:
            payload = operation()
        except BackendError as exc:
            self._write_error(exc.status_code, exc.__class__.__name__.lower(), str(exc))
            return

        self._write_json(success_status, payload)

    def _read_json_body(self, *, required: bool) -> dict[str, object] | None:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length == 0:
            if required:
                self._write_error(400, "invalid_request", "request body is required")
            return None

        raw_body = self.rfile.read(content_length)
        try:
            body = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._write_error(400, "invalid_json", "request body must be valid JSON")
            return None

        if not isinstance(body, dict):
            self._write_error(400, "invalid_request", "request body must be a JSON object")
            return None

        return body

    def _write_error(self, status_code: int, code: str, message: str) -> None:
        self._write_json(status_code, {"error": {"code": code, "message": message}})

    def _write_json(self, status_code: int, payload: object) -> None:
        if payload is None:
            body = b""
        else:
            body = json.dumps(payload).encode("utf-8")

        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)


def main() -> None:
    host = os.environ.get("HYBRID_AI_HOST", "127.0.0.1")
    port = int(os.environ.get("HYBRID_AI_PORT", "8080"))
    service = BackendService()
    server = HybridAIServer((host, port), service)
    print(f"listening on {host}:{port}")
    try:
        server.serve_forever()
    finally:
        service.shutdown()


if __name__ == "__main__":
    main()
