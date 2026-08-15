#!/bin/bash
# TLS certificate for the Web UI auth proxy on 47990.
if [ ! -f /opt/gow/ui-proxy.pem ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/CN=sunshine" \
    -keyout /tmp/ui-proxy.key -out /tmp/ui-proxy.crt >/dev/null 2>&1 \
    && cat /tmp/ui-proxy.key /tmp/ui-proxy.crt > /opt/gow/ui-proxy.pem \
    && rm -f /tmp/ui-proxy.key /tmp/ui-proxy.crt \
    && chmod 644 /opt/gow/ui-proxy.pem || true
fi
