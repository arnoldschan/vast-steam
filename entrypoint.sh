#!/bin/bash
# Runs as UNAME (retro) via Games on Whales /entrypoint.sh
set -u

source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

mkdir -p "${HOME}/.config/pulse" "${XDG_RUNTIME_DIR:-/tmp}"

# PulseAudio must not run as root; this script is already dropped to retro
if ! pulseaudio --check 2>/dev/null; then
  pulseaudio --start --exit-idle-time=-1 --disallow-exit --log-level=1 || true
fi

for _ in $(seq 1 30); do
  if pactl info >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

pactl load-module module-null-sink sink_name=Sunshine_Audio sink_properties=device.description="Sunshine_Audio" 2>/dev/null || true
pactl set-default-sink Sunshine_Audio 2>/dev/null || true

# Sunshine needs an X display; Steam/gamescope creates it in startup-app.sh
(
  for _ in $(seq 1 120); do
    if xdpyinfo >/dev/null 2>&1; then
      exec sunshine
    fi
    sleep 1
  done
  echo "Sunshine: gave up waiting for X display ${DISPLAY:-unset}" >&2
) &

exec /opt/gow/startup-app.sh
