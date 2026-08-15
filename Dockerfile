# Use the base Games on Whales Steam image which includes X11 and Nvidia libraries
FROM ghcr.io/games-on-whales/steam:master

# Switch to root to install core packages and system dependencies
USER root

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV APPIMAGE_EXTRACT_AND_RUN=1

# Update and install utilities, virtual audio drivers, and Sunshine dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    libcap2-bin \
    wget \
    curl \
    ca-certificates \
    libfuse2t64 \
    xvfb \
    x11-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Sunshine via AppImage so it matches Ubuntu 25.04 (GOW steam:master).
# Official .deb builds are only for 22.04 / 24.04 / 26.04 and fail on Plucky.
RUN wget -O /tmp/sunshine.AppImage \
      "https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine.AppImage" \
    && chmod +x /tmp/sunshine.AppImage \
    && mkdir -p /opt/sunshine \
    && cd /opt/sunshine \
    && /tmp/sunshine.AppImage --appimage-extract \
    && SUNSHINE_BIN="$(find /opt/sunshine/squashfs-root -type f -name sunshine -perm -111 | head -n 1)" \
    && test -n "$SUNSHINE_BIN" \
    && ln -sf "$SUNSHINE_BIN" /usr/local/bin/sunshine \
    && rm -f /tmp/sunshine.AppImage

# Give Sunshine capabilities to create virtual input devices and intercept GPU frames
RUN setcap cap_sys_admin+p $(readlink -f $(which sunshine))

# Games on Whales uses UNAME=retro, HOME=/home/retro (not "user")
# WORKDIR must not be $HOME: 10-setup_user.sh runs userdel -r and deletes cwd.
ENV HOME=/home/retro
ENV DISPLAY=:0
ENV RUN_GAMESCOPE=1
WORKDIR /

# Pre-create directory structures for the persistent volume mounts
RUN mkdir -p $HOME/.steam/steam/config/ \
    && mkdir -p $HOME/.local/share/Steam \
    && mkdir -p $HOME/.config/sunshine \
    && chown -R 1000:1000 $HOME/.steam $HOME/.local $HOME/.config || true

# Palworld → Proton Experimental (copied into $HOME after GOW recreates the user)
RUN echo '{"CompatToolMapping":{"2394300":{"name":"proton_experimental","config":"","priority":250}}}' \
    > /opt/gow/steam-compat.vdf \
    && mkdir -p $HOME/.steam/steam/config \
    && cp /opt/gow/steam-compat.vdf $HOME/.steam/steam/config/config.vdf

COPY --chmod=755 00-xdg-runtime.sh /etc/cont-init.d/00-xdg-runtime.sh
COPY --chmod=755 20-fix-home-perms.sh /etc/cont-init.d/20-fix-home-perms.sh
COPY --chmod=755 system-services.sh /etc/cont-init.d/system-services.sh

# Wrap GOW startup so PulseAudio and Sunshine run as retro, then Steam
COPY --chmod=755 entrypoint.sh /opt/gow/startup.sh

# Keep Games on Whales /entrypoint.sh (runs cont-init.d, then gosu retro)
# Expose Sunshine's UI and streaming traffic ports
EXPOSE 47984-47990/tcp 47984-47990/udp 48010/tcp
