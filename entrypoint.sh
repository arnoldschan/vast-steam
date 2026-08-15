#!/bin/bash
# Runs as UNAME (retro) via Games on Whales /entrypoint.sh
# Steam is PID of this script's child: if Steam exits, Docker restarts the
# whole container (cont-init loop). Keep a display up and respawn Steam.

source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

cd "${HOME:-/home/retro}"
mkdir -p "${HOME}/.config/pulse" "${XDG_RUNTIME_DIR:-/tmp/.X11-unix}"

export RUN_GAMESCOPE="${RUN_GAMESCOPE:-1}"
export ENABLE_GAMESCOPE_WSI="${ENABLE_GAMESCOPE_WSI:-0}"
# DISPLAY=:0 with no X server makes gamescope pick SDL "offscreen" (no Vulkan).
if [ -n "${DISPLAY:-}" ] && ! xdpyinfo >/dev/null 2>&1; then
  unset DISPLAY
  unset SDL_VIDEODRIVER
fi
if [ -z "${GAMESCOPE_MODE:-}" ]; then
  export GAMESCOPE_MODE="--backend headless -b"
else
  export GAMESCOPE_MODE
fi

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

# Wait for gamescope's nested Xwayland socket
(
  for _ in $(seq 1 180); do
    for sock in /tmp/.X11-unix/X*; do
      [ -e "$sock" ] || continue
      export DISPLAY=":${sock##*/X}"
      if xdpyinfo >/dev/null 2>&1; then
        exec sunshine
      fi
    done
    sleep 1
  done
  echo "Sunshine: gave up waiting for an X display" >&2
) &

while true; do
  /opt/gow/startup-app.sh || true
  echo "Steam exited; restarting in 5s" >&2
  sleep 5
done
