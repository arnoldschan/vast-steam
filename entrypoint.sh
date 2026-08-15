#!/bin/bash
# Start a virtual audio server in the background so Palworld sends sound to Moonlight
pulseaudio -D --exit-idle-time=-1 --no-cpu-limit

# Create a virtual dummy audio output sink device
pactl load-module module-null-sink sink_name=Sunshine_Audio sink_properties=device.description="Sunshine_Audio"
pactl set-default-sink Sunshine_Audio

# Run Sunshine in the background to handle user input and image streaming
sunshine &

# Execute the main Games on Whales window manager / X11 engine
exec /init
