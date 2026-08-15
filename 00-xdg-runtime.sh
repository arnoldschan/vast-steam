#!/usr/bin/env bash
# This file is sourced by GOW /entrypoint.sh — never call exit.
# Steam/dbus need XDG_RUNTIME_DIR owned by uid 1000. GOW steam sets it to
# /tmp/.X11-unix, which Xorg owns as root.
set -e
cd /
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

mkdir -p /tmp/.X11-unix /run/dbus
chmod 1777 /tmp/.X11-unix

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${PUID}}"
mkdir -p "${XDG_RUNTIME_DIR}"
chown "${PUID}:${PGID}" "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

if [ -f /run/dbus/pid ]; then
  oldpid="$(cat /run/dbus/pid 2>/dev/null || true)"
  if [ -z "$oldpid" ] || ! kill -0 "$oldpid" 2>/dev/null; then
    rm -f /run/dbus/pid
  fi
fi
