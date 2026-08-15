#!/usr/bin/env bash
# /tmp is a tmpfs, so XDG_RUNTIME_DIR from the Steam image does not survive from the image layer.
# 10-setup_user.sh does chown on it with set -e; missing dir restarts the container.
# userdel -r also deletes /home/retro while it is still the process cwd.
set -e
cd /
mkdir -p "${XDG_RUNTIME_DIR:-/tmp/.X11-unix}" /run/dbus
chmod 1777 "${XDG_RUNTIME_DIR:-/tmp/.X11-unix}"

# Stale pid from a previous start (or a persisted /run) makes dbus-daemon fail
if [ -f /run/dbus/pid ]; then
  oldpid="$(cat /run/dbus/pid 2>/dev/null || true)"
  if [ -z "$oldpid" ] || ! kill -0 "$oldpid" 2>/dev/null; then
    rm -f /run/dbus/pid
  fi
fi
