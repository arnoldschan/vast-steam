# Use the base Games on Whales Steam image which includes X11 and Nvidia libraries
FROM ghcr.io/games-on-whales/steam:master

# Switch to root to install core packages and system dependencies
USER root

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install utilities, virtual audio drivers, and Sunshine dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    libcap2-bin \
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install the latest stable Sunshine Ubuntu 22.04 amd64 package
RUN wget -O /tmp/sunshine.deb \
    "https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-ubuntu-22.04-amd64.deb" \
    && apt-get update \
    && apt-get install -y /tmp/sunshine.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/sunshine.deb

# Give Sunshine capabilities to create virtual input devices and intercept GPU frames
RUN setcap cap_sys_admin+p $(which sunshine)

# Switch back to the default non-root user included in the base image
USER user
ENV HOME=/home/user
WORKDIR $HOME

# Pre-create directory structures for the persistent volume mounts
RUN mkdir -p $HOME/.steam/steam/config/ \
    && mkdir -p $HOME/.local/share/Steam \
    && mkdir -p $HOME/.config/sunshine

# Enforce Steam to automatically map Palworld to Proton Experimental
RUN echo '{"CompatToolMapping":{"2394300":{"name":"proton_experimental","config":"","priority":250}}}' \
    > $HOME/.steam/steam/config/config.vdf

# Copy an entrypoint script to launch virtual audio and display automatically
COPY --chown=user:user entrypoint.sh /home/user/entrypoint.sh
RUN chmod +x /home/user/entrypoint.sh

# Expose Sunshine's UI and streaming traffic ports
EXPOSE 47984-47990/tcp 47984-47990/udp 48010/tcp

ENTRYPOINT ["/home/user/entrypoint.sh"]
