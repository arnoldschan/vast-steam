#!/bin/bash
# Incoming TCP 47990 is Sunshine's HTTPS UI. Redirect it to a proxy that
# injects HTTP Basic Auth so browsers do not get stuck on 401/welcome.
set -e
PROXY_PORT=18443

if command -v iptables >/dev/null 2>&1; then
  iptables -t nat -C PREROUTING -p tcp --dport 47990 -j REDIRECT --to-ports "$PROXY_PORT" 2>/dev/null \
    || iptables -t nat -A PREROUTING -p tcp --dport 47990 -j REDIRECT --to-ports "$PROXY_PORT" || true
fi
if command -v ip6tables >/dev/null 2>&1; then
  ip6tables -t nat -C PREROUTING -p tcp --dport 47990 -j REDIRECT --to-ports "$PROXY_PORT" 2>/dev/null \
    || ip6tables -t nat -A PREROUTING -p tcp --dport 47990 -j REDIRECT --to-ports "$PROXY_PORT" || true
fi

if [ ! -f /opt/gow/ui-proxy.pem ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/CN=sunshine" \
    -keyout /tmp/ui-proxy.key -out /tmp/ui-proxy.crt >/dev/null 2>&1 \
    && cat /tmp/ui-proxy.key /tmp/ui-proxy.crt > /opt/gow/ui-proxy.pem \
    && rm -f /tmp/ui-proxy.key /tmp/ui-proxy.crt \
    && chmod 644 /opt/gow/ui-proxy.pem
fi
