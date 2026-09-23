#!/usr/bin/env python3
"""Small NVIDIA model router for agy.

LiteLLM remains the protocol translator. This process owns the public :4000
endpoint, starts LiteLLM on :4001, and performs parallel tiny health probes
when a pre-stream request fails.
"""
from __future__ import annotations

import concurrent.futures
import http.client
import json
import os
import signal
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import yaml

HOME = Path.home()
CONFIG = HOME / ".config/agy-nvidia"
YAML_FILE = CONFIG / "litellm.yaml"
ENV_FILE = CONFIG / ".env"
PUBLIC_HOST, PUBLIC_PORT = "127.0.0.1", 4000
BACKEND_HOST, BACKEND_PORT = "127.0.0.1", 4001
NVIDIA_URL = "https://integrate.api.nvidia.com/v1/chat/completions"
PROBE_TIMEOUT = 8
MAX_PROBES = 8

# These aliases are stable router targets. The model list in litellm.yaml is
# deliberately kept as the source of truth for the real upstream model.
CANDIDATES = [
    ("openai/nvidia/nemotron-3-super-120b-a12b", "router-nemotron-super"),
    ("openai/nvidia/nemotron-3-ultra-550b-a55b", "router-nemotron-ultra"),
    ("openai/meta/llama-3.2-11b-vision-instruct", "router-llama-vision"),
    ("openai/deepseek-ai/deepseek-v4.1-flash", "router-deepseek"),
]

backend: subprocess.Popen[bytes] | None = None


def load_key() -> str:
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if line.startswith("NVIDIA_API_KEY="):
                return line.split("=", 1)[1].strip()
    return os.environ.get("NVIDIA_API_KEY", "")


def start_backend() -> None:
    global backend
    backend = subprocess.Popen(
        [str(HOME / ".local/bin/litellm"), "--config", str(YAML_FILE),
         "--port", str(BACKEND_PORT), "--host", BACKEND_HOST],
        cwd=CONFIG,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def probe(item: tuple[str, str]) -> tuple[str, str, float] | None:
    model, alias = item
    key = load_key()
    if not key:
        return None
    payload = json.dumps({"model": model.removeprefix("openai/"),
                          "messages": [{"role": "user", "content": "yo"}],
                          "max_tokens": 2, "stream": False})
    req = __import__("urllib.request").request.Request(
        NVIDIA_URL, data=payload.encode(), method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    started = time.monotonic()
    try:
        with __import__("urllib.request").request.urlopen(req, timeout=PROBE_TIMEOUT) as response:
            data = json.loads(response.read(4096).decode("utf-8", "replace"))
        content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        if response.status == 200 and isinstance(content, str) and content.strip():
            return alias, model.removeprefix("openai/"), time.monotonic() - started
    except Exception:
        return None
    return None


def first_healthy() -> tuple[str, str] | None:
    # Keep the probe count bounded. Add more candidates here as NVIDIA models
    # are verified; each probe is only two output tokens and no history.
    candidates = CANDIDATES[:MAX_PROBES]
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(candidates)) as pool:
        futures = [pool.submit(probe, item) for item in candidates]
        pending = set(futures)
        while pending:
            done, pending = concurrent.futures.wait(pending, return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                result = future.result()
                if result:
                    for other in pending:
                        other.cancel()
                    return result[0], result[1]
    return None


def backend_request(method: str, path: str, body: bytes | None, headers: dict[str, str]) -> tuple[int, list[tuple[str, str]], bytes | object]:
    conn = http.client.HTTPConnection(BACKEND_HOST, BACKEND_PORT, timeout=130)
    clean = {k: v for k, v in headers.items() if k.lower() not in {"host", "content-length", "connection"}}
    if body is not None:
        clean["Content-Length"] = str(len(body))
    conn.request(method, path, body=body, headers=clean)
    response = conn.getresponse()
    if response.status >= 500:
        data = response.read()
        conn.close()
        return response.status, response.getheaders(), data
    return response.status, response.getheaders(), response


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        return

    def end_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "content-type, x-goog-api-key")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.end_headers()

    def do_GET(self) -> None:
        if urlsplit(self.path).path == "/health/liveliness":
            payload = b'"I\'m alive!"'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(payload)
            self.close_connection = True
            return
        self.send_error(404)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""
        status, headers, result = backend_request("POST", self.path, body, dict(self.headers))
        # Retry only pre-stream HTTP failures. A response that has already begun
        # streaming cannot be safely replaced in the middle of the SSE body.
        if status >= 500 and "/models/" in self.path and ":streamGenerateContent" in self.path:
            selected = first_healthy()
            if selected:
                alias, _model = selected
                marker = "/models/"
                start = self.path.index(marker) + len(marker)
                end = self.path.index(":", start)
                retry_path = self.path[:start] + alias + self.path[end:]
                status, headers, result = backend_request("POST", retry_path, body, dict(self.headers))
        if isinstance(result, bytes):
            self.send_response(status)
            for key, value in headers:
                if key.lower() not in {"connection", "transfer-encoding", "content-length"}:
                    self.send_header(key, value)
            self.send_header("Content-Length", str(len(result)))
            self.end_headers()
            self.wfile.write(result)
            return
        try:
            self.send_response(status)
            for key, value in headers:
                if key.lower() not in {"connection", "transfer-encoding", "content-length"}:
                    self.send_header(key, value)
            self.send_header("Connection", "close")
            self.end_headers()
            while True:
                chunk = result.read(8192)
                if not chunk:
                    break
                self.wfile.write(chunk)
        finally:
            result.close()
            self.close_connection = True


def stop(*_args) -> None:
    if backend and backend.poll() is None:
        backend.terminate()
        try:
            backend.wait(timeout=5)
        except subprocess.TimeoutExpired:
            backend.kill()
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    start_backend()
    # LiteLLM can take time to initialize and fetch its local model metadata.
    for _ in range(45):
        try:
            c = http.client.HTTPConnection(BACKEND_HOST, BACKEND_PORT, timeout=1)
            c.request("GET", "/health/liveliness")
            c.getresponse().read()
            c.close()
            break
        except OSError:
            time.sleep(1)
    server = ThreadingHTTPServer((PUBLIC_HOST, PUBLIC_PORT), Handler)
    server.serve_forever()
