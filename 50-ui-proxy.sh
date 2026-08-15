#!/bin/bash
# Sunshine listens on a shifted base port (46989). Public 47990 is the auth
# proxy. Map the usual Moonlight ports onto the shifted ones when iptables works.
set -e

redirect_tcp() {
  local src="$1" dst="$2"
  iptables -t nat -C PREROUTING -p tcp --dport "$src" -j REDIRECT --to-ports "$dst" 2>/dev/null \
    || iptables -t nat -A PREROUTING -p tcp --dport "$src" -j REDIRECT --to-ports "$dst" || true
}

redirect_udp() {
  local src="$1" dst="$2"
  iptables -t nat -C PREROUTING -p udp --dport "$src" -j REDIRECT --to-ports "$dst" 2>/dev/null \
    || iptables -t nat -A PREROUTING -p udp --dport "$src" -j REDIRECT --to-ports "$dst" || true
}

if command -v iptables >/dev/null 2>&1; then
  redirect_tcp 47984 46984
  redirect_tcp 47989 46989
  redirect_tcp 48010 47010
  redirect_udp 47998 46998
  redirect_udp 47999 46999
  redirect_udp 48000 47000
  redirect_udp 48002 47002
  redirect_udp 48010 47010
fi

if [ ! -f /opt/gow/ui-proxy.pem ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/CN=sunshine" \
    -keyout /tmp/ui-proxy.key -out /tmp/ui-proxy.crt >/dev/null 2>&1 \
    && cat /tmp/ui-proxy.key /tmp/ui-proxy.crt > /opt/gow/ui-proxy.pem \
    && rm -f /tmp/ui-proxy.key /tmp/ui-proxy.crt \
    && chmod 644 /opt/gow/ui-proxy.pem || true
fi
