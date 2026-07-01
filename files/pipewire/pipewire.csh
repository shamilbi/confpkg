#!/bin/csh
# Enable pipewire for use on the console without X or Wayland:
loginctl | grep "$USER" | grep -q seat
if ( $status == 0 ) then
  daemon -rB --pidfiles=~/.run --name=wireplumber /usr/bin/wireplumber
  daemon -rB --pidfiles=~/.run --name=pipewire-pulse /usr/bin/pipewire-pulse
  daemon -rB --pidfiles=~/.run --name=pipewire /usr/bin/pipewire
endif
