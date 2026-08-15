#!/usr/bin/env bash
# Gamescope vkCreateDevice fails with VK_ERROR_EXTENSION_NOT_PRESENT (-7) on
# NVIDIA in containers. Use a headless NVIDIA Xorg instead.
# This file is sourced by GOW /entrypoint.sh — never call exit.
set +e
source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

export DISPLAY="${DISPLAY:-:0}"

mkdir -p /tmp/.X11-unix /var/log /run/dbus
chmod 1777 /tmp/.X11-unix

if [ -S /run/dbus/system_bus_socket ] || [ -S /var/run/dbus/system_bus_socket ]; then
  true
else
  mkdir -p /run/dbus
  if [ -f /run/dbus/pid ] && ! kill -0 "$(cat /run/dbus/pid 2>/dev/null)" 2>/dev/null; then
    rm -f /run/dbus/pid
  fi
  if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
    dbus-daemon --system --fork --nosyslog 2>/dev/null || true
  fi
fi

allow_x() {
  xhost + >/dev/null 2>&1 || true
  xhost +SI:localuser:retro >/dev/null 2>&1 || true
  xhost +local: >/dev/null 2>&1 || true
  chmod 1777 /tmp/.X11-unix 2>/dev/null || true
  chmod 666 /tmp/.X11-unix/X* 2>/dev/null || true
  touch /tmp/.Xauthority
  chmod 666 /tmp/.Xauthority
  xauth -f /tmp/.Xauthority generate "${DISPLAY}" . trusted >/dev/null 2>&1 || true
}

if xdpyinfo >/dev/null 2>&1; then
  gow_log "X display ${DISPLAY} already available"
  allow_x
else
  rm -f /tmp/.X0-lock "/tmp/.X${DISPLAY#:}-lock"
  gow_log "Starting NVIDIA Xorg on ${DISPLAY}"
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

  x_ok=0
  for _ in $(seq 1 50); do
    if xdpyinfo >/dev/null 2>&1; then
      gow_log "Xorg is up on ${DISPLAY}"
      x_ok=1
      allow_x
      break
    fi
    sleep 0.2
  done

  if [ "$x_ok" != 1 ]; then
    gow_log "NVIDIA Xorg failed; last log lines:"
    tail -n 40 /tmp/Xorg.log 2>/dev/null || true
    if command -v Xvfb >/dev/null && ! xdpyinfo >/dev/null 2>&1; then
      gow_log "Falling back to Xvfb (no GPU acceleration)"
      Xvfb "${DISPLAY}" -screen 0 1920x1080x24 +extension GLX >/tmp/Xvfb.log 2>&1 &
    fi
  fi
fi
set -e
