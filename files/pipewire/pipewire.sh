#!/bin/sh
# Enable pipewire for use on the console without X or Wayland:
if loginctl | grep "$USER" | grep -q seat ; then
  daemon -rB --pidfiles=~/.run --name=wireplumber /usr/bin/wireplumber
  daemon -rB --pidfiles=~/.run --name=pipewire-pulse /usr/bin/pipewire-pulse
  daemon -rB --pidfiles=~/.run --name=pipewire /usr/bin/pipewire
fi
