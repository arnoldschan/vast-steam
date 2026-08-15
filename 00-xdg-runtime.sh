#!/usr/bin/env bash
# /tmp is a tmpfs, so XDG_RUNTIME_DIR from the Steam image does not survive from the image layer.
# 10-setup_user.sh does chown on it with set -e; missing dir restarts the container.
set -e
mkdir -p "${XDG_RUNTIME_DIR:-/tmp/.X11-unix}"
chmod 1777 "${XDG_RUNTIME_DIR:-/tmp/.X11-unix}"
