#!/usr/bin/env python3
"""TLS proxy that injects Sunshine HTTP Basic Auth for the public Web UI."""
import base64
import os
import select
import socket
import ssl
import threading

LISTEN_PORT = int(os.environ.get("SUNSHINE_UI_PROXY_PORT", "18443"))
BACKEND = ("127.0.0.1", int(os.environ.get("SUNSHINE_UI_BACKEND_PORT", "47990")))
USER = os.environ.get("SUNSHINE_USERNAME", "sunshine")
PASSWORD = os.environ.get("SUNSHINE_PASSWORD", "sunshine")
AUTH = "Basic " + base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()
CERT = os.environ.get("SUNSHINE_UI_PROXY_CERT", "/opt/gow/ui-proxy.pem")


def inject_auth(header_blob: bytes) -> bytes:
    text = header_blob.decode("iso-8859-1")
    lines = text.split("\r\n")
    if not lines:
        return header_blob
    request_line = lines[0]
    filtered = []
    for line in lines[1:]:
        if not line:
            continue
        lower = line.lower()
        if lower.startswith("authorization:") or lower.startswith("connection:"):
            continue
        filtered.append(line)
    rebuilt = [request_line, f"Authorization: {AUTH}", "Connection: close"]
    rebuilt.extend(filtered)
    rebuilt.append("")
    rebuilt.append("")
    return "\r\n".join(rebuilt).encode("iso-8859-1")


def read_http_headers(sock) -> bytes:
    buf = b""
    while b"\r\n\r\n" not in buf and len(buf) < 65536:
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
    return buf


def pump(a, b):
    try:
        while True:
            r, _, _ = select.select([a, b], [], [], 120)
            if not r:
                break
            for s in r:
                other = b if s is a else a
                data = s.recv(16384)
                if not data:
                    return
                other.sendall(data)
    except OSError:
        return


def handle(client: ssl.SSLSocket):
    backend = None
    try:
        raw = read_http_headers(client)
        if not raw:
            return
        header, _, rest = raw.partition(b"\r\n\r\n")
        raw = inject_auth(header + b"\r\n\r\n") + rest
        bctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        bctx.check_hostname = False
        bctx.verify_mode = ssl.CERT_NONE
        raw_sock = socket.create_connection(BACKEND, timeout=20)
        backend = bctx.wrap_socket(raw_sock, server_hostname="127.0.0.1")
        backend.sendall(raw)
        pump(client, backend)
    except OSError:
        pass
    finally:
        try:
            client.close()
        except OSError:
            pass
        if backend is not None:
            try:
                backend.close()
            except OSError:
                pass


def main():
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.set_alpn_protocols(["http/1.1"])
    ctx.load_cert_chain(CERT)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", LISTEN_PORT))
    sock.listen(32)
    while True:
        conn, _ = sock.accept()
        try:
            tls = ctx.wrap_socket(conn, server_side=True)
        except ssl.SSLError:
            conn.close()
            continue
        threading.Thread(target=handle, args=(tls,), daemon=True).start()


if __name__ == "__main__":
    main()
