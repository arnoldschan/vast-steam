#!/bin/bash
# Runs as UNAME (retro) via Games on Whales /entrypoint.sh

source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

cd "${HOME:-/home/retro}"
mkdir -p "${HOME}/.config/pulse" "${XDG_RUNTIME_DIR:-/tmp/.X11-unix}"

# Do not use gamescope: NVIDIA containers fail vkCreateDevice (Vulkan -7).
unset RUN_GAMESCOPE
unset RUN_SWAY
export DISPLAY="${DISPLAY:-:0}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
export STEAM_STARTUP_FLAGS="${STEAM_STARTUP_FLAGS:--bigpicture}"

if ! pulseaudio --check 2>/dev/null; then
  pulseaudio --start --exit-idle-time=-1 --disallow-exit --log-level=1 >/dev/null 2>&1 || true
fi

for _ in $(seq 1 30); do
  if pactl info >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

pactl load-module module-null-sink sink_name=Sunshine_Audio sink_properties=device.description="Sunshine_Audio" >/dev/null 2>&1 || true
pactl set-default-sink Sunshine_Audio >/dev/null 2>&1 || true

(
  for _ in $(seq 1 180); do
    if xdpyinfo >/dev/null 2>&1; then
      exec sunshine
    fi
    sleep 1
  done
  echo "Sunshine: gave up waiting for X display ${DISPLAY}" >&2
) &

while true; do
  /opt/gow/startup-app.sh || true
  echo "Steam exited; restarting in 5s" >&2
  sleep 5
done
