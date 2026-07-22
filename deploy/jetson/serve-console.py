#!/usr/bin/env python3
"""
serve-console.py -- Linux replacement for the Windows Console/Serve.ps1.

On a Jetson the status API is LOCAL, so there is no SSH tunnel: this stdlib-only
HTTP server does three jobs on :8080:
  1. static-serve the Console front-end from CONSOLE_ROOT (no-cache for
     html/js/css/json so a redeploy is picked up without a hard refresh);
  2. reverse-proxy /api/*  ->  http://127.0.0.1:8090  (the local FastAPI);
  3. serve /__build -- a stamp (newest asset mtime) the dashboard polls to
     auto-reload itself when the front-end changes.

No third-party packages (works on a bare JetPack/Ubuntu Python 3). Threaded so a
slow API call never blocks the wallboard's static requests.

Env (set by serve-console.service):
  UPES_CONSOLE_ROOT   dir to serve            (default /opt/upes-ecs/console)
  UPES_CONSOLE_PORT   listen port             (default 8080)
  UPES_API_BASE       local API base to proxy (default http://127.0.0.1:8090)
"""
import json
import os
import posixpath
import socket
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

try:
    from http.server import ThreadingHTTPServer
except ImportError:  # Python 3.6 (JetPack 4.x / Ubuntu 18.04) has no ThreadingHTTPServer
    from socketserver import ThreadingMixIn

    class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
        daemon_threads = True

CONSOLE_ROOT = os.environ.get("UPES_CONSOLE_ROOT", "/opt/upes-ecs/console")
PORT = int(os.environ.get("UPES_CONSOLE_PORT", "8080"))
API_BASE = os.environ.get("UPES_API_BASE", "http://127.0.0.1:8090").rstrip("/")

# Extensions that must never be cached (code/markup/data the dashboard reloads).
NO_CACHE_EXT = {".html", ".js", ".css", ".json", ".md"}
CTYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".md": "text/plain; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
    ".wav": "audio/wav",
    ".gsm": "audio/x-gsm",
    ".woff2": "font/woff2",
}
# Front-end assets whose mtime feeds the /__build stamp.
BUILD_ASSETS = ["app.js", "app.css", "index.html", "tv.js", "tv.css",
                "tv-safety.html", "tv-ops.html", "directory.json"]
API_TIMEOUT = 25


_ip_cache = {"ip": "", "ts": 0.0}


def lan_ip():
    """Best-effort primary LAN IP of THIS box -- the address phones/other PCs reach it at.
    Serve.ps1 injected this on Windows; on bare metal the local API can't know it, so the
    Console would otherwise fall back to a stale hardcoded default. Cached ~60s. Uses a UDP
    'connect' (no packets are actually sent) so the OS routing table picks the egress IP;
    works even air-gapped as long as a default route exists."""
    now = time.time()
    if _ip_cache["ip"] and now - _ip_cache["ts"] < 60:
        return _ip_cache["ip"]
    ip = ""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 9))
            ip = s.getsockname()[0]
        finally:
            s.close()
    except Exception:
        pass
    if not ip or ip.startswith("127."):
        try:
            ip = socket.gethostbyname(socket.gethostname())
        except Exception:
            ip = ip or ""
    if ip and not ip.startswith("127."):
        _ip_cache["ip"] = ip
        _ip_cache["ts"] = now
    return ip or _ip_cache["ip"]


def safe_join(root, url_path):
    """Resolve url_path under root; return None on any traversal attempt."""
    url_path = url_path.split("?", 1)[0].split("#", 1)[0]
    parts = [p for p in posixpath.normpath(url_path).split("/") if p not in ("", ".", "..")]
    full = os.path.realpath(os.path.join(root, *parts))
    root_real = os.path.realpath(root)
    if full == root_real or full.startswith(root_real + os.sep):
        return full
    return None


class Handler(BaseHTTPRequestHandler):
    server_version = "UPES-Console/1.0"
    protocol_version = "HTTP/1.1"

    # --- helpers -------------------------------------------------------------
    def _send(self, code, body=b"", ctype="application/json; charset=utf-8", no_cache=True):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        if no_cache:
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def log_message(self, fmt, *args):  # keep journald tidy; drop per-request noise
        pass

    # --- routing -------------------------------------------------------------
    def do_GET(self):
        self._route("GET")

    def do_HEAD(self):
        self._route("HEAD")

    def do_POST(self):
        self._route("POST")

    def _route(self, method):
        path = self.path.split("?", 1)[0]
        try:
            if path == "/__build":
                self._build_stamp()
            elif path == "/api" or path.startswith("/api/"):
                self._proxy_api(method)
            else:
                self._static(path if path != "/" else "/index.html")
        except BrokenPipeError:
            pass
        except Exception as exc:  # never crash the server on a bad request
            try:
                self._send(500, json.dumps({"ok": False, "error": str(exc)}))
            except Exception:
                pass

    # --- /__build ------------------------------------------------------------
    def _build_stamp(self):
        newest = 0
        for name in BUILD_ASSETS:
            p = os.path.join(CONSOLE_ROOT, name)
            try:
                newest = max(newest, int(os.path.getmtime(p) * 1000))
            except OSError:
                pass
        self._send(200, json.dumps({"build": str(newest)}))

    # --- /api/* proxy --------------------------------------------------------
    def _proxy_api(self, method):
        # /api/status -> <API_BASE>/status  (strip the /api prefix)
        rel = self.path[len("/api"):]
        if not rel.startswith("/"):
            rel = "/" + rel
        target = API_BASE + rel
        body = None
        if method == "POST":
            length = int(self.headers.get("Content-Length", 0) or 0)
            body = self.rfile.read(length) if length > 0 else b""
        req = urllib.request.Request(target, data=body, method=method)
        ctype = self.headers.get("Content-Type")
        if ctype:
            req.add_header("Content-Type", ctype)
        try:
            with urllib.request.urlopen(req, timeout=API_TIMEOUT) as resp:
                data = resp.read()
                rctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                # Bare-metal parity with Serve.ps1: the local API can't know the box's LAN IP, so
                # inject serverIp (right SIP address for phones) + bareMetal (Console hides VM-only UI)
                # into /api/status. Only that endpoint; everything else passes through untouched.
                if method == "GET" and rel.split("?", 1)[0] == "/status":
                    try:
                        obj = json.loads(data.decode("utf-8"))
                        if isinstance(obj, dict):
                            _ip = lan_ip()
                            if _ip:
                                obj["serverIp"] = _ip
                            obj["bareMetal"] = True
                            data = json.dumps(obj).encode("utf-8")
                    except Exception:
                        pass
                self._send(resp.status, data, ctype=rctype)
        except urllib.error.HTTPError as e:
            self._send(e.code, e.read() or b"{}",
                       ctype=e.headers.get("Content-Type", "application/json; charset=utf-8"))
        except Exception:
            self._send(502, json.dumps(
                {"ok": False, "output": "Local API unreachable -- is upes-api.service up?"}))

    # --- static files --------------------------------------------------------
    def _static(self, path):
        full = safe_join(CONSOLE_ROOT, path)
        if full is None or not os.path.isfile(full):
            self._send(404, "Not Found", ctype="text/plain; charset=utf-8")
            return
        ext = os.path.splitext(full)[1].lower()
        ctype = CTYPES.get(ext, "application/octet-stream")
        try:
            with open(full, "rb") as fh:
                data = fh.read()
        except OSError:
            self._send(404, "Not Found", ctype="text/plain; charset=utf-8")
            return
        self._send(200, data, ctype=ctype, no_cache=(ext in NO_CACHE_EXT))


def main():
    os.chdir(CONSOLE_ROOT if os.path.isdir(CONSOLE_ROOT) else "/")
    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"UPES-ECS Console -> http://0.0.0.0:{PORT}  (root={CONSOLE_ROOT}, api={API_BASE})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
