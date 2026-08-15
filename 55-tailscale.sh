#!/bin/bash
# Start Tailscale. Vast typically denies TUN, so use userspace networking.
mkdir -p /var/lib/tailscale /run/tailscale || true

SOCK=/run/tailscale/tailscaled.sock

if ! pidof tailscaled >/dev/null 2>&1; then
  tailscaled \
    --tun=userspace-networking \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket="$SOCK" \
    --port=41641 &
fi

(
  for _ in $(seq 1 40); do
    if [ -S "$SOCK" ]; then
      break
    fi
    sleep 0.25
  done

  if [ -n "${TS_AUTHKEY:-}" ]; then
    tailscale --socket="$SOCK" up \
      --auth-key="${TS_AUTHKEY}" \
      --hostname="${TS_HOSTNAME:-vast-steam}" \
      --accept-dns=false >/tmp/tailscale-up.log 2>&1 || true
  else
    tailscale --socket="$SOCK" up \
      --hostname="${TS_HOSTNAME:-vast-steam}" \
      --accept-dns=false >/tmp/tailscale-up.log 2>&1 || true
  fi

  echo "=== tailscale up ==="
  cat /tmp/tailscale-up.log 2>/dev/null || true
  echo "=== tailscale status ==="
  tailscale --socket="$SOCK" status || true
  echo "=== tailscale ip ==="
  tailscale --socket="$SOCK" ip -4 || true

  if tailscale --socket="$SOCK" ip -4 >/dev/null 2>&1; then
    tailscale --socket="$SOCK" serve --bg --tcp 47989 tcp://127.0.0.1:47989 || true
    tailscale --socket="$SOCK" serve --bg --tcp 47984 tcp://127.0.0.1:47984 || true
    tailscale --socket="$SOCK" serve --bg --tcp 47990 tcp://127.0.0.1:47990 || true
    tailscale --socket="$SOCK" serve --bg --tcp 48010 tcp://127.0.0.1:48010 || true
  fi
) &
true
