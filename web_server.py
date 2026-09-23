#!/usr/bin/env python3
"""Same-origin local web server for AGY NVIDIA Studio."""
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit
import http.client, mimetypes, os, json

ROOT = Path(os.environ.get("AGY_NVIDIA_WEB_ROOT", Path.home()/".local/share/agy-nvidia-web"))
HOST, PORT = "0.0.0.0", int(os.environ.get("AGY_NVIDIA_WEB_PORT", "5173"))

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *_): pass
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/health": return self.json({"ok": True, "router": "127.0.0.1:4000"})
        rel = "index.html" if path in ("", "/") else path.lstrip("/")
        file = (ROOT / rel).resolve()
        if ROOT not in file.parents and file != ROOT: return self.send_error(403)
        if not file.is_file(): return self.send_error(404)
        data = file.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(str(file))[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers(); self.wfile.write(data)
    def do_POST(self):
        if urlsplit(self.path).path != "/api/chat": return self.send_error(404)
        size = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(size)
        try: payload = json.loads(body); model = payload["model"]
        except Exception: return self.json({"error":"invalid request"}, 400)
        path = f"/v1beta/models/{model}:streamGenerateContent?alt=sse"
        conn = http.client.HTTPConnection("127.0.0.1", 4000, timeout=130)
        request_body = json.dumps({"contents":payload.get("contents",[]), "generationConfig":payload.get("generationConfig",{})}).encode()
        conn.request("POST", path, body=request_body, headers={"Content-Type":"application/json", "Content-Length":str(len(request_body)), "x-goog-api-key":"local-router"})
        response = conn.getresponse()
        self.send_response(response.status)
        for key, value in response.getheaders():
            if key.lower() not in {"connection", "content-length", "transfer-encoding"}: self.send_header(key, value)
        self.send_header("Connection", "close"); self.end_headers()
        try:
            while True:
                chunk = response.read(8192)
                if not chunk: break
                self.wfile.write(chunk)
        finally: response.close(); conn.close(); self.close_connection = True
    def json(self, obj, status=200):
        data=json.dumps(obj).encode(); self.send_response(status); self.send_header("Content-Type","application/json"); self.send_header("Content-Length",str(len(data))); self.end_headers(); self.wfile.write(data)

if __name__ == "__main__":
    if not (ROOT/"index.html").exists(): raise SystemExit(f"UI assets not found: {ROOT}")
    print(f"AGY NVIDIA web: http://127.0.0.1:{PORT}/", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
