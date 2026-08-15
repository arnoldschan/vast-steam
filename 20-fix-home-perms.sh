#!/usr/bin/env bash
# 10-setup_user.sh only chowns $HOME itself. Baked or volume-mounted
# ~/.steam is often still root-owned, and Steam then cannot mkdir under it.
set -e
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
HOME_DIR="${HOME:-/home/retro}"

mkdir -p \
  "${HOME_DIR}/.steam/ubuntu12_32/steam-runtime" \
  "${HOME_DIR}/.steam/steam/config" \
  "${HOME_DIR}/.local/share/Steam" \
  "${HOME_DIR}/.config/sunshine" \
  "${HOME_DIR}/.config/pulse"

if [ ! -s "${HOME_DIR}/.steam/steam/config/config.vdf" ] && [ -f /opt/gow/steam-compat.vdf ]; then
  cp /opt/gow/steam-compat.vdf "${HOME_DIR}/.steam/steam/config/config.vdf"
fi

chown -R "${PUID}:${PGID}" "${HOME_DIR}"
