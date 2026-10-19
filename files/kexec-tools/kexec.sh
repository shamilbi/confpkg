#!/bin/bash
# If this script is executable, then kexec will be used to load the new kernel
# and initrd preparing to boot to them directly from the running kernel with
# the next reboot.
if [ -x /boot/load-latest-kernel-initrd-with-kexec.sh ]; then
  /boot/load-latest-kernel-initrd-with-kexec.sh
fi
