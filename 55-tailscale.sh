#!/bin/bash
# Start Tailscale so Moonlight can use standard Sunshine ports on 100.x.
# Vast often denies TUN/NET_ADMIN; fall back to userspace networking.
mkdir -p /var/lib/tailscale /run/tailscale || true

SOCK=/run/tailscale/tailscaled.sock

start_daemon() {
  tailscaled \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket="$SOCK" \
    --port=41641 \
    "$@" \
    >/proc/1/fd/1 2>/proc/1/fd/2 &
}

wait_sock() {
  for _ in $(seq 1 25); do
    if [ -S "$SOCK" ]; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

if ! pidof tailscaled >/dev/null 2>&1; then
  start_daemon
fi

(
  if ! wait_sock; then
    echo "tailscaled did not create a socket (TUN likely denied); retrying userspace-networking"
    kill $(pidof tailscaled) 2>/dev/null || true
    sleep 0.5
    rm -f "$SOCK" || true
    start_daemon --tun=userspace-networking
    wait_sock || true
  fi

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

  echo "=== tailscale status ==="
  tailscale --socket="$SOCK" status || true
  echo "=== tailscale ip ==="
  tailscale --socket="$SOCK" ip -4 || true
  cat /tmp/tailscale-up.log 2>/dev/null || true

  if tailscale --socket="$SOCK" ip -4 >/dev/null 2>&1; then
    tailscale --socket="$SOCK" serve --bg --tcp 47989 tcp://127.0.0.1:47989 || true
    tailscale --socket="$SOCK" serve --bg --tcp 47984 tcp://127.0.0.1:47984 || true
    tailscale --socket="$SOCK" serve --bg --tcp 47990 tcp://127.0.0.1:47990 || true
    tailscale --socket="$SOCK" serve --bg --tcp 48010 tcp://127.0.0.1:48010 || true
  fi
) 2>&1 | tee /tmp/tailscale.log >/proc/1/fd/1 &
true
