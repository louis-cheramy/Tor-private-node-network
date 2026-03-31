#!/usr/bin/env python3
import json
import subprocess
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock

HOST = "0.0.0.0"
PORT = 3000
SOCKS_PROXY = "127.0.0.1:9050"
ONION_HOSTNAME_FILE = Path("/shared/onion/hostname")
DASHBOARD_FILE = Path("/dashboard.html")

LOG_LOCK = Lock()
NODE_LOGS = {
    "client-1": [],
    "relay-1": [],
    "relay-2": [],
    "relay-3": [],
    "onion-web-1": [],
}

NODES = [
    {
        "id": "client-1",
        "name": "Client Tor",
        "type": "client",
        "status": "running",
        "ip": "tor-client",
        "connections": ["relay-1", "relay-2", "relay-3"],
    },
    {
        "id": "relay-1",
        "name": "Relay 1",
        "type": "relay",
        "status": "running",
        "ip": "relay1",
        "connections": ["relay-2", "relay-3", "onion-web-1"],
    },
    {
        "id": "relay-2",
        "name": "Relay 2",
        "type": "relay",
        "status": "running",
        "ip": "relay2",
        "connections": ["relay-1", "relay-3", "onion-web-1"],
    },
    {
        "id": "relay-3",
        "name": "Relay 3",
        "type": "relay",
        "status": "running",
        "ip": "relay3",
        "connections": ["relay-1", "relay-2", "onion-web-1"],
    },
    {
        "id": "onion-web-1",
        "name": "Onion Web",
        "type": "onion-web",
        "status": "running",
        "ip": "onion-web",
        "onionAddress": "",
        "connections": [],
    },
]


def now() -> str:
    return datetime.utcnow().strftime("[%Y-%m-%d %H:%M:%S UTC]")


def read_onion_address() -> str:
    if ONION_HOSTNAME_FILE.exists():
        return ONION_HOSTNAME_FILE.read_text(encoding="utf-8").strip()
    return ""


def append_log(node_id: str, message: str) -> None:
    with LOG_LOCK:
        NODE_LOGS.setdefault(node_id, []).append(f"{now()} {message}")
        NODE_LOGS[node_id] = NODE_LOGS[node_id][-200:]


def build_nodes():
    onion = read_onion_address()
    nodes = [dict(node) for node in NODES]
    for node in nodes:
        if node["id"] == "onion-web-1":
            node["onionAddress"] = onion
    return nodes


def do_real_request():
    onion_addr = read_onion_address()
    if not onion_addr:
        raise RuntimeError("Adresse onion indisponible (hostname non genere).")

    url = f"http://{onion_addr}"
    append_log("client-1", f"Initiating real HTTP request to {onion_addr}")
    append_log("relay-1", "Circuit hop selected")
    append_log("relay-2", "Circuit hop selected")
    append_log("relay-3", "Circuit hop selected")
    append_log("onion-web-1", "Waiting for inbound Tor request")

    start = time.perf_counter()
    proc = subprocess.run(
        [
            "curl",
            "--socks5-hostname",
            SOCKS_PROXY,
            "--max-time",
            "30",
            "-sS",
            "-D",
            "-",
            url,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    elapsed_ms = int((time.perf_counter() - start) * 1000)

    if proc.returncode != 0:
        append_log("client-1", f"Request failed with curl exit code {proc.returncode}")
        raise RuntimeError(proc.stderr.strip() or "curl failed")

    raw = proc.stdout
    header_blob, _, body = raw.partition("\r\n\r\n")
    if not body:
        header_blob, _, body = raw.partition("\n\n")

    status_line = "HTTP status unknown"
    for line in header_blob.splitlines():
        if line.startswith("HTTP/"):
            status_line = line.strip()
            break

    body_preview = body.strip().replace("\n", " ")
    if len(body_preview) > 220:
        body_preview = body_preview[:220] + "..."

    append_log("onion-web-1", f"Served request with {status_line}")
    append_log("relay-3", "Encrypted response relayed")
    append_log("relay-2", "Encrypted response relayed")
    append_log("relay-1", "Encrypted response relayed")
    append_log("client-1", f"Response received: {status_line}")
    append_log("client-1", f"Request completed in {elapsed_ms}ms")

    return {
        "ok": True,
        "url": url,
        "statusLine": status_line,
        "elapsedMs": elapsed_ms,
        "responsePreview": body_preview,
    }


class Handler(BaseHTTPRequestHandler):
    def _json(self, status: int, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            if not DASHBOARD_FILE.exists():
                self._json(500, {"ok": False, "error": "dashboard.html missing"})
                return
            content = DASHBOARD_FILE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            return

        if self.path == "/api/state":
            self._json(
                200,
                {
                    "ok": True,
                    "nodes": build_nodes(),
                    "onionAddress": read_onion_address(),
                    "socksProxy": SOCKS_PROXY,
                },
            )
            return

        if self.path == "/api/logs":
            with LOG_LOCK:
                self._json(200, {"ok": True, "logs": NODE_LOGS})
            return

        self._json(404, {"ok": False, "error": "Not found"})

    def do_POST(self):
        if self.path == "/api/request":
            try:
                data = do_real_request()
                self._json(200, data)
            except Exception as exc:
                self._json(500, {"ok": False, "error": str(exc)})
            return
        self._json(404, {"ok": False, "error": "Not found"})

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    print(f"[dashboard] Listening on http://{HOST}:{PORT}")
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.serve_forever()
