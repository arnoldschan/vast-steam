#!/usr/bin/env bash
# NVIDIA Xorg with a fake connected 1080p output so Sunshine x11 capture
# can enumerate RANDR displays. Sourced by GOW — never call exit.
set +e
source /opt/gow/bash-lib/utils.sh 2>/dev/null || true

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/tmp/.Xauthority}"

mkdir -p /tmp/.X11-unix /var/log /run/dbus /dev/shm
chmod 1777 /tmp/.X11-unix /dev/shm

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

# Inject the real GPU BusID; NVIDIA Xorg often starts with 0 outputs otherwise.
XORG_CONF=/tmp/xorg-nvidia.conf
cp /etc/X11/xorg-nvidia.conf "$XORG_CONF"
if command -v nvidia-smi >/dev/null 2>&1; then
  PCI="$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader 2>/dev/null | head -n 1 | tr -d '[:space:]')"
  if [ -n "$PCI" ]; then
        BUSID="$(python3 -c "
import re
s='${PCI}'
m=re.search(r'([0-9A-Fa-f]+):([0-9A-Fa-f]+)\\.([0-9A-Fa-f]+)\$', s)
if not m:
    raise SystemExit(1)
print('PCI:%d:%d:%d' % (int(m.group(1),16), int(m.group(2),16), int(m.group(3),16)))
" 2>/dev/null)"
    if [ -n "$BUSID" ]; then
      gow_log "NVIDIA BusID ${BUSID} (${PCI})"
      awk -v bus="$BUSID" '
        $1=="Driver" && $2=="\"nvidia\"" { print; print "    BusID          \"" bus "\""; next }
        { print }
      ' "$XORG_CONF" > "${XORG_CONF}.new" && mv "${XORG_CONF}.new" "$XORG_CONF"
    fi
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

connect_outputs() {
  # Sunshine 2025 only lists RANDR outputs; force a connected 1080p mode.
  xrandr --auto >/dev/null 2>&1 || true
  for out in DFP-0 HDMI-0 HDMI-1 DP-0 DP-1 DVI-D-0 DVI-I-0; do
    xrandr --output "$out" --mode 1920x1080 --primary >/dev/null 2>&1 || \
      xrandr --output "$out" --auto --primary >/dev/null 2>&1 || true
  done
  gow_log "xrandr:"; xrandr --current 2>/dev/null | head -n 30 || true
}

if xdpyinfo >/dev/null 2>&1; then
  gow_log "X display ${DISPLAY} already available"
  allow_x
  connect_outputs
else
  rm -f /tmp/.X0-lock "/tmp/.X${DISPLAY#:}-lock"
  gow_log "Starting NVIDIA Xorg on ${DISPLAY}"
  # Do not pass vtN: containers usually cannot allocate a VT, which kills Xorg.
  Xorg "${DISPLAY}" \
    -config "$XORG_CONF" \
    -noreset \
    -nolisten tcp \
    -allowMouseOpenFail \
    +extension GLX \
    +extension RANDR \
    +extension RENDER \
    +extension MIT-SHM \
    -logfile /tmp/Xorg.log \
    >/tmp/Xorg.stdout 2>&1 &

  x_ok=0
  for _ in $(seq 1 80); do
    if xdpyinfo >/dev/null 2>&1; then
      gow_log "Xorg is up on ${DISPLAY}"
      x_ok=1
      allow_x
      connect_outputs
      break
    fi
    sleep 0.25
  done

  if [ "$x_ok" != 1 ]; then
    gow_log "NVIDIA Xorg failed; last log lines:"
    tail -n 60 /tmp/Xorg.log 2>/dev/null || true
    tail -n 40 /tmp/Xorg.stdout 2>/dev/null || true
  fi
fi
set -e
