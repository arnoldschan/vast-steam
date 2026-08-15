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
SUNSHINE_BASE_PORT="${SUNSHINE_BASE_PORT:-46989}"
sed -i "s/^port = .*/port = ${SUNSHINE_BASE_PORT}/" "${HOME}/.config/sunshine/sunshine.conf"
gow_log "Sunshine base port ${SUNSHINE_BASE_PORT}"
PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
TS_IP=""
TS_DNS=""
if pidof tailscaled >/dev/null 2>&1; then
  for _ in $(seq 1 80); do
    if [ -s /tmp/tailscale-ip ]; then
      TS_IP="$(tr -d '[:space:]' < /tmp/tailscale-ip)"
      TS_DNS="$(tr -d '[:space:]' < /tmp/tailscale-dns 2>/dev/null || true)"
      break
    fi
    sleep 0.25
  done
fi
CSRF_ORIGINS=""
append_csrf() {
  case ",${CSRF_ORIGINS}," in
    *",$1,"*) ;;
    *)
      if [ -n "$CSRF_ORIGINS" ]; then
        CSRF_ORIGINS="${CSRF_ORIGINS},$1"
      else
        CSRF_ORIGINS="$1"
      fi
      ;;
  esac
}
[ -n "$PUBLIC_IP" ] && append_csrf "https://${PUBLIC_IP}"
[ -n "$TS_IP" ] && append_csrf "https://${TS_IP}"
[ -n "$TS_DNS" ] && append_csrf "https://${TS_DNS}"
if [ -n "${CSRF_ALLOWED_ORIGINS:-}" ]; then
  CSRF_ORIGINS="${CSRF_ORIGINS:+${CSRF_ORIGINS},}${CSRF_ALLOWED_ORIGINS}"
fi
if [ -n "$CSRF_ORIGINS" ]; then
  printf '\ncsrf_allowed_origins = %s\n' "$CSRF_ORIGINS" \
    >> "${HOME}/.config/sunshine/sunshine.conf"
  gow_log "Sunshine CSRF origins: ${CSRF_ORIGINS}"
fi
APPS_JSON="$(find /opt/sunshine/squashfs-root -name apps.json 2>/dev/null | head -n 1)"
if [ -n "$APPS_JSON" ] && [ ! -f "${HOME}/.config/sunshine/apps.json" ]; then
  cp "$APPS_JSON" "${HOME}/.config/sunshine/apps.json"
fi

# Pre-create Web UI credentials so Chrome's HTTP Basic dialog is used instead of
# the /welcome form (that form never sends Authorization and the UI spins forever).
SUNSHINE_USERNAME="${SUNSHINE_USERNAME:-sunshine}"
SUNSHINE_PASSWORD="${SUNSHINE_PASSWORD:-sunshine}"
cd /opt/sunshine/squashfs-root
./usr/bin/sunshine "${HOME}/.config/sunshine/sunshine.conf" \
  --creds "${SUNSHINE_USERNAME}" "${SUNSHINE_PASSWORD}" \
  >>/tmp/sunshine-creds.log 2>&1 || true
gow_log "Sunshine Web UI login: ${SUNSHINE_USERNAME} / (SUNSHINE_PASSWORD)"

gow_log "Starting Sunshine (Steam is not auto-started)"
if [ "${SUNSHINE_BASE_PORT}" = "46989" ]; then
(
  for _ in $(seq 1 40); do
    python3 -c "import socket; s=socket.create_connection(('127.0.0.1',46989),1); s.close(); s=socket.create_connection(('127.0.0.1',46990),1); s.close()" 2>/dev/null && break
    sleep 0.25
  done
  export PUBLIC_IP="${PUBLIC_IP}"
  python3 /opt/gow/gs-forward.py >>/tmp/gs-forward.log 2>&1 &
  gow_log "Starting Sunshine Web UI proxy on :47990 -> 127.0.0.1:46990"
  exec python3 /opt/gow/ui-proxy.py
) >>/tmp/ui-proxy.log 2>&1 &
fi
exec ./usr/bin/sunshine "${HOME}/.config/sunshine/sunshine.conf"
