from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def build_payload() -> dict[str, object]:
    return {
        "service": os.environ.get("LAB_NAME", "win-netlab-foundation"),
        "hostname": os.environ.get("LAB_HOSTNAME", "health-a.lab.example"),
        "management_ip": os.environ.get("LAB_IP", "192.0.2.44"),
        "serial": os.environ.get("LAB_SERIAL", "FTX0000HEALTH01"),
        "operator": os.environ.get("LAB_OPERATOR", "lab-operator"),
        "status": "ok",
        "scope": "synthetic-local-only",
    }


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, payload: dict[str, object], status_code: int = 200) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._write_json(build_payload())
            return

        if self.path == "/inventory":
            payload = build_payload()
            payload["devices"] = [
                {"hostname": "edge-a.lab.example", "management_ip": "192.0.2.10"},
                {"hostname": "core-a.lab.example", "management_ip": "198.51.100.20"},
                {"hostname": "access-a.lab.example", "management_ip": "203.0.113.30"},
            ]
            self._write_json(payload)
            return

        self._write_json({"status": "not-found", "path": self.path}, status_code=404)

    def log_message(self, fmt: str, *args: object) -> None:
        return


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()

