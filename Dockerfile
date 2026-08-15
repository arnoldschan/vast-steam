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
    x11-xserver-utils \
    xauth \
    dbus-x11 \
    xserver-xorg-core \
    xserver-xorg-input-libinput \
    iptables \
    openssl \
    python3 \
    iproute2 \
    squashfs-tools \
    libxcb1 \
    libxcb-shm0 \
    libxcb-render0 \
    libx11-6 \
    && rm -rf /var/lib/apt/lists/*

# Tailscale: Moonlight uses default Sunshine ports on the 100.x tailnet IP
RUN wget -O /tmp/tailscale.tgz "https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz" \
    && tar -xzf /tmp/tailscale.tgz -C /tmp \
    && TS_DIR="$(find /tmp -maxdepth 1 -type d -name 'tailscale_*' | head -n 1)" \
    && test -n "$TS_DIR" \
    && install -m 755 "$TS_DIR/tailscale" /usr/bin/tailscale \
    && install -m 755 "$TS_DIR/tailscaled" /usr/sbin/tailscaled \
    && rm -rf /tmp/tailscale.tgz "$TS_DIR"

# Install Sunshine via AppImage (Ubuntu 25.04 / Plucky has no official .deb).
RUN wget --tries=5 --retry-connrefused -O /tmp/sunshine.AppImage \
      "https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine.AppImage" \
    && chmod +x /tmp/sunshine.AppImage \
    && mkdir -p /opt/sunshine \
    && cd /opt/sunshine \
    && /tmp/sunshine.AppImage --appimage-extract \
    && SUNSHINE_BIN="$(find /opt/sunshine/squashfs-root -type f -name sunshine -perm -111 | head -n 1)" \
    && test -n "$SUNSHINE_BIN" \
    && ln -sf "$SUNSHINE_BIN" /usr/local/bin/sunshine \
    && mkdir -p /usr/share/sunshine \
    && cp -a /opt/sunshine/squashfs-root/usr/share/sunshine/. /usr/share/sunshine/ \
    && rm -f /tmp/sunshine.AppImage

# File caps make Sunshine use KMS (black on Vast). Drop them so X11 capture works.
RUN setcap -r $(readlink -f $(which sunshine)) 2>/dev/null || true

# Games on Whales uses UNAME=retro, HOME=/home/retro (not "user")
# WORKDIR must not be $HOME: 10-setup_user.sh runs userdel -r and deletes cwd.
ENV HOME=/home/retro
ENV DISPLAY=:0
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
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
COPY --chmod=755 40-xorg.sh /etc/cont-init.d/40-xorg.sh
COPY --chmod=644 xorg-nvidia.conf /etc/X11/xorg-nvidia.conf
COPY --chmod=755 system-services.sh /etc/cont-init.d/system-services.sh
COPY --chmod=755 50-ui-proxy.sh /etc/cont-init.d/50-ui-proxy.sh
COPY --chmod=755 55-tailscale.sh /etc/cont-init.d/55-tailscale.sh
COPY --chmod=755 ui-proxy.py /opt/gow/ui-proxy.py
COPY --chmod=755 gs-forward.py /opt/gow/gs-forward.py

# Wrap GOW startup: PulseAudio + Sunshine as retro (Steam is launched manually)
COPY --chmod=644 sunshine.conf /opt/gow/sunshine.conf
COPY --chmod=755 entrypoint.sh /opt/gow/startup.sh

# Vast remaps EXPOSE'd ports to random host ports, which breaks Moonlight's
# fixed offsets. Do not EXPOSE GameStream ports; use host networking + a base
# port inside Vast's allocated range (SUNSHINE_BASE_PORT).
