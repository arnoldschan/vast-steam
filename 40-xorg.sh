#!/usr/bin/env bash
# Gamescope vkCreateDevice fails with VK_ERROR_EXTENSION_NOT_PRESENT (-7) on
# NVIDIA in containers. Use a headless NVIDIA Xorg instead.
set +e
source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

export DISPLAY="${DISPLAY:-:0}"

if xdpyinfo >/dev/null 2>&1; then
  gow_log "X display ${DISPLAY} already available"
  set -e
  exit 0
fi

mkdir -p /tmp/.X11-unix /var/log
chmod 1777 /tmp/.X11-unix

gow_log "Starting NVIDIA Xorg on ${DISPLAY}"
# -noreset keeps the server up if clients disconnect
Xorg "${DISPLAY}" \
  -config /etc/X11/xorg-nvidia.conf \
  -noreset \
  -nolisten tcp \
  +extension GLX \
  +extension RANDR \
  +extension RENDER \
  -logfile /tmp/Xorg.log \
  vt8 \
  >/tmp/Xorg.stdout 2>&1 &

for _ in $(seq 1 50); do
  if xdpyinfo >/dev/null 2>&1; then
    gow_log "Xorg is up on ${DISPLAY}"
    set -e
    exit 0
  fi
  sleep 0.2
done

gow_log "NVIDIA Xorg failed; last log lines:"
tail -n 40 /tmp/Xorg.log 2>/dev/null || true
tail -n 20 /tmp/Xorg.stdout 2>/dev/null || true

if command -v Xvfb >/dev/null; then
  gow_log "Falling back to Xvfb (no GPU acceleration)"
  Xvfb "${DISPLAY}" -screen 0 1920x1080x24 +extension GLX >/tmp/Xvfb.log 2>&1 &
fi
set -e
