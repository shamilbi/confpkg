#!/bin/sh
# Uncomment the following line if you're worried about the pipewire
# daemons running for the root account:
#[ $(id -u) = 0 ] && return 0
# Sanity check:
if [ ! -x /usr/bin/daemon -o ! -x /usr/bin/wireplumber -o ! -x /usr/bin/pipewire-pulse -o ! -x /usr/bin/pipewire ]; then
  return 0
fi
# Leave if pulseaudio is in use:
grep -q '^autospawn *= *yes' /etc/pulse/client.conf && return 0
[ -x /etc/rc.d/rc.pulseaudio ] && return 0
# Continue only if the user has a seat
if loginctl | grep -q " $USER \+seat" ; then
  # Leave if pipewire is already running
  daemon --pidfiles=~/.run --name=pipewire --running && return 0
  # Start pipewire:
  daemon -rB --pidfiles=~/.run --name=pipewire /usr/bin/pipewire
  # wait for the pipewire socket in background and start the other daemons
  (setsid bash -c '
    timeout=100
    while [ $timeout -gt 0 ]; do
      [ -S "$XDG_RUNTIME_DIR"/pipewire-0 ] && break
      sleep 0.2
      timeout=$((timeout-1))
    done
    daemon -rB --pidfiles=~/.run --name=wireplumber /usr/bin/wireplumber
    daemon -rB --pidfiles=~/.run --name=pipewire-pulse /usr/bin/pipewire-pulse
  ' < /dev/null > /dev/null 2>&1 &) 
fi
