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
    libxfixes3 \
    libxrandr2 \
    libxtst6 \
    libxinerama1 \
    && rm -rf /var/lib/apt/lists/*

# Tailscale: Moonlight uses default Sunshine ports on the 100.x tailnet IP
RUN wget -O /tmp/tailscale.tgz "https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz" \
    && tar -xzf /tmp/tailscale.tgz -C /tmp \
    && TS_DIR="$(find /tmp -maxdepth 1 -type d -name 'tailscale_*' | head -n 1)" \
    && test -n "$TS_DIR" \
    && install -m 755 "$TS_DIR/tailscale" /usr/bin/tailscale \
    && install -m 755 "$TS_DIR/tailscaled" /usr/sbin/tailscaled \
    && rm -rf /tmp/tailscale.tgz "$TS_DIR"

# Sunshine 2025.122 .deb still does X11 capture. Pull Ubuntu 24.04 SONAMEs
# (libicu74, libminiupnpc17) that Plucky does not ship.
RUN wget --tries=5 --retry-connrefused -O /tmp/sunshine.deb \
      "https://github.com/LizardByte/Sunshine/releases/download/v2025.122.141614/sunshine-ubuntu-24.04-amd64.deb" \
    && wget --tries=5 --retry-connrefused -O /tmp/libicu74.deb \
      "http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu74_74.2-1ubuntu3_amd64.deb" \
    && wget --tries=5 --retry-connrefused -O /tmp/libminiupnpc17.deb \
      "http://archive.ubuntu.com/ubuntu/pool/main/m/miniupnpc/libminiupnpc17_2.2.6-1build2_amd64.deb" \
    && apt-get update \
    && { dpkg -i /tmp/libicu74.deb /tmp/libminiupnpc17.deb /tmp/sunshine.deb || true; } \
    && apt-get install -y -f --no-install-recommends \
    && rm -f /tmp/sunshine.deb /tmp/libicu74.deb /tmp/libminiupnpc17.deb \
    && test -x /usr/bin/sunshine \
    && setcap -r /usr/bin/sunshine 2>/dev/null || true \
    && ! ldd /usr/bin/sunshine | grep -q "not found" \
    && rm -rf /var/lib/apt/lists/*

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
# 1920x1080 HDMI EDID so NVIDIA reports a connected RANDR output (Sunshine x11)
RUN python3 - << 'PY'
edid = bytes.fromhex(
    "00FFFFFFFFFFFF0010AC404045393437"
    "2D1B010380351E78EA8D85A6544A9B26"
    "0E5054A54B00714F8180A9C0D1C00101"
    "010101010101023A801871382D40582C"
    "4500132A2100001E000000FF00353348"
    "593533330A2020202020000000FC0044"
    "454C4C205032343134480A20000000FD"
    "00384C1E5311000A20202020202000FC"
)
open("/etc/X11/edid-1080p.bin", "wb").write(edid)
assert len(edid) == 128
PY
COPY --chmod=755 system-services.sh /etc/cont-init.d/system-services.sh
COPY --chmod=755 50-ui-proxy.sh /etc/cont-init.d/50-ui-proxy.sh
COPY --chmod=755 55-tailscale.sh /etc/cont-init.d/55-tailscale.sh
COPY --chmod=755 ui-proxy.py /opt/gow/ui-proxy.py
COPY --chmod=755 gs-forward.py /opt/gow/gs-forward.py

# Wrap GOW startup: PulseAudio + Sunshine as retro (Steam is launched manually)
COPY --chmod=644 sunshine.conf /opt/gow/sunshine.conf
COPY --chmod=644 apps.json /opt/gow/apps.json
COPY --chmod=755 launch-steam.sh /opt/gow/launch-steam.sh
COPY --chmod=755 entrypoint.sh /opt/gow/startup.sh

# Vast remaps EXPOSE'd ports to random host ports, which breaks Moonlight's
# fixed offsets. Do not EXPOSE GameStream ports; use host networking + a base
# port inside Vast's allocated range (SUNSHINE_BASE_PORT).
