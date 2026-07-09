#!/bin/sh
# Uncomment the following line if you're worried about the pipewire
# daemons running for the root account:
#[ $(id -u) = 0 ] && return 0
# Sanity check:
if [ ! -x /usr/bin/daemon -o ! -x /usr/bin/wireplumber -o ! -x /usr/bin/pipewire-pulse -o ! -x /usr/bin/pipewire ]; then
  return 0
fi
# Start pipeware daemons.
# Continue only if the user has a seat:
if loginctl | grep -q " $USER \+seat" ; then
  # Leave if pipewire is already running
  daemon --pidfiles=~/.run --name=pipewire --running && return 0
  # A subshell waiting for the pipewire socket (timeout 10 seconds: -t 10)
  # Only after the socket has been created, start other daemons
  ( inotifywait -m -t 10 --format %f -e create $XDG_RUNTIME_DIR 2>/dev/null |\
    while IFS= read -r F ; do
      if [ "$F" = pipewire-0 ]; then
        daemon -rB --pidfiles=~/.run --name=wireplumber /usr/bin/wireplumber
        daemon -rB --pidfiles=~/.run --name=pipewire-pulse /usr/bin/pipewire-pulse
        return 0
      fi
    done 
    return 0 ) &
  # start pipewire
  daemon -rB --pidfiles=~/.run --name=pipewire /usr/bin/pipewire
fi
