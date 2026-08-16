#!/bin/bash
# Launch Steam on the NVIDIA X display. Sunshine must start Steam as a
# detached process — if Steam is the main cmd it daemonizes and Moonlight
# gets "Failed to start the specified application (Error 0)".
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/tmp/.Xauthority}"
export HOME="${HOME:-/home/retro}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export XDG_SESSION_TYPE=x11
export SDL_VIDEODRIVER=x11
mkdir -p "${XDG_RUNTIME_DIR}" "${HOME}/.steam" 2>/dev/null || true

STEAM=""
for c in /usr/games/steam /usr/bin/steam /usr/bin/steam-runtime steam; do
  if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
    STEAM="$c"
    break
  fi
done
if [ -z "$STEAM" ]; then
  echo "steam not found" >&2
  exit 1
fi
exec "$STEAM" "$@"
