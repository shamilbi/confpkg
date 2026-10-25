#!/bin/bash
#
# Running this script will load the latest vmlinuz-generic and
# initrd-generic.img using kexec. Then rebooting will boot from
# the currently running kernel into the kexec-loaded kernel
# bypassing the BIOS/UEFI boot and the subsequent hardware
# initialization, often shaving significant time off of the
# reboot process.
#
# The defaults handle the standard named Slackware kernel, AMD and
# Intel ucode, and initrd. If you use different filenames, you can
# edit /etc/default/kexec to define them.

if [ -r /etc/default/kexec ]; then
  # Load defaults:
  . /etc/default/kexec
fi

# If there are no default settings in /etc/default/kexec, then set
# the usual defaults here:
KEXEC_AMD_UCODE=${KEXEC_AMD_UCODE:-/boot/amd-ucode.img}
KEXEC_INTEL_UCODE=${KEXEC_INTEL_UCODE:-/boot/intel-ucode.img}
KEXEC_INITRD=${KEXEC_INITRD:-/boot/initrd-generic.img}
KEXEC_KERNEL=${KEXEC_KERNEL:-/boot/vmlinuz-generic}

# If these files don't exist, clear the variables:
[ ! -r "$KEXEC_AMD_UCODE" ] && unset KEXEC_AMD_UCODE
[ ! -r "$KEXEC_INTEL_UCODE" ] && unset KEXEC_INTEL_UCODE
[ ! -r "$KEXEC_INITRD" ] && unset KEXEC_INITRD
[ ! -r "$KEXEC_KERNEL" ] && unset KEXEC_KERNEL

# Exit if we have no kernel:
if [ -z "$KEXEC_KERNEL" ]; then
  echo "Error: no kernel found."
  exit 1
fi

# Prepare a kexec initrd that bundles the ucode and base initrd:
if [ -r "$KEXEC_INITRD" ] ; then
  if [ -r "$KEXEC_AMD_UCODE" -o -r "$KEXEC_INTEL_UCODE" ] ; then
    echo "Combining initrd and ucode into /boot/initrd-kexec.img."
    cat $KEXEC_AMD_UCODE $KEXEC_INTEL_UCODE $KEXEC_INITRD > /boot/initrd-kexec.img
    KEXEC_INITRD=/boot/initrd-kexec.img
  fi
# If there is no base initrd but we have KEXEC_AMD_UCODE and/or KEXEC_INTEL_UCODE
# then use ucodes as initrd
elif [ -r "$KEXEC_AMD_UCODE" -a -r "$KEXEC_INTEL_UCODE" ]; then
  echo "No base initrd. Combining ucodes into /boot/initrd-kexec.img."
  cat $KEXEC_AMD_UCODE $KEXEC_INTEL_UCODE > /boot/initrd-kexec.img
  KEXEC_INITRD=/boot/initrd-kexec.img
elif [ -r "$KEXEC_AMD_UCODE" ]; then
  echo "No base initrd. Include the AMD ucode."
  KEXEC_INITRD=$KEXEC_AMD_UCODE
elif [ -r "$KEXEC_INTEL_UCODE" ]; then
  echo "No base initrd. Include the Intel ucode."
  KEXEC_INITRD=$KEXEC_INTEL_UCODE
fi

CMDLINE=$(cat /proc/cmdline)
CMDLINE="${CMDLINE// reset_devices/} reset_devices"
if [ -r "$KEXEC_INITRD" ]; then
  echo "Loading kernel and initrd with kexec:"
  echo "kexec -l $KEXEC_KERNEL --append=\"$CMDLINE\" --initrd=$KEXEC_INITRD"
  kexec -l $KEXEC_KERNEL --append="$CMDLINE" --initrd=$KEXEC_INITRD
  ERRCODE=$?
  if [ ! "$ERRCODE" = "0" ]; then
    echo "ERROR: kexec returned error code $ERRCODE."
    echo "kernel/initrd were not loaded."
    exit 1
  else
    echo "Kernel and initrd loaded and ready. Use 'reboot' to start them."
  fi
else # we don't have an initrd
  echo "Loading kernel with kexec:"
  echo "kexec -l $KEXEC_KERNEL --append=\"$CMDLINE\""
  kexec -l $KEXEC_KERNEL --append="$CMDLINE"
  ERRCODE=$?
  if [ ! "$ERRCODE" = "0" ]; then
    echo "ERROR: kexec returned error code $ERRCODE."
    echo "kernel was not loaded."
    exit 1
  else
    echo "Kernel loaded and ready. Use 'reboot' to start it."
  fi
fi
