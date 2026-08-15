#!/usr/bin/env python3
"""Forward Vast-mapped GameStream ports to Sunshine's shifted listeners and
rewrite serverinfo so Moonlight uses the public host ports."""
import json
import os
import re
import select
import socket
import threading
import urllib.request

BASE = int(os.environ.get("SUNSHINE_INTERNAL_BASE", "46989"))
PUBLIC_IP = os.environ.get("PUBLIC_IP", "")
TCP_MAP = [(47984, BASE - 5), (47989, BASE), (48010, BASE + 21)]
UDP_MAP = [
    (47998, BASE + 9),
    (47999, BASE + 10),
    (48000, BASE + 11),
    (48002, BASE + 13),
    (48010, BASE + 21),
]


def log(msg: str) -> None:
    print(f"[gs-forward] {msg}", flush=True)


def vast_host_ports() -> dict[int, int]:
    """container_port -> host_port"""
    key = os.environ.get("VAST_API_KEY", "")
    if not key:
        return {}
    try:
        req = urllib.request.Request(
            "https://console.vast.ai/api/v0/instances/",
            headers={"Authorization": f"Bearer {key}"},
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.load(resp)
        insts = data.get("instances") or []
        chosen = None
        for inst in insts:
            if PUBLIC_IP and inst.get("public_ipaddr") == PUBLIC_IP:
                chosen = inst
                break
        if chosen is None and insts:
            chosen = insts[0]
        if not chosen:
            return {}
        out = {}
        ports = chosen.get("ports") or {}
        for spec, mapping in ports.items():
            if "/" not in spec:
                continue
            port_s, proto = spec.split("/", 1)
            if proto != "tcp" and proto != "udp":
                continue
            host = None
            if isinstance(mapping, list) and mapping:
                host = mapping[0].get("HostPort")
            elif isinstance(mapping, dict):
                host = mapping.get("HostPort")
            if host:
                out[int(port_s)] = int(host)
        log(f"vast host ports {out}")
        return out
    except Exception as exc:
        log(f"vast port lookup failed: {exc}")
        return {}


def rewrite_payload(data: bytes, host_ports: dict[int, int]) -> bytes:
    if not host_ports or not data:
        return data
    pairs = []
    for container_port, internal in [
        (47984, BASE - 5),
        (47989, BASE),
        (47990, BASE + 1),
        (48010, BASE + 21),
        (47998, BASE + 9),
        (47999, BASE + 10),
        (48000, BASE + 11),
        (48002, BASE + 13),
    ]:
        public = host_ports.get(container_port)
        if public:
            pairs.append((str(internal).encode(), str(public).encode()))
            pairs.append((str(container_port).encode(), str(public).encode()))
    pairs.sort(key=lambda p: len(p[0]), reverse=True)
    for old, new in pairs:
        data = data.replace(old, new)
    return data


def pump(a, b):
    try:
        while True:
            r, _, _ = select.select([a, b], [], [], 120)
            if not r:
                break
            for s in r:
                other = b if s is a else a
                chunk = s.recv(16384)
                if not chunk:
                    return
                other.sendall(chunk)
    except OSError:
        return


def handle_tcp(client, dest_port: int, http_rewrite: bool, host_ports: dict[int, int]):
    backend = None
    try:
        backend = socket.create_connection(("127.0.0.1", dest_port), timeout=10)
        if not http_rewrite:
            pump(client, backend)
            return
        client.settimeout(15)
        backend.settimeout(15)
        req = b""
        while b"\r\n\r\n" not in req and len(req) < 65536:
            chunk = client.recv(4096)
            if not chunk:
                break
            req += chunk
        if not req:
            return
        if b"Connection:" in req or b"connection:" in req:
            req = re.sub(br"(?i)connection:\s*[^\r\n]*", b"Connection: close", req)
        elif b"\r\n\r\n" in req:
            req = req.replace(b"\r\n\r\n", b"\r\nConnection: close\r\n\r\n", 1)
        backend.sendall(req)
        resp = b""
        while True:
            try:
                chunk = backend.recv(16384)
            except OSError:
                break
            if not chunk:
                break
            resp += chunk
            if len(resp) > 2_000_000:
                break
        client.sendall(rewrite_payload(resp, host_ports))
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


def listen_tcp(src: int, dest: int, http_rewrite: bool, host_ports: dict[int, int]):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", src))
    sock.listen(32)
    log(f"tcp {src} -> 127.0.0.1:{dest} rewrite={http_rewrite}")
    while True:
        conn, _ = sock.accept()
        threading.Thread(
            target=handle_tcp, args=(conn, dest, http_rewrite, host_ports), daemon=True
        ).start()


def listen_udp(src: int, dest: int):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", src))
    backend = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    clients: dict[tuple, tuple] = {}
    log(f"udp {src} -> 127.0.0.1:{dest}")
    while True:
        r, _, _ = select.select([sock, backend], [], [], 60)
        if sock in r:
            data, addr = sock.recvfrom(65535)
            clients["peer"] = addr
            backend.sendto(data, ("127.0.0.1", dest))
        if backend in r:
            data, _ = backend.recvfrom(65535)
            peer = clients.get("peer")
            if peer:
                sock.sendto(data, peer)


def main():
    host_ports = vast_host_ports()
    threads = []
    for src, dest in TCP_MAP:
        t = threading.Thread(
            target=listen_tcp, args=(src, dest, src == 47989, host_ports), daemon=True
        )
        t.start()
        threads.append(t)
    for src, dest in UDP_MAP:
        t = threading.Thread(target=listen_udp, args=(src, dest), daemon=True)
        t.start()
        threads.append(t)
    threads[0].join()


if __name__ == "__main__":
    main()
