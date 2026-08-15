#!/bin/sh

source /opt/gow/bash-lib/utils.sh

# This file is sourced by GOW /entrypoint.sh under set -e. Optional host
# services (BlueZ, NetworkManager) often fail in GPU cloud containers.
set +e

mkdir -p /run/dbus
if [ -f /run/dbus/pid ]; then
  oldpid="$(cat /run/dbus/pid 2>/dev/null || true)"
  if [ -z "$oldpid" ] || ! kill -0 "$oldpid" 2>/dev/null; then
    rm -f /run/dbus/pid
  fi
fi
if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
  dbus-daemon --system --fork --nosyslog
  gow_log "*** DBus started ***"
else
  gow_log "*** DBus already running ***"
fi

if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
  bluetoothd --nodetach &
  gow_log "*** Bluez started ***"
else
  gow_log "*** Bluez skipped (no Bluetooth adapter) ***"
fi

if pgrep -x NetworkManager >/dev/null 2>&1; then
  gow_log "*** NetworkManager already running ***"
else
  NetworkManager
  gow_log "*** NetworkManager started ***"
fi

steamos-dbus-watchdog.sh &
gow_log "*** D-Bus Watchdog started ***"

if [ ! -f "$HOME/homebrew/services/PluginLoader" ]; then
  gow_log "Installing Decky Loader"
  mkdir -p "$HOME/.steam/steam/"
  mkdir -p "$HOME/.steam/debian-installation/"
  touch "$HOME/.steam/debian-installation/.cef-enable-remote-debugging"
  mkdir -p "$HOME/homebrew/services/"
  cp /opt/decky/PluginLoader "$HOME/homebrew/services/PluginLoader"
  chmod +x "$HOME/homebrew/services/PluginLoader"
fi

if [ -x "$HOME/homebrew/services/PluginLoader" ]; then
  gow_log "*** Decky Loader started ***"
  "$HOME/homebrew/services/PluginLoader" &
fi

disown 2>/dev/null
set -e
