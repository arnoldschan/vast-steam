#!/bin/bash
# Start Tailscale in the container netns so Moonlight can use standard
# Sunshine ports on the tailnet IP (100.x).
mkdir -p /dev/net /var/lib/tailscale /run/tailscale || true
if [ ! -e /dev/net/tun ]; then
  mknod /dev/net/tun c 10 200 || true
  chmod 666 /dev/net/tun || true
fi

if ! pidof tailscaled >/dev/null 2>&1; then
  tailscaled \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket=/run/tailscale/tailscaled.sock \
    --port=41641 \
    >/tmp/tailscaled.log 2>&1 &
fi

(
  for _ in $(seq 1 25); do
    if [ -S /run/tailscale/tailscaled.sock ]; then
      break
    fi
    sleep 0.2
  done
  if [ -n "${TS_AUTHKEY:-}" ]; then
    tailscale --socket=/run/tailscale/tailscaled.sock up \
      --auth-key="${TS_AUTHKEY}" \
      --hostname="${TS_HOSTNAME:-vast-steam}" \
      --accept-dns=false >/tmp/tailscale-up.log 2>&1 || true
  else
    tailscale --socket=/run/tailscale/tailscaled.sock up \
      --hostname="${TS_HOSTNAME:-vast-steam}" \
      --accept-dns=false >/tmp/tailscale-up.log 2>&1 || true
  fi
  echo "=== tailscale status ==="
  tailscale --socket=/run/tailscale/tailscaled.sock status || true
  echo "=== tailscale ip ==="
  tailscale --socket=/run/tailscale/tailscaled.sock ip -4 || true
  cat /tmp/tailscale-up.log 2>/dev/null || true
) >/tmp/tailscale.log 2>&1 &
true
