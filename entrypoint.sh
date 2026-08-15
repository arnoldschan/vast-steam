#!/bin/bash
# Runs as UNAME (retro) via Games on Whales /entrypoint.sh

source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

cd "${HOME:-/home/retro}"
mkdir -p "${HOME}/.config/pulse" "${HOME}/.steam/ubuntu12_32/steam-runtime" "${XDG_RUNTIME_DIR:-/run/user/1000}"
chmod 700 "${XDG_RUNTIME_DIR:-/run/user/1000}" 2>/dev/null || true

unset RUN_GAMESCOPE
unset RUN_SWAY
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/tmp/.Xauthority}"
export XDG_SESSION_TYPE=x11
export SDL_VIDEODRIVER=x11
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

gow_log "DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY}"
if ! xdpyinfo >/dev/null 2>&1; then
  gow_log "WARNING: cannot open X display ${DISPLAY} as $(id -un)"
  ls -la /tmp/.X11-unix 2>&1 || true
  xdpyinfo 2>&1 | head -n 20 || true
else
  gow_log "X display ${DISPLAY} is usable"
fi

mkdir -p "${HOME}/.config/sunshine"
cp /opt/gow/sunshine.conf "${HOME}/.config/sunshine/sunshine.conf"
PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
if [ -n "$PUBLIC_IP" ]; then
  printf '\ncsrf_allowed_origins = https://%s,http://%s\n' "$PUBLIC_IP" "$PUBLIC_IP" \
    >> "${HOME}/.config/sunshine/sunshine.conf"
  gow_log "Sunshine CSRF origins include https://${PUBLIC_IP}"
fi
if [ -n "${CSRF_ALLOWED_ORIGINS:-}" ]; then
  printf '\ncsrf_allowed_origins = %s\n' "$CSRF_ALLOWED_ORIGINS" \
    >> "${HOME}/.config/sunshine/sunshine.conf"
fi
APPS_JSON="$(find /opt/sunshine/squashfs-root -name apps.json 2>/dev/null | head -n 1)"
if [ -n "$APPS_JSON" ] && [ ! -f "${HOME}/.config/sunshine/apps.json" ]; then
  cp "$APPS_JSON" "${HOME}/.config/sunshine/apps.json"
fi

gow_log "Starting Sunshine web UI on 0.0.0.0:47990"
# AppImage binary resolves web assets relative to squashfs-root (./usr/share/sunshine)
(
  cd /opt/sunshine/squashfs-root
  exec ./usr/bin/sunshine "${HOME}/.config/sunshine/sunshine.conf"
) >>/tmp/sunshine.log 2>&1 &

steam_still_running() {
  pgrep -u "$(id -u)" -x steam >/dev/null 2>&1 \
    || pgrep -u "$(id -u)" -f 'steamwebhelper|steam\.sh|ubuntu12_32/steam' >/dev/null 2>&1
}

while true; do
  if steam_still_running; then
    gow_log "Steam already running; waiting"
    while steam_still_running; do
      sleep 10
    done
    gow_log "Steam processes ended; restarting in 5s"
    sleep 5
    continue
  fi

  gow_log "Starting Steam ${STEAM_STARTUP_FLAGS}"
  if command -v dbus-run-session >/dev/null; then
    dbus-run-session -- /usr/games/steam ${STEAM_STARTUP_FLAGS} >>/tmp/steam.log 2>&1 &
  else
    /usr/games/steam ${STEAM_STARTUP_FLAGS} >>/tmp/steam.log 2>&1 &
  fi
  steam_pid=$!
  sleep 6
  if ! steam_still_running && ! kill -0 "$steam_pid" 2>/dev/null; then
    gow_log "Steam wrapper exited immediately; last log lines:"
    tail -n 40 /tmp/steam.log 2>/dev/null || true
    sleep 5
    continue
  fi
  while kill -0 "$steam_pid" 2>/dev/null || steam_still_running; do
    sleep 8
  done
  gow_log "Steam exited; last log lines:"
  tail -n 40 /tmp/steam.log 2>/dev/null || true
  sleep 5
done
